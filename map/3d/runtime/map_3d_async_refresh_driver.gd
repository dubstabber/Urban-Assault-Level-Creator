extends RefCounted

const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const UnitOverlayController := preload("res://map/3d/overlays/map_3d_unit_overlay_controller.gd")

var _renderer_node = null
var _context = null
var _scene = null
var _build = null

var is_building_3d := false
var total_chunks := 0
var completed_chunks := 0
var status_text := ""

var _refresh_pending := false
var _refresh_reframe_pending := false
var _refresh_deferred := false
var _refresh_requested_at_usec := 0

var _async_pending_reframe_camera := false
var _async_requested_restart := false
var _async_requested_reframe := false
var _async_overlay_apply_active := false
var _async_overlay_apply_state: Dictionary = {}
var _async_overlay_descriptors: Array = []
var _async_dynamic_overlay_descriptors: Array = []
var _async_overlay_metrics: Dictionary = {}
var _async_build_started_usec := 0
var _async_overlay_apply_started_usec := 0
var _overlay_only_refresh_requested := false
var _dynamic_overlay_refresh_requested := false
var _async_overlay_descriptor_dynamic_only := false
var _pending_unit_changes: Array = []


func bind(renderer, context_port, scene_port, build_state_port) -> void:
	_renderer_node = renderer
	_context = context_port
	_scene = scene_port
	_build = build_state_port


func get_build_state_snapshot() -> Dictionary:
	return {
		"is_building_3d": is_building_3d,
		"completed_chunks": completed_chunks,
		"total_chunks": total_chunks,
		"status_text": status_text,
	}


func has_pending_refresh() -> bool:
	return _refresh_pending


func get_refresh_requested_at_usec() -> int:
	return _refresh_requested_at_usec


func clear_refresh_requested_at_usec() -> void:
	_refresh_requested_at_usec = 0


func is_async_overlay_apply_active() -> bool:
	return _async_overlay_apply_active


func emit_build_state(building: bool, completed: int, total: int, status: String) -> void:
	is_building_3d = building
	completed_chunks = maxi(completed, 0)
	total_chunks = maxi(total, 0)
	status_text = status
	_renderer_node.build_state_changed.emit(is_building_3d, completed_chunks, total_chunks, status_text)


func begin_build_state(total_chunk_count: int, status: String) -> void:
	emit_build_state(true, 0, total_chunk_count, status)


func update_build_progress(completed: int, total: int, status: String = "") -> void:
	var text := status_text if status.is_empty() else status
	emit_build_state(true, completed, total, text)


func end_build_state(success: bool, status: String = "") -> void:
	emit_build_state(false, completed_chunks, total_chunks, status)
	_renderer_node.build_finished.emit(success)


func request_refresh(reframe_camera: bool) -> void:
	if not _refresh_pending and _refresh_requested_at_usec <= 0:
		_refresh_requested_at_usec = Time.get_ticks_usec()
	_refresh_pending = true
	_refresh_reframe_pending = _refresh_reframe_pending or reframe_camera
	if not _context.preview_refresh_active():
		return
	if _refresh_deferred:
		return
	_refresh_deferred = true
	_renderer_node.call_deferred("_apply_pending_refresh")


func apply_pending_refresh() -> void:
	_refresh_deferred = false
	if not _refresh_pending or not _context.preview_refresh_active():
		return
	var reframe_camera = _refresh_reframe_pending
	_refresh_pending = false
	_refresh_reframe_pending = false
	if _build.is_async_pipeline_active():
		_async_requested_restart = true
		_async_requested_reframe = _async_requested_reframe or reframe_camera
		_build.cancel_async_initial_build()
		return
	if _dynamic_overlay_refresh_requested:
		if start_async_dynamic_overlay_refresh(reframe_camera):
			return
	if _overlay_only_refresh_requested or can_use_overlay_only_refresh():
		if start_async_overlay_only_refresh(reframe_camera):
			return
	if try_start_async_initial_build(reframe_camera):
		return
	_build.build_from_current_map()
	_scene.bump_3d_viewport_rendering()
	if reframe_camera and _scene.is_inside_tree():
		_build.set_camera_framed(false)
		_build.frame_if_needed()


func process_frame() -> void:
	pump_async_initial_build()
	pump_async_overlay_descriptor_build()
	pump_async_overlay_apply()


func on_units_changed(changes: Array) -> void:
	var normalized := normalize_unit_changes(changes)
	if normalized.is_empty():
		return
	if not _context.preview_refresh_active():
		enqueue_pending_unit_changes(normalized)
		return
	if _build.is_async_pipeline_active():
		enqueue_pending_unit_changes(normalized)
		return
	if normalized.size() > _renderer_node._MAX_INCREMENTAL_UNIT_BATCH:
		request_dynamic_overlay_refresh()
		return
	if apply_unit_change_batch(normalized):
		return
	request_dynamic_overlay_refresh()


func request_overlay_only_refresh() -> void:
	_overlay_only_refresh_requested = true
	request_refresh(false)


func request_dynamic_overlay_refresh() -> void:
	_dynamic_overlay_refresh_requested = true
	request_refresh(false)


func flush_pending_unit_changes() -> bool:
	if _pending_unit_changes.is_empty():
		return false
	if not _context.preview_refresh_active() or _build.is_async_pipeline_active():
		return false
	var pending := normalize_unit_changes(_pending_unit_changes)
	_pending_unit_changes.clear()
	if pending.is_empty():
		return false
	if pending.size() > _renderer_node._MAX_INCREMENTAL_UNIT_BATCH:
		request_dynamic_overlay_refresh()
		return true
	if apply_unit_change_batch(pending):
		return true
	request_dynamic_overlay_refresh()
	return true


func can_use_overlay_only_refresh() -> bool:
	var chunk_runtime = _build.chunk_runtime()
	if chunk_runtime.initial_build_in_progress:
		return false
	if chunk_runtime.has_dirty_chunks():
		return false
	if _scene.terrain_chunk_nodes().is_empty() and _scene.edge_chunk_nodes().is_empty():
		return false
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	if Vector2i(w, h) != chunk_runtime.last_map_dimensions:
		return false
	if int(cmd.level_set) != chunk_runtime.last_level_set:
		return false
	return true


func start_async_overlay_only_refresh(reframe_camera: bool) -> bool:
	if not can_use_overlay_only_refresh():
		_overlay_only_refresh_requested = false
		return false
	if not sync_async_overlay_state_from_current_map():
		_overlay_only_refresh_requested = false
		return false
	_build.sync_terrain_overlay_animation_mode_from_editor()
	_overlay_only_refresh_requested = false
	var coordinator = _build.coordinator()
	coordinator.build_generation_id += 1
	coordinator.active_build_generation_id = coordinator.build_generation_id
	coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_build_started_usec = Time.get_ticks_usec()
	coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	begin_build_state(1, "Preparing overlays...")
	start_async_overlay_descriptor_build()
	return true


func start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	if not can_use_overlay_only_refresh():
		_dynamic_overlay_refresh_requested = false
		return false
	if not sync_async_overlay_state_from_current_map():
		_dynamic_overlay_refresh_requested = false
		return false
	_build.sync_terrain_overlay_animation_mode_from_editor()
	_dynamic_overlay_refresh_requested = false
	_overlay_only_refresh_requested = false
	var coordinator = _build.coordinator()
	coordinator.build_generation_id += 1
	coordinator.active_build_generation_id = coordinator.build_generation_id
	coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_build_started_usec = Time.get_ticks_usec()
	coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	begin_build_state(1, "Updating vehicles...")
	start_async_overlay_descriptor_build(true)
	return true


func sync_async_overlay_state_from_current_map() -> bool:
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if typ.size() != w * h:
		return false
	var game_data_type: String = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var effective_typ = _build.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	_build.set_async_map_snapshot(effective_typ, blg, w, h, int(cmd.level_set), game_data_type)
	return true


func try_start_async_initial_build(reframe_camera: bool) -> bool:
	var chunk_runtime = _build.chunk_runtime()
	if not chunk_runtime.chunked_terrain_enabled:
		return false
	if not chunk_runtime.has_dirty_chunks():
		return false
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	var hgt: PackedByteArray = cmd.hgt_map
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2) or typ.size() != w * h:
		return false
	var pre: Node = _context.preloads()
	if pre == null:
		return false
	var level_set := int(cmd.level_set)
	var requires_full_rebuild: bool = _build.needs_full_rebuild(w, h, level_set)
	if requires_full_rebuild:
		_scene.clear_chunk_nodes()
		chunk_runtime.clear_authored_caches()
		chunk_runtime.prepare_chunked_full_rebuild(w, h, level_set)
	if _scene.terrain_chunk_nodes().is_empty():
		_build.invalidate_all_chunks(w, h)
	var chunk_list: Array = _build.dirty_chunks_sorted_by_priority(w, h)
	if chunk_list.is_empty():
		return false
	var game_data_type: String = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var effective_typ: PackedByteArray = _build.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	var snapshot := {
		"w": w,
		"h": h,
		"hgt": hgt,
		"effective_typ": effective_typ,
		"level_set": level_set,
		"chunk_list": chunk_list,
		"edge_overlay_enabled": _build.edge_overlay_enabled(),
		"surface_type_map": pre.surface_type_map,
		"subsector_patterns": pre.subsector_patterns,
		"tile_mapping": pre.tile_mapping,
		"tile_remap": pre.tile_remap,
		"subsector_idx_remap": pre.subsector_idx_remap,
		"lego_defs": pre.lego_defs,
	}
	var coordinator = _build.coordinator()
	coordinator.build_generation_id += 1
	coordinator.active_build_generation_id = coordinator.build_generation_id
	coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_build_started_usec = Time.get_ticks_usec()
	_build.set_async_map_snapshot(effective_typ, blg, w, h, level_set, game_data_type)
	coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_build.clear_async_chunk_payloads()
	_build.set_async_worker_state(false, false, "")
	var total: int = chunk_list.size()
	begin_build_state(total, "Rendering map...")
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_initial_build_worker").bind(snapshot, coordinator.active_build_generation_id))
	if err != OK:
		end_build_state(false, "3D render worker could not start")
		return false
	coordinator.set_async_initial_thread(thread)
	return true


func _async_initial_build_worker(snapshot: Dictionary, generation_id: int) -> void:
	var w := int(snapshot.get("w", 0))
	var h := int(snapshot.get("h", 0))
	var hgt: PackedByteArray = snapshot.get("hgt", PackedByteArray())
	var effective_typ: PackedByteArray = snapshot.get("effective_typ", PackedByteArray())
	var level_set := int(snapshot.get("level_set", 0))
	var edge_overlay_enabled := bool(snapshot.get("edge_overlay_enabled", true))
	var surface_type_map = snapshot.get("surface_type_map", {})
	var subsector_patterns = snapshot.get("subsector_patterns", {})
	var tile_mapping = snapshot.get("tile_mapping", {})
	var tile_remap = snapshot.get("tile_remap", {})
	var subsector_idx_remap = snapshot.get("subsector_idx_remap", {})
	var lego_defs = snapshot.get("lego_defs", {})
	var chunk_list: Array = snapshot.get("chunk_list", [])
	for chunk_entry in chunk_list:
		if _build.is_async_cancel_requested(generation_id):
			break
		var chunk_coord := Vector2i(chunk_entry)
		var terrain_result := TerrainBuilder.build_chunk_mesh_with_textures(
			chunk_coord,
			hgt,
			effective_typ,
			w,
			h,
			surface_type_map,
			subsector_patterns,
			tile_mapping,
			tile_remap,
			subsector_idx_remap,
			lego_defs,
			level_set,
			true
		)
		var edge_result := {}
		if edge_overlay_enabled:
			edge_result = SlurpBuilder.build_chunk_edge_overlay_result(
				chunk_coord,
				hgt,
				w,
				h,
				effective_typ,
				surface_type_map,
				level_set
			)
		_build.push_async_chunk_payload({
			"generation_id": generation_id,
			"chunk_coord": chunk_coord,
			"terrain_result": terrain_result,
			"edge_result": edge_result,
			"has_edge_result": edge_overlay_enabled,
		})
	_build.set_async_worker_state(true, false, "")


func pump_async_initial_build() -> void:
	if not _build.is_async_build_active():
		return
	for _i in _renderer_node._ASYNC_APPLY_RESULTS_PER_FRAME:
		var payload: Dictionary = _build.pop_async_chunk_payload()
		if payload.is_empty():
			break
		if int(payload.get("generation_id", -1)) != _build.coordinator().active_build_generation_id:
			continue
		if _build.coordinator()._async_cancel_requested:
			continue
		apply_async_chunk_payload(payload)
	var state: Dictionary = _build.get_async_worker_state()
	if bool(state.get("done", false)) and _build.async_chunk_payload_count() == 0:
		finish_async_initial_build()


func apply_async_chunk_payload(payload: Dictionary) -> void:
	var chunk_coord := Vector2i(payload.get("chunk_coord", Vector2i.ZERO))
	var terrain_result: Dictionary = payload.get("terrain_result", {})
	var chunk_node: MeshInstance3D = _scene.get_or_create_terrain_chunk_node(chunk_coord)
	chunk_node.mesh = terrain_result.get("mesh", null)
	var pre: Node = _context.preloads()
	if pre != null and chunk_node.mesh != null:
		_scene.apply_sector_top_materials(chunk_node.mesh, pre, terrain_result.get("surface_to_surface_type", {}))
	var chunk_authored_descriptors: Array = terrain_result.get("authored_piece_descriptors", []).duplicate()
	if bool(payload.get("has_edge_result", false)):
		var edge_result: Dictionary = payload.get("edge_result", {})
		var edge_chunk_node: MeshInstance3D = _scene.get_or_create_edge_chunk_node(chunk_coord)
		edge_chunk_node.mesh = edge_result.get("mesh", null)
		if pre != null and edge_chunk_node.mesh != null:
			_scene.apply_edge_surface_materials(
				edge_chunk_node.mesh,
				pre,
				edge_result.get("fallback_horiz_keys", []),
				edge_result.get("fallback_vert_keys", [])
			)
		chunk_authored_descriptors.append_array(edge_result.get("authored_piece_descriptors", []))
	_build.update_terrain_authored_cache_for_chunk(chunk_coord, chunk_authored_descriptors)
	_build.chunk_runtime().erase_dirty_chunk(chunk_coord)
	var done := completed_chunks + 1
	update_build_progress(done, total_chunks, "Rendering map... %d / %d" % [done, total_chunks])
	_scene.bump_3d_viewport_rendering()


func finish_async_initial_build() -> void:
	_build.join_async_thread()
	var cancelled: bool = _build.coordinator()._async_cancel_requested
	var failed := bool(_build.get_async_worker_state().get("failed", false))
	var should_restart := _async_requested_restart
	var restart_reframe := _async_requested_reframe
	if cancelled:
		end_build_state(false, "3D render cancelled")
		reset_async_build_state()
		if should_restart:
			request_refresh(restart_reframe)
		return
	if failed:
		end_build_state(false, "3D render failed")
		reset_async_build_state()
		request_refresh(restart_reframe)
		return
	start_async_overlay_descriptor_build()


func start_async_overlay_descriptor_build(dynamic_only: bool = false) -> void:
	update_build_progress(total_chunks, total_chunks, "Preparing overlays...")
	var support_descriptors: Array = _build.chunk_runtime().get_support_descriptors()
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		start_async_overlay_apply(support_descriptors, [], _build.make_empty_build_metrics())
		return
	var host_station_snapshot: Array = []
	var squad_snapshot: Array = []
	if cmd.host_stations != null and is_instance_valid(cmd.host_stations):
		host_station_snapshot = _build.snapshot_host_station_nodes(cmd.host_stations.get_children())
	if cmd.squads != null and is_instance_valid(cmd.squads):
		squad_snapshot = _build.snapshot_squad_nodes(cmd.squads.get_children())
	var payload := {
		"generation_id": _build.coordinator().active_build_generation_id,
		"dynamic_only": dynamic_only,
		"support_descriptors": support_descriptors,
		"blg": _build.async_blg(),
		"effective_typ": _build.async_effective_typ(),
		"set_id": _build.async_level_set(),
		"hgt": cmd.hgt_map,
		"w": _build.async_w(),
		"h": _build.async_h(),
		"game_data_type": _build.async_game_data_type(),
		"host_station_snapshot": host_station_snapshot,
		"squad_snapshot": squad_snapshot,
	}
	_async_overlay_descriptor_dynamic_only = dynamic_only
	_build.set_async_overlay_descriptor_stage("Preparing overlays: queued")
	_build.set_async_overlay_descriptor_state(false, false, {}, {})
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_overlay_descriptor_worker").bind(payload))
	if err != OK:
		start_async_overlay_apply(support_descriptors, [], _build.make_empty_build_metrics())
		return
	_build.coordinator().set_async_overlay_descriptor_thread(thread)


func _async_overlay_descriptor_worker(payload: Dictionary) -> void:
	var generation_id := int(payload.get("generation_id", -1))
	var dynamic_only := bool(payload.get("dynamic_only", false))
	_build.set_async_overlay_descriptor_stage("Preparing overlays: starting")
	if _build.is_async_cancel_requested(generation_id):
		_build.set_async_overlay_descriptor_state(true, false, {}, {})
		return
	var metrics: Dictionary = _build.make_empty_build_metrics()
	var started_usec := Time.get_ticks_usec()
	var support_descriptors: Array = payload.get("support_descriptors", []).duplicate()
	var static_descriptors: Array = support_descriptors.duplicate()
	var dynamic_descriptors: Array = []
	var blg: PackedByteArray = payload.get("blg", PackedByteArray())
	var effective_typ: PackedByteArray = payload.get("effective_typ", PackedByteArray())
	var set_id := int(payload.get("set_id", 1))
	var hgt: PackedByteArray = payload.get("hgt", PackedByteArray())
	var w := int(payload.get("w", 0))
	var h := int(payload.get("h", 0))
	var game_data_type := String(payload.get("game_data_type", "original"))
	var host_station_snapshot: Array = payload.get("host_station_snapshot", [])
	var squad_snapshot: Array = payload.get("squad_snapshot", [])
	var static_started_usec := Time.get_ticks_usec()
	if not dynamic_only:
		_build.set_async_overlay_descriptor_stage("Preparing overlays: building attachments")
		static_descriptors.append_array(_build.build_blg_attachment_descriptors(blg, effective_typ, set_id, hgt, w, h, support_descriptors, game_data_type))
	metrics["static_overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(static_started_usec)
	if _build.is_async_cancel_requested(generation_id):
		_build.set_async_overlay_descriptor_state(true, false, {}, {})
		return
	_build.set_async_overlay_descriptor_stage("Preparing overlays: host stations")
	var dynamic_started_usec := Time.get_ticks_usec()
	dynamic_descriptors.append_array(_build.build_host_station_descriptors_from_snapshot(host_station_snapshot, set_id, hgt, w, h, support_descriptors, metrics))
	if _build.is_async_cancel_requested(generation_id):
		_build.set_async_overlay_descriptor_state(true, false, {}, {})
		return
	_build.set_async_overlay_descriptor_stage("Preparing overlays: squads")
	dynamic_descriptors.append_array(_build.build_squad_descriptors_from_snapshot(squad_snapshot, set_id, hgt, w, h, support_descriptors, game_data_type, metrics))
	metrics["dynamic_overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(dynamic_started_usec)
	metrics["overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(started_usec)
	metrics["overlay_descriptor_count"] = static_descriptors.size() + dynamic_descriptors.size()
	_build.set_async_overlay_descriptor_stage("Preparing overlays: complete")
	_build.set_async_overlay_descriptor_state(true, false, {
		"static_descriptors": static_descriptors,
		"dynamic_descriptors": dynamic_descriptors,
	}, metrics)


func pump_async_overlay_descriptor_build() -> void:
	if not _build.is_async_overlay_descriptor_active():
		return
	var stage: String = _build.get_async_overlay_descriptor_stage()
	if not stage.is_empty():
		update_build_progress(total_chunks, total_chunks, stage)
	if _build.coordinator()._async_cancel_requested:
		_build.join_async_overlay_descriptor_thread()
		var should_restart := _async_requested_restart
		var restart_reframe := _async_requested_reframe
		end_build_state(false, "3D render cancelled")
		reset_async_build_state()
		if should_restart:
			request_refresh(restart_reframe)
		return
	var state: Dictionary = _build.get_async_overlay_descriptor_state()
	if not bool(state.get("done", false)):
		return
	_build.join_async_overlay_descriptor_thread()
	if _build.coordinator()._async_cancel_requested:
		return
	if bool(state.get("failed", false)):
		end_build_state(false, "Overlay descriptor generation failed")
		reset_async_build_state()
		if _async_requested_restart:
			request_refresh(_async_requested_reframe)
		return
	var result_payload: Dictionary = state.get("result", {})
	var static_descriptors: Array = result_payload.get("static_descriptors", [])
	var dynamic_descriptors: Array = result_payload.get("dynamic_descriptors", [])
	var metrics: Dictionary = state.get("metrics", {})
	if _async_overlay_descriptor_dynamic_only:
		var dynamic_apply_started_usec := Time.get_ticks_usec()
		_scene.apply_dynamic_overlay(dynamic_descriptors)
		metrics["dynamic_overlay_apply_ms"] = _build.elapsed_ms_since(dynamic_apply_started_usec)
		_build.finalize_build_metrics(metrics, _async_build_started_usec)
		end_build_state(true, "3D map ready")
		_scene.bump_3d_viewport_rendering()
		if _async_pending_reframe_camera and _scene.is_inside_tree():
			_build.set_camera_framed(false)
			_build.frame_if_needed()
		var should_restart := _async_requested_restart
		var restart_reframe := _async_requested_reframe
		reset_async_build_state()
		if should_restart:
			request_refresh(restart_reframe)
			return
		flush_pending_unit_changes()
		return
	start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)


func start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_scene.ensure_overlay_nodes()
	_async_overlay_descriptors = static_descriptors
	_async_dynamic_overlay_descriptors = dynamic_descriptors
	_async_overlay_metrics = metrics.duplicate(true)
	_build.static_overlay_index().replace_all(static_descriptors)
	_async_overlay_apply_state = _build.overlay_apply_manager().begin_apply_overlay_node(_scene.authored_overlay(), _async_overlay_descriptors)
	_async_overlay_apply_started_usec = Time.get_ticks_usec()
	_async_overlay_apply_active = true
	UATerrainPieceLibrary.reset_piece_overlay_build_counters()
	update_build_progress(total_chunks, total_chunks, "Applying 3D overlays... 0%")


func pump_async_overlay_apply() -> void:
	if not _async_overlay_apply_active:
		return
	if _build.coordinator()._async_cancel_requested:
		_async_overlay_apply_active = false
		end_build_state(false, "3D render cancelled")
		reset_async_build_state()
		if _async_requested_restart:
			request_refresh(_async_requested_reframe)
		return
	var done: bool = _build.overlay_apply_manager().apply_overlay_node_step(_scene.authored_overlay(), _async_overlay_apply_state, _renderer_node._ASYNC_OVERLAY_APPLY_OPS_PER_FRAME)
	var progress: Dictionary = _build.overlay_apply_manager().overlay_apply_progress(_async_overlay_apply_state)
	var progress_done := int(progress.get("done", 0))
	var progress_total := int(progress.get("total", 0))
	var pct := 100
	if progress_total > 0:
		pct = int(round((float(progress_done) / float(progress_total)) * 100.0))
	update_build_progress(total_chunks, total_chunks, "Applying 3D overlays... %d%%" % clampi(pct, 0, 100))
	_scene.bump_3d_viewport_rendering()
	if done:
		finalize_async_overlay_apply()


func finalize_async_overlay_apply() -> void:
	if _scene.authored_overlay() != null and is_instance_valid(_scene.authored_overlay()):
		_build.overlay_apply_manager().finalize_apply_overlay_node(_scene.authored_overlay(), _async_overlay_apply_state)
	var dynamic_apply_started_usec := Time.get_ticks_usec()
	_scene.apply_dynamic_overlay(_async_dynamic_overlay_descriptors)
	_scene.apply_geometry_distance_culling_to_overlay()
	var metrics := _async_overlay_metrics
	var pc: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	metrics["overlay_node_creation_ms"] = _build.elapsed_ms_since(_async_overlay_apply_started_usec)
	metrics["static_overlay_apply_ms"] = metrics["overlay_node_creation_ms"]
	metrics["dynamic_overlay_apply_ms"] = _build.elapsed_ms_since(dynamic_apply_started_usec)
	_build.finalize_build_metrics(metrics, _async_build_started_usec)
	_build.chunk_runtime().initial_build_in_progress = false
	_build.chunk_runtime().initial_build_accumulated_authored_descriptors.clear()
	_async_overlay_apply_active = false
	end_build_state(true, "3D map ready")
	_scene.bump_3d_viewport_rendering()
	if _async_pending_reframe_camera and _scene.is_inside_tree():
		_build.set_camera_framed(false)
		_build.frame_if_needed()
	var should_restart := _async_requested_restart
	var restart_reframe := _async_requested_reframe
	reset_async_build_state()
	if should_restart:
		request_refresh(restart_reframe)
	elif _refresh_pending and _context.preview_refresh_active():
		request_refresh(_refresh_reframe_pending)
	else:
		flush_pending_unit_changes()


func reset_async_build_state() -> void:
	_build.coordinator().reset_async_state()
	_async_pending_reframe_camera = false
	_async_build_started_usec = 0
	_async_requested_restart = false
	_async_requested_reframe = false
	_async_overlay_apply_active = false
	_async_overlay_apply_state.clear()
	_async_overlay_descriptors.clear()
	_async_dynamic_overlay_descriptors.clear()
	_async_overlay_metrics.clear()
	_async_overlay_apply_started_usec = 0
	_overlay_only_refresh_requested = false
	_dynamic_overlay_refresh_requested = false
	_async_overlay_descriptor_dynamic_only = false


func normalize_unit_changes(changes: Array) -> Array:
	var normalized: Array = []
	var by_key := {}
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		var unit_kind := String(change.get("kind", ""))
		var unit_id := int(change.get("unit_id", 0))
		var action := String(change.get("action", ""))
		if unit_kind.is_empty() or unit_id <= 0 or action.is_empty():
			continue
		by_key["%s:%d" % [unit_kind, unit_id]] = {
			"kind": unit_kind,
			"unit_id": unit_id,
			"action": action,
		}
	for value in by_key.values():
		normalized.append(value)
	return normalized


func enqueue_pending_unit_changes(changes: Array) -> void:
	if changes.is_empty():
		return
	var merged: Array = _pending_unit_changes.duplicate(true)
	merged.append_array(changes)
	_pending_unit_changes = normalize_unit_changes(merged)


func apply_unit_change_batch(changes: Array) -> bool:
	if changes.is_empty():
		return false
	if not can_use_overlay_only_refresh():
		return false
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return false
	_build.unit_runtime_index().apply_changes(cmd, changes)
	var support_descriptors: Array = _build.chunk_runtime().get_support_descriptors()
	_scene.ensure_overlay_nodes()
	var game_data_type: String = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var applied := UnitOverlayController.apply_unit_changes(_scene.dynamic_overlay(), changes, cmd, support_descriptors, game_data_type, _build.unit_runtime_index())
	if not applied:
		return false
	_scene.apply_geometry_distance_culling_to_overlay()
	_scene.bump_3d_viewport_rendering()
	return true

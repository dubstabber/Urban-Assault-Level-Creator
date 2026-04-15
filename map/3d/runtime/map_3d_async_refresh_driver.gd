extends RefCounted

const AsyncOverlayPipeline := preload("res://map/3d/runtime/map_3d_async_overlay_pipeline.gd")
const ChunkBuildExecutor := preload("res://map/3d/services/map_3d_chunk_build_executor.gd")
const OverlayPlanBuilder := preload("res://map/3d/services/map_3d_overlay_plan_builder.gd")
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
var _async_processed_chunks: Array = []
var _async_chunk_authored_descriptors: Array = []
var _overlay_pipeline := AsyncOverlayPipeline.new()


func bind(renderer, context_port, scene_port, build_state_port) -> void:
	_renderer_node = renderer
	_context = context_port
	_scene = scene_port
	_build = build_state_port
	_overlay_pipeline.bind(self, renderer, context_port, scene_port, build_state_port)


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
	return _overlay_pipeline.start_async_overlay_only_refresh(reframe_camera)


func start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	return _overlay_pipeline.start_async_dynamic_overlay_refresh(reframe_camera)


func sync_async_overlay_state_from_current_map() -> bool:
	return _overlay_pipeline.sync_async_overlay_state_from_current_map()


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
	_async_processed_chunks.clear()
	_async_chunk_authored_descriptors.clear()
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
		var chunk_result := ChunkBuildExecutor.build_chunk_result(
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
			edge_overlay_enabled
		)
		chunk_result["generation_id"] = generation_id
		_build.push_async_chunk_payload(chunk_result)
	_build.set_async_worker_state(true, false, "")


func pump_async_initial_build() -> void:
	if not _build.is_async_build_active():
		return
	var apply_budget := maxi(int(_renderer_node._async_chunk_apply_budget()), 1)
	for _i in range(apply_budget):
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
	var pre: Node = _context.preloads()
	var apply_result := ChunkBuildExecutor.apply_chunk_result(_scene, _build.chunk_runtime(), payload, pre)
	var chunk_coord := Vector2i(apply_result.get("chunk_coord", Vector2i.ZERO))
	_async_processed_chunks.append(chunk_coord)
	_async_chunk_authored_descriptors.append_array(apply_result.get("descriptors", []))
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
	if try_finalize_async_localized_overlay_refresh():
		return
	start_async_overlay_descriptor_build()


func try_finalize_async_localized_overlay_refresh() -> bool:
	var chunk_runtime = _build.chunk_runtime()
	if chunk_runtime.initial_build_in_progress:
		return false
	if _async_processed_chunks.is_empty():
		return false
	var localized_overlay_sectors: Array[Vector2i] = _build.localized_overlay_sector_list()
	if localized_overlay_sectors.is_empty():
		return false
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	var hgt: PackedByteArray = cmd.hgt_map
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if hgt.size() != (w + 2) * (h + 2) or typ.size() != w * h or blg.size() != w * h:
		return false
	var level_set := int(cmd.level_set)
	var game_data_type: String = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var effective_typ: PackedByteArray = _build.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	_build.set_async_map_snapshot(effective_typ, blg, w, h, level_set, game_data_type)
	var metrics: Dictionary = _build.make_empty_build_metrics()
	metrics["incremental_rebuild"] = true
	metrics["chunks_rebuilt"] = _async_processed_chunks.size()
	metrics["dirty_chunk_count"] = _async_processed_chunks.size()
	metrics["dirty_sector_count"] = localized_overlay_sectors.size()
	var localized_dynamic_sectors: Array[Vector2i] = _build.localized_dynamic_sector_list()
	var rebuild_unit_index: bool = _build.unit_runtime_index().is_empty() or localized_dynamic_sectors.is_empty()
	if rebuild_unit_index:
		_build.unit_runtime_index().rebuild_from_map(cmd)
	metrics["unit_index_rebuilt"] = rebuild_unit_index
	var support_descriptors: Array = chunk_runtime.get_support_descriptors()
	metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
	var overlay_descriptor_started_usec := Time.get_ticks_usec()
	var localized_static_descriptors: Array = OverlayPlanBuilder.build_localized_static_descriptors(
		blg,
		effective_typ,
		level_set,
		hgt,
		w,
		h,
		localized_overlay_sectors,
		_async_chunk_authored_descriptors,
		game_data_type,
		metrics
	)
	metrics["static_overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(overlay_descriptor_started_usec)
	metrics["overlay_descriptor_generation_ms"] = metrics["static_overlay_descriptor_generation_ms"]
	metrics["overlay_descriptor_count"] = localized_static_descriptors.size()
	UATerrainPieceLibrary.reset_piece_overlay_build_counters()
	var overlay_node_started_usec := Time.get_ticks_usec()
	_build.apply_localized_static_overlay_refresh(localized_static_descriptors, _async_processed_chunks, localized_overlay_sectors, level_set, w, h)
	metrics["static_overlay_apply_ms"] = _build.elapsed_ms_since(overlay_node_started_usec)
	_build.apply_localized_dynamic_overlay_refresh(cmd, level_set, hgt, w, h, support_descriptors, game_data_type, localized_dynamic_sectors, metrics)
	metrics["overlay_node_creation_ms"] = float(metrics.get("static_overlay_apply_ms", 0.0)) + float(metrics.get("dynamic_overlay_apply_ms", 0.0))
	metrics["overlay_descriptor_generation_ms"] = float(metrics.get("static_overlay_descriptor_generation_ms", 0.0)) + float(metrics.get("dynamic_overlay_descriptor_generation_ms", 0.0))
	metrics["localized_overlay_refresh"] = true
	var piece_counters: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(piece_counters.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(piece_counters.get("piece_overlay_slow_path", 0))
	_build.finalize_build_metrics(metrics, _async_build_started_usec)
	end_build_state(true, "3D map ready")
	_scene.bump_3d_viewport_rendering()
	if _async_pending_reframe_camera and _scene.is_inside_tree():
		_build.set_camera_framed(false)
		_build.frame_if_needed()
	var should_restart: bool = _async_requested_restart
	var restart_reframe: bool = _async_requested_reframe
	reset_async_build_state()
	if should_restart:
		request_refresh(restart_reframe)
	elif _refresh_pending and _context.preview_refresh_active():
		request_refresh(_refresh_reframe_pending)
	return true


func start_async_overlay_descriptor_build(dynamic_only: bool = false) -> void:
	_overlay_pipeline.start_async_overlay_descriptor_build(dynamic_only)


func _async_overlay_descriptor_worker(payload: Dictionary) -> void:
	_overlay_pipeline._async_overlay_descriptor_worker(payload)


func pump_async_overlay_descriptor_build() -> void:
	_overlay_pipeline.pump_async_overlay_descriptor_build()


func start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_overlay_pipeline.start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)


func pump_async_overlay_apply() -> void:
	_overlay_pipeline.pump_async_overlay_apply()


func finalize_async_overlay_apply() -> void:
	_overlay_pipeline.finalize_async_overlay_apply()


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
	_async_processed_chunks.clear()
	_async_chunk_authored_descriptors.clear()


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

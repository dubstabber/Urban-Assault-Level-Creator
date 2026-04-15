extends RefCounted


var _driver = null
var _renderer_node = null
var _context = null
var _scene = null
var _build = null


func bind(driver, renderer, context_port, scene_port, build_state_port) -> void:
	_driver = driver
	_renderer_node = renderer
	_context = context_port
	_scene = scene_port
	_build = build_state_port


func start_async_overlay_only_refresh(reframe_camera: bool) -> bool:
	if not _driver.can_use_overlay_only_refresh():
		_driver._overlay_only_refresh_requested = false
		return false
	if not sync_async_overlay_state_from_current_map():
		_driver._overlay_only_refresh_requested = false
		return false
	_build.sync_terrain_overlay_animation_mode_from_editor()
	_driver._overlay_only_refresh_requested = false
	_prepare_overlay_refresh(reframe_camera)
	_driver.begin_build_state(1, "Preparing overlays...")
	start_async_overlay_descriptor_build()
	return true


func start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	if not _driver.can_use_overlay_only_refresh():
		_driver._dynamic_overlay_refresh_requested = false
		return false
	if not sync_async_overlay_state_from_current_map():
		_driver._dynamic_overlay_refresh_requested = false
		return false
	_build.sync_terrain_overlay_animation_mode_from_editor()
	_driver._dynamic_overlay_refresh_requested = false
	_driver._overlay_only_refresh_requested = false
	_prepare_overlay_refresh(reframe_camera)
	_driver.begin_build_state(1, "Updating vehicles...")
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


func start_async_overlay_descriptor_build(dynamic_only: bool = false) -> void:
	_driver.update_build_progress(_driver.total_chunks, _driver.total_chunks, "Preparing overlays...")
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
	_driver._async_overlay_descriptor_dynamic_only = dynamic_only
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
		_driver.update_build_progress(_driver.total_chunks, _driver.total_chunks, stage)
	if _build.coordinator()._async_cancel_requested:
		_build.join_async_overlay_descriptor_thread()
		var should_restart: bool = _driver._async_requested_restart
		var restart_reframe: bool = _driver._async_requested_reframe
		_driver.end_build_state(false, "3D render cancelled")
		_driver.reset_async_build_state()
		if should_restart:
			_driver.request_refresh(restart_reframe)
		return
	var state: Dictionary = _build.get_async_overlay_descriptor_state()
	if not bool(state.get("done", false)):
		return
	_build.join_async_overlay_descriptor_thread()
	if _build.coordinator()._async_cancel_requested:
		return
	if bool(state.get("failed", false)):
		_driver.end_build_state(false, "Overlay descriptor generation failed")
		_driver.reset_async_build_state()
		if _driver._async_requested_restart:
			_driver.request_refresh(_driver._async_requested_reframe)
		return
	var result_payload: Dictionary = state.get("result", {})
	var static_descriptors: Array = result_payload.get("static_descriptors", [])
	var dynamic_descriptors: Array = result_payload.get("dynamic_descriptors", [])
	var metrics: Dictionary = state.get("metrics", {})
	if _driver._async_overlay_descriptor_dynamic_only:
		_finalize_dynamic_only_overlay_refresh(dynamic_descriptors, metrics)
		return
	start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)


func start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_scene.ensure_overlay_nodes()
	_driver._async_overlay_descriptors = static_descriptors
	_driver._async_dynamic_overlay_descriptors = dynamic_descriptors
	_driver._async_overlay_metrics = metrics.duplicate(true)
	_build.static_overlay_index().replace_all(static_descriptors)
	_driver._async_overlay_apply_state = _build.overlay_apply_manager().begin_apply_overlay_node(_scene.authored_overlay(), _driver._async_overlay_descriptors)
	_driver._async_overlay_apply_started_usec = Time.get_ticks_usec()
	_driver._async_overlay_apply_active = true
	UATerrainPieceLibrary.reset_piece_overlay_build_counters()
	_driver.update_build_progress(_driver.total_chunks, _driver.total_chunks, "Applying 3D overlays... 0%")


func pump_async_overlay_apply() -> void:
	if not _driver._async_overlay_apply_active:
		return
	if _build.coordinator()._async_cancel_requested:
		_driver._async_overlay_apply_active = false
		_driver.end_build_state(false, "3D render cancelled")
		_driver.reset_async_build_state()
		if _driver._async_requested_restart:
			_driver.request_refresh(_driver._async_requested_reframe)
		return
	var done: bool = _build.overlay_apply_manager().apply_overlay_node_step(_scene.authored_overlay(), _driver._async_overlay_apply_state, _renderer_node._ASYNC_OVERLAY_APPLY_OPS_PER_FRAME)
	var progress: Dictionary = _build.overlay_apply_manager().overlay_apply_progress(_driver._async_overlay_apply_state)
	var progress_done := int(progress.get("done", 0))
	var progress_total := int(progress.get("total", 0))
	var pct := 100
	if progress_total > 0:
		pct = int(round((float(progress_done) / float(progress_total)) * 100.0))
	_driver.update_build_progress(_driver.total_chunks, _driver.total_chunks, "Applying 3D overlays... %d%%" % clampi(pct, 0, 100))
	_scene.bump_3d_viewport_rendering()
	if done:
		finalize_async_overlay_apply()


func finalize_async_overlay_apply() -> void:
	if _scene.authored_overlay() != null and is_instance_valid(_scene.authored_overlay()):
		_build.overlay_apply_manager().finalize_apply_overlay_node(_scene.authored_overlay(), _driver._async_overlay_apply_state)
	var dynamic_apply_started_usec := Time.get_ticks_usec()
	_scene.apply_dynamic_overlay(_driver._async_dynamic_overlay_descriptors)
	_scene.apply_geometry_distance_culling_to_overlay()
	var metrics: Dictionary = _driver._async_overlay_metrics
	var pc: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	metrics["overlay_node_creation_ms"] = _build.elapsed_ms_since(_driver._async_overlay_apply_started_usec)
	metrics["static_overlay_apply_ms"] = metrics["overlay_node_creation_ms"]
	metrics["dynamic_overlay_apply_ms"] = _build.elapsed_ms_since(dynamic_apply_started_usec)
	_build.finalize_build_metrics(metrics, _driver._async_build_started_usec)
	_build.chunk_runtime().initial_build_in_progress = false
	_build.chunk_runtime().initial_build_accumulated_authored_descriptors.clear()
	_driver._async_overlay_apply_active = false
	_driver.end_build_state(true, "3D map ready")
	_scene.bump_3d_viewport_rendering()
	if _driver._async_pending_reframe_camera and _scene.is_inside_tree():
		_build.set_camera_framed(false)
		_build.frame_if_needed()
	var should_restart: bool = _driver._async_requested_restart
	var restart_reframe: bool = _driver._async_requested_reframe
	_driver.reset_async_build_state()
	if should_restart:
		_driver.request_refresh(restart_reframe)
	elif _driver._refresh_pending and _context.preview_refresh_active():
		_driver.request_refresh(_driver._refresh_reframe_pending)
	else:
		_driver.flush_pending_unit_changes()


func _prepare_overlay_refresh(reframe_camera: bool) -> void:
	var coordinator = _build.coordinator()
	coordinator.build_generation_id += 1
	coordinator.active_build_generation_id = coordinator.build_generation_id
	coordinator.cancel_requested_generation_id = 0
	_driver._async_pending_reframe_camera = reframe_camera
	_driver._async_build_started_usec = Time.get_ticks_usec()
	coordinator._async_cancel_requested = false
	_driver._async_requested_restart = false
	_driver._async_requested_reframe = false


func _finalize_dynamic_only_overlay_refresh(dynamic_descriptors: Array, metrics: Dictionary) -> void:
	var dynamic_apply_started_usec := Time.get_ticks_usec()
	_scene.apply_dynamic_overlay(dynamic_descriptors)
	metrics["dynamic_overlay_apply_ms"] = _build.elapsed_ms_since(dynamic_apply_started_usec)
	_build.finalize_build_metrics(metrics, _driver._async_build_started_usec)
	_driver.end_build_state(true, "3D map ready")
	_scene.bump_3d_viewport_rendering()
	if _driver._async_pending_reframe_camera and _scene.is_inside_tree():
		_build.set_camera_framed(false)
		_build.frame_if_needed()
	var should_restart: bool = _driver._async_requested_restart
	var restart_reframe: bool = _driver._async_requested_reframe
	_driver.reset_async_build_state()
	if should_restart:
		_driver.request_refresh(restart_reframe)
		return
	_driver.flush_pending_unit_changes()

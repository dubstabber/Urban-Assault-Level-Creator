extends RefCounted


var _renderer = null
var _coordinator = null
var _chunk_runtime = null
var _effective_typ_service = null
var _unit_runtime_index = null
var _static_overlay_index = null
var _overlay_refresh_scope = null
var _async_map_snapshot = null
var _runtime_state = null
var _camera_controller = null
var _async_refresh_driver = null
var _build_pipeline = null
var _scene_graph = null
var _rebuild_policy = null
var _async_state_port = null
var _build_runtime_port = null
var _view_action_port = null


func bind(
	renderer,
	coordinator = null,
	chunk_runtime = null,
	effective_typ_service = null,
	unit_runtime_index = null,
	static_overlay_index = null,
	overlay_refresh_scope = null,
	async_map_snapshot = null,
	runtime_state = null,
	camera_controller = null,
	async_refresh_driver = null,
	build_pipeline = null,
	scene_graph = null,
	rebuild_policy = null,
	async_state_port = null,
	build_runtime_port = null,
	view_action_port = null
) -> void:
	_renderer = renderer
	_coordinator = coordinator
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_unit_runtime_index = unit_runtime_index
	_static_overlay_index = static_overlay_index
	_overlay_refresh_scope = overlay_refresh_scope
	_async_map_snapshot = async_map_snapshot
	_runtime_state = runtime_state
	_camera_controller = camera_controller
	_async_refresh_driver = async_refresh_driver
	_build_pipeline = build_pipeline
	_scene_graph = scene_graph
	_rebuild_policy = rebuild_policy
	_async_state_port = async_state_port
	_build_runtime_port = build_runtime_port
	_view_action_port = view_action_port


func renderer_node():
	return _renderer


func make_empty_build_metrics() -> Dictionary:
	if _build_runtime_port != null:
		return _build_runtime_port.make_empty_build_metrics()
	return _renderer._make_empty_build_metrics()


func elapsed_ms_since(started_usec: int) -> float:
	if _build_runtime_port != null:
		return _build_runtime_port.elapsed_ms_since(started_usec)
	return _renderer._elapsed_ms_since(started_usec)


func finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.finalize_build_metrics(metrics, build_started_usec)
		return
	_renderer._finalize_build_metrics(metrics, build_started_usec)


func apply_preview_activity_state() -> void:
	if _view_action_port != null:
		_view_action_port.apply_preview_activity_state()
		return
	_renderer._apply_preview_activity_state()


func apply_visibility_range_from_editor_state() -> void:
	if _view_action_port != null:
		_view_action_port.apply_visibility_range_from_editor_state()
		return
	_renderer._apply_visibility_range_from_editor_state()


func build_from_current_map() -> void:
	if _view_action_port != null:
		_view_action_port.build_from_current_map()
		return
	_renderer.build_from_current_map()


func has_pending_refresh() -> bool:
	if _view_action_port != null:
		return _view_action_port.has_pending_refresh()
	return _renderer.has_pending_refresh()


func request_refresh(reframe_camera: bool) -> void:
	if _view_action_port != null:
		_view_action_port.request_refresh(reframe_camera)
		return
	_renderer._request_refresh(reframe_camera)


func apply_pending_refresh() -> void:
	if _view_action_port != null:
		_view_action_port.apply_pending_refresh()
		return
	_renderer._apply_pending_refresh()


func request_overlay_only_refresh() -> void:
	if _view_action_port != null:
		_view_action_port.request_overlay_only_refresh()
		return
	_renderer._request_overlay_only_refresh()


func request_dynamic_overlay_refresh() -> void:
	if _view_action_port != null:
		_view_action_port.request_dynamic_overlay_refresh()
		return
	_renderer._request_dynamic_overlay_refresh()


func flush_pending_unit_changes() -> bool:
	if _view_action_port != null:
		return _view_action_port.flush_pending_unit_changes()
	return _renderer._flush_pending_unit_changes()


func cancel_async_initial_build() -> void:
	if _async_state_port != null:
		_async_state_port.cancel_async_initial_build()
		return
	coordinator().cancel_async_build(_async_refresh_driver.is_async_overlay_apply_active() if _async_refresh_driver != null else _renderer._async_refresh_driver.is_async_overlay_apply_active())


func join_async_thread() -> void:
	if _async_state_port != null:
		_async_state_port.join_async_thread()
		return
	coordinator().join_async_thread()


func join_async_overlay_descriptor_thread() -> void:
	if _async_state_port != null:
		_async_state_port.join_async_overlay_descriptor_thread()
		return
	coordinator().join_async_overlay_descriptor_thread()


func reset_async_build_state() -> void:
	if _async_state_port != null:
		_renderer._reset_async_build_state()
		return
	_renderer._reset_async_build_state()


func is_async_build_active() -> bool:
	if _async_state_port != null:
		return _async_state_port.is_async_build_active()
	return coordinator().is_async_build_active()


func is_async_pipeline_active() -> bool:
	if _async_state_port != null:
		var overlay_apply_active: bool = _async_refresh_driver.is_async_overlay_apply_active() if _async_refresh_driver != null else false
		return _async_state_port.is_async_pipeline_active(overlay_apply_active)
	var overlay_apply_active: bool = _async_refresh_driver.is_async_overlay_apply_active() if _async_refresh_driver != null else _renderer._async_refresh_driver.is_async_overlay_apply_active()
	return coordinator().is_async_pipeline_active(overlay_apply_active)


func is_async_overlay_descriptor_active() -> bool:
	if _async_state_port != null:
		return _async_state_port.is_async_overlay_descriptor_active()
	return coordinator().is_async_overlay_descriptor_active()


func is_async_cancel_requested(generation_id: int) -> bool:
	if _async_state_port != null:
		return _async_state_port.is_async_cancel_requested(generation_id)
	return coordinator().is_async_cancel_requested(generation_id)


func set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_overlay_descriptor_state(done, failed, result, metrics)
		return
	coordinator().set_async_overlay_descriptor_state(done, failed, result, metrics)


func set_async_overlay_descriptor_stage(stage: String) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_overlay_descriptor_stage(stage)
		return
	coordinator().set_async_overlay_descriptor_stage(stage)


func get_async_overlay_descriptor_stage() -> String:
	if _async_state_port != null:
		return _async_state_port.get_async_overlay_descriptor_stage()
	return coordinator().get_async_overlay_descriptor_stage()


func get_async_overlay_descriptor_state() -> Dictionary:
	if _async_state_port != null:
		return _async_state_port.get_async_overlay_descriptor_state()
	return coordinator().get_async_overlay_descriptor_state()


func set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_worker_state(done, failed, message)
		return
	coordinator().set_async_worker_state(done, failed, message)


func get_async_worker_state() -> Dictionary:
	if _async_state_port != null:
		return _async_state_port.get_async_worker_state()
	return coordinator().get_async_worker_state()


func push_async_chunk_payload(payload: Dictionary) -> void:
	if _async_state_port != null:
		_async_state_port.push_async_chunk_payload(payload)
		return
	coordinator().push_async_chunk_payload(payload)


func pop_async_chunk_payload() -> Dictionary:
	if _async_state_port != null:
		return _async_state_port.pop_async_chunk_payload()
	return coordinator().pop_async_chunk_payload()


func clear_async_chunk_payloads() -> void:
	if _async_state_port != null:
		_async_state_port.clear_async_chunk_payloads()
		return
	coordinator().clear_async_chunk_payloads()


func async_chunk_payload_count() -> int:
	if _async_state_port != null:
		return _async_state_port.async_chunk_payload_count()
	return coordinator().async_chunk_payload_count()


func coordinator():
	if _async_state_port != null:
		return _async_state_port.coordinator()
	return _coordinator if _coordinator != null else _renderer._coordinator


func chunk_runtime():
	if _build_runtime_port != null:
		return _build_runtime_port.chunk_runtime()
	return _chunk_runtime if _chunk_runtime != null else _renderer._chunk_rt


func effective_typ_service():
	if _build_runtime_port != null:
		return _build_runtime_port.effective_typ_service()
	return _effective_typ_service if _effective_typ_service != null else _renderer._effective_typ_service


func unit_runtime_index():
	if _build_runtime_port != null:
		return _build_runtime_port.unit_runtime_index()
	return _unit_runtime_index if _unit_runtime_index != null else _renderer._unit_runtime_index


func static_overlay_index():
	if _build_runtime_port != null:
		return _build_runtime_port.static_overlay_index()
	return _static_overlay_index if _static_overlay_index != null else _renderer._static_overlay_index


func overlay_apply_manager():
	if _build_runtime_port != null:
		return _build_runtime_port.overlay_apply_manager()
	if _runtime_state != null:
		return _runtime_state.overlay_apply_manager
	return _renderer._overlay_apply_manager


func async_effective_typ() -> PackedByteArray:
	if _async_state_port != null:
		return _async_state_port.async_effective_typ()
	return _async_map_snapshot.effective_typ if _async_map_snapshot != null else _renderer._async_effective_typ


func set_async_effective_typ(value: PackedByteArray) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_effective_typ(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.effective_typ = value
	else:
		_renderer._async_effective_typ = value


func async_blg() -> PackedByteArray:
	if _async_state_port != null:
		return _async_state_port.async_blg()
	return _async_map_snapshot.blg if _async_map_snapshot != null else _renderer._async_blg


func set_async_blg(value: PackedByteArray) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_blg(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.blg = value
	else:
		_renderer._async_blg = value


func async_w() -> int:
	if _async_state_port != null:
		return _async_state_port.async_w()
	return _async_map_snapshot.w if _async_map_snapshot != null else _renderer._async_w


func set_async_w(value: int) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_w(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.w = int(value)
	else:
		_renderer._async_w = value


func async_h() -> int:
	if _async_state_port != null:
		return _async_state_port.async_h()
	return _async_map_snapshot.h if _async_map_snapshot != null else _renderer._async_h


func set_async_h(value: int) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_h(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.h = int(value)
	else:
		_renderer._async_h = value


func async_level_set() -> int:
	if _async_state_port != null:
		return _async_state_port.async_level_set()
	return _async_map_snapshot.level_set if _async_map_snapshot != null else _renderer._async_level_set


func set_async_level_set(value: int) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_level_set(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.level_set = int(value)
	else:
		_renderer._async_level_set = value


func async_game_data_type() -> String:
	if _async_state_port != null:
		return _async_state_port.async_game_data_type()
	return _async_map_snapshot.game_data_type if _async_map_snapshot != null else _renderer._async_game_data_type


func set_async_game_data_type(value: String) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_game_data_type(value)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.game_data_type = String(value)
	else:
		_renderer._async_game_data_type = value


func set_async_map_snapshot(effective_typ: PackedByteArray, blg: PackedByteArray, w: int, h: int, level_set: int, game_data_type: String) -> void:
	if _async_state_port != null:
		_async_state_port.set_async_map_snapshot(effective_typ, blg, w, h, level_set, game_data_type)
		return
	if _async_map_snapshot != null:
		_async_map_snapshot.effective_typ = effective_typ
		_async_map_snapshot.blg = blg
		_async_map_snapshot.w = int(w)
		_async_map_snapshot.h = int(h)
		_async_map_snapshot.level_set = int(level_set)
		_async_map_snapshot.game_data_type = String(game_data_type)
		return
	_renderer._async_effective_typ = effective_typ
	_renderer._async_blg = blg
	_renderer._async_w = w
	_renderer._async_h = h
	_renderer._async_level_set = level_set
	_renderer._async_game_data_type = game_data_type


func skip_next_map_changed_refresh() -> bool:
	return _runtime_state.skip_next_map_changed_refresh if _runtime_state != null else _renderer._skip_next_map_changed_refresh


func set_skip_next_map_changed_refresh(value: bool) -> void:
	if _runtime_state != null:
		_runtime_state.skip_next_map_changed_refresh = bool(value)
	else:
		_renderer._skip_next_map_changed_refresh = value


func localized_overlay_sector_list() -> Array[Vector2i]:
	if _build_runtime_port != null:
		return _build_runtime_port.localized_overlay_sector_list()
	return _overlay_refresh_scope.overlay_sector_list() if _overlay_refresh_scope != null else _renderer._localized_overlay_sector_list()


func localized_dynamic_sector_list() -> Array[Vector2i]:
	if _build_runtime_port != null:
		return _build_runtime_port.localized_dynamic_sector_list()
	return _overlay_refresh_scope.dynamic_sector_list() if _overlay_refresh_scope != null else _renderer._localized_dynamic_sector_list()


func clear_localized_overlay_scope() -> void:
	if _build_runtime_port != null:
		_build_runtime_port.clear_localized_overlay_scope()
		return
	if _overlay_refresh_scope != null:
		_overlay_refresh_scope.clear()
	else:
		_renderer._clear_localized_overlay_scope()


func record_localized_overlay_sectors(sectors: Array) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.record_localized_overlay_sectors(sectors)
		return
	if _overlay_refresh_scope != null:
		_overlay_refresh_scope.record_sectors(sectors)
	else:
		_renderer._record_localized_overlay_sectors(sectors)


func compute_effective_typ_for_map(cmd: Node, w: int, h: int, typ: PackedByteArray, blg: PackedByteArray, game_data_type: String) -> PackedByteArray:
	if _build_runtime_port != null:
		return _build_runtime_port.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	return effective_typ_service().compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)


func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	return _renderer.build_mesh(hgt, w, h)


func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	return _renderer.build_mesh_with_textures(hgt, typ, w, h, mapping, subsector_patterns, tile_mapping, tile_remap, subsector_idx_remap, lego_defs, set_id)


func checksum_packed_byte_array(data: PackedByteArray) -> int:
	return _renderer._checksum_packed_byte_array(data)


func current_build_state_snapshot() -> Dictionary:
	return _renderer.get_build_state_snapshot()


func invalidate_all_chunks(w: int, h: int) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.invalidate_all_chunks(w, h)
		return
	chunk_runtime().invalidate_all_chunks(w, h)


func needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	if _build_runtime_port != null:
		return _build_runtime_port.needs_full_rebuild(w, h, level_set)
	if _rebuild_policy != null:
		return _rebuild_policy.needs_full_rebuild(w, h, level_set)
	return _renderer._needs_full_rebuild(w, h, level_set)


func update_terrain_authored_cache_for_chunk(chunk_coord: Vector2i, chunk_descriptors: Array) -> void:
	chunk_runtime().update_terrain_authored_cache_for_chunk(chunk_coord, chunk_descriptors)


func reset_terrain_authored_cache_from_descriptors(support_descriptors: Array, w: int, h: int) -> void:
	chunk_runtime().reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)


func dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	if _build_runtime_port != null:
		return _build_runtime_port.dirty_chunks_sorted_by_priority(w, h)
	if _rebuild_policy != null:
		return _rebuild_policy.dirty_chunks_sorted_by_priority(w, h)
	return _renderer._dirty_chunks_sorted_by_priority(w, h)


func clear_chunk_nodes() -> void:
	if _scene_graph != null:
		_scene_graph.clear_chunk_nodes()
	else:
		_renderer._clear_chunk_nodes()


func is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	if _async_state_port != null:
		return _async_state_port.is_map_signature_changed(w, h, level_set, hgt, typ, blg)
	return coordinator().is_map_signature_changed(w, h, level_set, hgt, typ, blg)


func record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	if _async_state_port != null:
		_async_state_port.record_map_signature(w, h, level_set, hgt, typ, blg)
		return
	coordinator().record_map_signature(w, h, level_set, hgt, typ, blg)


func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
	if _async_state_port != null:
		_async_state_port.mark_localized_signature_change(w, h, level_set)
		return
	coordinator().mark_localized_signature_change(w, h, level_set)


func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
	if _async_state_port != null:
		return _async_state_port.can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)
	return coordinator().can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)


func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
	if _async_state_port != null:
		_async_state_port.record_map_signature_metadata_only(w, h, level_set)
		return
	coordinator().record_map_signature_metadata_only(w, h, level_set)


func mark_chunks_dirty(chunk_coords: Array) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.mark_chunks_dirty(chunk_coords)
		return
	if _rebuild_policy != null:
		_rebuild_policy.mark_chunks_dirty(chunk_coords)
	else:
		_renderer.mark_chunks_dirty(chunk_coords)


func set_authored_overlay(descriptors: Array) -> void:
	if _scene_graph != null:
		_scene_graph.set_authored_overlay(descriptors)
	else:
		_renderer._set_authored_overlay(descriptors)


func sync_terrain_overlay_animation_mode_from_editor() -> void:
	if _view_action_port != null:
		_view_action_port.sync_terrain_overlay_animation_mode_from_editor()
		return
	_renderer._sync_terrain_overlay_animation_mode_from_editor()


func snapshot_host_station_nodes(host_stations: Array) -> Array:
	return _renderer._snapshot_host_station_nodes(host_stations)


func snapshot_squad_nodes(squads: Array) -> Array:
	return _renderer._snapshot_squad_nodes(squads)


func build_blg_attachment_descriptors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String) -> Array:
	return _renderer._build_blg_attachment_descriptors(blg, effective_typ, set_id, hgt, w, h, support_descriptors, game_data_type)


func build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return _renderer._build_host_station_descriptors(host_stations, set_id, hgt, w, h, support_descriptors, profile)


func build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return _renderer._build_host_station_descriptors_from_snapshot(host_stations, set_id, hgt, w, h, support_descriptors, profile)


func build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return _renderer._build_squad_descriptors(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)


func build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return _renderer._build_squad_descriptors_from_snapshot(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)


func apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)
		return
	if _build_pipeline != null:
		_build_pipeline.apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)
	else:
		_renderer._apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)


func apply_localized_dynamic_overlay_refresh(cmd: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)
		return
	if _build_pipeline != null:
		_build_pipeline.apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)
	else:
		_renderer._apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)


func frame_if_needed() -> void:
	if _view_action_port != null:
		_view_action_port.frame_if_needed()
		return
	if _camera_controller != null:
		_camera_controller.frame_if_needed()
	else:
		_renderer._frame_if_needed()


func set_camera_framed(value: bool) -> void:
	if _view_action_port != null:
		_view_action_port.set_camera_framed(value)
		return
	if _camera_controller != null:
		_camera_controller.set_framed(value)
	else:
		_renderer._camera_controller.set_framed(value)


func advance_debug_shader_mode() -> int:
	if _view_action_port != null:
		return _view_action_port.advance_debug_shader_mode()
	_renderer._debug_shader_mode = (_renderer._debug_shader_mode + 1) % 3
	return _renderer._debug_shader_mode


func apply_debug_mode_to_existing_materials() -> void:
	if _view_action_port != null:
		_view_action_port.apply_debug_mode_to_existing_materials()
		return
	_renderer._apply_debug_mode_to_existing_materials()


func terrain_material_cache() -> Dictionary:
	if _build_runtime_port != null:
		return _build_runtime_port.terrain_material_cache()
	return _runtime_state.terrain_material_cache if _runtime_state != null else _renderer._terrain_material_cache


func edge_material_cache() -> Dictionary:
	if _build_runtime_port != null:
		return _build_runtime_port.edge_material_cache()
	return _runtime_state.edge_material_cache if _runtime_state != null else _renderer._edge_material_cache


func geometry_distance_culling_enabled() -> bool:
	if _build_runtime_port != null:
		return _build_runtime_port.geometry_distance_culling_enabled()
	return _runtime_state.geometry_distance_culling_enabled if _runtime_state != null else _renderer._geometry_distance_culling_enabled


func set_geometry_distance_culling_enabled(value: bool) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.set_geometry_distance_culling_enabled(value)
		return
	if _runtime_state != null:
		_runtime_state.geometry_distance_culling_enabled = bool(value)
	else:
		_renderer._geometry_distance_culling_enabled = value


func geometry_cull_distance() -> float:
	if _build_runtime_port != null:
		return _build_runtime_port.geometry_cull_distance()
	return _runtime_state.geometry_cull_distance if _runtime_state != null else _renderer._geometry_cull_distance


func set_geometry_cull_distance(value: float) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.set_geometry_cull_distance(value)
		return
	if _runtime_state != null:
		_runtime_state.geometry_cull_distance = float(value)
	else:
		_renderer._geometry_cull_distance = value


func debug_shader_mode() -> int:
	if _build_runtime_port != null:
		return _build_runtime_port.debug_shader_mode()
	return _runtime_state.debug_shader_mode if _runtime_state != null else _renderer._debug_shader_mode


func edge_overlay_enabled() -> bool:
	if _build_runtime_port != null:
		return _build_runtime_port.edge_overlay_enabled()
	return _runtime_state.edge_overlay_enabled if _runtime_state != null else _renderer._edge_overlay_enabled


func sector_top_shader() -> Shader:
	if _build_runtime_port != null:
		return _build_runtime_port.sector_top_shader()
	return _runtime_state.sector_top_shader if _runtime_state != null else _renderer._sector_top_shader


func set_sector_top_shader(shader: Shader) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.set_sector_top_shader(shader)
		return
	if _runtime_state != null:
		_runtime_state.sector_top_shader = shader
	else:
		_renderer._sector_top_shader = shader


func edge_blend_shader() -> Shader:
	if _build_runtime_port != null:
		return _build_runtime_port.edge_blend_shader()
	return _runtime_state.edge_blend_shader if _runtime_state != null else _renderer._edge_blend_shader


func set_edge_blend_shader(shader: Shader) -> void:
	if _build_runtime_port != null:
		_build_runtime_port.set_edge_blend_shader(shader)
		return
	if _runtime_state != null:
		_runtime_state.edge_blend_shader = shader
	else:
		_renderer._edge_blend_shader = shader

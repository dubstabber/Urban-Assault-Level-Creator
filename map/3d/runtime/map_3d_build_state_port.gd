extends RefCounted


var _renderer = null


func bind(renderer) -> void:
	_renderer = renderer


func renderer_node():
	return _renderer


func make_empty_build_metrics() -> Dictionary:
	return _renderer._make_empty_build_metrics()


func elapsed_ms_since(started_usec: int) -> float:
	return _renderer._elapsed_ms_since(started_usec)


func finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	_renderer._finalize_build_metrics(metrics, build_started_usec)


func apply_preview_activity_state() -> void:
	_renderer._apply_preview_activity_state()


func apply_visibility_range_from_editor_state() -> void:
	_renderer._apply_visibility_range_from_editor_state()


func build_from_current_map() -> void:
	_renderer.build_from_current_map()


func has_pending_refresh() -> bool:
	return _renderer.has_pending_refresh()


func request_refresh(reframe_camera: bool) -> void:
	_renderer._request_refresh(reframe_camera)


func apply_pending_refresh() -> void:
	_renderer._apply_pending_refresh()


func request_overlay_only_refresh() -> void:
	_renderer._request_overlay_only_refresh()


func request_dynamic_overlay_refresh() -> void:
	_renderer._request_dynamic_overlay_refresh()


func flush_pending_unit_changes() -> bool:
	return _renderer._flush_pending_unit_changes()


func cancel_async_initial_build() -> void:
	_renderer._cancel_async_initial_build()


func join_async_thread() -> void:
	_renderer._join_async_thread()


func join_async_overlay_descriptor_thread() -> void:
	_renderer._join_async_overlay_descriptor_thread()


func reset_async_build_state() -> void:
	_renderer._reset_async_build_state()


func is_async_build_active() -> bool:
	return _renderer._is_async_build_active()


func is_async_pipeline_active() -> bool:
	return _renderer._is_async_pipeline_active()


func is_async_overlay_descriptor_active() -> bool:
	return _renderer._is_async_overlay_descriptor_active()


func is_async_cancel_requested(generation_id: int) -> bool:
	return _renderer._is_async_cancel_requested(generation_id)


func set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	_renderer._set_async_overlay_descriptor_state(done, failed, result, metrics)


func set_async_overlay_descriptor_stage(stage: String) -> void:
	_renderer._set_async_overlay_descriptor_stage(stage)


func get_async_overlay_descriptor_stage() -> String:
	return _renderer._get_async_overlay_descriptor_stage()


func get_async_overlay_descriptor_state() -> Dictionary:
	return _renderer._get_async_overlay_descriptor_state()


func set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	_renderer._set_async_worker_state(done, failed, message)


func get_async_worker_state() -> Dictionary:
	return _renderer._get_async_worker_state()


func push_async_chunk_payload(payload: Dictionary) -> void:
	_renderer._push_async_chunk_payload(payload)


func pop_async_chunk_payload() -> Dictionary:
	return _renderer._pop_async_chunk_payload()


func clear_async_chunk_payloads() -> void:
	_renderer._clear_async_chunk_payloads()


func async_chunk_payload_count() -> int:
	return _renderer._async_chunk_payload_count()


func coordinator():
	return _renderer._coordinator


func chunk_runtime():
	return _renderer._chunk_rt


func effective_typ_service():
	return _renderer._effective_typ_service


func unit_runtime_index():
	return _renderer._unit_runtime_index


func static_overlay_index():
	return _renderer._static_overlay_index


func overlay_apply_manager():
	return _renderer._overlay_apply_manager


func async_effective_typ() -> PackedByteArray:
	return _renderer._async_effective_typ


func set_async_effective_typ(value: PackedByteArray) -> void:
	_renderer._async_effective_typ = value


func async_blg() -> PackedByteArray:
	return _renderer._async_blg


func set_async_blg(value: PackedByteArray) -> void:
	_renderer._async_blg = value


func async_w() -> int:
	return _renderer._async_w


func set_async_w(value: int) -> void:
	_renderer._async_w = value


func async_h() -> int:
	return _renderer._async_h


func set_async_h(value: int) -> void:
	_renderer._async_h = value


func async_level_set() -> int:
	return _renderer._async_level_set


func set_async_level_set(value: int) -> void:
	_renderer._async_level_set = value


func async_game_data_type() -> String:
	return _renderer._async_game_data_type


func set_async_game_data_type(value: String) -> void:
	_renderer._async_game_data_type = value


func set_async_map_snapshot(effective_typ: PackedByteArray, blg: PackedByteArray, w: int, h: int, level_set: int, game_data_type: String) -> void:
	_renderer._async_effective_typ = effective_typ
	_renderer._async_blg = blg
	_renderer._async_w = w
	_renderer._async_h = h
	_renderer._async_level_set = level_set
	_renderer._async_game_data_type = game_data_type


func skip_next_map_changed_refresh() -> bool:
	return _renderer._skip_next_map_changed_refresh


func set_skip_next_map_changed_refresh(value: bool) -> void:
	_renderer._skip_next_map_changed_refresh = value


func localized_overlay_sector_list() -> Array[Vector2i]:
	return _renderer._localized_overlay_sector_list()


func localized_dynamic_sector_list() -> Array[Vector2i]:
	return _renderer._localized_dynamic_sector_list()


func clear_localized_overlay_scope() -> void:
	_renderer._clear_localized_overlay_scope()


func record_localized_overlay_sectors(sectors: Array) -> void:
	_renderer._record_localized_overlay_sectors(sectors)


func compute_effective_typ_for_map(cmd: Node, w: int, h: int, typ: PackedByteArray, blg: PackedByteArray, game_data_type: String) -> PackedByteArray:
	return _renderer._compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)


func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	return _renderer.build_mesh(hgt, w, h)


func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	return _renderer.build_mesh_with_textures(hgt, typ, w, h, mapping, subsector_patterns, tile_mapping, tile_remap, subsector_idx_remap, lego_defs, set_id)


func checksum_packed_byte_array(data: PackedByteArray) -> int:
	return _renderer._checksum_packed_byte_array(data)


func current_build_state_snapshot() -> Dictionary:
	return _renderer.get_build_state_snapshot()


func invalidate_all_chunks(w: int, h: int) -> void:
	_renderer._invalidate_all_chunks(w, h)


func needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	return _renderer._needs_full_rebuild(w, h, level_set)


func update_terrain_authored_cache_for_chunk(chunk_coord: Vector2i, chunk_descriptors: Array) -> void:
	_renderer._update_terrain_authored_cache_for_chunk(chunk_coord, chunk_descriptors)


func reset_terrain_authored_cache_from_descriptors(support_descriptors: Array, w: int, h: int) -> void:
	_renderer._reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)


func dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	return _renderer._dirty_chunks_sorted_by_priority(w, h)


func clear_chunk_nodes() -> void:
	_renderer._clear_chunk_nodes()


func is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	return _renderer._is_map_signature_changed(w, h, level_set, hgt, typ, blg)


func record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	_renderer._record_map_signature(w, h, level_set, hgt, typ, blg)


func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
	_renderer._coordinator.mark_localized_signature_change(w, h, level_set)


func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
	return _renderer._coordinator.can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)


func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
	_renderer._coordinator.record_map_signature_metadata_only(w, h, level_set)


func mark_chunks_dirty(chunk_coords: Array) -> void:
	_renderer.mark_chunks_dirty(chunk_coords)


func set_authored_overlay(descriptors: Array) -> void:
	_renderer._set_authored_overlay(descriptors)


func sync_terrain_overlay_animation_mode_from_editor() -> void:
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


func frame_if_needed() -> void:
	_renderer._frame_if_needed()


func set_camera_framed(value: bool) -> void:
	_renderer._camera_controller.set_framed(value)


func advance_debug_shader_mode() -> int:
	_renderer._debug_shader_mode = (_renderer._debug_shader_mode + 1) % 3
	return _renderer._debug_shader_mode


func apply_debug_mode_to_existing_materials() -> void:
	_renderer._apply_debug_mode_to_existing_materials()


func terrain_material_cache() -> Dictionary:
	return _renderer._terrain_material_cache


func edge_material_cache() -> Dictionary:
	return _renderer._edge_material_cache


func geometry_distance_culling_enabled() -> bool:
	return _renderer._geometry_distance_culling_enabled


func set_geometry_distance_culling_enabled(value: bool) -> void:
	_renderer._geometry_distance_culling_enabled = value


func geometry_cull_distance() -> float:
	return _renderer._geometry_cull_distance


func set_geometry_cull_distance(value: float) -> void:
	_renderer._geometry_cull_distance = value


func debug_shader_mode() -> int:
	return _renderer._debug_shader_mode


func edge_overlay_enabled() -> bool:
	return _renderer._edge_overlay_enabled


func sector_top_shader() -> Shader:
	return _renderer._sector_top_shader


func set_sector_top_shader(shader: Shader) -> void:
	_renderer._sector_top_shader = shader


func edge_blend_shader() -> Shader:
	return _renderer._edge_blend_shader


func set_edge_blend_shader(shader: Shader) -> void:
	_renderer._edge_blend_shader = shader

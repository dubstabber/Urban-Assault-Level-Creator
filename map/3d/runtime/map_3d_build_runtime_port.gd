extends RefCounted

const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")


var _renderer = null
var _chunk_runtime = null
var _effective_typ_service = null
var _unit_runtime_index = null
var _static_overlay_index = null
var _overlay_refresh_scope = null
var _runtime_state = null
var _build_pipeline = null
var _rebuild_policy = null


func bind(
	renderer,
	chunk_runtime,
	effective_typ_service,
	unit_runtime_index,
	static_overlay_index,
	overlay_refresh_scope,
	runtime_state,
	build_pipeline = null,
	rebuild_policy = null
) -> void:
	_renderer = renderer
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_unit_runtime_index = unit_runtime_index
	_static_overlay_index = static_overlay_index
	_overlay_refresh_scope = overlay_refresh_scope
	_runtime_state = runtime_state
	_build_pipeline = build_pipeline
	_rebuild_policy = rebuild_policy


func make_empty_build_metrics() -> Dictionary:
	return BuildMetrics.empty_metrics()


func elapsed_ms_since(started_usec: int) -> float:
	return BuildMetrics.elapsed_ms_since(started_usec)


func finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	_renderer._finalize_build_metrics(metrics, build_started_usec)


func chunk_runtime():
	return _chunk_runtime


func effective_typ_service():
	return _effective_typ_service


func unit_runtime_index():
	return _unit_runtime_index


func static_overlay_index():
	return _static_overlay_index


func overlay_apply_manager():
	return _runtime_state.overlay_apply_manager


func localized_overlay_sector_list() -> Array[Vector2i]:
	return _overlay_refresh_scope.overlay_sector_list()


func localized_dynamic_sector_list() -> Array[Vector2i]:
	return _overlay_refresh_scope.dynamic_sector_list()


func clear_localized_overlay_scope() -> void:
	_overlay_refresh_scope.clear()


func record_localized_overlay_sectors(sectors: Array) -> void:
	_overlay_refresh_scope.record_sectors(sectors)


func compute_effective_typ_for_map(cmd: Node, w: int, h: int, typ: PackedByteArray, blg: PackedByteArray, game_data_type: String) -> PackedByteArray:
	return _effective_typ_service.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)


func invalidate_all_chunks(w: int, h: int) -> void:
	_chunk_runtime.invalidate_all_chunks(w, h)


func needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	return _rebuild_policy.needs_full_rebuild(w, h, level_set)


func dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	return _rebuild_policy.dirty_chunks_sorted_by_priority(w, h)


func mark_chunks_dirty(chunk_coords: Array) -> void:
	_rebuild_policy.mark_chunks_dirty(chunk_coords)


func apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	_build_pipeline.apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)


func apply_localized_dynamic_overlay_refresh(cmd: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	_build_pipeline.apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)


func current_build_state_snapshot() -> Dictionary:
	return _renderer.get_build_state_snapshot()


func geometry_distance_culling_enabled() -> bool:
	return _runtime_state.geometry_distance_culling_enabled


func set_geometry_distance_culling_enabled(value: bool) -> void:
	_runtime_state.geometry_distance_culling_enabled = bool(value)


func geometry_cull_distance() -> float:
	return _runtime_state.geometry_cull_distance


func set_geometry_cull_distance(value: float) -> void:
	_runtime_state.geometry_cull_distance = float(value)


func debug_shader_mode() -> int:
	return _runtime_state.debug_shader_mode


func edge_overlay_enabled() -> bool:
	return _runtime_state.edge_overlay_enabled


func terrain_material_cache() -> Dictionary:
	return _runtime_state.terrain_material_cache


func edge_material_cache() -> Dictionary:
	return _runtime_state.edge_material_cache


func sector_top_shader() -> Shader:
	return _runtime_state.sector_top_shader


func set_sector_top_shader(shader: Shader) -> void:
	_runtime_state.sector_top_shader = shader


func edge_blend_shader() -> Shader:
	return _runtime_state.edge_blend_shader


func set_edge_blend_shader(shader: Shader) -> void:
	_runtime_state.edge_blend_shader = shader

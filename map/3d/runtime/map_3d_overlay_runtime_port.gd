extends RefCounted


var _unit_runtime_index = null
var _static_overlay_index = null
var _overlay_refresh_scope = null
var _runtime_state = null
var _build_pipeline = null


func bind(unit_runtime_index, static_overlay_index, overlay_refresh_scope, runtime_state, build_pipeline = null) -> void:
	_unit_runtime_index = unit_runtime_index
	_static_overlay_index = static_overlay_index
	_overlay_refresh_scope = overlay_refresh_scope
	_runtime_state = runtime_state
	_build_pipeline = build_pipeline


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


func apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	_build_pipeline.apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)


func apply_localized_dynamic_overlay_refresh(cmd: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	_build_pipeline.apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)


func geometry_distance_culling_enabled() -> bool:
	return bool(_runtime_state.geometry_distance_culling_enabled)

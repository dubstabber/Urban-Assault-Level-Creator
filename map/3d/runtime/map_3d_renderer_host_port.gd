extends RefCounted


var _renderer = null


func bind(renderer) -> void:
	_renderer = renderer


func emit_build_state_changed(is_building: bool, completed: int, total: int, status: String) -> void:
	_renderer.build_state_changed.emit(is_building, completed, total, status)


func emit_build_finished(success: bool) -> void:
	_renderer.build_finished.emit(success)


func defer_apply_pending_refresh() -> void:
	_renderer.call_deferred("_apply_pending_refresh")


func max_incremental_unit_batch() -> int:
	return int(_renderer._MAX_INCREMENTAL_UNIT_BATCH)


func async_chunk_apply_budget() -> int:
	return int(_renderer._async_chunk_apply_budget())


func async_overlay_apply_budget(descriptor_count: int = 0) -> int:
	return int(_renderer._async_overlay_apply_budget(descriptor_count))


func sector_size() -> float:
	return float(_renderer.SECTOR_SIZE)


func height_scale() -> float:
	return float(_renderer.HEIGHT_SCALE)


func normal_geometry_cull_distance() -> float:
	return float(_renderer.UA_NORMAL_GEOMETRY_CULL_DISTANCE)


func advance_debug_shader_mode() -> int:
	_renderer._debug_shader_mode = (_renderer._debug_shader_mode + 1) % 3
	return int(_renderer._debug_shader_mode)


func apply_debug_mode_to_existing_materials() -> void:
	_renderer._apply_debug_mode_to_existing_materials()

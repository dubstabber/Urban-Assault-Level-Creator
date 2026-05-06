extends RefCounted


var _renderer = null
var _camera_controller = null


func bind(renderer, camera_controller = null) -> void:
	_renderer = renderer
	_camera_controller = camera_controller


func renderer_node():
	return _renderer


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


func sync_terrain_overlay_animation_mode_from_editor() -> void:
	_renderer._sync_terrain_overlay_animation_mode_from_editor()


func frame_if_needed() -> void:
	if _camera_controller != null:
		_camera_controller.frame_if_needed()
	else:
		_renderer._frame_if_needed()


func set_camera_framed(value: bool) -> void:
	if _camera_controller != null:
		_camera_controller.set_framed(value)
	else:
		_renderer._camera_controller.set_framed(value)


func advance_debug_shader_mode() -> int:
	_renderer._debug_shader_mode = (_renderer._debug_shader_mode + 1) % 3
	return int(_renderer._debug_shader_mode)


func apply_debug_mode_to_existing_materials() -> void:
	_renderer._apply_debug_mode_to_existing_materials()

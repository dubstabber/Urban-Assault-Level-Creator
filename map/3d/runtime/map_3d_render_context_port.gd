extends RefCounted


var _renderer = null


func bind(renderer) -> void:
	_renderer = renderer


func event_system() -> Node:
	return _renderer._event_system()


func current_map_data() -> Node:
	return _renderer._current_map_data()


func editor_state() -> Node:
	return _renderer._editor_state()


func preloads() -> Node:
	return _renderer._preloads()


func current_game_data_type() -> String:
	return _renderer._current_game_data_type()


func preview_refresh_active() -> bool:
	return _renderer._preview_refresh_active()


func is_3d_view_visible() -> bool:
	return _renderer._is_3d_view_visible()


func terrain_overlay_animations_enabled() -> bool:
	return _renderer._runtime_context.terrain_overlay_animations_enabled()


func visibility_range_enabled() -> bool:
	return _renderer._runtime_context.visibility_range_enabled()


extends RefCounted

var _renderer = null
var _event_system_override: Node = null
var _current_map_data_override: Node = null
var _editor_state_override: Node = null
var _preloads_override: Node = null
var _preloads_override_set := false


func bind(renderer) -> void:
	_renderer = renderer


func set_event_system_override(event_system: Node) -> void:
	_event_system_override = event_system


func set_current_map_data_override(current_map_data: Node) -> void:
	_current_map_data_override = current_map_data


func set_editor_state_override(editor_state: Node) -> void:
	_editor_state_override = editor_state


func set_preloads_override(preloads: Node) -> void:
	_preloads_override = preloads
	_preloads_override_set = true


func event_system() -> Node:
	if _event_system_override != null and is_instance_valid(_event_system_override):
		return _event_system_override
	return _root_service("EventSystem")


func current_map_data() -> Node:
	if _current_map_data_override != null and is_instance_valid(_current_map_data_override):
		return _current_map_data_override
	return _root_service("CurrentMapData")


func editor_state() -> Node:
	if _editor_state_override != null and is_instance_valid(_editor_state_override):
		return _editor_state_override
	return _root_service("EditorState")


func preloads() -> Node:
	if _preloads_override_set:
		if _preloads_override != null and is_instance_valid(_preloads_override):
			return _preloads_override
		return null
	return _root_service("Preloads")


func is_3d_view_visible() -> bool:
	var editor_state := editor_state()
	if editor_state != null:
		return bool(editor_state.get("view_mode_3d"))
	return true


func preview_refresh_active(is_async_pipeline_active: bool) -> bool:
	if is_async_pipeline_active:
		return true
	return is_3d_view_visible()


func current_game_data_type() -> String:
	var editor_state := editor_state()
	var game_data_type := "original"
	if editor_state != null:
		var editor_game_data_type = editor_state.get("game_data_type")
		if editor_game_data_type != null:
			game_data_type = String(editor_game_data_type)
	return "original" if game_data_type.is_empty() else game_data_type


func terrain_overlay_animations_enabled() -> bool:
	var editor_state := editor_state()
	if editor_state == null:
		return true
	var raw: Variant = editor_state.get("map_3d_terrain_overlay_animations_enabled")
	if typeof(raw) == TYPE_BOOL:
		return bool(raw)
	return true


func visibility_range_enabled() -> bool:
	var editor_state := editor_state()
	if editor_state != null:
		return bool(editor_state.get("map_3d_visibility_range_enabled"))
	return false


func _root_service(node_name: String) -> Node:
	if _renderer != null and _renderer.is_inside_tree():
		var tree: SceneTree = _renderer.get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null(node_name)
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null(node_name)
	return null

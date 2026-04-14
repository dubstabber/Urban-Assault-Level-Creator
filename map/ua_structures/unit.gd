class_name Unit extends Sprite2D

signal position_changed

var dragging := false
var of := Vector2(0, 0)
var unit_name: String
var init_pos := Vector2.ZERO
var editor_unit_id := 0:
	set(value):
		editor_unit_id = max(0, value)
		var current_map_data := _current_map_data()
		if editor_unit_id > 0 and current_map_data != null:
			current_map_data.reserve_editor_unit_id(editor_unit_id)

var owner_id: int
var vehicle: int:
	set(value):
		vehicle = value
		check_player_vehicle()

var player_vehicle: int
var mb_status := false

var pos_to_move: Vector2
var drag_before_snapshot: Dictionary = {}
var top_limit := 1200
var bottom_limit := 1200
var left_limit := 1200
var right_limit := 1200


func _current_map_data() -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("CurrentMapData")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("CurrentMapData")
	return null


func _editor_state() -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("EditorState")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("EditorState")
	return null


func _event_system() -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("EventSystem")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("EventSystem")
	return null


func _preloads() -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("Preloads")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("Preloads")
	return null


func _ready() -> void:
	ensure_editor_unit_id()
	recalculate_limits()
	var event_system := _event_system()
	if event_system != null and event_system.has_signal("game_type_changed"):
		event_system.game_type_changed.connect(check_player_vehicle)


func _process(_delta):
	if dragging:
		pos_to_move = get_global_mouse_position() - of
		var current_map_data := _current_map_data()
		if init_pos != position and current_map_data != null:
			current_map_data.is_saved = false
		if pos_to_move.x > left_limit and pos_to_move.x < right_limit:
			position.x = pos_to_move.x
		if pos_to_move.y > top_limit and pos_to_move.y < bottom_limit:
			position.y = pos_to_move.y

		position_changed.emit()


func _on_button_button_down():
	var undo_redo_manager = get_node("/root/UndoRedoManager")
	drag_before_snapshot = undo_redo_manager.create_unit_snapshot()
	dragging = true
	of = get_global_mouse_position() - position
	init_pos = position


func _on_button_button_up():
	var moved := init_pos != position
	dragging = false
	if moved:
		var undo_redo_manager = get_node("/root/UndoRedoManager")
		undo_redo_manager.begin_group("Move unit")
		var unit_before: Dictionary = drag_before_snapshot
		undo_redo_manager.record_unit_snapshot(unit_before, undo_redo_manager.create_unit_snapshot())
		undo_redo_manager.commit_group()
		UnitChangeDispatcher.emit_for_unit(self, "moved")


func ensure_editor_unit_id() -> int:
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return editor_unit_id
	if editor_unit_id <= 0:
		editor_unit_id = current_map_data.allocate_editor_unit_id()
	else:
		current_map_data.reserve_editor_unit_id(editor_unit_id)
	return editor_unit_id


func recalculate_limits():
	var current_map_data := _current_map_data()
	if current_map_data == null:
		bottom_limit = 1200
		right_limit = 1200
		return
	bottom_limit = int(current_map_data.vertical_sectors) * 1200 + 1200
	right_limit = int(current_map_data.horizontal_sectors) * 1200 + 1200


func _on_button_mouse_entered() -> void:
	var editor_state := _editor_state()
	if editor_state != null:
		editor_state.mouse_over_unit = self


func _on_button_mouse_exited() -> void:
	var editor_state := _editor_state()
	if editor_state != null and self == editor_state.mouse_over_unit:
		editor_state.mouse_over_unit = null


func check_player_vehicle() -> void:
	if not self is HostStation:
		return
	
	var preloads := _preloads()
	var editor_state := _editor_state()
	if preloads == null or editor_state == null:
		return
	var game_data = preloads.ua_data.data[editor_state.game_data_type]
	var hoststations = game_data.hoststations
	
	for hs_key in hoststations:
		var robos = hoststations[hs_key].robos
		for robo in robos:
			if robo.id == vehicle:
				player_vehicle = robo.get("player_id", -1)
				return

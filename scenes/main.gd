extends Control

@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var map = %Map


func _ready():
	get_tree().root.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	EventSystem.unit_right_selected.connect(_on_unit_selected)
	_on_resize()


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_global_mouse_position().x) + get_window().position.x
		var mouse_y = round(get_global_mouse_position().y) + get_window().position.y

		map.right_clicked_x_global = mouse_x
		map.right_clicked_y_global = mouse_y
	if event.is_action_pressed("save_map"):
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		if CurrentMapData.map_path.is_empty():
			%SaveLevelFileDialog.popup()
		else:
			SingleplayerSaver.save()


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	map.recalculate_size()
	sub_viewport_map_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_map_container.custom_minimum_size.y = map.map_visible_height


func _on_unit_selected() -> void:
	if CurrentMapData.selected_unit:
		%MapContextMenu.hide()
		%UnitContextMenu.position = %MapContextMenu.position
		%UnitContextMenu.popup()

extends Control

@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var map = %Map


func _ready():
	get_tree().root.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	CurrentMapData.right_selected.connect(_on_unit_selected)
	_on_resize()


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_global_mouse_position().x)
		var mouse_y = round(get_global_mouse_position().y)
		map.right_clicked_x_global = mouse_x
		map.right_clicked_y_global = mouse_y
	if event is InputEventKey and event.pressed:
		var number_key = event.unicode - KEY_0
		if number_key >= 0 and number_key <= 7:
			change_sector_owner(number_key)


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	map.recalculate_size()
	sub_viewport_map_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_map_container.custom_minimum_size.y = map.map_visible_height


func change_sector_owner(number_key) -> void:
	if CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.own_map.size() > 0:
		CurrentMapData.own_map[CurrentMapData.selected_sector_idx] = number_key
		EventSystem.map_updated.emit()


func _on_unit_selected() -> void:
	if CurrentMapData.selected_unit:
		%MapContextMenu.hide()
		%UnitContextMenu.position = %MapContextMenu.position
		%UnitContextMenu.popup()

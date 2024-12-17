extends Control


func _ready():
	get_tree().set_auto_accept_quit(false)
	get_viewport().files_dropped.connect(_on_files_dropped)


func _on_files_dropped(files: Array):
	if not files.is_empty():
		var file_path = files[0]
		EventSystem.open_map_drag_requested.emit(file_path)


func _input(event):
	if event.is_action_pressed("context_menu"):
		var clicked_x = round(get_global_mouse_position().x) + get_window().position.x
		var clicked_y = round(get_global_mouse_position().y) + get_window().position.y
		EventSystem.global_right_clicked.emit(clicked_x, clicked_y)
	if event.is_action_pressed("save_map"):
		EventSystem.save_map_requested.emit()
	if event.is_action_pressed("unselect"):
		if %PropertiesContainer.visible:
			%PropertiesContainer.hide()
		else:
			CurrentMapData.selected_unit = null
			CurrentMapData.selected_sector_idx = -1
			CurrentMapData.border_selected_sector_idx = -1
			CurrentMapData.selected_sector = Vector2i(-1, -1)
			CurrentMapData.selected_sectors.clear()
			CurrentMapData.selected_beam_gate = null
			CurrentMapData.selected_bomb = null
			CurrentMapData.selected_tech_upgrade = null
			CurrentMapData.selected_bg_key_sector = Vector2i(-1, -1)
			CurrentMapData.selected_bomb_key_sector = Vector2i(-1, -1)
			EventSystem.map_updated.emit()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		EventSystem.exit_editor_requested.emit()

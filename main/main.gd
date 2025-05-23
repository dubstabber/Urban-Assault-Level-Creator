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
		if EditorState.selected_sector.x >= 0 or EditorState.selected_sectors.size() > 0:
			EditorState.unselect_all()
			EventSystem.map_view_updated.emit()
		else:
			%PropertiesContainer.hide()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		EventSystem.exit_editor_requested.emit()

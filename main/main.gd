extends Control


func _ready():
	get_tree().set_auto_accept_quit(false)


func _input(event):
	if event.is_action_pressed("context_menu"):
		var clicked_x = round(get_global_mouse_position().x) + get_window().position.x
		var clicked_y = round(get_global_mouse_position().y) + get_window().position.y
		EventSystem.global_right_clicked.emit(clicked_x, clicked_y)
	if event.is_action_pressed("save_map"):
		EventSystem.save_map_requested.emit()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		EventSystem.exit_editor_requested.emit()

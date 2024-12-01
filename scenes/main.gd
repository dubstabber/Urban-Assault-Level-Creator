extends Control

signal unsaved_decided

@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var map = %Map


func _ready():
	get_tree().set_auto_accept_quit(false)
	get_tree().root.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	_on_resize()
	%OpenLevelFileDialog.file_selected.connect(func(path: String):
		CurrentMapData.close_map()
		CurrentMapData.map_path = path
		SingleplayerOpener.load_level()
		)
	%SaveLevelFileDialog.file_selected.connect(func(path: String):
		CurrentMapData.map_path = path
		SingleplayerSaver.save()
		)
	EventSystem.new_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await unsaved_decided
		%NewMapWindow.popup()
		)
	EventSystem.open_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await unsaved_decided
		%OpenLevelFileDialog.popup()
		)
	EventSystem.save_map_requested.connect(func():
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		if CurrentMapData.map_path.is_empty():
			%SaveLevelFileDialog.popup()
		else:
			SingleplayerSaver.save()
		)
	EventSystem.save_as_map_requested.connect(func():
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		%SaveLevelFileDialog.popup()
		)
	EventSystem.close_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await unsaved_decided
		CurrentMapData.close_map()
		EventSystem.map_updated.emit()
		CurrentMapData.is_saved = true
		get_tree().get_root().size_changed.emit()
		)
	EventSystem.exit_editor_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await unsaved_decided
		get_tree().quit()
		)
	%UnsavedMapConfirmationDialog.confirmed.connect(func():
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		if CurrentMapData.map_path.is_empty():
			%SaveLevelFileDialog.popup()
			await %SaveLevelFileDialog.file_selected
		else:
			SingleplayerSaver.save()
		unsaved_decided.emit()
		)
	%UnsavedMapConfirmationDialog.canceled.connect(func():
		unsaved_decided.emit()
		)


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_global_mouse_position().x) + get_window().position.x
		var mouse_y = round(get_global_mouse_position().y) + get_window().position.y

		map.right_clicked_x_global = mouse_x
		map.right_clicked_y_global = mouse_y
	if event.is_action_pressed("save_map"):
		EventSystem.save_map_requested.emit()


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	map.recalculate_size()
	sub_viewport_map_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_map_container.custom_minimum_size.y = map.map_visible_height


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		EventSystem.exit_editor_requested.emit()

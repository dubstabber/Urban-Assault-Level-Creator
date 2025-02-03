extends Node


func _ready() -> void:
	EventSystem.new_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		%NewMapWindow.popup()
	)
	EventSystem.open_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		%OpenLevelFileDialog.popup()
		)
	EventSystem.open_map_drag_requested.connect(func(file_path: String):
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		CurrentMapData.close_map()
		CurrentMapData.map_path = file_path
		SingleplayerOpener.load_level()
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
			await %UnsavedMapConfirmationDialog.close_requested
		CurrentMapData.close_map()
		EventSystem.map_updated.emit()
		CurrentMapData.is_saved = true
		get_tree().get_root().size_changed.emit()
		)
	EventSystem.exit_editor_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		get_tree().quit()
		)

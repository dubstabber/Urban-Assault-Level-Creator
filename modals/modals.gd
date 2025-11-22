extends Node


func _ready() -> void:
	EventSystem.new_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		await _show_modal_window(%NewMapWindow)
	)
	EventSystem.open_map_requested.connect(func():
		if not CurrentMapData.is_saved:
			%UnsavedMapConfirmationDialog.show()
			await %UnsavedMapConfirmationDialog.close_requested
		await _show_modal_window(%OpenLevelFileDialog)
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
			await _show_modal_window(%SaveLevelFileDialog)
		else:
			SingleplayerSaver.save()
		)
	EventSystem.save_as_map_requested.connect(func():
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		await _show_modal_window(%SaveLevelFileDialog)
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


# Workaround for Godot 4.4+ exclusive window focus bug
# When showing exclusive windows, we need to explicitly request focus to prevent input blocking
func _show_modal_window(window: Window) -> void:
	window.popup()
	# Small delay to ensure window is properly initialized before grabbing focus
	await get_tree().process_frame
	# Find first focusable child and grab focus
	var focusable = _find_focusable_child(window)
	if focusable:
		focusable.grab_focus()
	else:
		window.grab_focus()


func _find_focusable_child(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node as Control
	for child in node.get_children():
		var result = _find_focusable_child(child)
		if result:
			return result
	return null

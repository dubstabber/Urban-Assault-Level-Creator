extends AcceptDialog


func _ready() -> void:
	EventSystem.open_map_failed.connect(func(error_type: String):
		title = "Open map error"
		dialog_text = "Error: The map from the file '%s' could not be loaded:\n" % CurrentMapData.map_path
		match error_type:
			"path_inaccessible":
				dialog_text += "The path is not accessible and cannot be opened."
			"inconsistent_data":
				dialog_text += "The data in the file is either inconsistent or incorrect:\n\n"
				dialog_text += "typ_map size: %s\n" % CurrentMapData.typ_map.size()
				dialog_text += "own_map size: %s\n" % CurrentMapData.own_map.size()
				dialog_text += "blg_map size: %s\n" % CurrentMapData.blg_map.size()
				dialog_text += "hgt_map size: %s\n" % CurrentMapData.hgt_map.size()
				dialog_text += "Horizontal sectors: %s\n" % CurrentMapData.horizontal_sectors
				dialog_text += "Vertical sectors: %s\n" % CurrentMapData.vertical_sectors
				var total_sectors = CurrentMapData.horizontal_sectors * CurrentMapData.vertical_sectors
				var total_border_sectors = (CurrentMapData.horizontal_sectors + 2) * (CurrentMapData.vertical_sectors + 2)
				dialog_text += "Total sectors: %s\n" % total_sectors
				dialog_text += "Total sectors with borders: %s" % total_border_sectors
			"invalid_format":
				dialog_text += "The file is not a valid LDF format."
			_:
				dialog_text += "An unknown error occurred."
		_show_modal_with_focus.call_deferred()
		CurrentMapData.close_map()
		EventSystem.map_updated.emit()
		get_tree().root.size_changed.emit()
		CurrentMapData.is_saved = true
		)
	EventSystem.save_map_failed.connect(func(error_type: String):
		title = "Save map error"
		dialog_text = "Error: The file '%s' cannot be saved:\n" % CurrentMapData.map_path
		match error_type:
			"path_inaccessible":
				dialog_text += "The path is not accessible and cannot be saved."
			_:
				dialog_text += "An unknown error occurred."
		_show_modal_with_focus.call_deferred()
		)


func _show_modal_with_focus() -> void:
	popup()
	# Small delay to ensure window is properly initialized before grabbing focus
	await get_tree().process_frame
	# Find first focusable child and grab focus
	var focusable = _find_focusable_child(self)
	if focusable:
		focusable.grab_focus()
	else:
		grab_focus()


func _find_focusable_child(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE:
		return node as Control
	for child in node.get_children():
		var result = _find_focusable_child(child)
		if result:
			return result
	return null

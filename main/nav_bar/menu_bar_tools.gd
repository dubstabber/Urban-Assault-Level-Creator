extends PopupMenu


func _ready() -> void:
	add_check_item("Switch to building design mode")
	add_separator()
	add_item("Resize the map")
	add_item("Select all sectors")
	add_item("Select all sectors except the borders")
	add_item("Generate buildings randomly")
	set_default_values()
	index_pressed.connect(_on_index_pressed)
	EventSystem.editor_mode_changed.connect(_update_checkitem.bind("Switch to building design mode"))


func set_default_values() -> void:
	for i in range(get_item_count()):
		match get_item_text(i):
			"Switch to building design mode": set_item_checked(i, EditorState.mode == EditorState.States.TypMapDesign)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Switch to building design mode":
			%TypMapDesignerContainer.visible = not %TypMapDesignerContainer.visible
		"Resize the map":
			%ResizeMapWindow.popup()
		"Select all sectors":
			Utils.select_all_sectors()
		"Select all sectors except the borders":
			Utils.select_all_sectors(true)
		"Generate buildings randomly":
			%RandomizeTypMapConfirmationDialog.popup()


func _update_checkitem(item_name: String) -> void:
	match item_name:
		"Switch to building design mode":
			set_item_checked(_get_item_index_by_text(item_name), %TypMapDesignerContainer.visible)


func _get_item_index_by_text(text: String) -> int:
	for i in range(get_item_count()):
		if get_item_text(i) == text:
			return i
	return -1

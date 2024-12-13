extends PopupMenu


func _ready() -> void:
	add_item("Show map properties panel")
	add_separator()
	add_check_item("Switch to building design mode")
	add_separator()
	add_check_item("Toggle typ_map images")
	add_check_item("Toggle typ_map values")
	add_check_item("Toggle own_map values")
	add_check_item("Toggle hgt_map values")
	add_check_item("Toggle blg_map values")
	set_default_values()
	index_pressed.connect(_on_index_pressed)
	EventSystem.editor_mode_changed.connect(_update_checkitem.bind("Switch to building design mode"))


func set_default_values() -> void:
	for i in range(get_item_count()):
		match get_item_text(i):
			"Switch to building design mode": set_item_checked(i, EditorState.mode == EditorState.State.TypMapDesign)
			"Toggle typ_map images": set_item_checked(i, CurrentMapData.typ_map_images_visible)
			"Toggle typ_map values": set_item_checked(i, CurrentMapData.typ_map_values_visible)
			"Toggle own_map values": set_item_checked(i, CurrentMapData.own_map_values_visible)
			"Toggle hgt_map values": set_item_checked(i, CurrentMapData.hgt_map_values_visible)
			"Toggle blg_map values": set_item_checked(i, CurrentMapData.blg_map_values_visible)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Show map properties panel":
			%PropertiesContainer.show()
		"Switch to building design mode":
			%TypMapDesignerContainer.visible = not %TypMapDesignerContainer.visible
		"Toggle typ_map images":
			CurrentMapData.typ_map_images_visible = not CurrentMapData.typ_map_images_visible
			set_item_checked(index, CurrentMapData.typ_map_images_visible)
		"Toggle typ_map values":
			CurrentMapData.typ_map_values_visible = not CurrentMapData.typ_map_values_visible
			set_item_checked(index, CurrentMapData.typ_map_values_visible)
		"Toggle own_map values":
			CurrentMapData.own_map_values_visible = not CurrentMapData.own_map_values_visible
			set_item_checked(index, CurrentMapData.own_map_values_visible)
		"Toggle hgt_map values":
			CurrentMapData.hgt_map_values_visible = not CurrentMapData.hgt_map_values_visible
			set_item_checked(index, CurrentMapData.hgt_map_values_visible)
		"Toggle blg_map values":
			CurrentMapData.blg_map_values_visible = not CurrentMapData.blg_map_values_visible
			set_item_checked(index, CurrentMapData.blg_map_values_visible)


func _update_checkitem(item_name: String) -> void:
	match item_name:
		"Switch to building design mode":
			set_item_checked(_get_item_index_by_text(item_name), %TypMapDesignerContainer.visible)


func _get_item_index_by_text(text: String) -> int:
	for i in range(get_item_count()):
		if get_item_text(i) == text:
			return i
	return -1

extends PopupMenu


func _ready():
	add_item("New map")
	add_separator()
	add_item("Open map")
	add_separator()
	add_item("Save map")
	add_item("Save map as...")
	add_separator()
	add_item("Close current map")
	add_separator()
	add_item("Exit")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"New map":
			EventSystem.new_map_requested.emit()
		"Open map":
			EventSystem.open_map_requested.emit()
		"Save map":
			EventSystem.save_map_requested.emit()
		"Save map as...":
			EventSystem.save_as_map_requested.emit()
		"Close current map":
			EventSystem.close_map_requested.emit()
		"Exit":
			EventSystem.exit_editor_requested.emit()

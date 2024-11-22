extends PopupMenu

@onready var new_map_window = %NewMapWindow


func _ready():
	add_item("New map")
	add_item("Open map")
	add_separator()
	add_item("Save map")
	add_item("Save map as...")
	add_separator()
	add_item("Close current map")
	add_separator()
	add_item("Exit")
	index_pressed.connect(_on_index_pressed)
	%SaveLevelFileDialog.file_selected.connect(func(path: String):
		CurrentMapData.save_path = path
		SingleplayerSaver.save()
		)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"New map":
			new_map_window.show()
		"Open map":
			print("Implement opening a map")
		"Save map":
			if CurrentMapData.save_path.is_empty():
				%SaveLevelFileDialog.popup()
			else:
				SingleplayerSaver.save()
		"Save map as...":
			print("Implement saving a map as...")
		"Close current map":
			print("Implement closing the current map")
		"Exit":
			print("Implement closing the editor")

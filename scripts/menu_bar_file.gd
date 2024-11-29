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
	%OpenLevelFileDialog.file_selected.connect(func(path: String):
		CurrentMapData.close_map()
		CurrentMapData.map_path = path
		SingleplayerOpener.load_level()
		)
	%SaveLevelFileDialog.file_selected.connect(func(path: String):
		CurrentMapData.map_path = path
		SingleplayerSaver.save()
		)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"New map":
			new_map_window.show()
		"Open map":
			%OpenLevelFileDialog.popup()
		"Save map":
			if CurrentMapData.map_path.is_empty():
				%SaveLevelFileDialog.popup()
			else:
				SingleplayerSaver.save()
		"Save map as...":
			%SaveLevelFileDialog.popup()
		"Close current map":
			CurrentMapData.close_map()
			EventSystem.map_updated.emit()
			get_tree().get_root().size_changed.emit()
		"Exit":
			get_tree().quit()

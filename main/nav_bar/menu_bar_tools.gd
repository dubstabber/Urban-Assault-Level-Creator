extends PopupMenu


func _ready() -> void:
	add_item("Generate buildings randomly")
	add_item("Resize the map")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Generate buildings randomly":
			%RandomizeTypMapConfirmationDialog.popup()
		"Resize the map":
			%ResizeMapWindow.popup()

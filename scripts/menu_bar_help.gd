extends PopupMenu


func _ready() -> void:
	add_item("Campaign maps")
	add_item("Keyboard shortcuts")
	add_item("About")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Campaign maps":
			print("implement campagin maps panel")
		"Keyboard shortcuts":
			print("implment keyboard shortcuts")
		"About":
			print("implement about page")

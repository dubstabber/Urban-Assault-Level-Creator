extends PopupMenu


func _ready() -> void:
	add_item("Toggle typ_map values")
	add_item("Toggle own_map values")
	add_item("Toggle hgt_map values")
	add_item("Toggle blg_map values")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Toggle typ_map values":
			EventSystem.toggled_values_visibility.emit("typ_map")
		"Toggle own_map values":
			EventSystem.toggled_values_visibility.emit("own_map")
		"Toggle hgt_map values":
			EventSystem.toggled_values_visibility.emit("hgt_map")
		"Toggle blg_map values":
			EventSystem.toggled_values_visibility.emit("blg_map")

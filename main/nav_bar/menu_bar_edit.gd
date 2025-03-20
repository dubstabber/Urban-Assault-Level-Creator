extends PopupMenu


func _ready() -> void:
	add_item("Select all sectors")
	add_item("Select all sectors except the borders")
	index_pressed.connect(_on_index_pressed)

func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Select all sectors":
			Utils.select_all_sectors()
		"Select all sectors except the borders":
			Utils.select_all_sectors(true)

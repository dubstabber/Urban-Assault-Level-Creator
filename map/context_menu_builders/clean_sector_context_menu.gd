extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("Clean this sector")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	var item_text = get_parent().get_item_text(index)
	if item_text == "Clean this sector":
		if CurrentMapData.horizontal_sectors > 0:
			if EditorState.selected_sectors.size() > 1:
				for sector_dict in EditorState.selected_sectors:
					CurrentMapData.clear_sector(sector_dict.idx)
			else:
				CurrentMapData.clear_sector(EditorState.selected_sector_idx)

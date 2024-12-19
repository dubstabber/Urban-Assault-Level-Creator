extends VBoxContainer


func _ready() -> void:
	%NormalKeySectorOptionButton.item_selected.connect(func(index: int):
		if %NormalKeySectorOptionButton.get_item_id(index) < 256:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = %NormalKeySectorOptionButton.get_item_id(index)
			EventSystem.map_updated.emit()
		)
	%ParasiteKeySectorOptionButton.item_selected.connect(func(index: int):
		if %ParasiteKeySectorOptionButton.get_item_id(index) < 256:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = %ParasiteKeySectorOptionButton.get_item_id(index)
			EventSystem.map_updated.emit()
		)


func set_labels(key_sector_id: int, bomb_id: int, bomb_building_type: String) -> void:
	%KeySectorInfoLabel.text = "Bomb key sector %s" % key_sector_id
	%BombInfoLabel.text = "This bomb key sector belongs to Stoudson Bomb %s" % bomb_id
	match bomb_building_type:
		"normal": 
			%NormalKeySectorOptionButton.show()
			var item_index = %NormalKeySectorOptionButton.get_item_index(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			if item_index >= 0:
				%NormalKeySectorOptionButton.select(item_index)
			else:
				%NormalKeySectorOptionButton.select(2)
			%ParasiteKeySectorOptionButton.hide()
		"parasite":
			%ParasiteKeySectorOptionButton.show()
			var item_index = %ParasiteKeySectorOptionButton.get_item_index(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			if item_index >= 0:
				%ParasiteKeySectorOptionButton.select(item_index)
			else:
				%ParasiteKeySectorOptionButton.select(6)
			%NormalKeySectorOptionButton.hide()

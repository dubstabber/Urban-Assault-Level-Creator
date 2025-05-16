extends VBoxContainer

@onready var normal_key_sector_option_button: Button = %NormalKeySectorOptionButton
@onready var parasite_key_sector_option_button: Button = %ParasiteKeySectorOptionButton


func _ready() -> void:
	normal_key_sector_option_button.item_selected.connect(func(index: int):
		if normal_key_sector_option_button.get_item_id(index) < 256:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = normal_key_sector_option_button.get_item_id(index)
			EventSystem.map_updated.emit()
		)
	parasite_key_sector_option_button.item_selected.connect(func(index: int):
		if parasite_key_sector_option_button.get_item_id(index) < 256:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = parasite_key_sector_option_button.get_item_id(index)
			EventSystem.map_updated.emit()
		)


func set_labels(key_sector_id: int, bomb_id: int, bomb_building_type: String) -> void:
	%KeySectorInfoLabel.text = "Bomb key sector %s" % key_sector_id
	%BombInfoLabel.text = "This bomb key sector belongs to Stoudson Bomb %s" % bomb_id
	match bomb_building_type:
		"normal":
			normal_key_sector_option_button.show()
			var item_index = normal_key_sector_option_button.get_item_index(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			if item_index >= 0:
				normal_key_sector_option_button.select(item_index)
			else:
				normal_key_sector_option_button.select(2)
			parasite_key_sector_option_button.hide()
		"parasite":
			parasite_key_sector_option_button.show()
			var item_index = parasite_key_sector_option_button.get_item_index(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			if item_index >= 0:
				parasite_key_sector_option_button.select(item_index)
			else:
				parasite_key_sector_option_button.select(6)
			normal_key_sector_option_button.hide()

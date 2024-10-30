extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("Clean this sector")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	var item_text = get_parent().get_item_text(index)
	if item_text == "Clean this sector":
		CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 0
		CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = 0
		CurrentMapData.own_map[CurrentMapData.selected_sector_idx] = 0
		
		CurrentMapData.beam_gates.erase(CurrentMapData.selected_beam_gate)
		CurrentMapData.selected_beam_gate = null
		CurrentMapData.stoudson_bombs.erase(CurrentMapData.selected_bomb)
		CurrentMapData.selected_bomb = null
		CurrentMapData.tech_upgrades.erase(CurrentMapData.selected_tech_upgrade)
		CurrentMapData.selected_tech_upgrade = null
		for bg in CurrentMapData.beam_gates:
			bg.key_sectors.erase(CurrentMapData.selected_bg_key_sector)
		CurrentMapData.selected_bg_key_sector = Vector2i(-1,-1)
		for bomb in CurrentMapData.stoudson_bombs:
			bomb.key_sectors.erase(CurrentMapData.selected_bomb_key_sector)
		CurrentMapData.selected_bomb_key_sector = Vector2i(-1,-1)
		
		EventSystem.map_updated.emit()
		EventSystem.item_updated.emit()

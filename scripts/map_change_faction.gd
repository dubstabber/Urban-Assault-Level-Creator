extends Node


func _ready() -> void:
	await get_parent().ready
	var sector_faction_submenu: PopupMenu = PopupMenu.new()
	sector_faction_submenu.name = "sector_faction"
	get_parent().add_child(sector_faction_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		sector_faction_submenu.add_item(hs, Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)
	sector_faction_submenu.add_item("Neutral", 0)
	sector_faction_submenu.id_pressed.connect(
		func(id): 
			if CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.own_map.size() > 0:
				CurrentMapData.own_map[CurrentMapData.selected_sector_idx] = id
				EventSystem.map_updated.emit())
	get_parent().add_submenu_item("Change sector faction", "sector_faction")

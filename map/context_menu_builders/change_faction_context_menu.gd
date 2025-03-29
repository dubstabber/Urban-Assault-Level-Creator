extends Node


func _ready() -> void:
	await get_parent().ready
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	var sector_faction_submenu: PopupMenu = PopupMenu.new()
	sector_faction_submenu.name = "sector_faction"
	sector_faction_submenu["theme_override_fonts/font"] = Preloads.font
	get_parent().add_child(sector_faction_submenu)
	
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		sector_faction_submenu.add_item(hs, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
	sector_faction_submenu.add_item("Neutral", 0)
	
	
	sector_faction_submenu.id_pressed.connect(
		func(id): 
			if CurrentMapData.own_map.size() > 0:
				if EditorState.selected_sectors.size() > 1:
					for sector_dict in EditorState.selected_sectors:
						if id == 0 and sector_dict.has("idx") and CurrentMapData.blg_map[sector_dict.idx] not in [0, 35, 68]:
							CurrentMapData.own_map[sector_dict.idx] = 7
						else:
							if sector_dict.has("idx"):
								CurrentMapData.own_map[sector_dict.idx] = id
				elif EditorState.selected_sector_idx >= 0:
					if id == 0 and CurrentMapData.blg_map[EditorState.selected_sector_idx] not in [0, 35, 68]:
						CurrentMapData.own_map[EditorState.selected_sector_idx] = 7
					else:
						CurrentMapData.own_map[EditorState.selected_sector_idx] = id
				EventSystem.map_updated.emit())
	get_parent().add_submenu_item("Change sector faction", "sector_faction")

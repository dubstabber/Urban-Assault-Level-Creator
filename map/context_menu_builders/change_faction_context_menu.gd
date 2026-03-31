extends Node

@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


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
				undo_redo_manager.begin_group("Ownership change")
				if EditorState.selected_sectors.size() > 1:
					for sector_dict in EditorState.selected_sectors:
						if sector_dict.has("idx"):
							var idx := int(sector_dict.idx)
							var before := int(CurrentMapData.own_map[idx])
							if id == 0 and CurrentMapData.blg_map[idx] not in [0, 35, 68]:
								CurrentMapData.own_map[idx] = 7
							else:
								CurrentMapData.own_map[idx] = id
							undo_redo_manager.record_change({
								"map": "own_map",
								"index": idx,
								"before": before,
								"after": int(CurrentMapData.own_map[idx])
							})
				elif EditorState.selected_sector_idx >= 0:
					var idx := EditorState.selected_sector_idx
					var before := int(CurrentMapData.own_map[idx])
					if id == 0 and CurrentMapData.blg_map[EditorState.selected_sector_idx] not in [0, 35, 68]:
						CurrentMapData.own_map[EditorState.selected_sector_idx] = 7
					else:
						CurrentMapData.own_map[EditorState.selected_sector_idx] = id
					undo_redo_manager.record_change({
						"map": "own_map",
						"index": idx,
						"before": before,
						"after": int(CurrentMapData.own_map[idx])
					})
				undo_redo_manager.commit_group()
				EventSystem.map_updated.emit())
	get_parent().add_submenu_item("Change sector faction", "sector_faction")

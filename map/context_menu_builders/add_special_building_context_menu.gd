extends Node

var special_buildings_submenu: PopupMenu = PopupMenu.new()
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	await get_parent().ready
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	special_buildings_submenu.name = "special_buildings"
	special_buildings_submenu["theme_override_fonts/font"] = Preloads.font
	get_parent().add_child(special_buildings_submenu)
	update_menus()
	get_parent().add_submenu_item("Add special building", "special_buildings")
	special_buildings_submenu.id_pressed.connect(_id_pressed)
	EventSystem.game_type_changed.connect(update_menus)


func update_menus() -> void:
	for menu in special_buildings_submenu.get_children():
		menu.queue_free()
	special_buildings_submenu.clear(true)
	
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		for building: Dictionary in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name, building.id)
	for building in Preloads.ua_data.data[EditorState.game_data_type].other.buildings:
		special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name, building.id)


func _id_pressed(id: int) -> void:
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		for special_building in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			if special_building.id == id:
				add_special_building(id, special_building.typ_map, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
				return
	
	for special_building in Preloads.ua_data.data[EditorState.game_data_type].other.buildings:
		if special_building.id == id:
			add_special_building(id, special_building.typ_map, 7)
			return


func add_special_building(building_id: int, typ_map: int, own_map: int) -> void:
	if CurrentMapData.blg_map.size() > 0:
		undo_redo_manager.begin_group("Add special building")
		var edited_typ_indices: Array = []
		var edited_blg_indices: Array = []
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if sector_dict.has("idx"):
					var idx := int(sector_dict.idx)
					var blg_before := int(CurrentMapData.blg_map[idx])
					var typ_before := int(CurrentMapData.typ_map[idx])
					var own_before := int(CurrentMapData.own_map[idx])
					CurrentMapData.blg_map[idx] = building_id
					CurrentMapData.typ_map[idx] = typ_map
					CurrentMapData.own_map[idx] = own_map
					CurrentMapData.append_edited_map_index(edited_typ_indices, idx, typ_before, int(CurrentMapData.typ_map[idx]))
					CurrentMapData.append_edited_map_index(edited_blg_indices, idx, blg_before, int(CurrentMapData.blg_map[idx]))
					undo_redo_manager.record_change({
						"map": "blg_map",
						"index": idx,
						"before": blg_before,
						"after": int(CurrentMapData.blg_map[idx])
					})
					undo_redo_manager.record_change({
						"map": "typ_map",
						"index": idx,
						"before": typ_before,
						"after": int(CurrentMapData.typ_map[idx])
					})
					undo_redo_manager.record_change({
						"map": "own_map",
						"index": idx,
						"before": own_before,
						"after": int(CurrentMapData.own_map[idx])
					})
		elif EditorState.selected_sector_idx >= 0:
			var idx := EditorState.selected_sector_idx
			var blg_before := int(CurrentMapData.blg_map[idx])
			var typ_before := int(CurrentMapData.typ_map[idx])
			var own_before := int(CurrentMapData.own_map[idx])
			CurrentMapData.blg_map[idx] = building_id
			CurrentMapData.typ_map[idx] = typ_map
			CurrentMapData.own_map[idx] = own_map
			CurrentMapData.append_edited_map_index(edited_typ_indices, idx, typ_before, int(CurrentMapData.typ_map[idx]))
			CurrentMapData.append_edited_map_index(edited_blg_indices, idx, blg_before, int(CurrentMapData.blg_map[idx]))
			undo_redo_manager.record_change({
				"map": "blg_map",
				"index": idx,
				"before": blg_before,
				"after": int(CurrentMapData.blg_map[idx])
			})
			undo_redo_manager.record_change({
				"map": "typ_map",
				"index": idx,
				"before": typ_before,
				"after": int(CurrentMapData.typ_map[idx])
			})
			undo_redo_manager.record_change({
				"map": "own_map",
				"index": idx,
				"before": own_before,
				"after": int(CurrentMapData.own_map[idx])
			})
		undo_redo_manager.commit_group()
		EventSystem.map_updated.emit()

extends Node

var special_buildings_submenu: PopupMenu = PopupMenu.new()


func _ready() -> void:
	await get_parent().ready
	special_buildings_submenu.name = "special_buildings"
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
	if EditorState.selected_sector_idx >= 0 and CurrentMapData.blg_map.size() > 0:
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				CurrentMapData.blg_map[sector_dict.idx] = building_id
				CurrentMapData.typ_map[sector_dict.idx] = typ_map
				CurrentMapData.own_map[sector_dict.idx] = own_map
		else:
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = building_id
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = typ_map
			CurrentMapData.own_map[EditorState.selected_sector_idx] = own_map
		EventSystem.map_updated.emit()

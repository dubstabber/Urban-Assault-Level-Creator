extends Node


func _ready() -> void:
	await get_parent().ready
	var special_buildings_submenu: PopupMenu = PopupMenu.new()
	special_buildings_submenu.name = "special_buildings"
	get_parent().add_child(special_buildings_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		for building: Dictionary in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].buildings:
			special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name, building.id)
	for building in Preloads.ua_data.data[CurrentMapData.game_data_type].other.buildings:
		special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name, building.id)
	special_buildings_submenu.id_pressed.connect(_id_pressed)
	get_parent().add_submenu_item("Add special building", "special_buildings")


func _id_pressed(id: int) -> void:
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		for special_building in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].buildings:
			if special_building.id == id:
				add_special_building(id, special_building.typ_map, Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)
				return
	
	for special_building in Preloads.ua_data.data[CurrentMapData.game_data_type].other.buildings:
		if special_building.id == id:
			add_special_building(id, special_building.typ_map, 7)
			return


func add_special_building(building_id: int, typ_map: int, own_map: int) -> void:
	if CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.blg_map.size() > 0:
		CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = building_id
		CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = typ_map
		CurrentMapData.own_map[CurrentMapData.selected_sector_idx] = own_map
		EventSystem.map_updated.emit()

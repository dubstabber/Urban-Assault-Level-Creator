extends Node


func _ready() -> void:
	await get_parent().ready
	var special_buildings_submenu: PopupMenu = PopupMenu.new()
	special_buildings_submenu.name = "special_buildings"
	get_parent().add_child(special_buildings_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		for building: Dictionary in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].buildings:
			special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name)
	for building in Preloads.ua_data.data[CurrentMapData.game_data_type].other.buildings:
		special_buildings_submenu.add_icon_item(Preloads.building_icons[building.icon_type], building.name)
	get_parent().add_submenu_item("Add special building", "special_buildings")

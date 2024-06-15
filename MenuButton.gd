extends MenuButton


var add_hoststation_menu: PopupMenu = get_popup()
var add_squad: PopupMenu = get_popup()

var hs_submenu: PopupMenu = PopupMenu.new()
var squad_submenu: PopupMenu = PopupMenu.new()

@onready var map = $"../PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map"


func _ready():
	hs_submenu.name = "hoststation"
	add_hoststation_menu.add_child(hs_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		var hs_icon = load("res://resources/img/"+Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].icon)
		hs_submenu.add_icon_item(hs_icon, hs)
	hs_submenu.connect("index_pressed", add_hoststation)
	add_hoststation_menu.add_submenu_item("Add host station", "hoststation")
	
	squad_submenu.name = "squad"
	add_squad.add_child(squad_submenu)
	
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		var squads: PopupMenu = PopupMenu.new()
		squads.name = hs+"-squads"
		squad_submenu.add_child(squads)
		if Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].units.size() > 0:
			for squad in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].units:
				var squad_icon = load("res://resources/img/icons/"+squad.iconName)
				squads.add_icon_item(squad_icon, squad.name)
			squad_submenu.add_submenu_item(hs+" units", squads.name)
	
	if Preloads.ua_data.data[CurrentMapData.game_data_type].other.units.size() > 0:
		var _squads: PopupMenu = PopupMenu.new()
		_squads.name = "special-squads"
		squad_submenu.add_child(_squads)
		for squad in Preloads.ua_data.data[CurrentMapData.game_data_type].other.units:
			var squad_icon = load("res://resources/img/icons/"+squad.iconName)
			_squads.add_icon_item(squad_icon, squad.name)
		squad_submenu.add_submenu_item("Special units", _squads.name)

	add_squad.add_submenu_item("Add squad", "squad")


func add_hoststation(idx):
	map.add_hoststation(hs_submenu.get_item_text(idx))


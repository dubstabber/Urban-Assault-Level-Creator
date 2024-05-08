extends MenuButton

var add_hoststation_menu: PopupMenu = get_popup()
var add_squad: PopupMenu = get_popup()

var submenu1: PopupMenu = PopupMenu.new()
var submenu2: PopupMenu = PopupMenu.new()

var hs_submenu: PopupMenu = PopupMenu.new()

func _ready():
	hs_submenu.name = "hoststation"
	add_hoststation_menu.add_child(hs_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		hs_submenu.add_item(hs)
		#Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations.hs.icon
		#var hs_icon = load()
		#hs_submenu.add_icon_item()
	add_hoststation_menu.add_submenu_item("Add host station", "hoststation")

	#submenu1.name = "submenu"
	#add_hoststation_menu.add_child(submenu1)
	#submenu1.add_item("syb")
	#submenu1.add_item("syb2")

	submenu2.name = "submenu2"
	add_squad.add_child(submenu2)
	submenu2.add_item("The newer item")
	
	#add_hoststation_menu.add_submenu_item("Add host station", "submenu")
	add_squad.add_submenu_item("Add squad", "submenu2")

extends MenuButton


var add_hoststation_menu: PopupMenu = get_popup()
var add_squad: PopupMenu = get_popup()

var submenu1: PopupMenu = PopupMenu.new()
var submenu2: PopupMenu = PopupMenu.new()

var hs_submenu: PopupMenu = PopupMenu.new()

@onready var map = $"../ScrollContainer/SubViewportContainer/SubViewport/Map"


func _ready():
	hs_submenu.name = "hoststation"
	add_hoststation_menu.add_child(hs_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		var hs_icon = load("res://resources/img/"+Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].icon)
		hs_submenu.add_icon_item(hs_icon, hs)
	hs_submenu.connect("index_pressed", add_hoststation)
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


func add_hoststation(idx):
	match idx:
		0:
			map.add_hoststation("Resistance")
		1:
			print('add ghorkov')
		2:
			print('add taerkasten')
		3:
			print('add mykonian')
		4:
			print('add sulgogar')
		5:
			print('add black sect')
		6:
			print('add training hs')

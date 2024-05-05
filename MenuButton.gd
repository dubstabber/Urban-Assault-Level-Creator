extends MenuButton

var add_hoststation_menu: PopupMenu = get_popup()
var add_squad: PopupMenu = get_popup()

var submenu1: PopupMenu = PopupMenu.new()
var submenu2: PopupMenu = PopupMenu.new()

func _ready():
	submenu1.name = "submenu"
	add_hoststation_menu.add_child(submenu1)
	submenu1.add_item("submenu submenu1")

	submenu2.name = "submenu2"
	add_squad.add_child(submenu2)
	submenu2.add_item("The newer item")
	
	add_hoststation_menu.add_submenu_item("Add host station", "submenu")
	add_squad.add_submenu_item("Add squad", "submenu2")

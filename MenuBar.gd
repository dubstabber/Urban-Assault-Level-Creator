extends MenuBar

var submenu1: PopupMenu = PopupMenu.new()
var submenu2: PopupMenu = PopupMenu.new()

@onready var file_menu = $File

func _ready():
	file_menu.add_item("New map")
	
	submenu1.name = "submenu"
	file_menu.add_child(submenu1)
	submenu1.add_item("sub item 1")
	
	submenu2.name = "submenu2"
	submenu1.add_child(submenu2)
	submenu2.add_item("The newer item")
	
	file_menu.add_submenu_item("submenuitem", "submenu")
	submenu1.add_submenu_item("subermenu", "submenu2")


func _process(_delta):
	pass

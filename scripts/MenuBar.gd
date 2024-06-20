extends MenuBar

var submenu1: PopupMenu = PopupMenu.new()
var submenu2: PopupMenu = PopupMenu.new()

@onready var file_menu = $File
@onready var view_menu = $View

@onready var new_map_window = $"../NewMapWindow"


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

	file_menu.connect("index_pressed", _on_file_menu_pressed)


func _on_file_menu_pressed(id: int):
	match id:
		0:
			new_map_window.show()

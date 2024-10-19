extends PopupMenu

@onready var new_map_window = %NewMapWindow


func _ready():
	add_item("New map")
	
	var submenu1: PopupMenu = PopupMenu.new()
	submenu1.name = "submenu"
	add_child(submenu1)
	submenu1.add_item("sub item 1")
	
	var submenu2: PopupMenu = PopupMenu.new()
	submenu2.name = "submenu2"
	submenu1.add_child(submenu2)
	submenu2.add_item("The newer item")
	
	add_submenu_item("submenuitem", "submenu")
	submenu1.add_submenu_item("subermenu", "submenu2")

	connect("index_pressed", _on_file_menu_pressed)


func _on_file_menu_pressed(id: int):
	match id:
		0:
			new_map_window.show()

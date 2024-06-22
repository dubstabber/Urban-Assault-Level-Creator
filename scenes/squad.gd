class_name Squad extends Unit

var map_icon: String

var quantity := 1
var useable := false


func create(_owner_id: int, squad_data: Dictionary):
	vehicle = squad_data.id
	map_icon = squad_data.map_icon
	unit_name = squad_data.name
	change_faction(_owner_id)


func change_faction(_owner_id: int):
	owner_id = _owner_id
	match owner_id:
		1:
			texture = Preloads.squad_icons[map_icon].blue
		2:
			texture = Preloads.squad_icons[map_icon].green
		3:
			texture = Preloads.squad_icons[map_icon].white
		4:
			texture = Preloads.squad_icons[map_icon].yellow
		5:
			texture = Preloads.squad_icons[map_icon].gray
		6:
			texture = Preloads.squad_icons[map_icon].red
		7:
			texture = Preloads.squad_icons["square"].red2
	size = Vector2.ZERO
	pivot_offset = Vector2(texture.get_width()/2.0, texture.get_height()/2.0)

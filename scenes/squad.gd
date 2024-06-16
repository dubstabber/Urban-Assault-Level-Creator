extends Unit

var map_icon: String

var num := 1
var useable := false


func create(_owner_id: int, squad_data: Dictionary):
	vehicle = squad_data.id
	map_icon = squad_data.mapIcon
	change_faction(_owner_id)
	button.position -= Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	button.size = Vector2(texture.get_width(), texture.get_height())


func change_faction(_owner_id: int):
	owner_id = _owner_id
	match owner_id:
		1:
			texture = CurrentMapData.squad_images[map_icon].blue
		2:
			texture = CurrentMapData.squad_images[map_icon].green
		3:
			texture = CurrentMapData.squad_images[map_icon].white
		4:
			texture = CurrentMapData.squad_images[map_icon].yellow
		5:
			texture = CurrentMapData.squad_images[map_icon].gray
		6:
			texture = CurrentMapData.squad_images[map_icon].red
		7:
			texture = CurrentMapData.squad_images["square"].red2

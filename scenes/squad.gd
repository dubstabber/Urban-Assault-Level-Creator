extends Unit

var num := 1
var useable := false


func create(_owner_id: int, squad_data: Dictionary):
	owner_id = _owner_id
	vehicle = squad_data.id
	match owner_id:
		1:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].blue
		2:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].green
		3:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].white
		4:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].yellow
		5:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].gray
		6:
			texture = CurrentMapData.squad_images[squad_data.mapIcon].red
		7:
			texture = CurrentMapData.squad_images["square"].red2
			
	button.position -= Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	button.size = Vector2(texture.get_width(), texture.get_height())

class_name Squad extends Unit

var map_icon: String

var quantity := 1:
	set(value):
		quantity = value
		$Button.tooltip_text = "%sx %s" % [quantity, unit_name]
var useable := false


func _ready() -> void:
	EventSystem.game_type_changed.connect(setup_properties)
	EventSystem.game_type_changed.connect(change_faction)


func create(_owner_id: int, _vehicle_id: int):
	vehicle = _vehicle_id
	setup_properties()
	scale = Vector2(6,6)
	change_faction(_owner_id)


func setup_properties() -> void:
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		for squad: Dictionary in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].units:
			if squad.id == vehicle:
				map_icon = squad.map_icon
				unit_name = squad.name
				return
	for squad: Dictionary in Preloads.ua_data.data[EditorState.game_data_type].other.units:
		if squad.id == vehicle:
			map_icon = squad.map_icon
			unit_name = squad.name
			return
	unit_name = "Unknown unit"
	if map_icon.is_empty():
		map_icon = "square"


func change_faction(_owner_id: int = owner_id) -> void:
	owner_id = _owner_id
	match owner_id:
		1: texture = Preloads.squad_icons[map_icon].blue
		2: texture = Preloads.squad_icons[map_icon].green
		3: texture = Preloads.squad_icons[map_icon].white
		4: texture = Preloads.squad_icons[map_icon].yellow
		5: texture = Preloads.squad_icons[map_icon].gray
		6: texture = Preloads.squad_icons[map_icon].red
		7: texture = Preloads.squad_icons["square"].red2
		_: texture = Preloads.squad_icons["square"].unknown
	
	$Button.position = -Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	$Button.tooltip_text = "%sx %s" % [quantity, unit_name]

class_name Squad extends Unit

var map_icon: String

var quantity := 1:
	set(value):
		quantity = value
		button.tooltip_text = "%sx %s" % [quantity, unit_name]
var useable := false

@onready var button: Button = $Button


func _preloads() -> Node:
	return get_node_or_null("/root/Preloads")


func _editor_state() -> Node:
	return get_node_or_null("/root/EditorState")


func _event_system() -> Node:
	return get_node_or_null("/root/EventSystem")


func _ready() -> void:
	super._ready()
	var event_system := _event_system()
	if event_system != null and event_system.has_signal("game_type_changed"):
		event_system.game_type_changed.connect(setup_properties)
		event_system.game_type_changed.connect(change_faction)


func create(_owner_id: int, _vehicle_id: int):
	vehicle = _vehicle_id
	setup_properties()
	scale = Vector2(6, 6)
	change_faction(_owner_id)


func setup_properties() -> void:
	var preloads := _preloads()
	var editor_state := _editor_state()
	if preloads == null or editor_state == null:
		return
	var game_data = preloads.ua_data.data[editor_state.game_data_type]
	
	# Search in host stations
	var hoststations = game_data.hoststations
	for hs_key in hoststations:
		var units = hoststations[hs_key].units
		for squad in units:
			if squad.id == vehicle:
				map_icon = squad.map_icon
				unit_name = squad.name
				return
	
	# Search in other units
	var other_units = game_data.other.units
	for squad in other_units:
		if squad.id == vehicle:
			map_icon = squad.map_icon
			unit_name = squad.name
			return
	
	# Default fallback
	unit_name = "Unknown unit"
	if map_icon.is_empty():
		map_icon = "square"


func change_faction(_owner_id: int = owner_id) -> void:
	owner_id = _owner_id
	var preloads := _preloads()
	if preloads == null:
		return
	match owner_id:
		1: texture = preloads.squad_icons[map_icon].blue
		2: texture = preloads.squad_icons[map_icon].green
		3: texture = preloads.squad_icons[map_icon].white
		4: texture = preloads.squad_icons[map_icon].yellow
		5: texture = preloads.squad_icons[map_icon].gray
		6: texture = preloads.squad_icons[map_icon].red
		7: texture = preloads.squad_icons["square"].red2
		_: texture = preloads.squad_icons["square"].unknown
	
	if texture != null:
		button.position = - Vector2(texture.get_width() / 2.0, texture.get_height() / 2.0)
	button.tooltip_text = "%sx %s" % [quantity, unit_name]

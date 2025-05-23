class_name HostStation extends Unit

var pos_y := -500
var energy := 300000:
	set(value):
		energy = value
		button.tooltip_text = "%s\nEnergy: %s" % [unit_name, int(energy / 400.0)]
var view_angle := 0
var view_angle_enabled := false
var reload_const := 0
var reload_const_enabled := false
var con_budget := 100
var con_delay := 0
var def_budget := 99
var def_delay := 0
var rec_budget := 99
var rec_delay := 0
var rob_budget := 80
var rob_delay := 0
var pow_budget := 80
var pow_delay := 0
var rad_budget := 0
var rad_delay := 0
var saf_budget := 50
var saf_delay := 0
var cpl_budget := 99
var cpl_delay := 0

@onready var button: Button = $Button


func create(_owner_id, _vehicle):
	owner_id = _owner_id
	vehicle = _vehicle
	if owner_id > 0 and owner_id < 8:
		setup_properties()
		texture = Preloads.hs_images[owner_id]
	else:
		unit_name = "Invalid host station"
		texture = Preloads.error_icon
	
	scale = Vector2(16, 16)
	button.position = - Vector2(texture.get_width() / 2.0, texture.get_height() / 2.0)
	button.tooltip_text = "%s\nEnergy: %s" % [unit_name, int(energy / 400.0)]


func setup_properties() -> void:
	var hoststations = Preloads.ua_data.data[EditorState.game_data_type].hoststations
	for hs_key in hoststations:
		if hoststations[hs_key].owner == owner_id:
			unit_name = hs_key
			return

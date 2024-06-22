class_name HostStation extends Unit

var pos_y := -500
var energy := 300000
var view_angle := 0
var view_angle_enabled := false
var reload_const := 0
var reload_const_enabled := false
var con_budget := 30
var con_delay := 0
var def_budget := 90
var def_delay := 0
var rec_budget := 80
var rec_delay := 0
var rob_budget := 100
var rob_delay := 0
var pow_budget := 50
var pow_delay := 0
var rad_budget := 30
var rad_delay := 0
var saf_budget := 50
var saf_delay := 0
var cpl_budget := 100
var cpl_delay := 0


func create(_owner_id, _vehicle, _name):
	owner_id = _owner_id
	vehicle = _vehicle
	unit_name = _name
	texture = Preloads.hs_images[str(owner_id)]
	pivot_offset = Vector2(texture.get_width()/2.0, texture.get_height()/2.0)

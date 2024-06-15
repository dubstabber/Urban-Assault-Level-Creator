extends Unit

var pos_y := 500
var energy := 460000
var con_budget: int
var con_delay: int
var def_budget: int
var def_delay: int
var rec_budget: int
var rec_delay: int
var rob_budget: int
var rob_delay: int
var pow_budget: int
var pow_delay: int
var rad_budget: int
var rad_delay: int
var saf_budget: int
var saf_delay: int
var cpl_budget: int
var cpl_delay: int


func create(_owner_id, _vehicle):
	owner_id = _owner_id
	vehicle = _vehicle
	texture = CurrentMapData.hs_images[str(owner_id)]
	button.position -= Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	button.size = Vector2(texture.get_width(), texture.get_height())

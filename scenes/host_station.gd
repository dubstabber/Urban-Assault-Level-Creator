extends Sprite2D

var dragging := false
var of := Vector2(0,0)

var owner_id: int
var vehicle: int
var pos_y: int
var energy: int
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

var pos_to_move: Vector2
var top_limit := 1200
var bottom_limit := CurrentMapData.vertical_sectors*1200+1200
var left_limit := 1200
var right_limit := CurrentMapData.horizontal_sectors*1200+1200

@onready var button = $Button


func _process(_delta):
	if dragging:
		pos_to_move = get_global_mouse_position() - of
		if pos_to_move.x > left_limit and pos_to_move.x < right_limit:
			position.x = pos_to_move.x
		if pos_to_move.y > top_limit and pos_to_move.y < bottom_limit:
			position.y = pos_to_move.y


func _on_button_button_down():
	dragging = true
	of = get_global_mouse_position() - global_position


func _on_button_button_up():
	dragging = false


func _on_button_gui_input(event):
	if event.is_action_pressed("select"):
		CurrentMapData.selected_unit = self


func create(_owner_id, _vehicle):
	owner_id = _owner_id
	vehicle = _vehicle
	texture = CurrentMapData.hs_images[str(owner_id)]
	button.position -= Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	button.size = Vector2(texture.get_width(), texture.get_height())
	
	# Default parameters
	pos_y = 500
	energy = 460000


func recalculate_limits():
	bottom_limit = CurrentMapData.vertical_sectors*1200+1200
	right_limit = CurrentMapData.horizontal_sectors*1200+1200


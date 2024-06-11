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

var pos_to_move: Vector2

@onready var button = $Button


func _process(_delta):
	if dragging:
		pos_to_move = get_global_mouse_position() - of
		if pos_to_move.x > 1200 and pos_to_move.x < CurrentMapData.horizontal_sectors*1200+1200:
			position.x = pos_to_move.x
		if pos_to_move.y > 1200 and pos_to_move.y < CurrentMapData.vertical_sectors*1200+1200:
			position.y = pos_to_move.y


func _on_button_button_down():
	dragging = true
	of = get_global_mouse_position() - global_position


func _on_button_button_up():
	dragging = false


func create(_owner_id, _vehicle):
	owner_id = _owner_id
	vehicle = _vehicle
	texture = CurrentMapData.hs_images[str(owner_id)]
	button.position -= Vector2(texture.get_width()/2.0, texture.get_height()/2.0)
	button.size = Vector2(texture.get_width(), texture.get_height())
	
	# Default parameters
	pos_y = 500
	energy = 460000



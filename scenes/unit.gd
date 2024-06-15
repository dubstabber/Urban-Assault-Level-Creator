class_name Unit extends Sprite2D

var dragging := false
var of := Vector2(0,0)

var owner_id: int
var vehicle: int
var mb_status := false

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


func recalculate_limits():
	bottom_limit = CurrentMapData.vertical_sectors*1200+1200
	right_limit = CurrentMapData.horizontal_sectors*1200+1200



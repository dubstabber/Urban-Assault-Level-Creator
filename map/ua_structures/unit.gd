class_name Unit extends TextureRect

signal position_changed

var dragging := false
var of := Vector2(0,0)
var unit_name: String
var init_pos := Vector2.ZERO

var owner_id: int
var vehicle: int:
	set(value):
		vehicle = value
		if self is HostStation:
			for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
				for robo in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].robos:
					if robo.id == vehicle:
						if "player_id" in robo:
							player_vehicle = robo.player_id
						else:
							player_vehicle = -1
						break
var player_vehicle: int
var mb_status := false

var pos_to_move: Vector2
var top_limit := 1200
var bottom_limit := CurrentMapData.vertical_sectors*1200+1200
var left_limit := 1200
var right_limit := CurrentMapData.horizontal_sectors*1200+1200


func _process(_delta):
	if dragging:
		pos_to_move = get_global_mouse_position() - of
		if init_pos != position: CurrentMapData.is_saved = false
		if pos_to_move.x > left_limit and pos_to_move.x < right_limit:
			position.x = pos_to_move.x
		if pos_to_move.y > top_limit and pos_to_move.y < bottom_limit:
			position.y = pos_to_move.y

		position_changed.emit()


func _on_button_button_down():
	dragging = true
	of = get_global_mouse_position() - position
	init_pos = position


func _on_button_button_up():
	dragging = false


func recalculate_limits():
	bottom_limit = CurrentMapData.vertical_sectors*1200+1200
	right_limit = CurrentMapData.horizontal_sectors*1200+1200


func _on_button_mouse_entered() -> void:
	CurrentMapData.mouse_over_unit = self
	set_default_cursor_shape(CursorShape.CURSOR_POINTING_HAND)


func _on_button_mouse_exited() -> void:
	if self == CurrentMapData.mouse_over_unit:
		CurrentMapData.mouse_over_unit = null
	

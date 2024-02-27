extends Node2D


func _draw() -> void:
	draw_rect(Rect2(20,20, 1200,1200), Color.WHITE, false, 35.0)

func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("context_menu"):
			var mouse_x = round(get_global_mouse_position().x)
			var mouse_y = round(get_global_mouse_position().y)
			prints('right click, x:', mouse_x, " ,y:",mouse_y)

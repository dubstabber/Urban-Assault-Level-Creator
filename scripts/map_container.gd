extends ScrollContainer

var drag_start_position: Vector2
var is_dragging: bool = false

func _ready():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_position = event.position
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				is_dragging = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion and is_dragging:
		scroll_horizontal -= event.relative.x
		scroll_vertical -= event.relative.y
		

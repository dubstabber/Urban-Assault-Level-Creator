extends ScrollContainer

var drag_start_position: Vector2
var is_dragging: bool = false

@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var map = %Map


func _ready():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().root.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	_on_resize()


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
				drag_start_position = event.position
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				is_dragging = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	elif event is InputEventMouseMotion and is_dragging:
		scroll_horizontal -= event.relative.x
		scroll_vertical -= event.relative.y


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	map.recalculate_size()
	sub_viewport_map_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_map_container.custom_minimum_size.y = map.map_visible_height

extends ScrollContainer

var drag_start_position: Vector2
var is_dragging: bool = false

@onready var map_scroll_content: Control = %MapScrollContent
@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var map = %Map


func _ready():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().root.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	EventSystem.map_load_started.connect(_on_map_load_started)
	EventSystem.map_load_finished.connect(_on_map_load_finished)
	sub_viewport_map_container.gui_input.connect(_on_middle_pan_gui_input)
	_on_resize()


func _gui_input(event: InputEvent) -> void:
	# Scrollbars / scroll container chrome still hit this node.
	_on_middle_pan_gui_input(event)


func _on_middle_pan_gui_input(event: InputEvent) -> void:
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


func _on_map_load_started() -> void:
	var o: Control = %Map2DLoadingOverlay
	o.visible = true
	o.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_map_load_finished() -> void:
	var o: Control = %Map2DLoadingOverlay
	o.visible = false
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_resize():
	map.recalculate_size()
	map_scroll_content.custom_minimum_size.x = map.map_visible_width
	map_scroll_content.custom_minimum_size.y = map.map_visible_height

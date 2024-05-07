extends Node2D


@onready var map = $ScrollContainer/SubViewportContainer/SubViewport/Camera2D/Map
@onready var sub_viewport_container = $ScrollContainer/SubViewportContainer
@onready var scroll_container = $ScrollContainer
@onready var context_menu = $ContextMenu


func _ready():
	get_tree().get_root().connect("size_changed",_on_resize)

func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("context_menu"):
			var mouse_x = round(get_local_mouse_position().x)
			var mouse_y = round(get_local_mouse_position().y)
			context_menu.position = Vector2(mouse_x, mouse_y - context_menu.size.y)
			context_menu.show_popup()
			prints('main: right click, x:', mouse_x, " ,y:",mouse_y)


func _on_ui_map_created():
	map.queue_redraw()
	_on_resize()
	

func _on_resize():
	scroll_container.size.x = DisplayServer.window_get_size().x -1
	scroll_container.size.y = DisplayServer.window_get_size().y -1
	map.recalculate_size()
	sub_viewport_container.custom_minimum_size.x = map.map_total_width
	sub_viewport_container.custom_minimum_size.y = map.map_total_height

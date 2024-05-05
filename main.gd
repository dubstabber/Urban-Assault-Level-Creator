extends Node2D


#@onready var map = $Map
@onready var camera = $Camera2D
@onready var context_menu = $ContextMenu


func _ready():
	#camera.zoom = Vector2(.05,.05)
	pass




func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("context_menu"):
			var mouse_x = round(get_local_mouse_position().x)
			var mouse_y = round(get_local_mouse_position().y)
			context_menu.position = Vector2(mouse_x, mouse_y - context_menu.size.y)
			context_menu.show_popup()
			prints('main: right click, x:', mouse_x, " ,y:",mouse_y)

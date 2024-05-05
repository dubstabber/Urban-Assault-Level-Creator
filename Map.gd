extends Node2D


var zoom_minimum = Vector2(.03,.03)
var zoom_maximum = Vector2(.3,.3)
var zoom_speed = Vector2(.3,.3)

@onready var map_camera = $"../Camera2D"


func _ready():
	map_camera.zoom = Vector2(.05,.05)


func _physics_process(delta):
	if Input.is_action_pressed("zoom_in"):
		if map_camera.zoom > zoom_minimum:
			map_camera.zoom -= zoom_speed * delta
	elif Input.is_action_pressed("zoom_out"):
		if map_camera.zoom < zoom_maximum:
			map_camera.zoom += zoom_speed * delta


func _draw() -> void:
	draw_rect(Rect2(20,20, 1200,1200), Color.WHITE, false, 35.0)


func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("context_menu"):
			var mouse_x = round(get_local_mouse_position().x)
			var mouse_y = round(get_local_mouse_position().y)
			prints('right click, x:', mouse_x, " ,y:",mouse_y)

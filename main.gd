extends Node2D

var zoom_minimum = Vector2(.05,.05)
var zoom_maximum = Vector2(7.1,7.1)
var zoom_speed = Vector2(.3,.3)

@onready var map = $Map
@onready var camera = $Camera2D


func _ready():
	camera.zoom = Vector2(.05,.05)
	pass


func _physics_process(delta):
	if Input.is_action_pressed("zoom_in"):
		if camera.zoom > zoom_minimum:
			camera.zoom -= zoom_speed * delta
	elif Input.is_action_pressed("zoom_out"):
		if camera.zoom < zoom_maximum:
			camera.zoom += zoom_speed * delta

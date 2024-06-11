extends Node2D


var zoom_minimum = Vector2(.03,.03)
var zoom_maximum = Vector2(.3,.3)
var zoom_speed = Vector2(.06,.06)
var map_visible_width: int
var map_visible_height: int
var sector_indent: int = 40

var right_clicked_x: int
var right_clicked_y: int

@onready var map_camera = $Camera2D
@onready var host_stations = $HostStations


func _ready():
	pass


func _physics_process(delta):
	if Input.is_action_pressed("zoom_out"):
		if map_camera.zoom > zoom_minimum:
			map_camera.zoom -= zoom_speed * delta
			get_tree().get_root().size_changed.emit()
			
	elif Input.is_action_pressed("zoom_in"):
		if map_camera.zoom < zoom_maximum:
			map_camera.zoom += zoom_speed * delta
			get_tree().get_root().size_changed.emit()


func _input(event):
	if event is InputEventMouseButton:
		if event.is_action_pressed("context_menu"):
			right_clicked_x = round(get_local_mouse_position().x)
			right_clicked_y = round(get_local_mouse_position().y - 40)
			#prints('right click, x:', right_clicked_x, " ,y:",right_clicked_y)


func _draw():
	var v_grid := 1200
	for v_sector in CurrentMapData.vertical_sectors:
		var h_grid := 1200
		for h_sector in CurrentMapData.horizontal_sectors:
			draw_rect(Rect2(h_grid,v_grid, 1200-sector_indent,1200-sector_indent), Color.WHITE, false, 25.0)
			h_grid += 1200
		v_grid += 1200
	


func recalculate_size():
	map_visible_width = map_camera.zoom.x * ((CurrentMapData.horizontal_sectors+2) * 1200)
	map_visible_height = map_camera.zoom.y * ((CurrentMapData.vertical_sectors+2) * 1200)


func add_hoststation(hs: String):
	var hoststation = Preloads.HOSTSTATION.instantiate()
	host_stations.add_child(hoststation)
	hoststation.create(Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner,
		Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].robos[0].id)
	hoststation.position.x = right_clicked_x
	hoststation.position.y = right_clicked_y
	hoststation.scale = (Vector2(10,10))
	

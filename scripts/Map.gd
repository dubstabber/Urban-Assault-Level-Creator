extends Control


var zoom_minimum := Vector2(.03,.03)
var zoom_maximum := Vector2(.3,.3)
var zoom_speed := Vector2(.06,.06)
var map_visible_width: int
var map_visible_height: int
var sector_indent := 40

var right_clicked_x_global: int
var right_clicked_y_global: int
var right_clicked_x: int
var right_clicked_y: int
var is_selection_kept := false

@onready var map_camera = $Camera2D
@onready var host_stations = $HostStations
@onready var squads = $Squads


func _ready():
	Signals.hoststation_added.connect(add_hoststation)
	Signals.squad_added.connect(add_squad)
	


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
	if event.is_action_pressed("hold"):
		is_selection_kept = true
	elif event.is_action_released("hold"):
		is_selection_kept = false
	if event.is_action_pressed("select"):
		handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
		CurrentMapData.selected_unit = null
		if is_selection_kept:
			#TODO: Implement multi-sector selection
			print('selection is kept')
	if event.is_action_pressed("context_menu"):
		right_clicked_x = round(get_local_mouse_position().x)
		right_clicked_y = round(get_local_mouse_position().y - 40)

		%ContextMenu.position = Vector2(right_clicked_x_global, right_clicked_y_global)
		%ContextMenu.popup()
		#accept_event()
	if event is InputEventKey and event.pressed:
		var number_key = event.unicode - KEY_0
		if number_key >= 0 and number_key <= 7:
			change_sector_owner(number_key)


func _draw():
	if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
		return
	var current_sector := 0
	var current_border_sector := 0
	var v_grid := 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		var h_grid := 0
		for x_sector in CurrentMapData.horizontal_sectors+2:
			var sector_color
			if (x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and 
				y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1):
				match CurrentMapData.typ_map[current_sector]:
					0:
						sector_color = Color.BLACK
					1:
						sector_color = Color.BLUE
					2:
						sector_color = Color.GREEN
					3:
						sector_color = Color.WHITE
					4:
						sector_color = Color.YELLOW
					5:
						sector_color = Color.DIM_GRAY
					6:
						sector_color = Color.RED
					7:
						sector_color = Color.BLACK
				draw_rect(Rect2(h_grid,v_grid, 1200-sector_indent,1200-sector_indent), sector_color, false, 25.0)
				current_sector += 1
			if current_border_sector == CurrentMapData.border_selected_sector:
				draw_rect(Rect2(h_grid,v_grid, 1200-sector_indent,1200-sector_indent), Color.DARK_SLATE_GRAY)
			h_grid += 1200
			current_border_sector += 1
			
		v_grid += 1200


func recalculate_size():
	map_visible_width = map_camera.zoom.x * ((CurrentMapData.horizontal_sectors+2) * 1200)
	map_visible_height = map_camera.zoom.y * ((CurrentMapData.vertical_sectors+2) * 1200)


func add_hoststation(hs: String):
	var hoststation = Preloads.HOSTSTATION.instantiate()
	host_stations.add_child(hoststation)
	hoststation.create(Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner,
		Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].robos[0].id, hs)
	hoststation.position.x = right_clicked_x
	hoststation.position.y = right_clicked_y
	hoststation.scale = Vector2(10,10)
	CurrentMapData.selected_unit = hoststation


func add_squad(sq: Dictionary, owner_id: int):
	var squad = Preloads.SQUAD.instantiate()
	squads.add_child(squad)
	squad.create(owner_id, sq)
	squad.position.x = right_clicked_x
	squad.position.y = right_clicked_y
	squad.scale = Vector2(5,5)
	CurrentMapData.selected_unit = squad


func handle_selection(clicked_x: int, clicked_y: int):
	var sector_counter := 0
	var border_sector_counter := 0
	var h_size := 0
	var v_size := 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if clicked_x > h_size and clicked_x < h_size + 1200 and clicked_y > v_size and clicked_y < v_size + 1200:
				#prints(x_sector,y_sector)
				CurrentMapData.selected_sector = sector_counter
				CurrentMapData.border_selected_sector = border_sector_counter
				break
			h_size += 1200
			border_sector_counter += 1
			if (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1 and 
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1):
				sector_counter += 1
		v_size += 1200
		h_size = 0
	queue_redraw()


func change_sector_owner(owner_id: int):
	if CurrentMapData.selected_sector >= 0:
		CurrentMapData.typ_map[CurrentMapData.selected_sector] = owner_id
		queue_redraw()

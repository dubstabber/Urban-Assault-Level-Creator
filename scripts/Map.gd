extends Control


var zoom_minimum := Vector2(.03,.03)
var zoom_maximum := Vector2(.3,.3)
var zoom_speed := Vector2(.06,.06)
var map_visible_width: int
var map_visible_height: int
var sector_indent := 50.0
var font: Font
var sector_font_size := 170

var right_clicked_x_global: int
var right_clicked_y_global: int
var right_clicked_x: int
var right_clicked_y: int
var is_selection_kept := false

var typ_map_values_visible := false
var own_map_values_visible := false
var hgt_map_values_visible := false
var blg_map_values_visible := false

@onready var map_camera = $Camera2D
@onready var host_stations = $HostStations
@onready var squads = $Squads


func _ready() -> void:
	font = ThemeDB.fallback_font
	EventSystem.hoststation_added.connect(add_hoststation)
	EventSystem.squad_added.connect(add_squad)
	EventSystem.map_updated.connect(queue_redraw)
	EventSystem.toggled_values_visibility.connect(toggle_values_visibility)


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
		right_clicked_y = round(get_local_mouse_position().y)
		handle_selection(right_clicked_x, right_clicked_y)
		%MapContextMenu.position = Vector2(right_clicked_x_global, right_clicked_y_global)
		%MapContextMenu.popup()
	if (event.is_action_pressed("increment_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		CurrentMapData.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx] < 255):
		CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx] += 1
		queue_redraw()
	if (event.is_action_pressed("decrement_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		CurrentMapData.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx] > 0):
		CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx] -= 1
		queue_redraw()


func _draw():
	if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
		return
	var current_sector := 0
	var current_border_sector := 0
	var v_grid := 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		var h_grid := 0
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if current_border_sector == CurrentMapData.border_selected_sector_idx: 
				# Highlight for selection
				draw_rect(Rect2(h_grid,v_grid, 1200,1200), Color.DARK_SLATE_GRAY)
			if (x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and 
				y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1):
				if Preloads.special_building_images.has(str(CurrentMapData.blg_map[current_sector])):
					draw_texture_rect(Preloads.special_building_images[str(CurrentMapData.blg_map[current_sector])], Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)),false)
				var sector_color
				match CurrentMapData.own_map[current_sector]:
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
				draw_rect(Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)), sector_color, false, 30.0)
				
				if (y_sector > 1 and
					CurrentMapData.hgt_map[current_border_sector - (CurrentMapData.horizontal_sectors+2)] - CurrentMapData.hgt_map[current_border_sector] > 4):
					draw_line(Vector2(h_grid+sector_indent,v_grid+sector_indent/3.0), Vector2(h_grid+1200-sector_indent,v_grid+sector_indent/3.0), Color.AQUA, sector_indent/2)
				
				if (x_sector < CurrentMapData.horizontal_sectors and
					CurrentMapData.hgt_map[current_border_sector+1] - CurrentMapData.hgt_map[current_border_sector] > 4):
					draw_line(Vector2(h_grid+1200-sector_indent/3.0,v_grid+sector_indent), Vector2(h_grid+1200-sector_indent/3.0,v_grid+1200-sector_indent), Color.AQUA, sector_indent/2)
				
				if (y_sector < CurrentMapData.vertical_sectors and
					CurrentMapData.hgt_map[current_border_sector + (CurrentMapData.horizontal_sectors+2)] - CurrentMapData.hgt_map[current_border_sector] > 4):
					draw_line(Vector2(h_grid+sector_indent,v_grid+1200-sector_indent/3.0), Vector2(h_grid+1200-sector_indent,v_grid+1200-sector_indent/3.0), Color.AQUA, sector_indent/2)
				
				if (x_sector > 1 and
					CurrentMapData.hgt_map[current_border_sector-1] - CurrentMapData.hgt_map[current_border_sector] > 4):
					draw_line(Vector2(h_grid+sector_indent/3.0,v_grid+sector_indent), Vector2(h_grid+sector_indent/3.0,v_grid+1200-sector_indent), Color.AQUA, sector_indent/2)
				
				if typ_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size), "typ_map: "+ str(CurrentMapData.typ_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if own_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*2), "own_map: "+ str(CurrentMapData.own_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if blg_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*4), "blg_map: "+ str(CurrentMapData.blg_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				current_sector += 1
			if hgt_map_values_visible:
				draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*3), "hgt_map: "+ str(CurrentMapData.hgt_map[current_border_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
			h_grid += 1200
			current_border_sector += 1
		v_grid += 1200
	
	for beam_gate in CurrentMapData.beam_gates:
		var pos_x = beam_gate.sec_x * 1200 + sector_indent
		var pos_y = beam_gate.sec_y * 1200 + sector_indent
		draw_texture_rect(Preloads.sector_item_images.beam_gate, Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		for key_sector in beam_gate.key_sectors:
			var kpos_x = key_sector.x * 1200 + sector_indent
			var kpos_y = key_sector.y * 1200 + sector_indent
			draw_texture_rect(Preloads.sector_item_images.beam_gate_key_sector, Rect2(kpos_x, kpos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	for bomb in CurrentMapData.stoudson_bombs:
		var pos_x = bomb.sec_x * 1200 + sector_indent
		var pos_y = bomb.sec_y * 1200 + sector_indent
		draw_texture_rect(Preloads.sector_item_images.stoudson_bomb, Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		for key_sector in bomb.key_sectors:
			var kpos_x = key_sector.x * 1200 + sector_indent
			var kpos_y = key_sector.y * 1200 + sector_indent
			draw_texture_rect(Preloads.sector_item_images.bomb_key_sector, Rect2(kpos_x, kpos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	for tech_upgrade in CurrentMapData.tech_upgrades:
		var pos_x = tech_upgrade.sec_x * 1200 + sector_indent
		var pos_y = tech_upgrade.sec_y * 1200 + sector_indent
		draw_texture_rect(Preloads.sector_item_images.tech_upgrades[str(tech_upgrade.building_id)], Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	# _draw() ends here


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
				CurrentMapData.selected_sector_idx = sector_counter
				CurrentMapData.border_selected_sector_idx = border_sector_counter
				CurrentMapData.selected_sector.x = x_sector
				CurrentMapData.selected_sector.y = y_sector
				break
			h_size += 1200
			border_sector_counter += 1
			if (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1 and 
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1):
				sector_counter += 1
		v_size += 1200
		h_size = 0
	
	CurrentMapData.selected_beam_gate = null
	CurrentMapData.selected_bomb = null
	CurrentMapData.selected_bg_key_sector = Vector2i(-1, -1)
	CurrentMapData.selected_bomb_key_sector = Vector2i(-1, -1)
	CurrentMapData.selected_tech_upgrade = null
	
	for bg in CurrentMapData.beam_gates:
		if bg.sec_x == CurrentMapData.selected_sector.x and bg.sec_y == CurrentMapData.selected_sector.y:
			CurrentMapData.selected_beam_gate = bg
		for ks in bg.key_sectors:
			if ks.x == CurrentMapData.selected_sector.x and ks.y == CurrentMapData.selected_sector.y:
				CurrentMapData.selected_bg_key_sector = ks
	for bomb in CurrentMapData.stoudson_bombs:
		if bomb.sec_x == CurrentMapData.selected_sector.x and bomb.sec_y == CurrentMapData.selected_sector.y:
			CurrentMapData.selected_bomb = bomb
		for ks in bomb.key_sectors:
			if ks.x == CurrentMapData.selected_sector.x and ks.y == CurrentMapData.selected_sector.y:
				CurrentMapData.selected_bomb_key_sector = ks
	for tu in CurrentMapData.tech_upgrades:
		if tu.sec_x == CurrentMapData.selected_sector.x and tu.sec_y == CurrentMapData.selected_sector.y:
			CurrentMapData.selected_tech_upgrade = tu
	queue_redraw()


func toggle_values_visibility(type: String) -> void:
	match type:
		"typ_map":
			typ_map_values_visible = not typ_map_values_visible
		"own_map":
			own_map_values_visible = not own_map_values_visible
		"hgt_map":
			hgt_map_values_visible = not hgt_map_values_visible
		"blg_map":
			blg_map_values_visible = not blg_map_values_visible
	queue_redraw()

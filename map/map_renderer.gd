extends Node2D


var zoom_minimum := Vector2(.03,.03)
var zoom_maximum := Vector2(.3,.3)
var zoom_speed := Vector2(.06,.06)
var map_visible_width: int
var map_visible_height: int
var sector_indent := 50.0
var font: Font
var sector_font_size := 260

var right_clicked_x_global: int
var right_clicked_y_global: int
var right_clicked_x: int
var right_clicked_y: int
var is_selection_kept := false
var is_multi_selection := false
var selection_start_point := Vector2.ZERO
var current_mouse_pos := Vector2.ZERO

@onready var map_camera = $Camera2D


func _ready() -> void:
	CurrentMapData.host_stations = $HostStations
	CurrentMapData.squads = $Squads
	font = ThemeDB.fallback_font
	EventSystem.hoststation_added.connect(add_hoststation)
	EventSystem.squad_added.connect(add_squad)
	EventSystem.map_updated.connect(queue_redraw)
	EventSystem.map_view_updated.connect(queue_redraw)
	EventSystem.global_right_clicked.connect(func(x, y):
		right_clicked_x_global = x
		right_clicked_y_global = y
	)
	EventSystem.map_created.connect(func():
		map_camera.zoom = Vector2(0.056, 0.056)
		)


func _process(delta):
	if Input.is_action_pressed("zoom_out"):
		if map_camera.zoom > zoom_minimum:
			map_camera.zoom -= zoom_speed * delta
			get_tree().get_root().size_changed.emit()
			
	elif Input.is_action_pressed("zoom_in"):
		if map_camera.zoom < zoom_maximum:
			map_camera.zoom += zoom_speed * delta
			get_tree().get_root().size_changed.emit()


func _draw():
	if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
		return
	var current_sector := 0
	var current_border_sector := 0
	var v_grid := 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		var h_grid := 0
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if (x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and 
				y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1):
				if Preloads.building_top_images[CurrentMapData.level_set].has(CurrentMapData.typ_map[current_sector]):
					if EditorState.typ_map_images_visible:
						draw_texture_rect(Preloads.building_top_images[CurrentMapData.level_set][CurrentMapData.typ_map[current_sector]], Rect2(h_grid, v_grid, 1200, 1200), false)
				else:
					draw_texture_rect(Preloads.error_sign, Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)), false)
				if CurrentMapData.blg_map[current_sector] == 62 and CurrentMapData.level_set in [3, 4, 5]:
					draw_texture_rect(Preloads.error_sign, Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)), false)
				if CurrentMapData.blg_map[current_sector] == 55 and CurrentMapData.level_set in [2, 5]:
					draw_texture_rect(Preloads.error_sign, Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)), false)
				if Preloads.special_building_images.has(str(CurrentMapData.blg_map[current_sector])):
					draw_texture_rect(Preloads.special_building_images[str(CurrentMapData.blg_map[current_sector])], Rect2(h_grid+sector_indent,v_grid+sector_indent, 1200-(sector_indent*2),1200-(sector_indent*2)),false)
				var sector_color: Color
				match CurrentMapData.own_map[current_sector]:
					0: sector_color = Color.BLACK
					1: sector_color = Color.BLUE
					2: sector_color = Color.GREEN
					3: sector_color = Color.WHITE
					4: sector_color = Color.YELLOW
					5: sector_color = Color.DIM_GRAY
					6: sector_color = Color.RED
					7: sector_color = Color(0.070588, 0.0, 0.168627, 1)
					_: sector_color = Color.TRANSPARENT
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
				
				current_sector += 1
			
			# Highlight for selection
			if EditorState.selected_sectors.any(func(dict): return dict.border_idx == current_border_sector):
				draw_rect(Rect2(h_grid,v_grid, 1200,1200), Color(0.184314, 0.309804, 0.309804, 0.6))
			
			h_grid += 1200
			current_border_sector += 1
		v_grid += 1200
	
	for beam_gate in CurrentMapData.beam_gates:
		var pos_x = beam_gate.sec_x * 1200 + sector_indent
		var pos_y = beam_gate.sec_y * 1200 + sector_indent
		draw_texture_rect(Preloads.sector_item_images.beam_gate, Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		if beam_gate.target_levels.is_empty():
			draw_texture_rect(Preloads.error_sign, Rect2(pos_x, pos_y, 1200-(sector_indent*2),1200-(sector_indent*2)), false)
		for key_sector in beam_gate.key_sectors:
			var kpos_x = key_sector.x * 1200 + sector_indent
			var kpos_y = key_sector.y * 1200 + sector_indent
			draw_texture_rect(Preloads.sector_item_images.beam_gate_key_sector, Rect2(kpos_x, kpos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	for bomb in CurrentMapData.stoudson_bombs:
		var pos_x = bomb.sec_x * 1200 + sector_indent
		var pos_y = bomb.sec_y * 1200 + sector_indent
		draw_texture_rect(Preloads.sector_item_images.stoudson_bomb, Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		if bomb.inactive_bp == 68 and CurrentMapData.level_set in [2, 3, 4, 5]:
			draw_texture_rect(Preloads.error_sign, Rect2(pos_x, pos_y, 1200-(sector_indent*2),1200-(sector_indent*2)), false)
		for key_sector in bomb.key_sectors:
			var kpos_x = key_sector.x * 1200 + sector_indent
			var kpos_y = key_sector.y * 1200 + sector_indent
			draw_texture_rect(Preloads.sector_item_images.bomb_key_sector, Rect2(kpos_x, kpos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	for tech_upgrade in CurrentMapData.tech_upgrades:
		var pos_x = tech_upgrade.sec_x * 1200 + sector_indent
		var pos_y = tech_upgrade.sec_y * 1200 + sector_indent
		if Preloads.sector_item_images.tech_upgrades.has(tech_upgrade.building_id):
			draw_texture_rect(Preloads.sector_item_images.tech_upgrades[tech_upgrade.building_id], Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		else: draw_texture_rect(Preloads.sector_item_images.tech_upgrades["unknown"], Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
		if tech_upgrade.building_id == 60 and CurrentMapData.level_set != 5:
			draw_texture_rect(Preloads.error_sign, Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
	
	current_sector = 0
	current_border_sector = 0
	v_grid = 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		var h_grid := 0
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if (x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and 
				y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1):
				if EditorState.typ_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size), "typ: "+ str(CurrentMapData.typ_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if EditorState.own_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*2), "own: "+ str(CurrentMapData.own_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if EditorState.blg_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*4), "blg: "+ str(CurrentMapData.blg_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				current_sector += 1
			if EditorState.hgt_map_values_visible:
				draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*3), "hgt: "+ str(CurrentMapData.hgt_map[current_border_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
			h_grid += 1200
			current_border_sector += 1
		v_grid += 1200
	
	if is_multi_selection and selection_start_point != Vector2.ZERO:
		current_mouse_pos = get_local_mouse_position()
		current_mouse_pos.x = clampf(current_mouse_pos.x, 0, (CurrentMapData.horizontal_sectors+2) * 1200)
		current_mouse_pos.y = clampf(current_mouse_pos.y, 0, (CurrentMapData.vertical_sectors+2) * 1200)
		var rect_width: float = current_mouse_pos.x - selection_start_point.x
		var rect_height: float = current_mouse_pos.y - selection_start_point.y
		draw_rect(Rect2(selection_start_point.x, selection_start_point.y, rect_width, rect_height), Color.CHARTREUSE, false, 30.0)
	
	# _draw() ends here


func recalculate_size():
	if CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0:
		map_visible_width = map_camera.zoom.x * ((CurrentMapData.horizontal_sectors+2) * 1200)
		map_visible_height = map_camera.zoom.y * ((CurrentMapData.vertical_sectors+2) * 1200)
	else:
		map_visible_width = 0
		map_visible_height = 0


func add_hoststation(owner_id: int, vehicle_id: int):
	var hoststation = Preloads.HOSTSTATION.instantiate()
	CurrentMapData.host_stations.add_child(hoststation)
	hoststation.create(owner_id, vehicle_id)
	hoststation.position.x = clampi(right_clicked_x, 1205, ((CurrentMapData.horizontal_sectors+1) * 1200) - 5)
	hoststation.position.y = clampi(right_clicked_y, 1205, ((CurrentMapData.vertical_sectors+1) * 1200) - 5)

	EditorState.selected_unit = hoststation
	if CurrentMapData.player_host_station == null or not is_instance_valid(CurrentMapData.player_host_station):
		CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
	CurrentMapData.is_saved = false
	if CurrentMapData.host_stations.get_child_count() > 8:
		EventSystem.safe_host_station_limit_exceeded.emit()


func add_squad(owner_id: int, vehicle_id: int):
	var squad = Preloads.SQUAD.instantiate()
	CurrentMapData.squads.add_child(squad)
	squad.create(owner_id, vehicle_id)
	squad.position.x = clampi(right_clicked_x, 1205, ((CurrentMapData.horizontal_sectors+1) * 1200) - 5)
	squad.position.y = clampi(right_clicked_y, 1205, ((CurrentMapData.vertical_sectors+1) * 1200) - 5)
	
	CurrentMapData.is_saved = false
	EditorState.selected_unit = squad

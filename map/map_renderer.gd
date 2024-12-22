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

@onready var map_camera = $Camera2D


func _ready() -> void:
	CurrentMapData.host_stations = $HostStations
	CurrentMapData.squads = $Squads
	font = ThemeDB.fallback_font
	EventSystem.hoststation_added.connect(add_hoststation)
	EventSystem.squad_added.connect(add_squad)
	EventSystem.map_updated.connect(queue_redraw)
	EventSystem.global_right_clicked.connect(func(x, y):
		right_clicked_x_global = x
		right_clicked_y_global = y
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


var number_key: int
var is_number_pressed := false
var is_left_pressed := false
func _input(event):
	if event.is_action_pressed("hold"):
		is_selection_kept = true
	elif event.is_action_released("hold"):
		is_selection_kept = false
	if event.is_action_pressed("select"):
		is_left_pressed = true
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
			handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.selected_typ_map
			CurrentMapData.is_saved = false
			return
		handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
		EditorState.selected_unit = EditorState.mouse_over_unit
		if event.double_click:
			EventSystem.left_double_clicked.emit()
	elif event.is_action_released("select"):
		is_left_pressed = false
	if event.is_action_pressed("context_menu"):
		if CurrentMapData.horizontal_sectors <= 0: return
		right_clicked_x = round(get_local_mouse_position().x)
		right_clicked_y = round(get_local_mouse_position().y)
		if EditorState.selected_sectors.size() > 1:
			%MultiSectorMapContextMenu.position = Vector2(right_clicked_x_global, right_clicked_y_global)
			%MultiSectorMapContextMenu.popup()
			return
		handle_selection(right_clicked_x, right_clicked_y)
		EditorState.selected_unit = EditorState.mouse_over_unit
		if EditorState.selected_unit:
			%UnitContextMenu.position = Vector2(right_clicked_x_global, right_clicked_y_global)
			%UnitContextMenu.popup()
		else:
			%MapContextMenu.position = Vector2(right_clicked_x_global, right_clicked_y_global)
			%MapContextMenu.popup()
	if event is InputEventKey and event.pressed:
		if CurrentMapData.horizontal_sectors <= 0: return
		number_key = event.unicode - KEY_0
		if number_key >= 0 and number_key <= 7:
			is_number_pressed = true
			handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
			if EditorState.selected_sector_idx >= 0 and CurrentMapData.own_map.size() > 0:
				if CurrentMapData.blg_map[EditorState.selected_sector_idx] not in [0, 35, 68] and number_key == 0:
					CurrentMapData.own_map[EditorState.selected_sector_idx] = 7
				else:
					CurrentMapData.own_map[EditorState.selected_sector_idx] = number_key
				CurrentMapData.is_saved = false
				EventSystem.map_updated.emit()
	elif event is InputEventKey and event.is_released():
		is_number_pressed = false
	
	if event is InputEventMouseMotion:
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
			handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.selected_typ_map
			CurrentMapData.is_saved = false
		elif is_number_pressed and number_key >= 0 and number_key <= 7:
			handle_selection(round(get_local_mouse_position().x), round(get_local_mouse_position().y))
	if (event.is_action_pressed("increment_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		EditorState.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] < 255):
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if CurrentMapData.hgt_map[sector_dict.border_idx] < 255:
					CurrentMapData.hgt_map[sector_dict.border_idx] += 1
		else:
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] += 1
		CurrentMapData.is_saved = false
		queue_redraw()
	if (event.is_action_pressed("decrement_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		EditorState.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] > 0):
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if CurrentMapData.hgt_map[sector_dict.border_idx] > 0:
					CurrentMapData.hgt_map[sector_dict.border_idx] -= 1
		else:
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] -= 1
		CurrentMapData.is_saved = false
		queue_redraw()
	if event.is_action_pressed("previous_building"):
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				Utils.decrement_typ_map(sector_dict.idx)
		else:
			Utils.decrement_typ_map(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
		EventSystem.map_updated.emit()
	if event.is_action_pressed("next_building"):
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				Utils.increment_typ_map(sector_dict.idx)
		else:
			Utils.increment_typ_map(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
		EventSystem.map_updated.emit()
	if event.is_action_pressed("show_height_window") and not CurrentMapData.hgt_map.is_empty():
		EventSystem.sector_height_window_requested.emit()
	if event.is_action_pressed("show_building_window") and not CurrentMapData.typ_map.is_empty():
		EventSystem.sector_building_windows_requested.emit()
	if event.is_action_pressed("clear_sector") and not CurrentMapData.typ_map.is_empty():
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				CurrentMapData.clear_sector(sector_dict.idx)
		else:
			CurrentMapData.clear_sector(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if not EditorState.selected_unit:
			EventSystem.left_double_clicked.emit()
	if event.is_action_pressed("copy"):
		Utils.copy_sector()
	if event.is_action_pressed("paste"):
		Utils.paste_sector()


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
				var sector_color
				match CurrentMapData.own_map[current_sector]:
					0: sector_color = Color.BLACK
					1: sector_color = Color.BLUE
					2: sector_color = Color.GREEN
					3: sector_color = Color.WHITE
					4: sector_color = Color.YELLOW
					5: sector_color = Color.DIM_GRAY
					6: sector_color = Color.RED
					7: sector_color = Color(0.070588, 0.0, 0.168627, 1)
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
		draw_texture_rect(Preloads.sector_item_images.tech_upgrades[tech_upgrade.building_id], Rect2(pos_x, pos_y,1200-(sector_indent*2),1200-(sector_indent*2)), false)
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
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size), "typ_map: "+ str(CurrentMapData.typ_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if EditorState.own_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*2), "own_map: "+ str(CurrentMapData.own_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				if EditorState.blg_map_values_visible:
					draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*4), "blg_map: "+ str(CurrentMapData.blg_map[current_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				current_sector += 1
			if EditorState.hgt_map_values_visible:
				draw_string(font, Vector2(h_grid+50, v_grid+sector_font_size*3), "hgt_map: "+ str(CurrentMapData.hgt_map[current_border_sector]), HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
			h_grid += 1200
			current_border_sector += 1
		v_grid += 1200
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


func handle_selection(clicked_x: int, clicked_y: int):
	var sector_counter := 0
	var border_sector_counter := 0
	var h_size := 0
	var v_size := 0
	if not is_selection_kept: EditorState.selected_sectors.clear()
	
	for y_sector in CurrentMapData.vertical_sectors+2:
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if clicked_x > h_size and clicked_x < h_size + 1200 and clicked_y > v_size and clicked_y < v_size + 1200:
				EditorState.selected_sector_idx = sector_counter
				EditorState.border_selected_sector_idx = border_sector_counter
				EditorState.selected_sector.x = x_sector
				EditorState.selected_sector.y = y_sector
				if not EditorState.selected_sectors.any(func(dict): return dict.border_idx == border_sector_counter):
					EditorState.selected_sectors.append(
						{
							"border_idx": border_sector_counter, 
							"idx": sector_counter,
							"x": x_sector, 
							"y":y_sector
						})
				break
			h_size += 1200
			border_sector_counter += 1
			if (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1 and
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and
				sector_counter < (CurrentMapData.vertical_sectors*CurrentMapData.horizontal_sectors-1)
				):
				sector_counter += 1
		v_size += 1200
		h_size = 0
	
	EditorState.selected_beam_gate = null
	EditorState.selected_bomb = null
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	EditorState.selected_tech_upgrade = null
	
	for bg in CurrentMapData.beam_gates:
		if bg.sec_x == EditorState.selected_sector.x and bg.sec_y == EditorState.selected_sector.y:
			EditorState.selected_beam_gate = bg
		for ks in bg.key_sectors:
			if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
				EditorState.selected_bg_key_sector = ks
				break
	for bomb in CurrentMapData.stoudson_bombs:
		if bomb.sec_x == EditorState.selected_sector.x and bomb.sec_y == EditorState.selected_sector.y:
			EditorState.selected_bomb = bomb
		for ks in bomb.key_sectors:
			if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
				EditorState.selected_bomb_key_sector = ks
				break
	for tu in CurrentMapData.tech_upgrades:
		if tu.sec_x == EditorState.selected_sector.x and tu.sec_y == EditorState.selected_sector.y:
			EditorState.selected_tech_upgrade = tu
			break
	EventSystem.sector_selected.emit()
	queue_redraw()

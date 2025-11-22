extends Node2D

var zoom_minimum := Constants.ZOOM_MINIMUM
var zoom_maximum := Constants.ZOOM_MAXIMUM
var zoom_speed := Constants.ZOOM_SPEED
var map_visible_width: int
var map_visible_height: int
var sector_indent := Constants.SECTOR_INDENT
var font: Font
var sector_font_size := Constants.SECTOR_FONT_SIZE

var right_clicked_x_global: int
var right_clicked_y_global: int
var right_clicked_x: int
var right_clicked_y: int
var is_selection_kept := false
var is_multi_selection := false
var selection_start_point := Vector2.ZERO
var current_mouse_pos := Vector2.ZERO

@onready var map_camera = $Camera2D

var _owner_colors := {
	0: Color.BLACK,
	1: Color.BLUE,
	2: Color.GREEN,
	3: Color.WHITE,
	4: Color.YELLOW,
	5: Color.DIM_GRAY,
	6: Color.RED,
	7: Color(0.110088, 0.0, 0.188627, 1),
	-1: Color.TRANSPARENT
}

# Cached values for performance
var _sector_rect_size: float
var _total_horizontal_sectors: int
var _total_vertical_sectors: int
var _third_indent: float # Cache sector_indent/3.0
var _two_thirds_indent: float # Cache 1200-sector_indent/3.0
var _cached_level_set: int = -1
var _cached_horizontal_sectors: int = 0
var _cached_vertical_sectors: int = 0


func _ready() -> void:
	CurrentMapData.host_stations = $HostStations
	CurrentMapData.squads = $Squads
	font = ThemeDB.fallback_font
	EventSystem.hoststation_added.connect(add_hoststation)
	EventSystem.squad_added.connect(add_squad)
	EventSystem.map_updated.connect(_on_map_changed)
	EventSystem.map_view_updated.connect(queue_redraw)
	EventSystem.global_right_clicked.connect(func(x, y):
		right_clicked_x_global = x
		right_clicked_y_global = y
	)
	EventSystem.map_created.connect(func():
		map_camera.zoom = Vector2(0.056, 0.056)
		_invalidate_cache()
		)
	_sector_rect_size = Constants.SECTOR_SIZE - (sector_indent * 2)
	_third_indent = sector_indent / 3.0
	_two_thirds_indent = Constants.SECTOR_SIZE - _third_indent


func _on_map_changed() -> void:
	"""Called when map data changes to invalidate cache and redraw."""
	_invalidate_cache()
	queue_redraw()


func _invalidate_cache() -> void:
	"""Invalidate cached map dimensions."""
	_cached_horizontal_sectors = 0
	_cached_vertical_sectors = 0
	_cached_level_set = -1


func _process(delta) -> void:
	if Input.is_action_pressed("zoom_out"):
		if map_camera.zoom > zoom_minimum:
			map_camera.zoom -= zoom_speed * delta
			get_tree().get_root().size_changed.emit()
			
	elif Input.is_action_pressed("zoom_in"):
		if map_camera.zoom < zoom_maximum:
			map_camera.zoom += zoom_speed * delta
			get_tree().get_root().size_changed.emit()


func _is_valid_map_size() -> bool:
	return CurrentMapData.horizontal_sectors != 0 and CurrentMapData.vertical_sectors != 0


func _draw() -> void:
	if not _is_valid_map_size():
		return
	
	# Update cache if map size changed
	if (_cached_horizontal_sectors != CurrentMapData.horizontal_sectors or
		_cached_vertical_sectors != CurrentMapData.vertical_sectors or
		_cached_level_set != CurrentMapData.level_set):
		_cached_horizontal_sectors = CurrentMapData.horizontal_sectors
		_cached_vertical_sectors = CurrentMapData.vertical_sectors
		_cached_level_set = CurrentMapData.level_set
		_total_horizontal_sectors = CurrentMapData.horizontal_sectors + 2
		_total_vertical_sectors = CurrentMapData.vertical_sectors + 2
	
	var current_sector := 0
	var current_border_sector := 0
	var rect_base := Rect2(0, 0, _sector_rect_size, _sector_rect_size)
	var level_set := _cached_level_set
	var horizontal_sectors := _cached_horizontal_sectors
	
	for y_sector in _total_vertical_sectors:
		var v_grid := y_sector * Constants.SECTOR_SIZE
		
		for x_sector in _total_horizontal_sectors:
			var h_grid := x_sector * Constants.SECTOR_SIZE
			
			if _is_valid_sector(x_sector, y_sector):
				# Draw main sector content
				_draw_sector_content(current_sector, h_grid, v_grid, rect_base, level_set)
				
				# Draw height differences
				_draw_height_differences(current_border_sector, x_sector, y_sector, h_grid, v_grid, horizontal_sectors, _cached_vertical_sectors)
				
				current_sector += 1
				
			# Draw selection highlight
			if EditorState.selected_sectors.any(func(dict): return dict.border_idx == current_border_sector):
				draw_rect(Rect2(h_grid, v_grid, Constants.SECTOR_SIZE, Constants.SECTOR_SIZE),
						 Color(0.184314, 0.309804, 0.309804, 0.6))
				
			current_border_sector += 1
	
	# Draw special elements
	_draw_beam_gates()
	_draw_bombs()
	_draw_tech_upgrades()
	_draw_sector_values(current_sector, current_border_sector)
	_draw_selection_rect()


func _is_valid_sector(x: int, y: int) -> bool:
	return x > 0 and x < _total_horizontal_sectors - 1 and y > 0 and y < _total_vertical_sectors - 1


func _draw_sector_content(current_sector: int, h_grid: int, v_grid: int, rect_base: Rect2, level_set: int) -> void:
	var typ := CurrentMapData.typ_map[current_sector]
	var blg := CurrentMapData.blg_map[current_sector]
	var rect := rect_base
	rect.position = Vector2(h_grid + sector_indent, v_grid + sector_indent)
	
	# Draw typ map image
	if Preloads.building_top_images[level_set].has(typ):
		if EditorState.typ_map_images_visible:
			draw_texture_rect(Preloads.building_top_images[level_set][typ],
					 Rect2(h_grid, v_grid, Constants.SECTOR_SIZE, Constants.SECTOR_SIZE), false)
	else:
		draw_texture_rect(Preloads.error_sign, rect, false)
	
	# Draw special building indicators
	if (blg == Constants.SPECIAL_BUILDING_62 and level_set in [Constants.LEVEL_SET_3, Constants.LEVEL_SET_4, Constants.LEVEL_SET_5]) or (blg == Constants.SPECIAL_BUILDING_55 and level_set in [Constants.LEVEL_SET_2, Constants.LEVEL_SET_5]):
		draw_texture_rect(Preloads.error_sign, rect, false)
	
	if Preloads.special_building_images.has(blg):
		draw_texture_rect(Preloads.special_building_images[blg], rect, false)
	
	# Draw owner color
	var owner_id := CurrentMapData.own_map[current_sector]
	var color_index := owner_id if owner_id >= 0 and owner_id <= 7 else -1
	draw_rect(rect, _owner_colors[color_index], false, -1.0)


func _draw_height_differences(border_sector: int, x: int, y: int, h_grid: int, v_grid: int, horizontal_sectors: int, vertical_sectors: int) -> void:
	var hgt_map := CurrentMapData.hgt_map
	var height_threshold := Constants.HEIGHT_THRESHOLD
	
	# Top edge - check if sector above is higher
	if y > 1 and hgt_map[border_sector - (horizontal_sectors + 2)] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + sector_indent, v_grid + _third_indent),
			Vector2(h_grid + Constants.SECTOR_SIZE - sector_indent, v_grid + _third_indent),
			Color.AQUA,
			-1.0
		)
	
	# Right edge - check if sector to the right is higher
	if x < horizontal_sectors and hgt_map[border_sector + 1] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + _two_thirds_indent, v_grid + sector_indent),
			Vector2(h_grid + _two_thirds_indent, v_grid + Constants.SECTOR_SIZE - sector_indent),
			Color.AQUA,
			-1.0
		)
	
	# Bottom edge - check if sector below is higher
	if y < vertical_sectors and hgt_map[border_sector + (horizontal_sectors + 2)] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + sector_indent, v_grid + _two_thirds_indent),
			Vector2(h_grid + Constants.SECTOR_SIZE - sector_indent, v_grid + _two_thirds_indent),
			Color.AQUA,
			-1.0
		)
	
	# Left edge - check if sector to the left is higher
	if x > 1 and hgt_map[border_sector - 1] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + _third_indent, v_grid + sector_indent),
			Vector2(h_grid + _third_indent, v_grid + Constants.SECTOR_SIZE - sector_indent),
			Color.AQUA,
			-1.0
		)


func recalculate_size() -> void:
	if CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0:
		map_visible_width = map_camera.zoom.x * ((CurrentMapData.horizontal_sectors + 2) * Constants.SECTOR_SIZE)
		map_visible_height = map_camera.zoom.y * ((CurrentMapData.vertical_sectors + 2) * Constants.SECTOR_SIZE)
	else:
		map_visible_width = 0
		map_visible_height = 0


func add_hoststation(owner_id: int, vehicle_id: int) -> void:
	var hoststation = Preloads.HOSTSTATION.instantiate()
	CurrentMapData.host_stations.add_child(hoststation)
	hoststation.create(owner_id, vehicle_id)
	hoststation.position.x = clampi(right_clicked_x, Constants.SECTOR_SIZE + 5, ((CurrentMapData.horizontal_sectors + 1) * Constants.SECTOR_SIZE) - 5)
	hoststation.position.y = clampi(right_clicked_y, Constants.SECTOR_SIZE + 5, ((CurrentMapData.vertical_sectors + 1) * Constants.SECTOR_SIZE) - 5)

	EditorState.selected_unit = hoststation
	if CurrentMapData.player_host_station == null or not is_instance_valid(CurrentMapData.player_host_station):
		CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
	CurrentMapData.is_saved = false
	if CurrentMapData.host_stations.get_child_count() > Constants.HOST_STATION_LIMIT:
		EventSystem.safe_host_station_limit_exceeded.emit()


func add_squad(owner_id: int, vehicle_id: int) -> void:
	var squad = Preloads.SQUAD.instantiate()
	CurrentMapData.squads.add_child(squad)
	squad.create(owner_id, vehicle_id)
	squad.position.x = clampi(right_clicked_x, Constants.SECTOR_SIZE + 5, ((CurrentMapData.horizontal_sectors + 1) * Constants.SECTOR_SIZE) - 5)
	squad.position.y = clampi(right_clicked_y, Constants.SECTOR_SIZE + 5, ((CurrentMapData.vertical_sectors + 1) * Constants.SECTOR_SIZE) - 5)
	
	CurrentMapData.is_saved = false
	EditorState.selected_unit = squad

func _draw_key_sector(pos_x: int, pos_y: int, texture) -> void:
	var key_rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)
	draw_texture_rect(texture, key_rect, false)

func _draw_beam_gates() -> void:
	for beam_gate in CurrentMapData.beam_gates:
		var pos_x := int(beam_gate.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(beam_gate.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)
		
		draw_texture_rect(Preloads.sector_item_images.beam_gate, rect, false)
		
		if beam_gate.target_levels.is_empty():
			draw_texture_rect(Preloads.error_sign, rect, false)
		
		for key_sector in beam_gate.key_sectors:
			_draw_key_sector(
				int(key_sector.x * Constants.SECTOR_SIZE + sector_indent),
				int(key_sector.y * Constants.SECTOR_SIZE + sector_indent),
				Preloads.sector_item_images.beam_gate_key_sector
			)

func _draw_bombs() -> void:
	for bomb in CurrentMapData.stoudson_bombs:
		var pos_x := int(bomb.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(bomb.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)
		
		draw_texture_rect(Preloads.sector_item_images.stoudson_bomb, rect, false)
		
		if bomb.inactive_bp == Constants.INACTIVE_BP_68 and CurrentMapData.level_set in [Constants.LEVEL_SET_2, Constants.LEVEL_SET_3, Constants.LEVEL_SET_4, Constants.LEVEL_SET_5]:
			draw_texture_rect(Preloads.error_sign, rect, false)
		
		for key_sector in bomb.key_sectors:
			_draw_key_sector(
				int(key_sector.x * Constants.SECTOR_SIZE + sector_indent),
				int(key_sector.y * Constants.SECTOR_SIZE + sector_indent),
				Preloads.sector_item_images.bomb_key_sector
			)

func _draw_tech_upgrades() -> void:
	for tech_upgrade in CurrentMapData.tech_upgrades:
		var pos_x := int(tech_upgrade.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(tech_upgrade.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)
		
		var texture = Preloads.sector_item_images.tech_upgrades.get(
			tech_upgrade.building_id,
			Preloads.sector_item_images.tech_upgrades["unknown"]
		)
		draw_texture_rect(texture, rect, false)
		
		if tech_upgrade.building_id == Constants.TECH_UPGRADE_BUILDING_ID_60 and CurrentMapData.level_set != Constants.LEVEL_SET_5:
			draw_texture_rect(Preloads.error_sign, rect, false)

func _draw_sector_values(current_sector: int, current_border_sector: int) -> void:
	if not (EditorState.typ_map_values_visible or
			EditorState.own_map_values_visible or
			EditorState.hgt_map_values_visible or
			EditorState.blg_map_values_visible):
		return
		
	current_sector = 0
	current_border_sector = 0
	var v_grid := 0
	var base_pos := Vector2.ZERO
	
	for y_sector in _total_vertical_sectors:
		var h_grid := 0
		for x_sector in _total_horizontal_sectors:
			if _is_valid_sector(x_sector, y_sector):
				base_pos.x = h_grid + sector_indent
				base_pos.y = v_grid
				
				if EditorState.typ_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size),
							  "typ: " + str(CurrentMapData.typ_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				
				if EditorState.own_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size * 2),
							  "own: " + str(CurrentMapData.own_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				
				if EditorState.blg_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size * 4),
							  "blg: " + str(CurrentMapData.blg_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
				
				current_sector += 1
				
			if EditorState.hgt_map_values_visible:
				draw_string(font, Vector2(h_grid + sector_indent, v_grid + sector_font_size * 3),
						  "hgt: " + str(CurrentMapData.hgt_map[current_border_sector]),
						  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)
			
			h_grid += Constants.SECTOR_SIZE
			current_border_sector += 1
		v_grid += Constants.SECTOR_SIZE

func _draw_selection_rect() -> void:
	if not (is_multi_selection and selection_start_point != Vector2.ZERO):
		return
		
	current_mouse_pos = get_local_mouse_position()
	current_mouse_pos.x = clampf(current_mouse_pos.x, 0, _total_horizontal_sectors * Constants.SECTOR_SIZE)
	current_mouse_pos.y = clampf(current_mouse_pos.y, 0, _total_vertical_sectors * Constants.SECTOR_SIZE)
	
	var rect_size := current_mouse_pos - selection_start_point
	draw_rect(Rect2(selection_start_point, rect_size), Color.CHARTREUSE, false, -1.0)

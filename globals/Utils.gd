extends Node

# Invalid typ_map ranges for each level set
# Format: [start_exclusive, end_exclusive] means values > start AND < end are invalid
const INVALID_TYP_RANGES := {
	1: [[53, 59], [59, 66], [82, 95], [104, 110], [113, 120], [121, 130], [141, 150], [189, 198], [205, 207], [208, 228], [236, 239]],
	2: [[24, 27], [104, 110], [113, 118], [131, 133], [133, 150], [195, 198], [205, 207], [208, 210], [225, 228], [230, 239]],
	3: [[49, 59], [59, 66], [82, 100], [104, 110], [113, 121], [121, 130], [141, 150], [189, 198], [205, 207], [208, 228], [230, 239]],
	4: [[49, 59], [60, 66], [82, 100], [104, 110], [113, 121], [121, 130], [141, 150], [189, 198], [205, 207], [208, 228], [230, 239]],
	5: [[95, 97], [116, 118], [131, 133], [137, 150], [191, 198], [205, 207], [208, 210], [225, 228], [230, 239]],
	6: [[49, 59], [59, 66], [82, 95], [104, 110], [113, 121], [121, 130], [141, 150], [189, 198], [205, 207], [208, 228], [235, 239]]
}


func _is_valid_typ(value: int, level_set: int) -> bool:
	"""Check if a typ value is valid for the given level set."""
	if not INVALID_TYP_RANGES.has(level_set):
		return true
	
	for range_pair in INVALID_TYP_RANGES[level_set]:
		if value > range_pair[0] and value < range_pair[1]:
			return false
	return true


func _adjust_typ_increment(value: int, level_set: int) -> int:
	"""Adjust an incremented typ value to skip invalid ranges."""
	if not INVALID_TYP_RANGES.has(level_set):
		return value
	
	for range_pair in INVALID_TYP_RANGES[level_set]:
		if value > range_pair[0] and value < range_pair[1]:
			return range_pair[1]
	return value


func _adjust_typ_decrement(value: int, level_set: int) -> int:
	"""Adjust a decremented typ value to skip invalid ranges."""
	if not INVALID_TYP_RANGES.has(level_set):
		return value
	
	for range_pair in INVALID_TYP_RANGES[level_set]:
		if value > range_pair[0] and value < range_pair[1]:
			return range_pair[0]
	return value


func increment_typ_map(index: int) -> void:
	if CurrentMapData.typ_map.is_empty() or index < 0:
		return
	
	var temp := CurrentMapData.typ_map[index]
	temp += 1
	if temp > 255:
		temp = 0
	
	temp = _adjust_typ_increment(temp, CurrentMapData.level_set)
	CurrentMapData.typ_map[index] = temp


func decrement_typ_map(index: int) -> void:
	if CurrentMapData.typ_map.is_empty() or index < 0:
		return
	
	var temp := CurrentMapData.typ_map[index]
	temp -= 1
	if temp < 0:
		temp = 255
	
	temp = _adjust_typ_decrement(temp, CurrentMapData.level_set)
	CurrentMapData.typ_map[index] = temp


func randomize_whole_typ_map() -> void:
	if CurrentMapData.typ_map.is_empty():
		return
	
	for i in CurrentMapData.typ_map.size():
		var rand: int
		var is_valid := false
		
		while not is_valid:
			rand = randi_range(0, 255)
			is_valid = _is_valid_typ(rand, CurrentMapData.level_set)
		
		CurrentMapData.typ_map[i] = rand
	
	EventSystem.map_updated.emit()


func convert_sky_name_case(sky_name: String) -> String:
	for sky in Preloads.skies.keys():
		if sky.to_lower() == sky_name.to_lower():
			return sky
	
	return Preloads.skies.keys()[0]


func copy_sector() -> void:
	if EditorState.selected_sector_idx >= 0 and CurrentMapData.horizontal_sectors > 0:
		EditorState.sector_clipboard.typ_map = CurrentMapData.typ_map[EditorState.selected_sector_idx]
		EditorState.sector_clipboard.own_map = CurrentMapData.own_map[EditorState.selected_sector_idx]
		EditorState.sector_clipboard.blg_map = CurrentMapData.blg_map[EditorState.selected_sector_idx]
		EditorState.sector_clipboard.beam_gate = EditorState.selected_beam_gate
		EditorState.sector_clipboard.stoudson_bomb = EditorState.selected_bomb
		EditorState.sector_clipboard.tech_upgrade = EditorState.selected_tech_upgrade
		EditorState.sector_clipboard.bg_key_sector_parent = null
		if EditorState.selected_bg_key_sector != Vector2i(-1, -1):
			for bg: BeamGate in CurrentMapData.beam_gates:
				for ks in bg.key_sectors:
					if ks == EditorState.selected_bg_key_sector:
						EditorState.sector_clipboard.bg_key_sector_parent = bg
						break
		EditorState.sector_clipboard.bomb_key_sector_parent = null
		if EditorState.selected_bomb_key_sector != Vector2i(-1, -1):
			for bomb: StoudsonBomb in CurrentMapData.stoudson_bombs:
				for ks in bomb.key_sectors:
					if ks == EditorState.selected_bomb_key_sector:
						EditorState.sector_clipboard.bomb_key_sector_parent = bomb
						break


func paste_sector() -> void:
	if EditorState.selected_sector_idx >= 0 and CurrentMapData.horizontal_sectors > 0:
		if EditorState.sector_clipboard.typ_map >= 0:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.sector_clipboard.typ_map
		if EditorState.sector_clipboard.own_map >= 0:
			CurrentMapData.own_map[EditorState.selected_sector_idx] = EditorState.sector_clipboard.own_map
		if EditorState.sector_clipboard.blg_map >= 0:
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = EditorState.sector_clipboard.blg_map
		if not (EditorState.selected_sector.x > 0 and
			EditorState.selected_sector.x < CurrentMapData.horizontal_sectors + 1 and
			EditorState.selected_sector.y > 0 and
			EditorState.selected_sector.y < CurrentMapData.vertical_sectors + 1):
			return
		if EditorState.sector_clipboard.beam_gate:
			for bg in CurrentMapData.beam_gates:
				if bg.sec_x == EditorState.selected_sector.x and bg.sec_y == EditorState.selected_sector.y:
					EventSystem.map_updated.emit()
					return
			
			var bg = BeamGate.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			bg.closed_bp = EditorState.sector_clipboard.beam_gate.closed_bp
			bg.opened_bp = EditorState.sector_clipboard.beam_gate.opened_bp
			bg.key_sectors = EditorState.sector_clipboard.beam_gate.key_sectors.duplicate()
			bg.target_levels = EditorState.sector_clipboard.beam_gate.target_levels.duplicate()
			bg.mb_status = EditorState.sector_clipboard.beam_gate.mb_status
			CurrentMapData.beam_gates.append(bg)
			EditorState.selected_beam_gate = bg
			EventSystem.item_updated.emit()
		if EditorState.sector_clipboard.stoudson_bomb:
			for bomb in CurrentMapData.stoudson_bombs:
				if bomb.sec_x == EditorState.selected_sector.x and bomb.sec_y == EditorState.selected_sector.y:
					EventSystem.map_updated.emit()
					return
			
			var bomb = StoudsonBomb.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			bomb.inactive_bp = EditorState.sector_clipboard.stoudson_bomb.inactive_bp
			bomb.active_bp = EditorState.sector_clipboard.stoudson_bomb.active_bp
			bomb.trigger_bp = EditorState.sector_clipboard.stoudson_bomb.trigger_bp
			bomb.type = EditorState.sector_clipboard.stoudson_bomb.type
			bomb.countdown = EditorState.sector_clipboard.stoudson_bomb.countdown
			bomb.key_sectors = EditorState.sector_clipboard.stoudson_bomb.key_sectors.duplicate()
			CurrentMapData.stoudson_bombs.append(bomb)
			EditorState.selected_bomb = bomb
			EventSystem.item_updated.emit()
		if EditorState.sector_clipboard.tech_upgrade:
			for tu in CurrentMapData.tech_upgrades:
				if tu.sec_x == EditorState.selected_sector.x and tu.sec_y == EditorState.selected_sector.y:
					EventSystem.map_updated.emit()
					return
			
			var tech_upgrade = TechUpgrade.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			tech_upgrade.building_id = EditorState.sector_clipboard.tech_upgrade.building_id
			tech_upgrade.type = EditorState.sector_clipboard.tech_upgrade.type
			tech_upgrade.duplicate_modifiers(EditorState.sector_clipboard.tech_upgrade.vehicles)
			tech_upgrade.duplicate_modifiers(EditorState.sector_clipboard.tech_upgrade.weapons)
			tech_upgrade.duplicate_modifiers(EditorState.sector_clipboard.tech_upgrade.buildings)
			tech_upgrade.mb_status = EditorState.sector_clipboard.tech_upgrade.mb_status
			CurrentMapData.tech_upgrades.append(tech_upgrade)
			EditorState.selected_tech_upgrade = tech_upgrade
			EventSystem.item_updated.emit()
		if EditorState.sector_clipboard.bg_key_sector_parent and EditorState.selected_bg_key_sector == Vector2i(-1, -1):
			EditorState.sector_clipboard.bg_key_sector_parent.key_sectors.append(Vector2i(EditorState.selected_sector.x, EditorState.selected_sector.y))
		if EditorState.sector_clipboard.bomb_key_sector_parent and EditorState.selected_bomb_key_sector == Vector2i(-1, -1):
			EditorState.sector_clipboard.bomb_key_sector_parent.key_sectors.append(Vector2i(EditorState.selected_sector.x, EditorState.selected_sector.y))
		EventSystem.map_updated.emit()


func select_all_sectors(no_borders := false) -> void:
	if CurrentMapData.horizontal_sectors == 0: return
	EditorState.unselect_all()
	var sector_counter := 0
	var border_sector_counter := 0
	EditorState.border_selected_sector_idx = -1
	EditorState.selected_sector_idx = -1
	for y_sector in CurrentMapData.vertical_sectors + 2:
		for x_sector in CurrentMapData.horizontal_sectors + 2:
			if not no_borders:
				EditorState.selected_sectors.append(
					{
						"border_idx": border_sector_counter,
						"x": x_sector,
						"y": y_sector
					})
			
			if (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors + 1 and
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors + 1 and
				sector_counter < (CurrentMapData.vertical_sectors * CurrentMapData.horizontal_sectors)
				):
					if no_borders:
						EditorState.selected_sectors.append(
							{
								"border_idx": border_sector_counter,
								"idx": sector_counter,
								"x": x_sector,
								"y": y_sector
							})
					else:
						EditorState.selected_sectors[-1].idx = sector_counter
					
					sector_counter += 1
			border_sector_counter += 1
		
	EventSystem.map_view_updated.emit()

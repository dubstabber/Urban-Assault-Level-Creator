extends Node


func increment_typ_map(index: int) -> void:
	if CurrentMapData.typ_map.is_empty() or index < 0: 
		return
	var temp := CurrentMapData.typ_map[index]
	temp += 1
	if temp > 255:
		temp = 0
	match CurrentMapData.level_set:
		1:
			if temp > 53 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 95: temp = 95
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 120: temp = 120
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 236 and temp < 239: temp = 239
		2:
			if temp > 24 and temp < 27: temp = 27
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 118: temp = 118
			if temp > 131 and temp < 133: temp = 133
			if temp > 133 and temp < 150: temp = 150
			if temp > 195 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 210: temp = 210
			if temp > 225 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		3:
			if temp > 49 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 100: temp = 100
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		4:
			if temp > 49 and temp < 59: temp = 59
			if temp > 60 and temp < 66: temp = 66
			if temp > 82 and temp < 100: temp = 100
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		5:
			if temp > 95 and temp < 97: temp = 97
			if temp > 116 and temp < 118: temp = 118
			if temp > 131 and temp < 133: temp = 133
			if temp > 137 and temp < 150: temp = 150
			if temp > 191 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 210: temp = 210
			if temp > 225 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		6:
			if temp > 49 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 95: temp = 95
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 235 and temp < 239: temp = 239
	CurrentMapData.typ_map[index] = temp


func decrement_typ_map(index: int) -> void:
	if CurrentMapData.typ_map.is_empty() or index < 0: 
		return
	
	var temp := CurrentMapData.typ_map[index]
	temp -= 1
	if temp < 0:
		temp = 255
	match CurrentMapData.level_set:
		1:
			if temp > 53 and temp < 59: temp = 53
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 95: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 120: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 236 and temp < 239: temp = 236
		2:
			if temp > 24 and temp < 27: temp = 24
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 118: temp = 113
			if temp > 131 and temp < 133: temp = 131
			if temp > 133 and temp < 150: temp = 133
			if temp > 195 and temp < 198: temp = 195
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 210: temp = 208
			if temp > 225 and temp < 228: temp = 225
			if temp > 230 and temp < 239: temp = 230
		3:
			if temp > 49 and temp < 59: temp = 49
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 100: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 230 and temp < 239: temp = 230
		4:
			if temp > 49 and temp < 59: temp = 49
			if temp > 60 and temp < 66: temp = 60
			if temp > 82 and temp < 100: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 230 and temp < 239: temp = 230
		5:
			if temp > 95 and temp < 97: temp = 95
			if temp > 116 and temp < 118: temp = 116
			if temp > 131 and temp < 133: temp = 131
			if temp > 137 and temp < 150: temp = 137
			if temp > 191 and temp < 198: temp = 191
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 210: temp = 208
			if temp > 225 and temp < 228: temp = 225
			if temp > 230 and temp < 239: temp = 230
		6:
			if temp > 49 and temp < 59: temp = 49
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 95: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 235 and temp < 239: temp = 235
	CurrentMapData.typ_map[index] = temp


func randomize_whole_typ_map() -> void:
	if CurrentMapData.typ_map.is_empty(): return
	
	for i in CurrentMapData.typ_map.size():
		var fail := true
		var rand: int
		
		while fail:
			rand = randi_range(0,255)
			fail = false
			
			match CurrentMapData.level_set:
				1:
					if rand > 53 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 95: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 120: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 236 and rand < 239: fail = true
				2:
					if rand > 24 and rand < 27: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 118: fail = true
					if rand > 131 and rand < 133: fail = true
					if rand > 133 and rand < 150: fail = true
					if rand > 195 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 210: fail = true
					if rand > 225 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				3:
					if rand > 49 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 100: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				4:
					if rand > 49 and rand < 59: fail = true
					if rand > 60 and rand < 66: fail = true
					if rand > 82 and rand < 100: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				5:
					if rand > 95 and rand < 97: fail = true
					if rand > 116 and rand < 118: fail = true
					if rand > 131 and rand < 133: fail = true
					if rand > 137 and rand < 150: fail = true
					if rand > 191 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 210: fail = true
					if rand > 225 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				6:
					if rand > 49 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 95: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 235 and rand < 239: fail = true
			
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
		if not(EditorState.selected_sector.x > 0 and 
			EditorState.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
			EditorState.selected_sector.y > 0 and 
			EditorState.selected_sector.y < CurrentMapData.vertical_sectors+1):
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
	EditorState.border_selected_sector_idx = 0
	EditorState.selected_sector_idx = 0
	for y_sector in CurrentMapData.vertical_sectors+2:
		for x_sector in CurrentMapData.horizontal_sectors+2:
			if not no_borders:
				
				EditorState.selected_sectors.append(
					{
						"border_idx": border_sector_counter, 
						"x": x_sector, 
						"y":y_sector
					})
			
			if (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors+1 and
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors+1 and
				sector_counter < (CurrentMapData.vertical_sectors*CurrentMapData.horizontal_sectors)
				):
					if no_borders:
						EditorState.selected_sectors.append(
							{
								"border_idx": border_sector_counter,
								"idx": sector_counter,
								"x": x_sector,
								"y":y_sector
							})
					else:
						EditorState.selected_sectors[-1].idx = sector_counter
					#if sector_counter+1 != CurrentMapData.vertical_sectors*CurrentMapData.horizontal_sectors:
					sector_counter += 1
			border_sector_counter += 1
		
	EventSystem.map_updated.emit()

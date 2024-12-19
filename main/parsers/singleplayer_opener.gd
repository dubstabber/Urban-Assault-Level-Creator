class_name SingleplayerOpener

static var string_line: String


static func load_level() -> void:
	var file = FileAccess.open(CurrentMapData.map_path, FileAccess.READ)
	if not file: 
		printerr("Error: File '%s' cannot be opened" % CurrentMapData.map_path)
		return
	string_line = ""
	
	while file.get_position() < file.get_length():
		string_line = file.get_line().strip_edges()
		_handle_typ_map(file)
		_handle_own_map(file)
		_handle_hgt_map(file)
		_handle_blg_map(file)
	
	var total_sectors = CurrentMapData.horizontal_sectors * CurrentMapData.vertical_sectors
	var total_border_sectors = (CurrentMapData.horizontal_sectors+2) * (CurrentMapData.vertical_sectors+2)
	if (CurrentMapData.typ_map.size() != total_sectors or CurrentMapData.own_map.size() != total_sectors or 
		CurrentMapData.blg_map.size() != total_sectors or CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0 or 
		CurrentMapData.hgt_map.size() != total_border_sectors or CurrentMapData.typ_map.is_empty() or CurrentMapData.own_map.is_empty() or 
		CurrentMapData.blg_map.is_empty() or CurrentMapData.hgt_map.is_empty()):
		printerr("Something went wrong while opening the file")
		printerr("typ_map size: %s" % CurrentMapData.typ_map.size())
		printerr("own_map size: %s" % CurrentMapData.own_map.size())
		printerr("blg_map size: %s" % CurrentMapData.blg_map.size())
		printerr("hgt_map size: %s" % CurrentMapData.hgt_map.size())
		printerr("Horizontal sectors: %s" % CurrentMapData.horizontal_sectors)
		printerr("Vertical sectors: %s" % CurrentMapData.vertical_sectors)
		printerr("Total sectors: %s" % total_sectors)
		printerr("Total sectors with borders: %s" % total_border_sectors)
		EventSystem.open_map_failed.emit()
		return
	
	file.seek(0)
	
	_handle_description(file)
	while file.get_position() < file.get_length():
		if string_line.is_empty():
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			continue
		_handle_level_parameters(file)
		_handle_briefing_maps(file)
		_handle_beam_gates(file)
		_handle_host_stations(file)
		_handle_bombs(file)
		_handle_predefined_squads(file)
		_handle_modifications(file)
		_handle_prototype_enabling(file)
		_handle_tech_upgrades(file)
		
		string_line = file.get_line().get_slice(';', 0).strip_edges()
	
	_infer_game_type()
	
	EventSystem.map_created.emit()
	EventSystem.item_updated.emit()
	CurrentMapData.is_saved = true


static func _handle_typ_map(file: FileAccess) -> void:
	if string_line.begins_with('typ_map'):
		string_line = file.get_line().strip_edges()
		for i in len(string_line):
			if string_line[i] == " ":
				CurrentMapData.horizontal_sectors = int(string_line.substr(0,i))
				CurrentMapData.vertical_sectors = int(string_line.substr(i))
		
		CurrentMapData.horizontal_sectors -=2
		CurrentMapData.vertical_sectors -=2
		string_line = file.get_line().strip_edges()
		for v in CurrentMapData.vertical_sectors:
			string_line = file.get_line().strip_edges().substr(3)
			for h in CurrentMapData.horizontal_sectors:
				if string_line.substr(0, 2).is_valid_hex_number():
					CurrentMapData.typ_map.append(string_line.substr(0, 2).hex_to_int())
				else:
					CurrentMapData.typ_map.append(0)
				string_line = string_line.substr(3).strip_edges()


static func _handle_own_map(file: FileAccess) -> void:
	if string_line.begins_with('own_map'):
		string_line = file.get_line()
		string_line = file.get_line()
		for v in CurrentMapData.vertical_sectors:
			string_line = file.get_line().strip_edges().substr(3)
			for h in CurrentMapData.horizontal_sectors:
				if string_line.substr(0, 2).is_valid_hex_number():
					CurrentMapData.own_map.append(string_line.substr(0, 2).hex_to_int())
				else:
					CurrentMapData.own_map.append(0)
				string_line = string_line.substr(3).strip_edges()


static func _handle_hgt_map(file: FileAccess) -> void:
	if string_line.begins_with('hgt_map'):
		string_line = file.get_line()
		for v in CurrentMapData.vertical_sectors+2:
			string_line = file.get_line().strip_edges()
			for h in CurrentMapData.horizontal_sectors+2:
				if string_line.substr(0, 2).is_valid_hex_number():
					CurrentMapData.hgt_map.append(string_line.substr(0, 2).hex_to_int())
				else:
					CurrentMapData.hgt_map.append(0)
				string_line = string_line.substr(3).strip_edges()


static func _handle_blg_map(file: FileAccess) -> void:
	if string_line.begins_with('blg_map'):
		string_line = file.get_line()
		string_line = file.get_line()
		for v in CurrentMapData.vertical_sectors:
			string_line = file.get_line().strip_edges().substr(3)
			for h in CurrentMapData.horizontal_sectors:
				if string_line.substr(0, 2).is_valid_hex_number():
					CurrentMapData.blg_map.append(string_line.substr(0, 2).hex_to_int())
				else:
					CurrentMapData.blg_map.append(0)
				string_line = string_line.substr(3).strip_edges()


static func _handle_description(file: FileAccess) -> void:
	file.get_line()
	file.get_line()
	file.get_line()
	file.get_line()
	file.get_line()
	file.get_line()
	string_line = file.get_line().strip_edges(true, false)
	
	while(not string_line.is_empty() and string_line[0] == ';' and file.get_position() < file.get_length()):
		CurrentMapData.level_description += string_line.substr(1) + '\n'
		string_line = file.get_line().strip_edges(true, false)


static func _handle_level_parameters(file: FileAccess) -> void:
	if string_line.begins_with('begin_level'):
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("set"):
				string_line = string_line.replacen("set", "").replacen("=", "").strip_edges()
				CurrentMapData.level_set = int(string_line)
				
			if string_line.begins_with("sky"):
				string_line = string_line.replace("sky", "").replacen("=", "").strip_edges()
				string_line = string_line.get_slice('/', 1).replacen(".base", "").replacen(".bas", "")
				CurrentMapData.sky = Utils.convert_sky_name_case(string_line)
			
			if string_line.containsn("event_loop"):
				string_line = string_line.replacen("event_loop", "").replacen("=", "").strip_edges()
				CurrentMapData.event_loop = int(string_line)
			
			if string_line.containsn("ambiencetrack"):
				string_line = string_line.replacen("ambiencetrack", "").replacen("=", "").strip_edges()
				var music_data = string_line.split('_')
				CurrentMapData.music = int(music_data[0])
				if music_data.size() > 1:
					CurrentMapData.min_break = int(music_data[1])
					CurrentMapData.max_break = int(music_data[2])
			
			if string_line.begins_with("movie"):
				string_line = string_line.replacen("movie", "").replacen("=", "").strip_edges()
				CurrentMapData.movie = string_line.replacen("mov:", "")


static func _handle_briefing_maps(file: FileAccess) -> void:
	if string_line.begins_with('begin_mbmap'):
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("name"):
				string_line = string_line.replacen("name", "").replacen("=", "").strip_edges()
				CurrentMapData.briefing_map = string_line.to_lower()
			
			if string_line.containsn("size_x"):
				string_line = string_line.replacen("size_x", "").replacen("=", "").strip_edges()
				CurrentMapData.briefing_size_x = int(string_line)
				
			if string_line.containsn("size_y"):
				string_line = string_line.replacen("size_y", "").replacen("=", "").strip_edges()
				CurrentMapData.briefing_size_y = int(string_line)
				
	if string_line.begins_with('begin_dbmap'):
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("name"):
				string_line = string_line.replacen("name", "").replacen("=", "").strip_edges()
				CurrentMapData.debriefing_map = string_line.to_lower()
			
			if string_line.containsn("size_x"):
				string_line = string_line.replacen("size_x", "").replacen("=", "").strip_edges()
				CurrentMapData.debriefing_size_x = int(string_line)
				
			if string_line.containsn("size_y"):
				string_line = string_line.replacen("size_y", "").replacen("=", "").strip_edges()
				CurrentMapData.debriefing_size_y = int(string_line)


static func _handle_beam_gates(file: FileAccess) -> void:
	if string_line.begins_with('begin_gate'):
		var sec_x: int
		var sec_y: int
		var closed_bp: int
		var opened_bp: int
		var target_levels: Array[int] = []
		var key_sectors: Array[Vector2i] = []
		var key_sector: Vector2i
		var mb_status := false
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.begins_with("sec_x"):
				string_line = string_line.replacen("sec_x", "").replacen("=", "").strip_edges()
				sec_x = int(string_line)
			
			if string_line.begins_with("sec_y"):
				string_line = string_line.replacen("sec_y", "").replacen("=", "").strip_edges()
				sec_y = int(string_line)
			
			if string_line.begins_with("closed_bp"):
				string_line = string_line.replacen("closed_bp", "").replacen("=", "").strip_edges()
				closed_bp = int(string_line)
			
			if string_line.begins_with("opened_bp"):
				string_line = string_line.replacen("opened_bp", "").replacen("=", "").strip_edges()
				opened_bp = int(string_line)
			
			if string_line.begins_with("target_level"):
				string_line = string_line.replacen("target_level", "").replacen("=", "").strip_edges()
				target_levels.append(int(string_line))
			
			if string_line.begins_with("keysec_x"):
				string_line = string_line.replacen("keysec_x", "").replacen("=", "").strip_edges()
				key_sector.x = int(string_line)
			
			if string_line.begins_with("keysec_y"):
				string_line = string_line.replacen("keysec_y", "").replacen("=", "").strip_edges()
				key_sector.y = int(string_line)
				key_sectors.append(key_sector)
			
			if string_line.begins_with("mb_status"):
				mb_status = true
		
		var beam_gate = BeamGate.new(sec_x, sec_y)
		beam_gate.closed_bp = closed_bp
		beam_gate.opened_bp = opened_bp
		beam_gate.target_levels = target_levels
		beam_gate.key_sectors = key_sectors
		beam_gate.mb_status = mb_status
		CurrentMapData.beam_gates.append(beam_gate)


static func _handle_host_stations(file: FileAccess) -> void:
	if string_line.begins_with('begin_robo'):
		var owner_id: int
		var vehicle_id: int
		var pos_x: int
		var pos_y: int
		var pos_z: int
		var energy: int
		var reload_const_enabled := false
		var reload_const: int
		var view_angle_enabled := false
		var view_angle: int
		var mb_status := false
		var con_budget: int
		var con_delay: int
		var def_budget: int
		var def_delay: int
		var rec_budget: int
		var rec_delay: int
		var rob_budget: int
		var rob_delay: int
		var pow_budget: int
		var pow_delay: int
		var rad_budget: int
		var rad_delay: int
		var saf_budget: int
		var saf_delay: int
		var cpl_budget: int
		var cpl_delay: int
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("owner"):
				string_line = string_line.replacen("owner", "").replacen("=", "").strip_edges()
				owner_id = int(string_line)
			
			if string_line.containsn("vehicle"):
				string_line = string_line.replacen("vehicle", "").replacen("=", "").strip_edges()
				vehicle_id = int(string_line)
			
			if string_line.containsn("pos_x"):
				string_line = string_line.replacen("pos_x", "").replacen("=", "").strip_edges()
				pos_x = int(string_line)
			
			if string_line.containsn("pos_y"):
				string_line = string_line.replacen("pos_y", "").replacen("=", "").strip_edges()
				pos_y = int(string_line)
			
			if string_line.containsn("pos_z"):
				string_line = string_line.replacen("pos_z", "").replacen("=", "").strip_edges()
				pos_z = int(string_line)
			
			if string_line.containsn("energy"):
				string_line = string_line.replacen("energy", "").replacen("=", "").strip_edges()
				energy = int(string_line)
			
			if string_line.containsn("reload_const"):
				string_line = string_line.replacen("reload_const", "").replacen("=", "").strip_edges()
				reload_const = int(string_line)
				reload_const_enabled = true
			
			if string_line.containsn("viewangle"):
				string_line = string_line.replacen("viewangle", "").replacen("=", "").strip_edges()
				view_angle = int(string_line)
				view_angle_enabled = true
			
			if string_line.containsn("mb_status"):
				mb_status = true
			
			if string_line.containsn("con_budget"):
				string_line = string_line.replacen("con_budget", "").replacen("=", "").strip_edges()
				con_budget = int(string_line)
			
			if string_line.containsn("con_delay"):
				string_line = string_line.replacen("con_delay", "").replacen("=", "").strip_edges()
				con_delay = int(string_line)
			
			if string_line.containsn("def_budget"):
				string_line = string_line.replacen("def_budget", "").replacen("=", "").strip_edges()
				def_budget = int(string_line)
			
			if string_line.containsn("def_delay"):
				string_line = string_line.replacen("def_delay", "").replacen("=", "").strip_edges()
				def_delay = int(string_line)
			
			if string_line.containsn("rec_budget"):
				string_line = string_line.replacen("rec_budget", "").replacen("=", "").strip_edges()
				rec_budget = int(string_line)
			
			if string_line.containsn("rec_delay"):
				string_line = string_line.replacen("rec_delay", "").replacen("=", "").strip_edges()
				rec_delay = int(string_line)
			
			if string_line.containsn("rob_budget"):
				string_line = string_line.replacen("rob_budget", "").replacen("=", "").strip_edges()
				rob_budget = int(string_line)
			
			if string_line.containsn("rob_delay"):
				string_line = string_line.replacen("rob_delay", "").replacen("=", "").strip_edges()
				rob_delay = int(string_line)
			
			if string_line.containsn("pow_budget"):
				string_line = string_line.replacen("pow_budget", "").replacen("=", "").strip_edges()
				pow_budget = int(string_line)
			
			if string_line.containsn("pow_delay"):
				string_line = string_line.replacen("pow_delay", "").replacen("=", "").strip_edges()
				pow_delay = int(string_line)
			
			if string_line.containsn("rad_budget"):
				string_line = string_line.replacen("rad_budget", "").replacen("=", "").strip_edges()
				rad_budget = int(string_line)
			
			if string_line.containsn("rad_delay"):
				string_line = string_line.replacen("rad_delay", "").replacen("=", "").strip_edges()
				rad_delay = int(string_line)
			
			if string_line.containsn("saf_budget"):
				string_line = string_line.replacen("saf_budget", "").replacen("=", "").strip_edges()
				saf_budget = int(string_line)
			
			if string_line.containsn("saf_delay"):
				string_line = string_line.replacen("saf_delay", "").replacen("=", "").strip_edges()
				saf_delay = int(string_line)
			
			if string_line.containsn("cpl_budget"):
				string_line = string_line.replacen("cpl_budget", "").replacen("=", "").strip_edges()
				cpl_budget = int(string_line)
			
			if string_line.containsn("cpl_delay"):
				string_line = string_line.replacen("cpl_delay", "").replacen("=", "").strip_edges()
				cpl_delay = int(string_line)
		
		var host_station = Preloads.HOSTSTATION.instantiate()
		host_station.create(owner_id, vehicle_id)
		host_station.position.x = pos_x
		host_station.pos_y = pos_y
		host_station.position.y = abs(pos_z)
		host_station.energy = energy
		host_station.reload_const_enabled = reload_const_enabled
		host_station.reload_const = reload_const
		host_station.view_angle_enabled = view_angle_enabled
		host_station.view_angle = view_angle
		host_station.mb_status = mb_status
		host_station.con_budget = con_budget
		host_station.con_delay = con_delay
		host_station.def_budget = def_budget
		host_station.def_delay = def_delay
		host_station.rec_budget = rec_budget
		host_station.rec_delay = rec_delay
		host_station.rob_budget = rob_budget
		host_station.rob_delay = rob_delay
		host_station.pow_budget = pow_budget
		host_station.pow_delay = pow_delay
		host_station.rad_budget = rad_budget
		host_station.rad_delay = rad_delay
		host_station.saf_budget = saf_budget
		host_station.saf_delay = saf_delay
		host_station.cpl_budget = cpl_budget
		host_station.cpl_delay = cpl_delay
		CurrentMapData.host_stations.add_child(host_station)
		if CurrentMapData.player_host_station == null:
			CurrentMapData.player_host_station = host_station


static func _handle_bombs(file: FileAccess) -> void:
	if string_line.begins_with('begin_item'):
		var sec_x: int
		var sec_y: int
		var inactive_bp: int
		var active_bp: int
		var trigger_bp: int
		var type: int
		var countdown: int
		var key_sectors: Array[Vector2i] = []
		var key_sector: Vector2i
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.begins_with("sec_x"):
				string_line = string_line.replacen("sec_x", "").replacen("=", "").strip_edges()
				sec_x = int(string_line)
			
			if string_line.begins_with("sec_y"):
				string_line = string_line.replacen("sec_y", "").replacen("=", "").strip_edges()
				sec_y = int(string_line)
			
			if string_line.begins_with("inactive_bp"):
				string_line = string_line.replacen("inactive_bp", "").replacen("=", "").strip_edges()
				inactive_bp = int(string_line)
			
			if string_line.begins_with("active_bp"):
				string_line = string_line.replacen("active_bp", "").replacen("=", "").strip_edges()
				active_bp = int(string_line)
			
			if string_line.begins_with("trigger_bp"):
				string_line = string_line.replacen("trigger_bp", "").replacen("=", "").strip_edges()
				trigger_bp = int(string_line)
			
			if string_line.begins_with("type"):
				string_line = string_line.replacen("type", "").replacen("=", "").strip_edges()
				type = int(string_line)
			
			if string_line.begins_with("countdown"):
				string_line = string_line.replacen("countdown", "").replacen("=", "").strip_edges()
				countdown = int(string_line)
			
			if string_line.begins_with("keysec_x"):
				string_line = string_line.replacen("keysec_x", "").replacen("=", "").strip_edges()
				key_sector.x = int(string_line)
			
			if string_line.begins_with("keysec_y"):
				string_line = string_line.replacen("keysec_y", "").replacen("=", "").strip_edges()
				key_sector.y = int(string_line)
				key_sectors.append(key_sector)
		
		var bomb = StoudsonBomb.new(sec_x, sec_y)
		bomb.inactive_bp = inactive_bp
		bomb.active_bp = active_bp
		bomb.trigger_bp = trigger_bp
		bomb.type = type
		bomb.countdown = countdown
		bomb.key_sectors = key_sectors
		CurrentMapData.stoudson_bombs.append(bomb)


static func _handle_predefined_squads(file: FileAccess) -> void:
	if string_line.begins_with('begin_squad'):
		var owner_id: int
		var vehicle_id: int
		var quantity: int
		var pos_x: int
		var pos_z: int
		var useable := false
		var mb_status := false
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("owner"):
				string_line = string_line.replacen("owner", "").replacen("=", "").strip_edges()
				owner_id = int(string_line)
			
			if string_line.containsn("vehicle"):
				string_line = string_line.replacen("vehicle", "").replacen("=", "").strip_edges()
				vehicle_id = int(string_line)
			
			if string_line.begins_with("num"):
				string_line = string_line.replacen("num", "").replacen("=", "").strip_edges()
				quantity = int(string_line)
			
			if string_line.containsn("pos_x"):
				string_line = string_line.replacen("pos_x", "").replacen("=", "").strip_edges()
				pos_x = int(string_line)
			
			if string_line.containsn("pos_z"):
				string_line = string_line.replacen("pos_z", "").replacen("=", "").strip_edges()
				pos_z = int(string_line)
			
			if string_line.containsn("useable"):
				useable = true
			
			if string_line.containsn("mb_status"):
				mb_status = true
		
		var squad = Preloads.SQUAD.instantiate()
		squad.create(owner_id, vehicle_id)
		squad.position.x = pos_x
		squad.position.y = abs(pos_z)
		squad.quantity = quantity
		squad.useable = useable
		squad.mb_status = mb_status
		CurrentMapData.squads.add_child(squad)


static func _handle_modifications(file: FileAccess) -> void:
	if string_line.begins_with('include'):
		while(file.get_position() < file.get_length()):
			CurrentMapData.prototype_modifications += string_line + '\n'
			string_line = file.get_line()
			if not string_line.is_empty() and string_line[0] == ';': break
		
		CurrentMapData.prototype_modifications = CurrentMapData.prototype_modifications.strip_edges()


static func _handle_prototype_enabling(file: FileAccess) -> void:
	if string_line.begins_with("begin_enable"):
		string_line = string_line.replace("begin_enable", "").replace("=", "").strip_edges()
		var owner_id = int(string_line)
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("vehicle"):
				string_line = string_line.replacen("vehicle", "").replacen("=", "").strip_edges()
				match owner_id:
					1: CurrentMapData.resistance_enabled_units.append(int(string_line))
					2: CurrentMapData.sulgogar_enabled_units.append(int(string_line))
					3: CurrentMapData.mykonian_enabled_units.append(int(string_line))
					4: CurrentMapData.taerkasten_enabled_units.append(int(string_line))
					5: CurrentMapData.blacksect_enabled_units.append(int(string_line))
					6: CurrentMapData.ghorkov_enabled_units.append(int(string_line))
					7: CurrentMapData.training_enabled_units.append(int(string_line))
			
			if string_line.containsn("building"):
				string_line = string_line.replacen("building", "").replacen("=", "").strip_edges()
				match owner_id:
					1: CurrentMapData.resistance_enabled_buildings.append(int(string_line))
					2: CurrentMapData.sulgogar_enabled_buildings.append(int(string_line))
					3: CurrentMapData.mykonian_enabled_buildings.append(int(string_line))
					4: CurrentMapData.taerkasten_enabled_buildings.append(int(string_line))
					5: CurrentMapData.blacksect_enabled_buildings.append(int(string_line))
					6: CurrentMapData.ghorkov_enabled_buildings.append(int(string_line))
					7: CurrentMapData.training_enabled_buildings.append(int(string_line))


static func _handle_tech_upgrades(file: FileAccess) -> void:
	if string_line.begins_with("begin_gem"):
		var sec_x: int
		var sec_y: int
		var building_id := 4
		var type := 99
		var mb_status := false
		var vehicles := []
		var weapons := []
		var buildings := []
		
		while(string_line != "end" and file.get_position() < file.get_length()):
			string_line = file.get_line().get_slice(';', 0).strip_edges()
			if string_line.is_empty(): continue
			
			if string_line.containsn("sec_x"):
				string_line = string_line.replacen("sec_x", "").replacen("=", "").strip_edges()
				sec_x = int(string_line)
			
			if string_line.containsn("sec_y"):
				string_line = string_line.replacen("sec_y", "").replacen("=", "").strip_edges()
				sec_y = int(string_line)
			
			if string_line.containsn("building"):
				string_line = string_line.replacen("building", "").replacen("=", "").strip_edges()
				building_id = int(string_line)
			
			if string_line.containsn("type"):
				string_line = string_line.replacen("type", "").replacen("=", "").strip_edges()
				type = int(string_line)
			
			if string_line.containsn("mb_status"):
				mb_status = true
			
			if string_line.containsn("begin_action"):
				while(string_line != "end_action" and file.get_position() < file.get_length()):
					string_line = file.get_line().get_slice(';', 0).strip_edges()
					if string_line.is_empty(): continue
					
					if string_line.containsn("modify_vehicle"):
						string_line = string_line.replacen("modify_vehicle", "").replacen("=", "").strip_edges()
						var vehicle_id = int(string_line)
						var add_energy := 0
						var add_shield := 0
						var add_radar := 0
						var num_weapons := 0
						var res_enabled := false
						var ghor_enabled := false
						var taer_enabled := false
						var myko_enabled := false
						var sulg_enabled := false
						var blacksect_enabled := false
						var training_enabled := false
						
						while(string_line != "end" and file.get_position() < file.get_length()):
							string_line = file.get_line().get_slice(';', 0).strip_edges()
							if string_line.is_empty(): continue
							
							if string_line.containsn("enable"):
								string_line = string_line.replacen("enable", "").replacen("=", "").strip_edges()
								var owner_id := int(string_line)
								match owner_id:
									1: res_enabled = true
									2: sulg_enabled = true
									3: myko_enabled = true
									4: taer_enabled = true
									5: blacksect_enabled = true
									6: ghor_enabled = true
									7: training_enabled = true
							
							if string_line.containsn("add_energy"):
								string_line = string_line.replacen("add_energy", "").replacen("=", "").strip_edges()
								add_energy = int(string_line)
							
							if string_line.containsn("add_shield"):
								string_line = string_line.replacen("add_shield", "").replacen("=", "").strip_edges()
								add_shield = int(string_line)
							
							if string_line.containsn("add_radar"):
								string_line = string_line.replacen("add_radar", "").replacen("=", "").strip_edges()
								add_radar = int(string_line)
							
							if string_line.containsn("num_weapons"):
								string_line = string_line.replacen("num_weapons", "").replacen("=", "").strip_edges()
								num_weapons = int(string_line)
							
						var modifier = {}
						modifier.vehicle_id = vehicle_id
						modifier.res_enabled = res_enabled
						modifier.ghor_enabled = ghor_enabled
						modifier.taer_enabled = taer_enabled
						modifier.myko_enabled = myko_enabled
						modifier.sulg_enabled = sulg_enabled
						modifier.blacksect_enabled = blacksect_enabled
						modifier.training_enabled = training_enabled
						modifier.energy = add_energy
						modifier.shield = add_shield
						modifier.radar = add_radar
						modifier.num_weapons = num_weapons
						vehicles.append(modifier)
					
					if string_line.containsn("modify_weapon"):
						string_line = string_line.replacen("modify_weapon", "").replacen("=", "").strip_edges()
						var weapon_id = int(string_line)
						var energy := 0
						var shot_time := 0
						var shot_time_user := 0
						
						while(string_line != "end" and file.get_position() < file.get_length()):
							string_line = file.get_line().get_slice(';', 0).strip_edges()
							if string_line.is_empty(): continue
							
							if string_line.containsn("add_energy"):
								string_line = string_line.replacen("add_energy", "").replacen("=", "").strip_edges()
								energy = int(string_line)
							
							if string_line.containsn("add_shot_time"):
								string_line = string_line.replacen("add_shot_time", "").replacen("=", "").strip_edges()
								shot_time = int(string_line)
							
							if string_line.containsn("add_shot_time_user"):
								string_line = string_line.replacen("add_shot_time_user", "").replacen("=", "").strip_edges()
								shot_time_user = int(string_line)
						
						var modifier = {}
						modifier.weapon_id = weapon_id
						modifier.energy = energy
						modifier.shot_time = shot_time
						modifier.shot_time_user = shot_time_user
						weapons.append(modifier)
					
					if string_line.containsn("modify_building"):
						string_line = string_line.replacen("modify_building", "").replacen("=", "").strip_edges()
						var _building_id = int(string_line)
						var res_enabled := false
						var ghor_enabled := false
						var taer_enabled := false
						var myko_enabled := false
						var sulg_enabled := false
						var blacksect_enabled := false
						var training_enabled := false
						
						while(string_line != "end" and file.get_position() < file.get_length()):
							string_line = file.get_line().get_slice(';', 0).strip_edges()
							if string_line.is_empty(): continue
							
							if string_line.containsn("enable"):
								string_line = string_line.replacen("enable", "").replacen("=", "").strip_edges()
								var owner_id := int(string_line)
								match owner_id:
									1: res_enabled = true
									2: sulg_enabled = true
									3: myko_enabled = true
									4: taer_enabled = true
									5: blacksect_enabled = true
									6: ghor_enabled = true
									7: training_enabled = true
						
						var modifier = {}
						modifier.building_id = _building_id
						modifier.res_enabled = res_enabled
						modifier.ghor_enabled = ghor_enabled
						modifier.taer_enabled = taer_enabled
						modifier.myko_enabled = myko_enabled
						modifier.sulg_enabled = sulg_enabled
						modifier.blacksect_enabled = blacksect_enabled
						modifier.training_enabled = training_enabled
						buildings.append(modifier)
		
		var tech_upgrade = TechUpgrade.new(sec_x, sec_y)
		tech_upgrade.building_id = building_id
		tech_upgrade.type = type
		tech_upgrade.mb_status = mb_status
		for vehicle_modifier: Dictionary in vehicles:
			var new_modifier = tech_upgrade.new_vehicle_modifier(vehicle_modifier.vehicle_id)
			if new_modifier:
				new_modifier.res_enabled = vehicle_modifier.res_enabled
				new_modifier.ghor_enabled = vehicle_modifier.ghor_enabled
				new_modifier.taer_enabled = vehicle_modifier.taer_enabled
				new_modifier.myko_enabled = vehicle_modifier.myko_enabled
				new_modifier.sulg_enabled = vehicle_modifier.sulg_enabled
				new_modifier.blacksect_enabled = vehicle_modifier.blacksect_enabled
				new_modifier.training_enabled = vehicle_modifier.training_enabled
				new_modifier.energy = vehicle_modifier.energy
				new_modifier.shield = vehicle_modifier.shield
				new_modifier.num_weapons = vehicle_modifier.num_weapons
				new_modifier.radar = vehicle_modifier.radar
				tech_upgrade.vehicles.append(new_modifier)
		for weapon_modifier: Dictionary in weapons:
			var new_modifier = tech_upgrade.new_weapon_modifier(weapon_modifier.weapon_id)
			if new_modifier:
				new_modifier.energy = weapon_modifier.energy
				new_modifier.shot_time = weapon_modifier.shot_time
				new_modifier.shot_time_user = weapon_modifier.shot_time_user
				tech_upgrade.weapons.append(new_modifier)
		for building_modifier: Dictionary in buildings:
			var new_modifier = tech_upgrade.new_building_modifier(building_modifier.building_id)
			if new_modifier:
				new_modifier.res_enabled = building_modifier.res_enabled
				new_modifier.ghor_enabled = building_modifier.ghor_enabled
				new_modifier.taer_enabled = building_modifier.taer_enabled
				new_modifier.myko_enabled = building_modifier.myko_enabled
				new_modifier.sulg_enabled = building_modifier.sulg_enabled
				new_modifier.blacksect_enabled = building_modifier.blacksect_enabled
				new_modifier.training_enabled = building_modifier.training_enabled
				tech_upgrade.buildings.append(new_modifier)
		
		CurrentMapData.tech_upgrades.append(tech_upgrade)


static func _infer_game_type() -> void:
	# Note: Inferring game type is not 100% accurate. Always check if game type matches your specific mod
	var player_hs: HostStation
	if CurrentMapData.host_stations.get_child_count() > 0:
		player_hs = CurrentMapData.host_stations.get_child(0)
	var inferred_game_type: String
	for game_type in Preloads.ua_data.data:
		if ((CurrentMapData.briefing_map in Preloads.ua_data.data[game_type].missionBriefingMaps or 
			CurrentMapData.briefing_map in Preloads.ua_data.data[game_type].missionDebriefingMaps) and
			(CurrentMapData.debriefing_map in Preloads.ua_data.data[game_type].missionDebriefingMaps or
			CurrentMapData.debriefing_map in Preloads.ua_data.data[game_type].missionBriefingMaps) and 
			inferred_game_type.is_empty()):
			inferred_game_type = game_type
		elif ((not CurrentMapData.briefing_map in Preloads.ua_data.data[game_type].missionBriefingMaps and
			  not CurrentMapData.briefing_map in Preloads.ua_data.data[game_type].missionDebriefingMaps) or 
			  (not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_type].missionDebriefingMaps and
			  not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_type].missionBriefingMaps)):
			continue
		
		if player_hs:
			for hs in Preloads.ua_data.data[game_type].hoststations:
				for robo in Preloads.ua_data.data[game_type].hoststations[hs].robos:
					if "player_id" in robo:
						if player_hs.vehicle == int(robo.player_id):
							player_hs.player_vehicle = int(robo.player_id)
							player_hs.vehicle = int(robo.id)
							inferred_game_type = game_type
							EditorState.game_data_type = inferred_game_type
							return
	
	if ((CurrentMapData.prototype_modifications.containsn("include script:startupG.scr") or 
		CurrentMapData.prototype_modifications.containsn("include script:startupT.scr")) and 
		Preloads.ua_data.data.keys().has("metropolisDawn")):
		inferred_game_type = "metropolisDawn"
	
	if not inferred_game_type.is_empty():
		EditorState.game_data_type = inferred_game_type

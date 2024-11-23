class_name SingleplayerSaver


static func save() -> void:
	var file = FileAccess.open(CurrentMapData.save_path, FileAccess.WRITE)
	_handle_header(file)
	_handle_description(file)
	_handle_level_parameters(file)
	_handle_briefing_maps(file)
	_handle_beam_gates(file)
	_handle_host_stations(file)
	_handle_bombs(file)
	_handle_predefined_squads(file)
	_handle_modifications(file)
	_handle_prototype_enabling(file)
	_handle_tech_upgrades(file)
	_handle_typ_map(file)
	_handle_own_map(file)
	_handle_hgt_map(file)
	_handle_blg_map(file)


static func _handle_header(file: FileAccess) -> void:
	file.store_line(";#*+ don't edit the magic runes")
	file.store_line("")
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Original Header                                      ---")
	file.store_line(";------------------------------------------------------------")
	file.store_line(";")


static func _handle_description(file: FileAccess) -> void:
	file.store_line(";"+CurrentMapData.level_description.replace('\n', '\n;'))
	file.store_line("")
	

static func _handle_level_parameters(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Main Level Info                                      ---")
	file.store_line(";------------------------------------------------------------")
	file.store_line("begin_level")
	file.store_line("\tset = %s" % CurrentMapData.level_set)
	file.store_line("\tsky = objects/%s.base" % CurrentMapData.sky)
	file.store_line("\tslot0 = palette/standard.pal")
	file.store_line("\tslot1 = palette/red.pal")
	file.store_line("\tslot2 = palette/blau.pal")
	file.store_line("\tslot3 = palette/gruen.pal")
	file.store_line("\tslot4 = palette/inverse.pal")
	file.store_line("\tslot5 = palette/invdark.pal")
	file.store_line("\tslot6 = palette/sw.pal")
	file.store_line("\tslot7 = palette/invtuerk.pal")
	if CurrentMapData.event_loop > 0:
		file.store_line("\tevent_loop = %s" % CurrentMapData.event_loop)
	if CurrentMapData.music > 0:
		file.store_string("\tambiencetrack = %s" % CurrentMapData.music)
		if CurrentMapData.min_break < 10: file.store_string("_0%s" % CurrentMapData.min_break)
		else: file.store_string("_%s" % CurrentMapData.min_break)
		if CurrentMapData.max_break < 10: file.store_line("_0%s" % CurrentMapData.max_break)
		else: file.store_line("_%s" % CurrentMapData.max_break)
	if not CurrentMapData.movie.is_empty(): file.store_line("\tmovie = mov:%s" % CurrentMapData.movie)
	file.store_line("end")


static func _handle_briefing_maps(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Mission Briefing Maps                                ---")
	file.store_line(";------------------------------------------------------------")
	file.store_line("begin_mbmap")
	file.store_line("\tname = %s" % CurrentMapData.briefing_map)
	if CurrentMapData.briefing_size_x > 0: file.store_line("\tsize_x = %s" % CurrentMapData.briefing_size_x)
	if CurrentMapData.briefing_size_y > 0: file.store_line("\tsize_y = %s" % CurrentMapData.briefing_size_y)
	file.store_line("end")
	file.store_line("begin_dbmap")
	file.store_line("\tname = %s" % CurrentMapData.debriefing_map)
	if CurrentMapData.debriefing_size_x > 0: file.store_line("\tsize_x = %s" % CurrentMapData.debriefing_size_x)
	if CurrentMapData.debriefing_size_y > 0: file.store_line("\tsize_y = %s" % CurrentMapData.debriefing_size_y)
	file.store_line("end")
	

static func _handle_beam_gates(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Beam Gates                                           ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.beam_gates.size() > 0:
		for bg in CurrentMapData.beam_gates:
			file.store_line("begin_gate")
			file.store_line("\tsec_x = %s" % bg.sec_x)
			file.store_line("\tsec_y = %s" % bg.sec_y)
			file.store_line("\tclosed_bp = %s" % bg.closed_bp)
			file.store_line("\topened_bp = %s" % bg.opened_bp)
			for target_level in bg.target_levels:
				file.store_line("\ttarget_level = %s" % target_level)
			for key_sector in bg.key_sectors:
				file.store_line("\tkeysec_x = %s" % key_sector.x)
				file.store_line("\tkeysec_y = %s" % key_sector.y)
			if bg.mb_status:
				file.store_line("\tmb_status = unknown")
			file.store_line("end")
	else:
		file.store_line(";none")


static func _handle_host_stations(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Robo Definitions                                     ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.host_stations.get_child_count() > 0:
		var player_hs: HostStation = CurrentMapData.host_stations.get_child(CurrentMapData.player_host_station)
		file.store_line("begin_robo")
		file.store_line("\towner = %s" % player_hs.owner_id)
		if player_hs.player_vehicle >= 0: file.store_line("\tvehicle = %s" % player_hs.player_vehicle)
		else: file.store_line("\tvehicle = %s" % player_hs.vehicle)
		file.store_line("\tpos_x = %s" % round(player_hs.position.x))
		file.store_line("\tpos_y = %s" % player_hs.pos_y)
		file.store_line("\tpos_z = -%s" % round(player_hs.position.y))
		file.store_line("\tenergy = %s" % player_hs.energy)
		if player_hs.reload_const_enabled: file.store_line("\treload_const = %s" % player_hs.reload_const)
		if player_hs.view_angle_enabled: file.store_line("\tviewangle = %s" % player_hs.view_angle)
		if player_hs.mb_status: file.store_line("\tmb_status = unknown")
		file.store_line("end")
		
		for hs: HostStation in CurrentMapData.host_stations.get_children():
			if hs == player_hs: continue
			file.store_line("begin_robo")
			file.store_line("\towner = %s" % hs.owner_id)
			file.store_line("\tvehicle = %s" % hs.vehicle)
			file.store_line("\tpos_x = %s" % round(hs.position.x))
			file.store_line("\tpos_y = %s" % hs.pos_y)
			file.store_line("\tpos_z = -%s" % round(hs.position.y))
			file.store_line("\tenergy = %s" % hs.energy)
			if hs.reload_const_enabled: file.store_line("\treload_const = %s" % hs.reload_const)
			if hs.view_angle_enabled: file.store_line("\tviewangle = %s" % hs.view_angle)
			if hs.mb_status: file.store_line("\tmb_status = unknown")
			file.store_line("\tcon_budget = %s" % hs.con_budget)
			file.store_line("\tcon_delay = %s" % hs.con_delay)
			file.store_line("\tdef_budget = %s" % hs.def_budget)
			file.store_line("\tdef_delay = %s" % hs.def_delay)
			file.store_line("\trec_budget = %s" % hs.rec_budget)
			file.store_line("\trec_delay = %s" % hs.rec_delay)
			file.store_line("\trob_budget = %s" % hs.rob_budget)
			file.store_line("\trob_delay = %s" % hs.rob_delay)
			file.store_line("\tpow_budget = %s" % hs.pow_budget)
			file.store_line("\tpow_delay = %s" % hs.pow_delay)
			file.store_line("\trad_budget = %s" % hs.rad_budget)
			file.store_line("\trad_delay = %s" % hs.rad_delay)
			file.store_line("\tsaf_budget = %s" % hs.saf_budget)
			file.store_line("\tsaf_delay = %s" % hs.saf_delay)
			file.store_line("\tcpl_budget = %s" % hs.cpl_budget)
			file.store_line("\tcpl_delay = %s" % hs.cpl_delay)
			file.store_line("end")
	else:
		file.store_line(";none")


static func _handle_bombs(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Superitem	                                          ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.stoudson_bombs.size() > 0:
		for bomb in CurrentMapData.stoudson_bombs:
			file.store_line("begin_item")
			file.store_line("\tsec_x = %s" % bomb.sec_x)
			file.store_line("\tsec_y = %s" % bomb.sec_y)
			file.store_line("\tinactive_bp = %s" % bomb.inactive_bp)
			file.store_line("\tactive_bp = %s" % bomb.active_bp)
			file.store_line("\ttrigger_bp = %s" % bomb.trigger_bp)
			file.store_line("\ttype = %s" % bomb.type)
			file.store_line("\tcountdown = %s" % bomb.countdown)
			for key_sector in bomb.key_sectors:
				file.store_line("\tkeysec_x = %s" % key_sector.x)
				file.store_line("\tkeysec_y = %s" % key_sector.y)
			file.store_line("end")
	else:
		file.store_line(";none")


static func _handle_predefined_squads(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Predefined Squads                                    ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.squads.get_child_count() > 0:
		for squad: Squad in CurrentMapData.squads.get_children():
			file.store_line("begin_squad")
			file.store_line("\towner = %s" % squad.owner_id)
			file.store_line("\tvehicle = %s" % squad.vehicle)
			file.store_line("\tnum = %s" % squad.quantity)
			if squad.useable: file.store_line("\tuseable")
			file.store_line("\tpos_x = %s" % round(squad.position.x))
			file.store_line("\tpos_z = -%s" % round(squad.position.y))
			if squad.mb_status: file.store_line("\tmb_status = unknown")
			file.store_line("end")
	else:
		file.store_line(";none")


static func _handle_modifications(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Prototype Modifications                              ---")
	file.store_line(";------------------------------------------------------------")
	file.store_line(CurrentMapData.prototype_modifications)


static func _handle_prototype_enabling(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Prototype Enabling                                   ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.resistance_enabled_units.size() > 0 or CurrentMapData.resistance_enabled_buildings.size() > 0:
		file.store_line("begin_enable 1")
		for unit_id in CurrentMapData.resistance_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.resistance_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.ghorkov_enabled_units.size() > 0 or CurrentMapData.ghorkov_enabled_buildings.size() > 0:
		file.store_line("begin_enable 6")
		for unit_id in CurrentMapData.ghorkov_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.ghorkov_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.taerkasten_enabled_units.size() > 0 or CurrentMapData.taerkasten_enabled_buildings.size() > 0:
		file.store_line("begin_enable 4")
		for unit_id in CurrentMapData.taerkasten_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.taerkasten_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.mykonian_enabled_units.size() > 0 or CurrentMapData.mykonian_enabled_buildings.size() > 0:
		file.store_line("begin_enable 3")
		for unit_id in CurrentMapData.mykonian_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.mykonian_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.sulgogar_enabled_units.size() > 0 or CurrentMapData.sulgogar_enabled_buildings.size() > 0:
		file.store_line("begin_enable 2")
		for unit_id in CurrentMapData.sulgogar_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.sulgogar_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.blacksect_enabled_units.size() > 0 or CurrentMapData.blacksect_enabled_buildings.size() > 0:
		file.store_line("begin_enable 5")
		for unit_id in CurrentMapData.blacksect_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.blacksect_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	if CurrentMapData.training_enabled_units.size() > 0 or CurrentMapData.training_enabled_buildings.size() > 0:
		file.store_line("begin_enable 7")
		for unit_id in CurrentMapData.training_enabled_units: file.store_line("\tvehicle = %s" % unit_id)
		for building_id in CurrentMapData.training_enabled_buildings: file.store_line("\tbuilding = %s" % building_id)
		file.store_line("end")
	
	if (CurrentMapData.resistance_enabled_units.is_empty() and CurrentMapData.resistance_enabled_buildings.is_empty() and
		CurrentMapData.ghorkov_enabled_units.is_empty() and CurrentMapData.ghorkov_enabled_buildings.is_empty() and
		CurrentMapData.taerkasten_enabled_units.is_empty() and CurrentMapData.taerkasten_enabled_buildings.is_empty() and
		CurrentMapData.mykonian_enabled_units.is_empty() and CurrentMapData.mykonian_enabled_buildings.is_empty() and
		CurrentMapData.sulgogar_enabled_units.is_empty() and CurrentMapData.sulgogar_enabled_buildings.is_empty() and
		CurrentMapData.blacksect_enabled_units.is_empty() and CurrentMapData.blacksect_enabled_buildings.is_empty() and
		CurrentMapData.training_enabled_units.is_empty() and CurrentMapData.training_enabled_buildings.is_empty()):
			file.store_line(";none")


static func _handle_tech_upgrades(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Tech Upgrades                                        ---")
	file.store_line(";------------------------------------------------------------")
	if CurrentMapData.tech_upgrades.size() > 0:
		for tu in CurrentMapData.tech_upgrades:
			file.store_line("begin_gem")
			file.store_line("\tsec_x = %s" % tu.sec_x)
			file.store_line("\tsec_y = %s" % tu.sec_y)
			file.store_line("\tbuilding = %s" % tu.building_id)
			if tu.type != 99: file.store_line("\ttype = %s" % tu.type)
			if tu.vehicles.size() > 0 or tu.weapons.size() > 0 or tu.buildings.size() > 0:
				file.store_line("\tbegin_action")
			
				for vehicle in tu.vehicles:
					if (vehicle.energy == 0 and vehicle.shield == 0 and vehicle.radar == 0 and vehicle.weapon_num == 0 and 
					not vehicle.res_enabled and not vehicle.ghor_enabled and not vehicle.taer_enabled and not vehicle.myko_enabled and 
					not vehicle.sulg_enabled and not vehicle.blacksect_enabled and not vehicle.training_enabled): continue
					
					file.store_line("\t\tmodify_vehicle %s" % vehicle.vehicle_id)
					if vehicle.res_enabled: file.store_line("\t\t\tenable = 1")
					if vehicle.ghor_enabled: file.store_line("\t\t\tenable = 6")
					if vehicle.taer_enabled: file.store_line("\t\t\tenable = 4")
					if vehicle.myko_enabled: file.store_line("\t\t\tenable = 3")
					if vehicle.sulg_enabled: file.store_line("\t\t\tenable = 2")
					if vehicle.blacksect_enabled: file.store_line("\t\t\tenable = 5")
					if vehicle.training_enabled: file.store_line("\t\t\tenable = 7")
					if vehicle.energy != 0: file.store_line("\t\t\tadd_energy = %s" % vehicle.energy)
					if vehicle.shield != 0: file.store_line("\t\t\tadd_shield = %s" % vehicle.shield)
					if vehicle.radar != 0: file.store_line("\t\t\tadd_radar = %s" % vehicle.radar)
					if vehicle.weapon_num != 0: 
						file.store_line("\t\t\tnum_weapons = %s" % vehicle.weapon_num)
						file.store_line("\t\t\tfire_x = %s" % vehicle.fire_x)
						file.store_line("\t\t\tfire_y = %s" % vehicle.fire_y)
						file.store_line("\t\t\tfire_z = %s" % vehicle.fire_z)
					file.store_line("\t\tend")
					
				for weapon in tu.weapons:
					if weapon.energy == 0 and weapon.shot_time == 0 and weapon.shot_time_user == 0: continue
					
					file.store_line("\t\tmodify_weapon %s" % weapon.weapon_id)
					if weapon.energy != 0: file.store_line("\t\t\tadd_energy = %s" % weapon.energy)
					if weapon.shot_time != 0: file.store_line("\t\t\tadd_shot_time = %s" % weapon.shot_time)
					if weapon.shot_time_user != 0: file.store_line("\t\t\tadd_shot_time_user = %s" % weapon.shot_time_user)
					file.store_line("\t\tend")
				
				for building in tu.buildings:
					if (not building.res_enabled and not building.ghor_enabled and not building.taer_enabled and not building.myko_enabled and
					not building.sulg_enabled and not building.blacksect_enabled and not building.training_enabled): continue
					
					file.store_line("\t\tmodify_building %s" % building.building_id)
					if building.res_enabled: file.store_line("\t\t\tenable = 1")
					if building.ghor_enabled: file.store_line("\t\t\tenable = 6")
					if building.taer_enabled: file.store_line("\t\t\tenable = 4")
					if building.myko_enabled: file.store_line("\t\t\tenable = 3")
					if building.sulg_enabled: file.store_line("\t\t\tenable = 2")
					if building.blacksect_enabled: file.store_line("\t\t\tenable = 5")
					if building.training_enabled: file.store_line("\t\t\tenable = 7")
					file.store_line("\t\tend")
				
				file.store_line("\tend_action")
			if tu.mb_status: file.store_line("\tmb_status = unknown")
			file.store_line("end")
	else:
		file.store_line(";none")


static func _handle_typ_map(file: FileAccess) -> void:
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- Map Dumps                                            ---")
	file.store_line(";------------------------------------------------------------")
	file.store_line("begin_maps")
	file.store_line("    typ_map =")
	file.store_line("        %s %s" % [(CurrentMapData.horizontal_sectors+2), (CurrentMapData.vertical_sectors+2)])
	file.store_string("        f8 ")
	for _i in CurrentMapData.horizontal_sectors: file.store_string("fc ")
	file.store_line("f9 ")
	var index := 0
	for v in CurrentMapData.vertical_sectors:
		file.store_string("        ff ")
		for h in CurrentMapData.horizontal_sectors:
			if CurrentMapData.typ_map[index] < 16: file.store_string("0%x " % CurrentMapData.typ_map[index])
			else: file.store_string("%x " % CurrentMapData.typ_map[index])
			index += 1
		file.store_line("fd ")
	
	file.store_string("        fb ")
	for _i in CurrentMapData.horizontal_sectors: file.store_string("fe ")
	file.store_line("fa ")


static func _handle_own_map(file: FileAccess) -> void:
	file.store_line("    own_map =")
	file.store_line("        %s %s" % [(CurrentMapData.horizontal_sectors+2), (CurrentMapData.vertical_sectors+2)])
	file.store_string("        ")
	for _i in CurrentMapData.horizontal_sectors+1: file.store_string("00 ")
	file.store_line("00 ")
	var index := 0
	for v in CurrentMapData.vertical_sectors:
		file.store_string("        00 ")
		for h in CurrentMapData.horizontal_sectors:
			file.store_string("0%x " % CurrentMapData.own_map[index])
			index += 1
		file.store_line("00 ")
	file.store_string("        ")
	for _i in CurrentMapData.horizontal_sectors+1: file.store_string("00 ")
	file.store_line("00 ")


static func _handle_hgt_map(file: FileAccess) -> void:
	file.store_line("    hgt_map =")
	file.store_line("        %s %s" % [(CurrentMapData.horizontal_sectors+2), (CurrentMapData.vertical_sectors+2)])
	var index := 0
	for v in CurrentMapData.vertical_sectors+2:
		file.store_string("        ")
		for h in CurrentMapData.horizontal_sectors+2:
			if CurrentMapData.hgt_map[index] < 16: file.store_string("0%x " % CurrentMapData.hgt_map[index])
			else: file.store_string("%x " % CurrentMapData.hgt_map[index])
			index += 1
		file.store_line("")
	

static func _handle_blg_map(file: FileAccess) ->void:
	file.store_line("    blg_map =")
	file.store_line("        %s %s" % [(CurrentMapData.horizontal_sectors+2), (CurrentMapData.vertical_sectors+2)])
	file.store_string("        ")
	for _i in CurrentMapData.horizontal_sectors+1: file.store_string("00 ")
	file.store_line("00 ")
	var index := 0
	for v in CurrentMapData.vertical_sectors:
		file.store_string("        00 ")
		for h in CurrentMapData.horizontal_sectors:
			if CurrentMapData.blg_map[index] < 16: file.store_string("0%x " % CurrentMapData.blg_map[index])
			else: file.store_string("%x " % CurrentMapData.blg_map[index])
			index += 1
		file.store_line("00 ")
	file.store_string("        ")
	for _i in CurrentMapData.horizontal_sectors+1: file.store_string("00 ")
	file.store_line("00 ")
	
	file.store_line("; ------------------------ ")
	file.store_line(";--- map dumps end here ---")
	file.store_line("; ------------------------ ")
	file.store_line("end")
	file.store_line("")
	file.store_line(";------------------------------------------------------------")
	file.store_line(";--- End Of File                                          ---")
	file.store_line(";------------------------------------------------------------")

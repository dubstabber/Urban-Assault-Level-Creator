class_name SingleplayerSaver


static func save() -> void:
	var file = FileAccess.open(CurrentMapData.save_path, FileAccess.WRITE)
	_handle_header(file)
	_handle_description(file)
	_handle_level_parameters(file)
	_handle_briefing_maps(file)


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
	
	file.store_line("end")
	
	

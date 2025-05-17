extends Node

var level_set := 1:
	set(value):
		if value > 6 or value < 1:
			EventSystem.invalid_set_detected.emit(value)
			level_set = 1
		else:
			level_set = value
		EventSystem.level_set_changed.emit()
var movie := ""
var event_loop := 0
var sky := "1998_01"
var music := 0
var min_break := 0
var max_break := 0
var briefing_map: String
var briefing_size_x: int
var briefing_size_y: int
var debriefing_map: String
var debriefing_size_x: int
var debriefing_size_y: int
var player_host_station: HostStation = null
var level_description := ""
var prototype_modifications := ""

var host_stations: Node2D
var squads: Node2D
var horizontal_sectors := 0
var vertical_sectors := 0
var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []
var beam_gates: Array[BeamGate] = []
var stoudson_bombs: Array[StoudsonBomb] = []
var tech_upgrades: Array[TechUpgrade] = []

var resistance_enabled_units: Array[int] = []
var ghorkov_enabled_units: Array[int] = []
var taerkasten_enabled_units: Array[int] = []
var mykonian_enabled_units: Array[int] = []
var sulgogar_enabled_units: Array[int] = []
var blacksect_enabled_units: Array[int] = []
var training_enabled_units: Array[int] = []
var unknown_enabled_units: Array[Dictionary] = []

var resistance_enabled_buildings: Array[int] = []
var ghorkov_enabled_buildings: Array[int] = []
var taerkasten_enabled_buildings: Array[int] = []
var mykonian_enabled_buildings: Array[int] = []
var sulgogar_enabled_buildings: Array[int] = []
var blacksect_enabled_buildings: Array[int] = []
var training_enabled_buildings: Array[int] = []
var unknown_enabled_buildings: Array[Dictionary] = []

var map_path := ""
var is_saved := true:
	set(value):
		if horizontal_sectors and vertical_sectors:
			is_saved = value
			if map_path.is_empty():
				get_viewport().title = "[not saved] (%sx%s) - %s" % [horizontal_sectors, vertical_sectors, "Urban Assault Level Creator"]
			else:
				if is_saved:
					get_viewport().title = "%s (%sx%s) - %s" % [map_path, horizontal_sectors, vertical_sectors, "Urban Assault Level Creator"]
					if host_stations.get_child_count() == 0:
						EventSystem.saved_with_no_hoststation.emit()
				else:
					get_viewport().title = "*%s (%sx%s) - %s" % [map_path, horizontal_sectors, vertical_sectors, "Urban Assault Level Creator"]
		else:
			is_saved = true
			get_viewport().title = "Urban Assault Level Creator"


func _ready() -> void:
	EventSystem.map_updated.connect(func(): is_saved = false)
	EventSystem.item_updated.connect(func(): is_saved = false)


func close_map() -> void:
	EditorState.unselect_all()
	map_path = ""
	EditorState.game_data_type = Preloads.ua_data.data.keys()[0]
	level_set = 1
	movie = ""
	event_loop = 0
	sky = "1998_01"
	music = 0
	min_break = 0
	max_break = 0
	briefing_map = "mb.ilb"
	briefing_size_x = 0
	briefing_size_y = 0
	debriefing_map = "db_01.iff"
	debriefing_size_x = 0
	debriefing_size_y = 0
	player_host_station = null
	level_description = ""
	prototype_modifications = ""
	for hs in host_stations.get_children():
		host_stations.remove_child(hs)
		hs.queue_free()
	for squad in squads.get_children():
		squads.remove_child(squad)
		squad.queue_free()
	horizontal_sectors = 0
	vertical_sectors = 0
	typ_map.clear()
	own_map.clear()
	hgt_map.clear()
	blg_map.clear()
	beam_gates.clear()
	stoudson_bombs.clear()
	tech_upgrades.clear()
	
	resistance_enabled_units.clear()
	ghorkov_enabled_units.clear()
	taerkasten_enabled_units.clear()
	mykonian_enabled_units.clear()
	sulgogar_enabled_units.clear()
	blacksect_enabled_units.clear()
	training_enabled_units.clear()
	unknown_enabled_units.clear()
	
	resistance_enabled_buildings.clear()
	ghorkov_enabled_buildings.clear()
	taerkasten_enabled_buildings.clear()
	mykonian_enabled_buildings.clear()
	sulgogar_enabled_buildings.clear()
	blacksect_enabled_buildings.clear()
	training_enabled_buildings.clear()
	unknown_enabled_buildings.clear()
	
	EditorState.error_messages.clear()
	EditorState.warning_messages.clear()
	EventSystem.warning_logs_updated.emit(true)
	
	DisplayServer.window_set_title("Urban Assault Level Creator")


func clear_sector(index: int, refresh_map := true) -> void:
	typ_map[index] = 0
	blg_map[index] = 0
	own_map[index] = 0
	
	beam_gates.erase(EditorState.selected_beam_gate)
	EditorState.selected_beam_gate = null
	stoudson_bombs.erase(EditorState.selected_bomb)
	EditorState.selected_bomb = null
	tech_upgrades.erase(EditorState.selected_tech_upgrade)
	EditorState.selected_tech_upgrade = null
	for bg in beam_gates:
		bg.key_sectors.erase(EditorState.selected_bg_key_sector)
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	for bomb in stoudson_bombs:
		bomb.key_sectors.erase(EditorState.selected_bomb_key_sector)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	if refresh_map:
		EventSystem.map_updated.emit()
		EventSystem.item_updated.emit()

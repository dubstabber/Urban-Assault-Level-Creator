extends Node

var game_data_type:String:
	set(value):
		game_data_type = value
		EventSystem.game_type_changed.emit()
		EventSystem.map_updated.emit()

var level_set := 1:
	set(value):
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

var host_stations: Control
var squads: Control
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

var resistance_enabled_buildings: Array[int] = []
var ghorkov_enabled_buildings: Array[int] = []
var taerkasten_enabled_buildings: Array[int] = []
var mykonian_enabled_buildings: Array[int] = []
var sulgogar_enabled_buildings: Array[int] = []
var blacksect_enabled_buildings: Array[int] = []
var training_enabled_buildings: Array[int] = []


var selected_unit: Unit = null:
	set(value):
		selected_unit = value
		EventSystem.unit_selected.emit()
var selected_sector_idx: int = -1
var border_selected_sector_idx: int = -1
var selected_sector: Vector2i = Vector2i(-1, -1)
var selected_sectors: Array[Dictionary] = []
var selected_beam_gate: BeamGate = null
var selected_bomb: StoudsonBomb = null
var selected_tech_upgrade: TechUpgrade = null
var selected_bg_key_sector: Vector2i = Vector2i(-1, -1)
var selected_bomb_key_sector: Vector2i = Vector2i(-1, -1)

var mouse_over_unit: Unit = null

var typ_map_images_visible := true:
	set(value):
		typ_map_images_visible = value
		EventSystem.map_updated.emit()
var typ_map_values_visible := false:
	set(value):
		typ_map_values_visible = value
		EventSystem.map_updated.emit()
var own_map_values_visible := false:
	set(value):
		own_map_values_visible = value
		EventSystem.map_updated.emit()
var hgt_map_values_visible := false:
	set(value):
		hgt_map_values_visible = value
		EventSystem.map_updated.emit()
var blg_map_values_visible := false:
	set(value):
		blg_map_values_visible = value
		EventSystem.map_updated.emit()

var units_db := {}
var blg_names := {}
var weapons_db := {}

var map_path := ""
var is_saved := true:
	set(value):
		is_saved = value
		if CurrentMapData.horizontal_sectors and CurrentMapData.vertical_sectors:
			if map_path.is_empty():
				DisplayServer.window_set_title("[not saved] (%sx%s) - %s" % [CurrentMapData.horizontal_sectors, CurrentMapData.vertical_sectors, "Urban Assault Level Creator"])
			else:
				if is_saved:
					DisplayServer.window_set_title("%s (%sx%s) - %s" % [CurrentMapData.map_path, CurrentMapData.horizontal_sectors, CurrentMapData.vertical_sectors, "Urban Assault Level Creator"])
				else:
					DisplayServer.window_set_title("*%s (%sx%s) - %s" % [CurrentMapData.map_path, CurrentMapData.horizontal_sectors, CurrentMapData.vertical_sectors, "Urban Assault Level Creator"])
		


func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	reload()
	EventSystem.game_type_changed.connect(reload)
	EventSystem.map_updated.connect(func(): CurrentMapData.is_saved = false)
	EventSystem.item_updated.connect(func(): CurrentMapData.is_saved = false)


func reload() -> void:
	if (not briefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps and
		not briefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps):
		briefing_map = Preloads.ua_data.data[game_data_type].missionBriefingMaps[0]
	if (not debriefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps and 
		not debriefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps):
		debriefing_map = Preloads.ua_data.data[game_data_type].missionDebriefingMaps[0]
	
	units_db.clear()
	blg_names.clear()
	weapons_db.clear()
	
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
		for robo: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].robos:
			if host_stations:
				for hss: HostStation in host_stations.get_children():
					if hss.vehicle == robo.id:
						if "player_id" in robo:
							hss.player_vehicle = robo.player_id
						else:
							hss.player_vehicle = -1
		for unit: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].units:
			units_db[unit.name] = unit.id
		for building: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].buildings:
			blg_names[str(building.id)] = building.name
	for building: Dictionary in Preloads.ua_data.data[game_data_type].other.buildings:
		blg_names[str(building.id)] = building.name
	for unit: Dictionary in Preloads.ua_data.data[game_data_type].other.units:
		units_db[unit.name] = unit.id
	for weapon in Preloads.ua_data.data[game_data_type].techUpgrade:
		units_db[weapon.name] = weapon.id
		weapons_db[weapon.name] = weapon.id


func close_map() -> void:
	selected_unit = null
	selected_sector_idx = -1
	border_selected_sector_idx = -1
	selected_sector = Vector2i(-1, -1)
	selected_sectors.clear()
	selected_beam_gate = null
	selected_bomb = null
	selected_tech_upgrade = null
	selected_bg_key_sector = Vector2i(-1, -1)
	selected_bomb_key_sector = Vector2i(-1, -1)
	map_path = ""
	game_data_type = Preloads.ua_data.data.keys()[0]
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
	
	resistance_enabled_buildings.clear()
	ghorkov_enabled_buildings.clear()
	taerkasten_enabled_buildings.clear()
	mykonian_enabled_buildings.clear()
	sulgogar_enabled_buildings.clear()
	blacksect_enabled_buildings.clear()
	training_enabled_buildings.clear()
	
	DisplayServer.window_set_title("Urban Assault Level Creator")


func clear_sector(index: int) -> void:
	typ_map[index] = 0
	blg_map[index] = 0
	own_map[index] = 0
	
	beam_gates.erase(selected_beam_gate)
	selected_beam_gate = null
	stoudson_bombs.erase(selected_bomb)
	selected_bomb = null
	tech_upgrades.erase(selected_tech_upgrade)
	selected_tech_upgrade = null
	for bg in beam_gates:
		bg.key_sectors.erase(selected_bg_key_sector)
	selected_bg_key_sector = Vector2i(-1,-1)
	for bomb in stoudson_bombs:
		bomb.key_sectors.erase(selected_bomb_key_sector)
	selected_bomb_key_sector = Vector2i(-1,-1)
	EventSystem.map_updated.emit()
	EventSystem.item_updated.emit()

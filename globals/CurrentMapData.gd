extends Node

var game_data_type:String:
	set(value):
		game_data_type = value
		EventSystem.game_type_changed.emit()
		EventSystem.map_updated.emit()

var level_set := 1
var movie := ""
var event_loop := 0
var sky := "1998_01"
var music := 0
var min_break := 0
var max_break := 0
var briefing_map: String
var debriefing_map: String
var player_host_station := 0
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
var selected_beam_gate: BeamGate = null
var selected_bomb: StoudsonBomb = null
var selected_tech_upgrade: TechUpgrade = null
var selected_bg_key_sector: Vector2i = Vector2i(-1, -1)
var selected_bomb_key_sector: Vector2i = Vector2i(-1, -1)

var units_db := {}
var blg_names := {}
var weapons_db := {}


func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	reload()
	EventSystem.game_type_changed.connect(reload)


func reload() -> void:
	briefing_map = Preloads.ua_data.data[game_data_type].missionBriefingMaps[0]
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

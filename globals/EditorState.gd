extends Node

enum States {
	Select,
	TypMapDesign
}

var game_data_type:String:
	set(value):
		game_data_type = value
		EventSystem.game_type_changed.emit()
		EventSystem.map_updated.emit()


var mode: States = States.Select:
	set(value):
		mode = value
		EventSystem.editor_mode_changed.emit()

var selected_typ_map: int

var typ_map_images_visible := true:
	set(value):
		typ_map_images_visible = value
		EventSystem.map_view_updated.emit()
var typ_map_values_visible := false:
	set(value):
		typ_map_values_visible = value
		EventSystem.map_view_updated.emit()
var own_map_values_visible := false:
	set(value):
		own_map_values_visible = value
		EventSystem.map_view_updated.emit()
var hgt_map_values_visible := false:
	set(value):
		hgt_map_values_visible = value
		EventSystem.map_view_updated.emit()
var blg_map_values_visible := false:
	set(value):
		blg_map_values_visible = value
		EventSystem.map_view_updated.emit()

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

var sector_clipboard := {
	typ_map = -1,
	own_map = -1,
	blg_map = -1,
	beam_gate = null,
	stoudson_bomb = null,
	tech_upgrade = null,
	bg_key_sector_parent = null,
	bomb_key_sector_parent = null
}

var units_db := {}
var blg_names := {}
var weapons_db := {}

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	reload()
	EventSystem.game_type_changed.connect(reload)


func reload() -> void:
	if (not CurrentMapData.briefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps and
		not CurrentMapData.briefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps):
		CurrentMapData.briefing_map = Preloads.ua_data.data[game_data_type].missionBriefingMaps[0]
	if (not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps and 
		not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps):
		CurrentMapData.debriefing_map = Preloads.ua_data.data[game_data_type].missionDebriefingMaps[0]
	
	units_db.clear()
	blg_names.clear()
	weapons_db.clear()
	
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
		for robo: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].robos:
			if CurrentMapData.host_stations:
				for hss: HostStation in CurrentMapData.host_stations.get_children():
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


func unselect_all() -> void:
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

extends Node

var game_data_type:String

var level_set := 1
var host_stations: Control
var squads: Control
var horizontal_sectors := 0
var vertical_sectors := 0
var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []
var error_map: Array[bool] = []
var beam_gates: Array[BeamGate] = []
var stoudson_bombs: Array[StoudsonBomb] = []
var tech_upgrades: Array[TechUpgrade] = []


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
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
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

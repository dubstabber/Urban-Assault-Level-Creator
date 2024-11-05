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


func get_beam_gate(x: int, y: int) -> BeamGate:
	for beam_gate in beam_gates:
		if beam_gate.sec_x == x and beam_gate.sec_y == y:
			return beam_gate
	return null


func is_sector_valid(sector_index) -> bool:
	match level_set:
		1:
			if typ_map[sector_index] > 53 and typ_map[sector_index] < 59:
				return false
			if typ_map[sector_index] > 59 and typ_map[sector_index] < 66:
				return false
			if typ_map[sector_index] > 82 and typ_map[sector_index] < 95:
				return false
			if typ_map[sector_index] > 104 and typ_map[sector_index] < 110:
				return false
			if typ_map[sector_index] > 113 and typ_map[sector_index] < 120:
				return false
			if typ_map[sector_index] > 121 and typ_map[sector_index] < 130:
				return false
			if typ_map[sector_index] > 141 and typ_map[sector_index] < 150:
				return false
			if typ_map[sector_index] > 189 and typ_map[sector_index] < 198:
				return false
			if typ_map[sector_index] > 205 and typ_map[sector_index] < 207:
				return false
			if typ_map[sector_index] > 208 and typ_map[sector_index] < 228:
				return false
			if typ_map[sector_index] > 236 and typ_map[sector_index] < 239:
				return false
		
		
	return true

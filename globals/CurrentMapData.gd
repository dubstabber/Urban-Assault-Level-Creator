extends Node

signal selected

var game_data_type:String

var horizontal_sectors := 0
var vertical_sectors := 0
var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []
var beam_gates: Array[BeamGate] = []
var stoudson_bombs: Array[StoudsonBomb] = []
var tech_upgrades: Array[TechUpgrade] = []


var selected_unit:
	set(value):
		selected_unit = value
		selected.emit()
var selected_sector_idx: int = -1
var border_selected_sector_idx: int = -1:
	set(value):
		border_selected_sector_idx = value
		selected.emit()
var selected_sector_x: int = -1
var selected_sector_y: int = -1

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	

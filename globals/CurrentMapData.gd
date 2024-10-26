extends Node

signal selected
signal right_selected

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
var selected_sector: Vector2i = Vector2i(-1, -1)
var selected_beam_gate: BeamGate = null
var selected_bomb: StoudsonBomb = null
var selected_tech_upgrade: TechUpgrade = null
var selected_bg_key_sector: Vector2i = Vector2i(-1, -1)
var selected_bomb_key_sector: Vector2i = Vector2i(-1, -1)

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	

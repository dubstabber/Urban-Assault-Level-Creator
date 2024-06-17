extends Node

signal selected

var game_data_type:String

var horizontal_sectors := 0
var vertical_sectors := 0
var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []


var selected_unit:
	set(value):
		selected_unit = value
		selected.emit()
var selected_sector: int = -1
var border_selected_sector: int = -1:
	set(value):
		border_selected_sector = value
		selected.emit()

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	

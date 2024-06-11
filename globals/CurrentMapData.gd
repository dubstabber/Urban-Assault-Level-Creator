extends Node

var hs_images := {}
var game_data_type:String
var horizontal_sectors := 0
var vertical_sectors := 0

var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
		hs_images[str(Preloads.ua_data.data[game_data_type].hoststations[hs].owner)] = load("res://resources/img/"+ Preloads.ua_data.data[game_data_type].hoststations[hs].icon)


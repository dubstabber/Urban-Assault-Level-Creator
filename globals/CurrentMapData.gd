extends Node

var hs_images := {}
var game_data_type:String
var horizontal_sectors: int = 0
var vertical_sectors: int = 0



func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
		hs_images[str(Preloads.ua_data.data[game_data_type].hoststations[hs].owner)] = load("res://resources/img/"+ Preloads.ua_data.data[game_data_type].hoststations[hs].icon)


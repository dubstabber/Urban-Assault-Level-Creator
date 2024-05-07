extends Node

var game_data_type:String
var horizontal_sectors: int = 0
var vertical_sectors: int = 0


func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]


extends Node

var hs_images := {}
var squad_images := {}
var game_data_type:String

var horizontal_sectors := 0
var vertical_sectors := 0
var typ_map: Array[int] = []
var own_map: Array[int] = []
var hgt_map: Array[int] = []
var blg_map: Array[int] = []


var selected_unit
var selected_sector: int = -1
var border_selected_sector: int = -1

func _ready():
	game_data_type = Preloads.ua_data.data.keys()[0]
	for hs in Preloads.ua_data.data[game_data_type].hoststations:
		hs_images[str(Preloads.ua_data.data[game_data_type].hoststations[hs].owner)] = load("res://resources/img/"+ Preloads.ua_data.data[game_data_type].hoststations[hs].icon)
	squad_images.square = {
		"blue": load("res://resources/img/BlueUnit1.png"),
		"red": load("res://resources/img/RedUnit1.png"),
		"yellow": load("res://resources/img/YellowUnit1.png"),
		"white": load("res://resources/img/WhiteUnit1.png"),
		"green": load("res://resources/img/GreenUnit1.png"),
		"gray": load("res://resources/img/GrayUnit1.png"),
		"red2": load("res://resources/img/Training.png"),
	}
	squad_images.circle = {
		"blue": load("res://resources/img/BlueUnit2.png"),
		"red": load("res://resources/img/RedUnit2.png"),
		"yellow": load("res://resources/img/YellowUnit2.png"),
		"white": load("res://resources/img/WhiteUnit2.png"),
		"green": load("res://resources/img/GreenUnit2.png"),
		"gray": load("res://resources/img/GrayUnit2.png"),
	}
	squad_images.left_triangle = {
		"blue": load("res://resources/img/BlueUnit3.png"),
		"red": load("res://resources/img/RedUnit3.png"),
		"yellow": load("res://resources/img/YellowUnit3.png"),
		"white": load("res://resources/img/WhiteUnit3.png"),
		"green": load("res://resources/img/GreenUnit3.png"),
		"gray": load("res://resources/img/GrayUnit3.png"),
	}
	squad_images.down_triangle = {
		"blue": load("res://resources/img/BlueUnit4.png"),
		"red": load("res://resources/img/RedUnit4.png"),
		"yellow": load("res://resources/img/YellowUnit4.png"),
		"white": load("res://resources/img/WhiteUnit4.png"),
		"green": load("res://resources/img/GreenUnit4.png"),
		"gray": load("res://resources/img/GrayUnit4.png"),
	}

extends Node

var ua_data: JSON = preload("res://UAdata.json")

const HOSTSTATION = preload("res://scenes/host_station.tscn")
const SQUAD = preload("res://scenes/squad.tscn")

var hs_images := {}
var squad_images := {}

func _ready():
	for hs in ua_data.data[CurrentMapData.game_data_type].hoststations:
		hs_images[str(ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)] = load("res://resources/img/"+ ua_data.data[CurrentMapData.game_data_type].hoststations[hs].icon)
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


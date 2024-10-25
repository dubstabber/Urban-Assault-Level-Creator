extends Node

var ua_data: JSON = preload("res://resources/UAdata.json")

const HOSTSTATION = preload("res://scenes/host_station.tscn")
const SQUAD = preload("res://scenes/squad.tscn")

var hs_images := {}
var hs_robo_images := {}
var squad_images := {}
var squad_icons := {}
var building_icons := {}
var special_building_images := {}
var sector_item_images := {}


func _ready():
	for hs in ua_data.data[CurrentMapData.game_data_type].hoststations:
		hs_images[str(ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)] = load("res://resources/img/hostStationImages/"+ ua_data.data[CurrentMapData.game_data_type].hoststations[hs].image_file)
		for robo in ua_data.data[CurrentMapData.game_data_type].hoststations[hs].robos:
			hs_robo_images[int(robo.id)] = {
				"name": robo.name,
				"image": load("res://resources/img/hostStationRoboImages/"+robo.image_file)
			}
		for squad in ua_data.data[CurrentMapData.game_data_type].hoststations[hs].units:
			squad_images[str(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
		for building in ua_data.data[CurrentMapData.game_data_type].hoststations[hs].buildings:
			special_building_images[str(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)
	
	for squad in ua_data.data[CurrentMapData.game_data_type].other.units:
		squad_images[str(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
	for building in ua_data.data[CurrentMapData.game_data_type].other.buildings:
		special_building_images[str(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)
	
	
	squad_icons.square = {
		"blue": load("res://resources/img/squadIcons/BlueUnit1.png"),
		"red": load("res://resources/img/squadIcons/RedUnit1.png"),
		"yellow": load("res://resources/img/squadIcons/YellowUnit1.png"),
		"white": load("res://resources/img/squadIcons/WhiteUnit1.png"),
		"green": load("res://resources/img/squadIcons/GreenUnit1.png"),
		"gray": load("res://resources/img/squadIcons/GrayUnit1.png"),
		"red2": load("res://resources/img/squadIcons/TrainingUnit.png"),
	}
	squad_icons.circle = {
		"blue": load("res://resources/img/squadIcons/BlueUnit2.png"),
		"red": load("res://resources/img/squadIcons/RedUnit2.png"),
		"yellow": load("res://resources/img/squadIcons/YellowUnit2.png"),
		"white": load("res://resources/img/squadIcons/WhiteUnit2.png"),
		"green": load("res://resources/img/squadIcons/GreenUnit2.png"),
		"gray": load("res://resources/img/squadIcons/GrayUnit2.png"),
	}
	squad_icons.left_triangle = {
		"blue": load("res://resources/img/squadIcons/BlueUnit3.png"),
		"red": load("res://resources/img/squadIcons/RedUnit3.png"),
		"yellow": load("res://resources/img/squadIcons/YellowUnit3.png"),
		"white": load("res://resources/img/squadIcons/WhiteUnit3.png"),
		"green": load("res://resources/img/squadIcons/GreenUnit3.png"),
		"gray": load("res://resources/img/squadIcons/GrayUnit3.png"),
	}
	squad_icons.down_triangle = {
		"blue": load("res://resources/img/squadIcons/BlueUnit4.png"),
		"red": load("res://resources/img/squadIcons/RedUnit4.png"),
		"yellow": load("res://resources/img/squadIcons/YellowUnit4.png"),
		"white": load("res://resources/img/squadIcons/WhiteUnit4.png"),
		"green": load("res://resources/img/squadIcons/GreenUnit4.png"),
		"gray": load("res://resources/img/squadIcons/GrayUnit4.png"),
	}
	building_icons.power_station = load("res://resources/img/buildingIcons/powerStation.png")
	building_icons.flak_station = load("res://resources/img/buildingIcons/flakStation.png")
	building_icons.radar_station = load("res://resources/img/buildingIcons/radarStation.png")
	
	sector_item_images.beam_gate = load("res://resources/img/sectorItems/beamgate.png")
	sector_item_images.stoudson_bomb = load("res://resources/img/sectorItems/mainbomb.png")
	sector_item_images.tech_upgrades = {
		"60" = load("res://resources/img/sectorItems/techupgradesphinx.png"),
		"61" = load("res://resources/img/sectorItems/techupgrademoreroboflak.png"),
		"4" = load("res://resources/img/sectorItems/techupgradenewvehiclesmall.png"),
		"7" = load("res://resources/img/sectorItems/techupgradenewvehicleheavy.png"),
		"15" = load("res://resources/img/sectorItems/techupgrademoreweaponvehicle.png"),
		"51" = load("res://resources/img/sectorItems/techupgrademorepowerweapon.png"),
		"50" = load("res://resources/img/sectorItems/techupgrademoreshieldvehicle.png"),
		"16" = load("res://resources/img/sectorItems/techupgradenewbuilding.png"),
		"65" = load("res://resources/img/sectorItems/techupgradenewvehicletower.png"),
	}
	
	sector_item_images.beam_gate_key_sector = load("res://resources/img/sectorItems/keysector.png")
	sector_item_images.bomb_key_sector = load("res://resources/img/sectorItems/sectorbomb.png")

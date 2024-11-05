extends Node

var ua_data: JSON = preload("res://resources/UAdata.json")

const HOSTSTATION = preload("res://scenes/host_station.tscn")
const SQUAD = preload("res://scenes/squad.tscn")

var hs_images := {}
var hs_robo_images := {}
var squad_images := {}
var squad_icons := {}
var building_icons := {}
var building_side_images := {}
var building_top_images := {}
var special_building_images := {}
var sector_item_images := {}
var error_sign: CompressedTexture2D


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
	sector_item_images.tech_upgrades = {}
	sector_item_images.tech_upgrades[60] = load("res://resources/img/sectorItems/techupgradesphinx.png")
	sector_item_images.tech_upgrades[61] = load("res://resources/img/sectorItems/techupgrademoreroboflak.png")
	sector_item_images.tech_upgrades[4] = load("res://resources/img/sectorItems/techupgradenewvehiclesmall.png")
	sector_item_images.tech_upgrades[7] = load("res://resources/img/sectorItems/techupgradenewvehicleheavy.png")
	sector_item_images.tech_upgrades[15] = load("res://resources/img/sectorItems/techupgrademoreweaponvehicle.png")
	sector_item_images.tech_upgrades[51] = load("res://resources/img/sectorItems/techupgrademorepowerweapon.png")
	sector_item_images.tech_upgrades[50] = load("res://resources/img/sectorItems/techupgrademoreshieldvehicle.png")
	sector_item_images.tech_upgrades[16] = load("res://resources/img/sectorItems/techupgradenewbuilding.png")
	sector_item_images.tech_upgrades[65] = load("res://resources/img/sectorItems/techupgradenewvehicletower.png")
	
	
	sector_item_images.beam_gate_key_sector = load("res://resources/img/sectorItems/keysector.png")
	sector_item_images.bomb_key_sector = load("res://resources/img/sectorItems/sectorbomb.png")
	
	building_side_images[1] = {}
	building_top_images[1] = {}
	building_side_images[2] = {}
	building_top_images[2] = {}
	building_side_images[3] = {}
	building_top_images[3] = {}
	building_side_images[4] = {}
	building_top_images[4] = {}
	building_side_images[5] = {}
	building_top_images[5] = {}
	building_side_images[6] = {}
	building_top_images[6] = {}
	
	var idx := 0
	while(idx < 256):
		if idx == 54: idx = 59
		if idx == 60: idx = 66
		if idx == 83: idx = 95
		if idx == 105: idx = 110
		if idx == 114: idx = 120
		if idx == 122: idx = 130
		if idx == 142: idx = 150
		if idx == 190: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 228
		if idx == 237: idx = 239
		building_side_images[1][idx] = load("res://resources/img/Sector_images/set1-side/Set1_sector%s.jpg" % idx)
		building_top_images[1][idx] = load("res://resources/img/Sector_images/set1-above/Set1_sector_%s.jpg" % idx)
		idx += 1
		
	
	idx = 0
	while(idx < 256):
		if idx == 25: idx = 27
		if idx == 105: idx = 110
		if idx == 114: idx = 118
		if idx == 132: idx = 133
		if idx == 134: idx = 150
		if idx == 196: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 210
		if idx == 226: idx = 228
		if idx == 231: idx = 239
		building_side_images[2][idx] = load("res://resources/img/Sector_images/set2-side/Set2_sector%s.jpg" % idx)
		building_top_images[2][idx] = load("res://resources/img/Sector_images/set2-above/Set2_sector_%s.jpg" % idx)
		idx += 1
	
	idx = 0
	while(idx < 256):
		if idx == 50: idx = 59
		if idx == 60: idx = 66
		if idx == 83: idx = 100
		if idx == 105: idx = 110
		if idx == 114: idx = 121
		if idx == 122: idx = 130
		if idx == 142: idx = 150
		if idx == 190: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 228
		if idx == 231: idx = 239
		building_side_images[3][idx] = load("res://resources/img/Sector_images/set3-side/Set3_sector%s.jpg" % idx)
		building_top_images[3][idx] = load("res://resources/img/Sector_images/set3-above/Set3_sector_%s.jpg" % idx)
		idx += 1
		
	idx = 0
	while(idx < 256):
		if idx == 50: idx = 59
		if idx == 61: idx = 66
		if idx == 83: idx = 100
		if idx == 105: idx = 110
		if idx == 114: idx = 121
		if idx == 122: idx = 130
		if idx == 142: idx = 150
		if idx == 190: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 228
		if idx == 231: idx = 239
		building_side_images[4][idx] = load("res://resources/img/Sector_images/set4-side/Set4_sector%s.jpg" % idx)
		building_top_images[4][idx] = load("res://resources/img/Sector_images/set4-above/Set4_sector_%s.jpg" % idx)
		idx += 1
		
	idx = 0
	while(idx < 256):
		if idx == 96: idx = 97
		if idx == 117: idx = 118
		if idx == 132: idx = 133
		if idx == 138: idx = 150
		if idx == 192: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 210
		if idx == 226: idx = 228
		if idx == 231: idx = 239
		building_side_images[5][idx] = load("res://resources/img/Sector_images/set5-side/Set5_sector%s.jpg" % idx)
		building_top_images[5][idx] = load("res://resources/img/Sector_images/set5-above/Set5_sector_%s.jpg" % idx)
		idx += 1
		
	idx = 0
	while(idx < 256):
		if idx == 50: idx = 59
		if idx == 60: idx = 66
		if idx == 83: idx = 95
		if idx == 105: idx = 110
		if idx == 114: idx = 121
		if idx == 122: idx = 130
		if idx == 142: idx = 150
		if idx == 190: idx = 198
		if idx == 206: idx = 207
		if idx == 209: idx = 228
		if idx == 236: idx = 239
		building_side_images[6][idx] = load("res://resources/img/Sector_images/set6-side/Set6_sector%s.jpg" % idx)
		building_top_images[6][idx] = load("res://resources/img/Sector_images/set6-above/Set6_sector_%s.jpg" % idx)
		idx += 1
		
	error_sign = load("res://resources/img/blgMapImages/error.png")

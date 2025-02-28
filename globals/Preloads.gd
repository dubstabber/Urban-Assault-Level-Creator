extends Node

var ua_data: JSON = preload("res://resources/UAdata.json")

const HOSTSTATION = preload("res://map/ua_structures/host_station.tscn")
const SQUAD = preload("res://map/ua_structures/squad.tscn")

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
var error_icon: CompressedTexture2D
var movies_db := {}
var skies := {}
var musics := {}
var mbmaps := {}
var font = preload("res://resources/Xolonium-Regular.ttf")


func _ready():
	if not ua_data.data or typeof(ua_data.data) != TYPE_DICTIONARY or not ua_data.data.has("original"):
		EventSystem.editor_fatal_error_occured.emit.call_deferred("invalid_json")
		return
	reload_units_and_buildings()
	
	squad_icons.square = {
		"blue": load("res://resources/img/squadIcons/BlueUnit1.png"),
		"red": load("res://resources/img/squadIcons/RedUnit1.png"),
		"yellow": load("res://resources/img/squadIcons/YellowUnit1.png"),
		"white": load("res://resources/img/squadIcons/WhiteUnit1.png"),
		"green": load("res://resources/img/squadIcons/GreenUnit1.png"),
		"gray": load("res://resources/img/squadIcons/GrayUnit1.png"),
		"red2": load("res://resources/img/squadIcons/TrainingUnit.png"),
		"unknown": load("res://resources/img/squadIcons/UnknownUnit.png")
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
	sector_item_images.tech_upgrades["unknown"] = load("res://resources/img/sectorItems/techupgradeunknown.png")
	
	
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
	error_icon = load("res://resources/img/ui_icons/error-icon.png")
	
	movies_db["none"] = ""
	movies_db["Intro"] = "intro.mpg"
	movies_db["Tutorial 1"] = "tut1.mpg"
	movies_db["Tutorial 2"] = "tut2.mpg"
	movies_db["Tutorial 3"] = "tut3.mpg"
	movies_db["Ghorkov"] = "kyt.mpg"
	movies_db["Taerkasten"] = "taer.mpg"
	movies_db["Mykonian"] = "myk.mpg"
	movies_db["Sulgogar"] = "sulg.mpg"
	movies_db["Black sect"] = "black.mpg"
	movies_db["Lose"] = "lose.mpg"
	movies_db["Win"] = "win.mpg"
	
	skies["1998_01"] = load("res://resources/img/sky-images/1998_01.jpg")
	skies["1998_02"] = load("res://resources/img/sky-images/1998_02.jpg")
	skies["1998_03"] = load("res://resources/img/sky-images/1998_03.jpg")
	skies["1998_05"] = load("res://resources/img/sky-images/1998_05.jpg")
	skies["1998_06"] = load("res://resources/img/sky-images/1998_06.jpg")
	skies["Am_1"] = load("res://resources/img/sky-images/Am_1.jpg")
	skies["Am_2"] = load("res://resources/img/sky-images/Am_2.jpg")
	skies["Am_3"] = load("res://resources/img/sky-images/Am_3.jpg")
	skies["ARZ1"] = load("res://resources/img/sky-images/ARZ1.jpg")
	skies["ASKY2"] = load("res://resources/img/sky-images/ASKY2.jpg")
	skies["BRAUN1"] = load("res://resources/img/sky-images/BRAUN1.jpg")
	skies["CT6"] = load("res://resources/img/sky-images/CT6.jpg")
	skies["H7"] = load("res://resources/img/sky-images/H7.jpg")
	skies["H"] = load("res://resources/img/sky-images/H.jpg")
	skies["HAAMITT1"] = load("res://resources/img/sky-images/HAAMITT1.jpg")
	skies["HAAMITT4"] = load("res://resources/img/sky-images/HAAMITT4.jpg")
	skies["MOD2"] = load("res://resources/img/sky-images/MOD2.jpg")
	skies["MOD4"] = load("res://resources/img/sky-images/MOD4.jpg")
	skies["MOD5"] = load("res://resources/img/sky-images/MOD5.jpg")
	skies["MOD7"] = load("res://resources/img/sky-images/MOD7.jpg")
	skies["MOD8"] = load("res://resources/img/sky-images/MOD8.jpg")
	skies["MOD9"] = load("res://resources/img/sky-images/MOD9.jpg")
	skies["MODA"] = load("res://resources/img/sky-images/MODA.jpg")
	skies["MODB"] = load("res://resources/img/sky-images/MODB.jpg")
	skies["Nacht1"] = load("res://resources/img/sky-images/Nacht1.jpg")
	skies["NACHT2"] = load("res://resources/img/sky-images/NACHT2.jpg")
	skies["NEWTRY5"] = load("res://resources/img/sky-images/NEWTRY5.jpg")
	skies["NOSKY"] = load("res://resources/img/sky-images/NOSKY.jpg")
	skies["NT1"] = load("res://resources/img/sky-images/NT1.jpg")
	skies["NT2"] = load("res://resources/img/sky-images/NT2.jpg")
	skies["NT3"] = load("res://resources/img/sky-images/NT3.jpg")
	skies["NT5"] = load("res://resources/img/sky-images/NT5.jpg")
	skies["NT6"] = load("res://resources/img/sky-images/NT6.jpg")
	skies["NT7"] = load("res://resources/img/sky-images/NT7.jpg")
	skies["NT8"] = load("res://resources/img/sky-images/NT8.jpg")
	skies["NT9"] = load("res://resources/img/sky-images/NT9.jpg")
	skies["NTA"] = load("res://resources/img/sky-images/NTA.jpg")
	skies["S3_1"] = load("res://resources/img/sky-images/S3_1.jpg")
	skies["S3_4"] = load("res://resources/img/sky-images/S3_4.jpg")
	skies["SMOD1"] = load("res://resources/img/sky-images/SMOD1.jpg")
	skies["SMOD2"] = load("res://resources/img/sky-images/SMOD2.jpg")
	skies["SMOD3"] = load("res://resources/img/sky-images/SMOD3.jpg")
	skies["SMOD4"] = load("res://resources/img/sky-images/SMOD4.jpg")
	skies["SMOD5"] = load("res://resources/img/sky-images/SMOD5.jpg")
	skies["SMOD6"] = load("res://resources/img/sky-images/SMOD6.jpg")
	skies["SMOD7"] = load("res://resources/img/sky-images/SMOD7.jpg")
	skies["SMOD8"] = load("res://resources/img/sky-images/SMOD8.jpg")
	skies["STERNE"] = load("res://resources/img/sky-images/STERNE.jpg")
	skies["wow1"] = load("res://resources/img/sky-images/wow1.jpg")
	skies["wow5"] = load("res://resources/img/sky-images/wow5.jpg")
	skies["wow7"] = load("res://resources/img/sky-images/wow7.jpg")
	skies["wow8"] = load("res://resources/img/sky-images/wow8.jpg")
	skies["wow9"] = load("res://resources/img/sky-images/wow9.jpg")
	skies["wowa"] = load("res://resources/img/sky-images/wowa.jpg")
	skies["wowb"] = load("res://resources/img/sky-images/wowb.jpg")
	skies["wowc"] = load("res://resources/img/sky-images/wowc.jpg")
	skies["wowd"] = load("res://resources/img/sky-images/wowd.jpg")
	skies["wowe"] = load("res://resources/img/sky-images/wowe.jpg")
	skies["wowf"] = load("res://resources/img/sky-images/wowf.jpg")
	skies["wowh"] = load("res://resources/img/sky-images/wowh.jpg")
	skies["wowi"] = load("res://resources/img/sky-images/wowi.jpg")
	skies["wowj"] = load("res://resources/img/sky-images/wowj.jpg")
	skies["x1"] = load("res://resources/img/sky-images/x1.jpg")
	skies["x2"] = load("res://resources/img/sky-images/x2.jpg")
	skies["x4"] = load("res://resources/img/sky-images/x4.jpg")
	skies["x5"] = load("res://resources/img/sky-images/x5.jpg")
	skies["x7"] = load("res://resources/img/sky-images/x7.jpg")
	skies["x8"] = load("res://resources/img/sky-images/x8.jpg")
	skies["x9"] = load("res://resources/img/sky-images/x9.jpg")
	skies["xa"] = load("res://resources/img/sky-images/xa.jpg")
	skies["xb"] = load("res://resources/img/sky-images/xb.jpg")
	skies["xc"] = load("res://resources/img/sky-images/xc.jpg")
	
	musics[2] = load("res://resources/audio/track-2.mp3")
	musics[3] = load("res://resources/audio/track-3.mp3")
	musics[4] = load("res://resources/audio/track-4.mp3")
	musics[5] = load("res://resources/audio/track-5.mp3")
	musics[6] = load("res://resources/audio/track-6.mp3")
	
	reload_mb_db_maps()
	EventSystem.game_type_changed.connect(reload_units_and_buildings)
	EventSystem.game_type_changed.connect(reload_mb_db_maps)


func reload_units_and_buildings() -> void:
	if EditorState.game_data_type.is_empty():
		return
	squad_images.clear()
	special_building_images.clear()
	
	if not ua_data.data[EditorState.game_data_type].has("hoststations"):
		EventSystem.editor_fatal_error_occured.emit.call_deferred("no_hoststations")
		return
	for hs in ua_data.data[EditorState.game_data_type].hoststations:
		hs_images[str(ua_data.data[EditorState.game_data_type].hoststations[hs].owner)] = load("res://resources/img/hostStationImages/"+ ua_data.data[EditorState.game_data_type].hoststations[hs].image_file)
		for robo in ua_data.data[EditorState.game_data_type].hoststations[hs].robos:
			hs_robo_images[int(robo.id)] = {
				"name": robo.name,
				"image": load("res://resources/img/hostStationRoboImages/"+robo.image_file)
			}
		for squad in ua_data.data[EditorState.game_data_type].hoststations[hs].units:
			squad_images[str(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
		for building in ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			special_building_images[str(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)
	
	for squad in ua_data.data[EditorState.game_data_type].other.units:
		squad_images[str(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
	for building in ua_data.data[EditorState.game_data_type].other.buildings:
		special_building_images[str(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)


func reload_mb_db_maps() -> void:
	var map_name := ""
	mbmaps.clear()
	for file_name in DirAccess.get_files_at("res://resources/img/mbgfx/%s/" % EditorState.game_data_type):
		if (file_name.get_extension() == "import"):
			file_name = file_name.replace(".import", "")
			map_name = file_name.replace(".png", "")
			if map_name.begins_with("mb"):
				mbmaps[map_name] = load("res://resources/img/mbgfx/%s/%s" % [EditorState.game_data_type, file_name])
			elif map_name.begins_with("db"):
				mbmaps[map_name] = load("res://resources/img/mbgfx/%s/%s" % [EditorState.game_data_type, file_name])

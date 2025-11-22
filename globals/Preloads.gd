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
var skies := {} # Lazy loaded on first access
var musics := {} # Lazy loaded on first access
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
	
	# Initialize building image dictionaries
	for set_id in range(1, 7):
		building_side_images[set_id] = {}
		building_top_images[set_id] = {}
	
	# Define skip indices for each level set
	var skip_indices := {
		1: [54, 60, 83, 105, 114, 122, 142, 190, 206, 209, 237],
		2: [25, 105, 114, 132, 134, 196, 206, 209, 226, 231],
		3: [50, 60, 83, 105, 114, 122, 142, 190, 206, 209, 231],
		4: [50, 61, 83, 105, 114, 122, 142, 190, 206, 209, 231],
		5: [96, 117, 132, 138, 192, 206, 209, 226, 231],
		6: [50, 60, 83, 105, 114, 122, 142, 190, 206, 209, 236]
	}
	
	# Define end indices for skip ranges
	var skip_ends := {
		1: [59, 66, 95, 110, 120, 130, 150, 198, 207, 228, 239],
		2: [27, 110, 118, 133, 150, 198, 207, 210, 228, 239],
		3: [59, 66, 100, 110, 121, 130, 150, 198, 207, 228, 239],
		4: [59, 66, 100, 110, 121, 130, 150, 198, 207, 228, 239],
		5: [97, 118, 133, 150, 198, 207, 210, 228, 239],
		6: [59, 66, 95, 110, 121, 130, 150, 198, 207, 228, 239]
	}
	
	# Load building images for all sets
	for set_id in range(1, 7):
		_load_building_images_for_set(set_id, skip_indices[set_id], skip_ends[set_id])
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
	
	var sky_names := ["1998_01", "1998_02", "1998_03", "1998_05", "1998_06",
		"Am_1", "Am_2", "Am_3", "ARZ1", "ASKY2", "BRAUN1", "CT6", "H7", "H",
		"HAAMITT1", "HAAMITT4", "MOD2", "MOD4", "MOD5", "MOD7", "MOD8", "MOD9",
		"MODA", "MODB", "Nacht1", "NACHT2", "NEWTRY5", "NOSKY", "NT1", "NT2",
		"NT3", "NT5", "NT6", "NT7", "NT8", "NT9", "NTA", "S3_1", "S3_4",
		"SMOD1", "SMOD2", "SMOD3", "SMOD4", "SMOD5", "SMOD6", "SMOD7", "SMOD8",
		"STERNE", "wow1", "wow5", "wow7", "wow8", "wow9", "wowa", "wowb",
		"wowc", "wowd", "wowe", "wowf", "wowh", "wowi", "wowj", "x1", "x2",
		"x4", "x5", "x7", "x8", "x9", "xa", "xb", "xc"]
	
	for sky_name in sky_names:
		skies[sky_name] = load("res://resources/img/sky-images/%s.jpg" % sky_name)
	
	for track_id in [2, 3, 4, 5, 6]:
		musics[track_id] = load("res://resources/audio/track-%s.mp3" % track_id)
	
	reload_mb_db_maps()
	EventSystem.game_type_changed.connect(reload_units_and_buildings)
	EventSystem.game_type_changed.connect(reload_mb_db_maps)


func _load_building_images_for_set(set_id: int, skip_starts: Array, skip_ends: Array) -> void:
	"""Load building images for a specific level set, skipping invalid indices."""
	var idx := 0
	var skip_idx := 0
	
	while idx < 256:
		# Check if we need to skip to next valid range
		if skip_idx < skip_starts.size() and idx == skip_starts[skip_idx]:
			idx = skip_ends[skip_idx]
			skip_idx += 1
			continue
		
		# Load the images for this index
		building_side_images[set_id][idx] = load("res://resources/img/Sector_images/set%s-side/Set%s_sector%s.jpg" % [set_id, set_id, idx])
		building_top_images[set_id][idx] = load("res://resources/img/Sector_images/set%s-above/Set%s_sector_%s.jpg" % [set_id, set_id, idx])
		idx += 1


func reload_units_and_buildings() -> void:
	if EditorState.game_data_type.is_empty():
		return
	squad_images.clear()
	special_building_images.clear()
	
	if not ua_data.data[EditorState.game_data_type].has("hoststations"):
		EventSystem.editor_fatal_error_occured.emit.call_deferred("no_hoststations")
		return
	for hs in ua_data.data[EditorState.game_data_type].hoststations:
		hs_images[int(ua_data.data[EditorState.game_data_type].hoststations[hs].owner)] = load("res://resources/img/hostStationImages/" + ua_data.data[EditorState.game_data_type].hoststations[hs].image_file)
		for robo in ua_data.data[EditorState.game_data_type].hoststations[hs].robos:
			hs_robo_images[int(robo.id)] = {
				"name": robo.name,
				"image": load("res://resources/img/hostStationRoboImages/" + robo.image_file)
			}
		for squad in ua_data.data[EditorState.game_data_type].hoststations[hs].units:
			squad_images[int(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
		for building in ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			special_building_images[int(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)
	
	for squad in ua_data.data[EditorState.game_data_type].other.units:
		squad_images[int(squad.id)] = load("res://resources/img/squadImages/" + squad.image_file)
	for building in ua_data.data[EditorState.game_data_type].other.buildings:
		special_building_images[int(building.id)] = load("res://resources/img/blgMapImages/" + building.image_file)


func get_sky(sky_name: String) -> Texture2D:
	if not skies.has(sky_name):
		return null
	return skies[sky_name]


func get_music(track_id: int) -> AudioStream:
	if not musics.has(track_id):
		return null
	return musics[track_id]


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

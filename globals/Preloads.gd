extends Node

const _UAProjectDataRoots = preload("res://map/ua_project_data_roots.gd")
const _UALegacyText = preload("res://map/ua_legacy_text.gd")
const _ResDir = preload("res://scripts/res_dir.gd")



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


# UA 3D terrain (edge-based) resources
var surface_type_map := {}
var subsector_patterns := {} # typ_id -> {surface_type, sector_type, subsectors: PackedInt32Array}
var tile_mapping := {} # subsector_index -> {val0, val1, val2, val3, flag}
var lego_defs := {} # raw selected tile id -> {raw_id, base_name, base_file, skeleton_ref}
var ground_textures: Array[Texture2D] = []
var tile_remap := {} # optional: raw tile id -> {file:int, variant:int}
var subsector_idx_remap := {} # optional: sub_idx -> remapped_sub_idx (per UA remap table)
# Note: SetSdfParser is a global class (class_name in set_sdf_parser.gd);
# avoid naming conflicts by not preloading it into a const with the same name.
var _ground_fb_colors := [
	Color(0.35, 0.55, 0.35), # grass
	Color(0.42, 0.30, 0.20), # dirt
	Color(0.55, 0.55, 0.55), # concrete
	Color(0.30, 0.30, 0.35), # rock
	Color(0.20, 0.35, 0.60), # water
	Color(0.70, 0.60, 0.45) # sand
]


# Each pair is [inclusive_start, exclusive_end): same semantics as legacy skip_starts/skip_ends
# (when idx hit skip_starts[i], it jumped to skip_ends[i], which is the first loaded index).
func _is_in_skip_ranges(idx: int, ranges: Array) -> bool:
	for r in ranges:
		if idx >= r[0] and idx < r[1]:
			return true
	return false


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

	# Missing sector image files — half-open ranges [start, end) to skip when loading.
	var skip_ranges := {
		1: [[54,59], [60,66], [83,95], [105,110], [114,120], [122,130], [142,150], [190,198], [206,207], [209,228], [237,239]],
		2: [[25,27], [105,110], [114,118], [132,133], [134,150], [196,198], [206,207], [209,210], [226,228], [231,239]],
		3: [[50,59], [60,66], [83,100], [105,110], [114,121], [122,130], [142,150], [190,198], [206,207], [209,228], [231,239]],
		4: [[50,59], [61,66], [83,100], [105,110], [114,121], [122,130], [142,150], [190,198], [206,207], [209,228], [231,239]],
		5: [[96,97], [117,118], [132,133], [138,150], [192,198], [206,207], [209,210], [226,228], [231,239]],
		6: [[50,59], [60,66], [83,95], [105,110], [114,121], [122,130], [142,150], [190,198], [206,207], [209,228], [236,239]]
	}

	# Load building images for all sets
	for set_id in range(1, 7):
		var ranges = skip_ranges[set_id]
		var idx = 0
		while idx < 256:
			if _is_in_skip_ranges(idx, ranges):
				for r in ranges:
					if idx >= r[0] and idx < r[1]:
						idx = r[1]
						break
				continue
			building_side_images[set_id][idx] = load("res://resources/img/Sector_images/set%d-side/Set%d_sector%s.jpg" % [set_id, set_id, idx])
			building_top_images[set_id][idx] = load("res://resources/img/Sector_images/set%d-above/Set%d_sector_%s.jpg" % [set_id, set_id, idx])
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

	# 3D terrain edge-based resources
	load_ground_textures()
	reload_surface_type_map()
	if EventSystem:
		EventSystem.level_set_changed.connect(reload_surface_type_map)
		EventSystem.level_set_changed.connect(load_ground_textures)

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
	mbmaps.clear()
	for file_name in _ResDir.get_files_at("res://resources/img/mbgfx/%s/" % EditorState.game_data_type):
		if not file_name.get_extension().to_lower() == "png":
			continue
		var map_name := file_name.replace(".png", "")
		if map_name.begins_with("mb") or map_name.begins_with("db"):
			mbmaps[map_name] = load("res://resources/img/mbgfx/%s/%s" % [EditorState.game_data_type, file_name])


# ---- UA 3D terrain helpers ----
func load_ground_textures() -> void:
	# Determine current set (1..6); default to 1 if unavailable
	var set_id := 1
	var cmd = get_node_or_null("/root/CurrentMapData")
	if cmd:
		set_id = int(cmd.level_set)
	ground_textures.resize(6)
	for i in 6:
		# Three-tier fallback: set-specific -> common -> procedural color
		var set_path := "res://resources/terrain/textures/set%d/ground_%d.png" % [set_id, i]
		var common_path := "res://resources/terrain/textures/common/ground_%d.png" % i
		var tex: Texture2D = null
		# Only try loading set-specific if the file exists to avoid benign loader errors
		if _ResDir.file_exists(set_path):
			tex = load(set_path)
			if tex is Texture2D:
				ground_textures[i] = tex
				print("[Preloads] ground_%d <- %s" % [i, set_path])
				continue
		# Try common fallback if present
		if _ResDir.file_exists(common_path):
			tex = load(common_path)
			if tex is Texture2D:
				ground_textures[i] = tex
				print("[Preloads] ground_%d <- %s" % [i, common_path])
				continue
		else:
			_ensure_common_placeholder_png(i)
			if _ResDir.file_exists(common_path):
				tex = load(common_path)
				if tex is Texture2D:
					ground_textures[i] = tex
					print("[Preloads] ground_%d <- %s (placeholder)" % [i, common_path])
					continue
		# Final fallback: procedural color
		ground_textures[i] = _make_color_tex(_ground_fb_colors[i % _ground_fb_colors.size()])
		push_warning("Preloads: no ground texture for index %d (set %d). Using procedural color." % [i, set_id])

func get_ground_texture(surface_type: int) -> Texture2D:
	if ground_textures.is_empty():
		load_ground_textures()
	var idx: int = clampi(surface_type, 0, 5)
	var tex: Texture2D = ground_textures[idx]
	if tex == null:
		tex = _make_color_tex(_ground_fb_colors[idx])
		ground_textures[idx] = tex
	return tex

func reload_surface_type_map() -> void:
	var set_id := 1
	var cmd = get_node_or_null("/root/CurrentMapData")
	if cmd:
		set_id = int(cmd.level_set)

	var game_data_type := "original"
	var es := get_node_or_null("/root/EditorState")
	if es:
		game_data_type = es.game_data_type
	# Load full typ data including subsector patterns and tile mapping
	var full_data := SetSdfParser.parse_full_typ_data(set_id, game_data_type)
	surface_type_map = full_data.get("surface_types", {})
	subsector_patterns = full_data.get("subsector_patterns", {})
	tile_mapping = full_data.get("tile_mapping", {})
	lego_defs = full_data.get("lego_defs", {})

	# Optional per-set remap file (editor overrides first, then bundled set scripts).
	# Format: { "0": {"file": 2, "variant": 0}, "1": {"file": 0, "variant": 1}, ... }
	tile_remap = {}
	var remap_path := "%s/set%d/tile_remap.json" % [_UAProjectDataRoots.EDITOR_OVERRIDES_ROOT, set_id]
	if not _ResDir.file_exists(remap_path):
		remap_path = UAProjectDataRoots.first_existing_path_under_set_roots(
			set_id, game_data_type, "scripts/tile_remap.json"
		)
	if _ResDir.file_exists(remap_path):
		tile_remap = _ResDir.load_json_dict(remap_path)

	subsector_idx_remap = {}
	var subremap_path := "%s/set%d/subsector_idx_remap.json" % [_UAProjectDataRoots.EDITOR_OVERRIDES_ROOT, set_id]
	if not _ResDir.file_exists(subremap_path):
		subremap_path = UAProjectDataRoots.first_existing_path_under_set_roots(
			set_id, game_data_type, "scripts/subsector_idx_remap.json"
		)
	if _ResDir.file_exists(subremap_path):
		subsector_idx_remap = _ResDir.load_json_dict(subremap_path)

	if surface_type_map.is_empty():
		# Leave empty; renderer will default to 0
		push_warning("Preloads: surface_type_map empty for set %d; edges will use texture 0" % set_id)
	else:
		print("[Preloads] surface_type_map loaded for set ", set_id, ", entries=", surface_type_map.size())
		print("[Preloads] subsector_patterns loaded for set ", set_id, ", entries=", subsector_patterns.size())
		print("[Preloads] tile_mapping loaded for set ", set_id, ", entries=", tile_mapping.size())
		print("[Preloads] lego_defs loaded for set ", set_id, ", entries=", lego_defs.size())
		if not tile_remap.is_empty():
			print("[Preloads] tile_remap loaded for set ", set_id, ", entries=", tile_remap.size())
		if not subsector_idx_remap.is_empty():
			print("[Preloads] subsector_idx_remap loaded for set ", set_id, ", entries=", subsector_idx_remap.size())

func _make_color_tex(color: Color) -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _ensure_common_placeholder_png(i: int) -> void:
	var dir := "res://resources/terrain/textures/common"
	var da := DirAccess.open("res://")
	if da:
		da.make_dir_recursive("resources/terrain/textures/common")
	var path := "%s/ground_%d.png" % [dir, i]
	if FileAccess.file_exists(path):
		return
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(_ground_fb_colors[i % _ground_fb_colors.size()])
	var err := img.save_png(path)
	if err != OK:
		push_warning("Preloads: failed to save placeholder %s (err %d)" % [path, err])

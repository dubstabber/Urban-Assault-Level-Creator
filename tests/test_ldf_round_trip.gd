extends RefCounted

# Golden round-trip test for the LDF level format.
#
# Builds a representative map in CurrentMapData, saves it with the real
# SingleplayerSaver, clears state, reloads it with the real SingleplayerOpener,
# and asserts the reconstructed data equals the original. This is the editor's
# core promise: saving a loaded map reproduces it.
#
# It also pins the fire_x/fire_y/fire_z regression: the saver writes those weapon
# offsets for a tech-upgrade modify_vehicle modifier, and the opener must read
# them back. Before the opener fix they reverted to the 30/5/15 defaults; the
# non-default values asserted below fail loudly if that regresses.
#
# Notes / current scope:
# - Runs the opener synchronously by passing a null yield_host (every suspension
#   point in load_level_async is guarded by `yield_host != null`), so this fits
#   the runner's synchronous run() contract.
# - Covers map dumps, level params, per-faction enable lists, and tech upgrades.
#   Host stations, squads, beam gates, and bombs are left as empty containers for
#   now (a future extension); they are the node-backed/auxiliary entities.

const _TMP_PATH := "user://test_ldf_round_trip.ldf"

var _errors: Array[String] = []
var _saved_state: Dictionary = {}
var _tmp_host_stations: Node2D = null
var _tmp_squads: Node2D = null


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


func run() -> int:
	_errors.clear()
	_snapshot_global_state()
	# Wrap the body so global state is always restored, even on assertion failure.
	_run_body()
	_restore_global_state()
	return _errors.size()


func _run_body() -> void:
	_build_fixture()

	# 1. Save the in-memory map to a temp file via the real saver.
	CurrentMapData.map_path = _TMP_PATH
	SingleplayerSaver.save()
	_check(FileAccess.file_exists(_TMP_PATH), "saver did not produce a file at %s" % _TMP_PATH)
	if not FileAccess.file_exists(_TMP_PATH):
		return

	# 2. Clear the state the opener repopulates (the opener appends, it does not
	#    reset), so the reload starts from a clean slate like a real "open".
	_clear_loadable_state()

	# 3. Reload via the real opener. yield_host = null -> fully synchronous.
	var opener := SingleplayerOpener.new()
	opener.load_level_async(null)

	# 4. Assert the reconstructed data matches the fixture.
	_assert_map_dumps()
	_assert_level_params()
	_assert_enable_lists()
	_assert_tech_upgrades()


# --- Fixture -----------------------------------------------------------------

func _build_fixture() -> void:
	# Containers must be valid for the saver/opener (they call get_child_count()).
	_tmp_host_stations = Node2D.new()
	_tmp_squads = Node2D.new()
	CurrentMapData.host_stations = _tmp_host_stations
	CurrentMapData.squads = _tmp_squads

	CurrentMapData.horizontal_sectors = 3
	CurrentMapData.vertical_sectors = 2
	CurrentMapData.typ_map = PackedByteArray([1, 2, 3, 4, 5, 6])
	CurrentMapData.own_map = PackedByteArray([0, 1, 2, 3, 4, 5])
	CurrentMapData.blg_map = PackedByteArray([10, 11, 12, 13, 14, 15])
	# hgt_map is border-indexed: (w+2) * (h+2) = 5 * 4 = 20 cells.
	var hgt := PackedByteArray()
	for i in 20:
		hgt.append(i)
	CurrentMapData.hgt_map = hgt

	CurrentMapData.level_set = 3
	CurrentMapData.event_loop = 5
	CurrentMapData.music = 2
	CurrentMapData.min_break = 3
	CurrentMapData.max_break = 7
	CurrentMapData.movie = "intro"

	# Per-faction enable lists (round-trips the owner_id <-> faction mapping).
	CurrentMapData.resistance_enabled_units = [10, 20, 30]
	CurrentMapData.resistance_enabled_buildings = [5, 6]
	CurrentMapData.ghorkov_enabled_units = [100]
	CurrentMapData.taerkasten_enabled_buildings = [7]

	# Tech upgrade with a modify_vehicle carrying NON-DEFAULT fire_x/y/z (the bug),
	# plus a modify_weapon and a modify_building.
	var tu := TechUpgrade.new(1, 1)
	tu.building_id = 15
	tu.type = 1
	var veh := tu.new_vehicle_modifier(96)
	veh.energy = 500
	veh.shield = 100
	veh.radar = 50
	veh.num_weapons = 2
	veh.fire_x = 42.0
	veh.fire_y = 7.5
	veh.fire_z = -3.0
	veh.res_enabled = true
	veh.ghor_enabled = true
	tu.vehicles.append(veh)
	var wpn := tu.new_weapon_modifier(200)
	wpn.energy = 999
	wpn.shot_time = 10
	wpn.shot_time_user = 20
	tu.weapons.append(wpn)
	var bld := tu.new_building_modifier(50)
	bld.res_enabled = true
	bld.taer_enabled = true
	tu.buildings.append(bld)
	CurrentMapData.tech_upgrades = [tu]


func _clear_loadable_state() -> void:
	CurrentMapData.horizontal_sectors = 0
	CurrentMapData.vertical_sectors = 0
	CurrentMapData.typ_map = PackedByteArray()
	CurrentMapData.own_map = PackedByteArray()
	CurrentMapData.hgt_map = PackedByteArray()
	CurrentMapData.blg_map = PackedByteArray()
	CurrentMapData.tech_upgrades = []
	CurrentMapData.beam_gates = []
	CurrentMapData.stoudson_bombs = []
	# Reset level params to sentinels to prove they are actually re-read.
	CurrentMapData.level_set = 1
	CurrentMapData.event_loop = 0
	CurrentMapData.music = 0
	CurrentMapData.min_break = 0
	CurrentMapData.max_break = 0
	CurrentMapData.movie = ""
	for arr in [
		CurrentMapData.resistance_enabled_units, CurrentMapData.resistance_enabled_buildings,
		CurrentMapData.ghorkov_enabled_units, CurrentMapData.ghorkov_enabled_buildings,
		CurrentMapData.taerkasten_enabled_units, CurrentMapData.taerkasten_enabled_buildings,
		CurrentMapData.mykonian_enabled_units, CurrentMapData.mykonian_enabled_buildings,
		CurrentMapData.sulgogar_enabled_units, CurrentMapData.sulgogar_enabled_buildings,
		CurrentMapData.blacksect_enabled_units, CurrentMapData.blacksect_enabled_buildings,
		CurrentMapData.training_enabled_units, CurrentMapData.training_enabled_buildings,
	]:
		arr.clear()
	CurrentMapData.unknown_enabled_units.clear()
	CurrentMapData.unknown_enabled_buildings.clear()


# --- Assertions --------------------------------------------------------------

func _assert_map_dumps() -> void:
	_check_eq(CurrentMapData.horizontal_sectors, 3, "horizontal_sectors round-trip")
	_check_eq(CurrentMapData.vertical_sectors, 2, "vertical_sectors round-trip")
	_check_eq(CurrentMapData.typ_map, PackedByteArray([1, 2, 3, 4, 5, 6]), "typ_map round-trip")
	_check_eq(CurrentMapData.own_map, PackedByteArray([0, 1, 2, 3, 4, 5]), "own_map round-trip")
	_check_eq(CurrentMapData.blg_map, PackedByteArray([10, 11, 12, 13, 14, 15]), "blg_map round-trip")
	var expected_hgt := PackedByteArray()
	for i in 20:
		expected_hgt.append(i)
	_check_eq(CurrentMapData.hgt_map, expected_hgt, "hgt_map round-trip")


func _assert_level_params() -> void:
	_check_eq(CurrentMapData.level_set, 3, "level_set round-trip")
	_check_eq(CurrentMapData.event_loop, 5, "event_loop round-trip")
	_check_eq(CurrentMapData.music, 2, "music round-trip")
	_check_eq(CurrentMapData.min_break, 3, "min_break round-trip")
	_check_eq(CurrentMapData.max_break, 7, "max_break round-trip")
	_check_eq(CurrentMapData.movie, "intro", "movie round-trip")


func _assert_enable_lists() -> void:
	_check_eq(CurrentMapData.resistance_enabled_units, [10, 20, 30], "resistance_enabled_units round-trip")
	_check_eq(CurrentMapData.resistance_enabled_buildings, [5, 6], "resistance_enabled_buildings round-trip")
	_check_eq(CurrentMapData.ghorkov_enabled_units, [100], "ghorkov_enabled_units round-trip")
	_check_eq(CurrentMapData.taerkasten_enabled_buildings, [7], "taerkasten_enabled_buildings round-trip")


func _assert_tech_upgrades() -> void:
	_check_eq(CurrentMapData.tech_upgrades.size(), 1, "tech_upgrades count")
	if CurrentMapData.tech_upgrades.size() != 1:
		return
	var tu = CurrentMapData.tech_upgrades[0]
	_check_eq(tu.sec_x, 1, "tech_upgrade sec_x")
	_check_eq(tu.sec_y, 1, "tech_upgrade sec_y")
	_check_eq(tu.building_id, 15, "tech_upgrade building_id")
	_check_eq(tu.type, 1, "tech_upgrade type")

	_check_eq(tu.vehicles.size(), 1, "vehicle modifier count")
	if tu.vehicles.size() == 1:
		var veh = tu.vehicles[0]
		_check_eq(veh.vehicle_id, 96, "vehicle_id")
		_check_eq(veh.energy, 500, "vehicle energy")
		_check_eq(veh.shield, 100, "vehicle shield")
		_check_eq(veh.radar, 50, "vehicle radar")
		_check_eq(veh.num_weapons, 2, "vehicle num_weapons")
		# The regression guards: non-default fire offsets must survive the round trip.
		_check_eq(veh.fire_x, 42.0, "vehicle fire_x round-trip")
		_check_eq(veh.fire_y, 7.5, "vehicle fire_y round-trip")
		_check_eq(veh.fire_z, -3.0, "vehicle fire_z round-trip")
		_check_eq(veh.res_enabled, true, "vehicle res_enabled")
		_check_eq(veh.ghor_enabled, true, "vehicle ghor_enabled")
		_check_eq(veh.taer_enabled, false, "vehicle taer_enabled stays false")

	_check_eq(tu.weapons.size(), 1, "weapon modifier count")
	if tu.weapons.size() == 1:
		var wpn = tu.weapons[0]
		_check_eq(wpn.weapon_id, 200, "weapon_id")
		_check_eq(wpn.energy, 999, "weapon energy")
		_check_eq(wpn.shot_time, 10, "weapon shot_time")
		_check_eq(wpn.shot_time_user, 20, "weapon shot_time_user")

	_check_eq(tu.buildings.size(), 1, "building modifier count")
	if tu.buildings.size() == 1:
		var bld = tu.buildings[0]
		_check_eq(bld.building_id, 50, "building_id")
		_check_eq(bld.res_enabled, true, "building res_enabled")
		_check_eq(bld.taer_enabled, true, "building taer_enabled")


# --- Global-state isolation --------------------------------------------------

func _snapshot_global_state() -> void:
	_saved_state = {
		"map_path": CurrentMapData.map_path,
		"is_saved": CurrentMapData.is_saved,
		"game_data_type": EditorState.game_data_type,
		"horizontal_sectors": CurrentMapData.horizontal_sectors,
		"vertical_sectors": CurrentMapData.vertical_sectors,
		"typ_map": CurrentMapData.typ_map.duplicate(),
		"own_map": CurrentMapData.own_map.duplicate(),
		"hgt_map": CurrentMapData.hgt_map.duplicate(),
		"blg_map": CurrentMapData.blg_map.duplicate(),
		"level_set": CurrentMapData.level_set,
		"event_loop": CurrentMapData.event_loop,
		"music": CurrentMapData.music,
		"min_break": CurrentMapData.min_break,
		"max_break": CurrentMapData.max_break,
		"movie": CurrentMapData.movie,
		"tech_upgrades": CurrentMapData.tech_upgrades.duplicate(),
		"beam_gates": CurrentMapData.beam_gates.duplicate(),
		"stoudson_bombs": CurrentMapData.stoudson_bombs.duplicate(),
		"resistance_enabled_units": CurrentMapData.resistance_enabled_units.duplicate(),
		"resistance_enabled_buildings": CurrentMapData.resistance_enabled_buildings.duplicate(),
		"ghorkov_enabled_units": CurrentMapData.ghorkov_enabled_units.duplicate(),
		"taerkasten_enabled_buildings": CurrentMapData.taerkasten_enabled_buildings.duplicate(),
		"host_stations": CurrentMapData.host_stations,
		"squads": CurrentMapData.squads,
	}


func _restore_global_state() -> void:
	CurrentMapData.host_stations = _saved_state["host_stations"]
	CurrentMapData.squads = _saved_state["squads"]
	if is_instance_valid(_tmp_host_stations):
		_tmp_host_stations.free()
	if is_instance_valid(_tmp_squads):
		_tmp_squads.free()

	CurrentMapData.horizontal_sectors = _saved_state["horizontal_sectors"]
	CurrentMapData.vertical_sectors = _saved_state["vertical_sectors"]
	CurrentMapData.typ_map = _saved_state["typ_map"]
	CurrentMapData.own_map = _saved_state["own_map"]
	CurrentMapData.hgt_map = _saved_state["hgt_map"]
	CurrentMapData.blg_map = _saved_state["blg_map"]
	CurrentMapData.event_loop = _saved_state["event_loop"]
	CurrentMapData.music = _saved_state["music"]
	CurrentMapData.min_break = _saved_state["min_break"]
	CurrentMapData.max_break = _saved_state["max_break"]
	CurrentMapData.movie = _saved_state["movie"]
	CurrentMapData.level_set = _saved_state["level_set"]
	CurrentMapData.tech_upgrades = _saved_state["tech_upgrades"]
	CurrentMapData.beam_gates = _saved_state["beam_gates"]
	CurrentMapData.stoudson_bombs = _saved_state["stoudson_bombs"]
	CurrentMapData.resistance_enabled_units = _saved_state["resistance_enabled_units"]
	CurrentMapData.resistance_enabled_buildings = _saved_state["resistance_enabled_buildings"]
	CurrentMapData.ghorkov_enabled_units = _saved_state["ghorkov_enabled_units"]
	CurrentMapData.taerkasten_enabled_buildings = _saved_state["taerkasten_enabled_buildings"]
	EditorState.game_data_type = _saved_state["game_data_type"]
	CurrentMapData.map_path = _saved_state["map_path"]
	CurrentMapData.is_saved = _saved_state["is_saved"]

	if FileAccess.file_exists(_TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))

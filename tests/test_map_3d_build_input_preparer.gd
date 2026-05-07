extends RefCounted

const AsyncMapSnapshot := preload("res://map/3d/runtime/map_3d_async_map_snapshot.gd")
const BuildInputPreparer := preload("res://map/3d/services/map_3d_build_input_preparer.gd")
const EffectiveTypService := preload("res://map/3d/services/map_3d_effective_typ_service.gd")

var _errors: Array[String] = []


class ContextPortStub extends RefCounted:
	var current_map_data_ref: Node = null
	var game_data_type := "original"
	var preloads_ref = null

	func current_map_data() -> Node:
		return current_map_data_ref

	func current_game_data_type() -> String:
		return game_data_type

	func preloads():
		return preloads_ref


class CurrentMapDataStub extends Node:
	var horizontal_sectors := 0
	var vertical_sectors := 0
	var level_set := 1
	var hgt_map: PackedByteArray = PackedByteArray()
	var typ_map: PackedByteArray = PackedByteArray()
	var blg_map: PackedByteArray = PackedByteArray()
	var beam_gates: Array = []
	var tech_upgrades: Array = []
	var stoudson_bombs: Array = []


func _reset_errors() -> void:
	_errors.clear()
	EffectiveTypService.clear_runtime_lookup_caches_for_tests()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var detail := "%s  (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(detail)
		_errors.append(detail)


func _make_valid_map() -> CurrentMapDataStub:
	var current_map_data := CurrentMapDataStub.new()
	current_map_data.horizontal_sectors = 2
	current_map_data.vertical_sectors = 2
	current_map_data.level_set = 3
	current_map_data.hgt_map = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	current_map_data.typ_map = PackedByteArray([12, 12, 12, 12])
	current_map_data.blg_map = PackedByteArray([0, 0, 0, 0])
	current_map_data.tech_upgrades = [{"sec_x": 2, "sec_y": 1, "building": 50}]
	return current_map_data


func _make_preparer(context: ContextPortStub, snapshot: RefCounted, effective_typ_service: RefCounted) -> RefCounted:
	var preparer := BuildInputPreparer.new()
	preparer.bind(context, snapshot, effective_typ_service)
	return preparer


func test_missing_current_map_returns_clear_result_without_snapshot_mutation() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var snapshot := AsyncMapSnapshot.new()
	snapshot.set_snapshot(PackedByteArray([7]), PackedByteArray([2]), 1, 1, 5, "md")
	var preparer := _make_preparer(context, snapshot, EffectiveTypService.new())
	var result: Dictionary = preparer.prepare_current_map()
	_check(not bool(result.get("valid", true)), "Missing map data should not produce a valid preparation result")
	_check(bool(result.get("missing_map", false)), "Missing map data should be reported distinctly from invalid input")
	_check(not bool(result.get("invalid_input", true)), "Missing map data should not be marked as malformed map input")
	_check_eq(snapshot.effective_typ, PackedByteArray([7]), "Missing map data should leave the existing async snapshot untouched")
	_check_eq(snapshot.level_set, 5, "Missing map data should not reset snapshot metadata")
	return _errors.is_empty()


func test_invalid_dimensions_return_invalid_input_without_snapshot_mutation() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var current_map_data := _make_valid_map()
	current_map_data.hgt_map = PackedByteArray([0, 0, 0])
	context.current_map_data_ref = current_map_data
	var snapshot := AsyncMapSnapshot.new()
	snapshot.set_snapshot(PackedByteArray([9]), PackedByteArray([4]), 2, 2, 6, "original")
	var preparer := _make_preparer(context, snapshot, EffectiveTypService.new())
	var result: Dictionary = preparer.prepare_current_map()
	_check(not bool(result.get("valid", true)), "Malformed map arrays should not produce a valid preparation result")
	_check(not bool(result.get("missing_map", true)), "Malformed map arrays should not be reported as missing map data")
	_check(bool(result.get("invalid_input", false)), "Malformed map arrays should be marked as invalid input")
	_check_eq(snapshot.effective_typ, PackedByteArray([9]), "Invalid input should not update the async snapshot")
	return _errors.is_empty()


func test_valid_input_returns_prepared_payload_and_updates_snapshot() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var current_map_data := _make_valid_map()
	var preloads := Node.new()
	context.current_map_data_ref = current_map_data
	context.preloads_ref = preloads
	var snapshot := AsyncMapSnapshot.new()
	var effective_typ_service := EffectiveTypService.new()
	var preparer := _make_preparer(context, snapshot, effective_typ_service)
	var result: Dictionary = preparer.prepare_current_map()
	var expected_effective_typ := PackedByteArray([12, 102, 12, 12])
	_check(bool(result.get("valid", false)), "Valid map data should produce a valid preparation result")
	_check_eq(int(result.get("w", 0)), 2, "Prepared payload should expose map width")
	_check_eq(int(result.get("h", 0)), 2, "Prepared payload should expose map height")
	_check_eq(int(result.get("level_set", 0)), 3, "Prepared payload should expose level set")
	_check_eq(String(result.get("game_data_type", "")), "original", "Prepared payload should expose game data type")
	_check_eq(result.get("effective_typ", PackedByteArray()), expected_effective_typ, "Prepared payload should expose effective typ overrides")
	_check(result.get("preloads", null) == preloads, "Prepared payload should pass through the current preload service")
	_check_eq(snapshot.blg, current_map_data.blg_map, "Valid preparation should copy blg into the async snapshot")
	_check_eq(snapshot.effective_typ, expected_effective_typ, "Valid preparation should copy effective typ into the async snapshot")
	_check_eq(snapshot.w, 2, "Valid preparation should copy width into the async snapshot")
	_check_eq(snapshot.h, 2, "Valid preparation should copy height into the async snapshot")
	_check_eq(snapshot.level_set, 3, "Valid preparation should copy level set into the async snapshot")
	_check(effective_typ_service.is_valid_cache(2, 2, "original", EffectiveTypService.checksum_packed_byte_array(current_map_data.typ_map), EffectiveTypService.checksum_packed_byte_array(current_map_data.blg_map)), "Valid preparation should leave the effective typ cache reusable")
	preloads.free()
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_missing_current_map_returns_clear_result_without_snapshot_mutation",
		"test_invalid_dimensions_return_invalid_input_without_snapshot_mutation",
		"test_valid_input_returns_prepared_payload_and_updates_snapshot",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

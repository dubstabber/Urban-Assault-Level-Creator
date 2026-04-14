extends RefCounted

const EffectiveTypServiceScript = preload("res://map/3d/services/map_3d_effective_typ_service.gd")
const RendererScript = preload("res://map/map_3d_renderer.gd")

const LOOKUP_TEST_SET_ID := 178

class CurrentMapDataStub:
	extends Node

	var beam_gates: Array = []
	var tech_upgrades: Array = []
	var stoudson_bombs: Array = []


class EntityObjectStub:
	extends Node

	var sec_x := 0


var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()
	EffectiveTypServiceScript.clear_runtime_lookup_caches_for_tests()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var detail := "%s  (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(detail)
		_errors.append(detail)


func test_effective_typ_map_for_3d_applies_known_blg_overrides_only() -> bool:
	_reset_errors()
	var effective := EffectiveTypServiceScript.effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 28, 20, 255]),
		"original",
		-1,
		-1,
		[],
		[],
		[],
		LOOKUP_TEST_SET_ID
	)
	_check_eq(effective, PackedByteArray([12, 205, 199, 12]), "Known building ids should replace only their matching 3D typ_map slots while unknown ids leave typ_map unchanged")
	return _errors.is_empty()


func test_effective_typ_map_for_3d_applies_secondary_sector_overrides() -> bool:
	_reset_errors()
	var effective := EffectiveTypServiceScript.effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[ {"sec_x": 1, "sec_y": 2, "closed_bp": 25}],
		[ {"sec_x": 2, "sec_y": 1, "building": 50}],
		[ {"sec_x": 2, "sec_y": 2, "inactive_bp": 35}],
		LOOKUP_TEST_SET_ID
	)
	_check_eq(effective, PackedByteArray([12, 102, 3, 245]), "Beam gates, tech upgrades, and Stoudson bombs should all apply their visible typ overrides to the expected 1-based sectors")
	return _errors.is_empty()


func test_effective_typ_map_for_3d_ignores_unknown_or_out_of_bounds_secondary_building_overrides() -> bool:
	_reset_errors()
	var effective := EffectiveTypServiceScript.effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[
			{"sec_x": 3, "sec_y": 1, "closed_bp": 25},
			{"sec_x": 0, "sec_y": 1, "closed_bp": 999}
		],
		[ {"sec_x": 1, "sec_y": 2}],
		[ {"sec_x": 2, "sec_y": 2, "inactive_bp": - 1}],
		LOOKUP_TEST_SET_ID
	)
	_check_eq(effective, PackedByteArray([12, 12, 12, 12]), "Out-of-bounds 1-based sector coordinates and unknown secondary building ids should leave the 3D typ_map unchanged")
	return _errors.is_empty()


func test_compute_effective_typ_for_map_cache_tracks_checksums_and_dirty_state() -> bool:
	_reset_errors()
	var service := EffectiveTypServiceScript.new()
	var cmd := CurrentMapDataStub.new()
	cmd.tech_upgrades = [ {"sec_x": 2, "sec_y": 1, "building": 50}]
	var typ := PackedByteArray([12, 12, 12, 12])
	var blg := PackedByteArray([0, 0, 0, 0])
	var typ_checksum := RendererScript._checksum_packed_byte_array(typ)
	var blg_checksum := RendererScript._checksum_packed_byte_array(blg)
	_check(not service.is_valid_cache(2, 2, "original", typ_checksum, blg_checksum), "Cache should start invalid")
	var effective := service.compute_effective_typ_for_map(cmd, 2, 2, typ, blg, "original")
	_check_eq(effective, PackedByteArray([12, 102, 12, 12]), "Computed effective typ should include the expected tech-upgrade override")
	_check(service.is_valid_cache(2, 2, "original", typ_checksum, blg_checksum), "Cache should be valid immediately after compute")
	_check_eq(service.get_effective_typ(), effective, "Cached effective typ should match the computed payload")
	service.set_dirty(true)
	_check(not service.is_valid_cache(2, 2, "original", typ_checksum, blg_checksum), "Dirty flag should invalidate cache reuse")
	var recomputed := service.compute_effective_typ_for_map(cmd, 2, 2, typ, blg, "original")
	_check_eq(recomputed, effective, "Recomputing after dirty should preserve output")
	_check(service.is_valid_cache(2, 2, "original", typ_checksum, blg_checksum), "Cache should become valid again after recompute")
	var changed_typ := PackedByteArray([12, 11, 12, 12])
	var changed_typ_checksum := RendererScript._checksum_packed_byte_array(changed_typ)
	_check(not service.is_valid_cache(2, 2, "original", changed_typ_checksum, blg_checksum), "A typ checksum change should invalidate the previous cache entry")
	service.invalidate_cache()
	_check(not service.is_valid_cache(2, 2, "original", typ_checksum, blg_checksum), "Explicit cache invalidation should clear reuse state")
	return _errors.is_empty()


func test_entity_property_reads_dictionary_and_object_variants() -> bool:
	_reset_errors()
	var dict_value: int = int(EffectiveTypServiceScript.entity_property({"building": 50}, ["building_id", "building"], -1))
	_check_eq(dict_value, 50, "Dictionary entities should resolve the first matching property name")
	var object_entity := EntityObjectStub.new()
	object_entity.sec_x = 2
	var object_value := EffectiveTypServiceScript.entity_int_property(object_entity, ["sec_x"], -1)
	_check_eq(object_value, 2, "Object entities should resolve integer properties via get_property_list")
	return _errors.is_empty()


func run() -> int:
	var tests: Array[String] = [
		"test_effective_typ_map_for_3d_applies_known_blg_overrides_only",
		"test_effective_typ_map_for_3d_applies_secondary_sector_overrides",
		"test_effective_typ_map_for_3d_ignores_unknown_or_out_of_bounds_secondary_building_overrides",
		"test_compute_effective_typ_for_map_cache_tracks_checksums_and_dirty_state",
		"test_entity_property_reads_dictionary_and_object_variants",
	]
	var total_failures := 0
	for test_name in tests:
		if not has_method(test_name):
			push_error("Missing test method: %s" % test_name)
			total_failures += 1
			continue
		var passed: bool = call(test_name)
		if passed:
			print("  PASS  %s" % test_name)
		else:
			print("  FAIL  %s" % test_name)
			total_failures += 1
	if total_failures == 0:
		print("All %d effective typ service tests passed" % tests.size())
	else:
		push_error("%d / %d effective typ service tests failed" % [total_failures, tests.size()])
	return total_failures

extends RefCounted

# Unit tests for Map3DOverlayDescriptorProducers
# Run via: godot4 --headless -s res://tests/_selected_test_runner.gd

const Producers = preload("res://map/map_3d_overlay_descriptor_producers.gd")
const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var detail := "%s  (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(detail)
		_errors.append(detail)


# ---- Helpers ----

func _make_flat_hgt(w: int, h: int, height_byte: int = 10) -> PackedByteArray:
	var bw := w + 2
	var bh := h + 2
	var hgt := PackedByteArray()
	hgt.resize(bw * bh)
	hgt.fill(height_byte)
	return hgt


func _make_host_station_snapshot(vehicle: int, x: float, y: float, pos_y: float = 0.0, id: int = 100) -> Dictionary:
	return {
		"id": id,
		"vehicle": vehicle,
		"x": x,
		"y": y,
		"pos_y": pos_y,
	}


func _make_squad_snapshot(vehicle: int, x: float, y: float, quantity: int = 1, id: int = 200) -> Dictionary:
	return {
		"id": id,
		"vehicle": vehicle,
		"x": x,
		"y": y,
		"quantity": quantity,
	}


# ---- Tests ----

func test_constants_match_renderer() -> bool:
	_reset_errors()
	_check_eq(Producers.SECTOR_SIZE, Map3DRendererScript.SECTOR_SIZE, "SECTOR_SIZE should match renderer")
	_check_eq(Producers.HEIGHT_SCALE, Map3DRendererScript.HEIGHT_SCALE, "HEIGHT_SCALE should match renderer")
	_check_eq(Producers.SQUAD_FORMATION_SPACING, Map3DRendererScript.SQUAD_FORMATION_SPACING, "SQUAD_FORMATION_SPACING should match renderer")
	_check_eq(Producers.SQUAD_EXTRA_Y_OFFSET, Map3DRendererScript.SQUAD_EXTRA_Y_OFFSET, "SQUAD_EXTRA_Y_OFFSET should match renderer")
	_check_eq(Producers.HOST_STATION_BASE_NAMES, Map3DRendererScript.HOST_STATION_BASE_NAMES, "HOST_STATION_BASE_NAMES should match renderer")
	_check_eq(Producers.HOST_STATION_VISIBLE_GUN_BASE_NAMES, Map3DRendererScript.HOST_STATION_VISIBLE_GUN_BASE_NAMES, "HOST_STATION_VISIBLE_GUN_BASE_NAMES should match renderer")
	return _errors.is_empty()


func test_ground_height_at_world_position_matches_renderer() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 20)
	var world_x := 2700.0
	var world_z := 2700.0
	var producer_h := Producers.ground_height_at_world_position(hgt, w, h, world_x, world_z)
	var renderer_h := Map3DRendererScript._ground_height_at_world_position(hgt, w, h, world_x, world_z)
	_check_eq(producer_h, renderer_h, "Producer ground height should match renderer")
	_check(producer_h > 0.0, "Ground height should be positive for non-zero hgt")
	return _errors.is_empty()


func test_support_height_at_world_position_matches_renderer() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 15)
	var world_x := 2700.0
	var world_z := 2700.0
	var producer_h := Producers.support_height_at_world_position(hgt, w, h, [], world_x, world_z)
	var renderer_h := Map3DRendererScript._support_height_at_world_position(hgt, w, h, [], world_x, world_z)
	_check_eq(producer_h, renderer_h, "Producer support height should match renderer (no support descriptors)")
	return _errors.is_empty()


func test_sector_center_origin_matches_renderer() -> bool:
	_reset_errors()
	var producer_origin := Producers.sector_center_origin(2, 3, 500.0)
	var renderer_origin := Map3DRendererScript._sector_center_origin(2, 3, 500.0)
	_check_eq(producer_origin, renderer_origin, "Producer sector_center_origin should match renderer")
	return _errors.is_empty()


func test_vector3_from_variant_dict() -> bool:
	_reset_errors()
	var v := Producers.vector3_from_variant({"x": 1.0, "y": 2.0, "z": 3.0})
	_check_eq(v, Vector3(1.0, 2.0, 3.0), "vector3_from_variant should parse dictionary")
	var v2 := Producers.vector3_from_variant(Vector3(4.0, 5.0, 6.0))
	_check_eq(v2, Vector3(4.0, 5.0, 6.0), "vector3_from_variant should pass through Vector3")
	var v3 := Producers.vector3_from_variant(null)
	_check_eq(v3, Vector3.ZERO, "vector3_from_variant should return ZERO for null")
	return _errors.is_empty()


func test_godot_offset_from_ua() -> bool:
	_reset_errors()
	var offset := Producers.godot_offset_from_ua(Vector3(10.0, 20.0, 30.0))
	_check_eq(offset, Vector3(10.0, -20.0, -30.0), "godot_offset_from_ua should negate Y and Z")
	return _errors.is_empty()


func test_godot_direction_from_ua_normalizes_horizontal() -> bool:
	_reset_errors()
	var dir := Producers.godot_direction_from_ua(Vector3(0.0, 0.0, 1.0))
	_check(dir.length() > 0.99 and dir.length() < 1.01, "Direction should be normalized")
	_check_eq(dir.y, 0.0, "Direction should have zero Y component")
	var zero_dir := Producers.godot_direction_from_ua(Vector3.ZERO)
	_check_eq(zero_dir, Vector3.ZERO, "Zero UA direction should produce zero Godot direction")
	return _errors.is_empty()


func test_host_station_base_name_for_known_vehicles() -> bool:
	_reset_errors()
	_check_eq(Producers.host_station_base_name_for_vehicle(56), "VP_ROBO", "Vehicle 56 should be VP_ROBO")
	_check_eq(Producers.host_station_base_name_for_vehicle(62), "VP_BSECT", "Vehicle 62 should be VP_BSECT")
	_check_eq(Producers.host_station_base_name_for_vehicle(999), "", "Unknown vehicle should return empty")
	return _errors.is_empty()


func test_host_station_gun_base_name_for_known_types() -> bool:
	_reset_errors()
	_check_eq(Producers.host_station_gun_base_name_for_type(90), "VP_MFLAK", "Gun type 90 should be VP_MFLAK")
	_check_eq(Producers.host_station_gun_base_name_for_type(93), "VP_FLAK2", "Gun type 93 should be VP_FLAK2")
	_check_eq(Producers.host_station_gun_base_name_for_type(999), "", "Unknown gun type should return empty")
	return _errors.is_empty()


func test_squad_formation_offsets_single_unit() -> bool:
	_reset_errors()
	var offsets := Producers.squad_formation_offsets(1)
	_check_eq(offsets.size(), 1, "Single unit should produce 1 offset")
	var renderer_offsets := Map3DRendererScript._squad_formation_offsets(1)
	_check_eq(offsets[0], renderer_offsets[0], "Single unit offset should match renderer")
	return _errors.is_empty()


func test_squad_formation_offsets_multiple_units() -> bool:
	_reset_errors()
	var offsets := Producers.squad_formation_offsets(4)
	_check_eq(offsets.size(), 4, "4 units should produce 4 offsets")
	var renderer_offsets := Map3DRendererScript._squad_formation_offsets(4)
	for i in 4:
		_check_eq(offsets[i], renderer_offsets[i], "Offset %d should match renderer" % i)
	return _errors.is_empty()


func test_build_host_station_descriptors_from_snapshot_produces_correct_keys() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var snapshot := [_make_host_station_snapshot(56, 1800.0, -1800.0, 0.0, 42)]
	var descriptors := Producers.build_host_station_descriptors_from_snapshot(snapshot, 1, hgt, w, h)
	# VP_ROBO may or may not have piece source; check consistency with renderer
	var renderer_descriptors := Map3DRendererScript._build_host_station_descriptors_from_snapshot(snapshot, 1, hgt, w, h)
	_check_eq(descriptors.size(), renderer_descriptors.size(), "Producer and renderer descriptor counts should match")
	for i in descriptors.size():
		_check_eq(descriptors[i]["instance_key"], renderer_descriptors[i]["instance_key"], "Instance key %d should match" % i)
		_check_eq(descriptors[i]["origin"], renderer_descriptors[i]["origin"], "Origin %d should match" % i)
		_check_eq(descriptors[i]["base_name"], renderer_descriptors[i]["base_name"], "Base name %d should match" % i)
	return _errors.is_empty()


func test_build_squad_descriptors_from_snapshot_produces_correct_keys() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var snapshot := [_make_squad_snapshot(143, 2400.0, -2400.0, 2, 77)]
	var descriptors := Producers.build_squad_descriptors_from_snapshot(snapshot, 1, hgt, w, h, [], "original")
	var renderer_descriptors := Map3DRendererScript._build_squad_descriptors_from_snapshot(snapshot, 1, hgt, w, h, [], "original")
	_check_eq(descriptors.size(), renderer_descriptors.size(), "Producer and renderer squad descriptor counts should match")
	for i in descriptors.size():
		_check_eq(descriptors[i]["instance_key"], renderer_descriptors[i]["instance_key"], "Squad instance key %d should match" % i)
		_check_eq(descriptors[i]["origin"], renderer_descriptors[i]["origin"], "Squad origin %d should match" % i)
	return _errors.is_empty()


func test_build_blg_attachment_descriptors_matches_renderer() -> bool:
	_reset_errors()
	var w := 2
	var h := 2
	var hgt := _make_flat_hgt(w, h, 10)
	var blg := PackedByteArray([0, 0, 0, 0])
	var typ := PackedByteArray([12, 12, 12, 12])
	var producer_descs := Producers.build_blg_attachment_descriptors(blg, typ, 1, hgt, w, h, [], "original")
	var renderer_descs := Map3DRendererScript._build_blg_attachment_descriptors(blg, typ, 1, hgt, w, h, [], "original")
	_check_eq(producer_descs.size(), renderer_descs.size(), "BLG attachment descriptor counts should match")
	return _errors.is_empty()


func test_build_host_station_descriptors_from_snapshot_skips_unknown_vehicle() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var snapshot := [_make_host_station_snapshot(9999, 1800.0, -1800.0, 0.0, 1)]
	var descriptors := Producers.build_host_station_descriptors_from_snapshot(snapshot, 1, hgt, w, h)
	_check_eq(descriptors.size(), 0, "Unknown vehicle should produce 0 descriptors")
	return _errors.is_empty()


func test_build_squad_descriptors_from_snapshot_skips_unknown_vehicle() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var snapshot := [_make_squad_snapshot(9999, 1800.0, -1800.0, 1, 1)]
	var descriptors := Producers.build_squad_descriptors_from_snapshot(snapshot, 1, hgt, w, h, [], "original")
	_check_eq(descriptors.size(), 0, "Unknown vehicle should produce 0 squad descriptors")
	return _errors.is_empty()


func test_build_host_station_descriptors_from_snapshot_skips_invalid_entries() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var snapshot := ["not_a_dict", 42, null]
	var descriptors := Producers.build_host_station_descriptors_from_snapshot(snapshot, 1, hgt, w, h)
	_check_eq(descriptors.size(), 0, "Invalid entries should be skipped")
	return _errors.is_empty()


func test_build_blg_attachment_descriptors_rejects_mismatched_sizes() -> bool:
	_reset_errors()
	var w := 2
	var h := 2
	var hgt := _make_flat_hgt(w, h, 10)
	var blg := PackedByteArray([0, 0])  # Wrong size
	var typ := PackedByteArray([12, 12, 12, 12])
	var descriptors := Producers.build_blg_attachment_descriptors(blg, typ, 1, hgt, w, h, [], "original")
	_check_eq(descriptors.size(), 0, "Mismatched blg size should produce 0 descriptors")
	return _errors.is_empty()


func test_snapshot_host_station_nodes_skips_null_and_non_node2d() -> bool:
	_reset_errors()
	var snapshot := Producers.snapshot_host_station_nodes([null, "string", 42])
	_check_eq(snapshot.size(), 0, "Non-Node2D entries should be skipped")
	return _errors.is_empty()


func test_snapshot_squad_nodes_skips_null_and_non_node2d() -> bool:
	_reset_errors()
	var snapshot := Producers.snapshot_squad_nodes([null, "string", 42])
	_check_eq(snapshot.size(), 0, "Non-Node2D entries should be skipped")
	return _errors.is_empty()


# ---- Runner ----

func run() -> int:
	var tests: Array[String] = []
	for method in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_"):
			tests.append(method_name)
	tests.sort()
	var failures := 0
	for test_name in tests:
		_reset_errors()
		print("RUN %s" % test_name)
		var passed: bool = call(test_name)
		if passed:
			print("OK  %s" % test_name)
		else:
			print("FAIL%s" % test_name)
			failures += 1
	if failures > 0:
		push_error("%d test(s) failed" % failures)
	return failures

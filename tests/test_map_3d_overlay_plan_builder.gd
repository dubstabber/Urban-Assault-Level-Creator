extends RefCounted

const Builder := preload("res://map/3d/services/map_3d_overlay_plan_builder.gd")
const Producers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")


class HostStationStub:
	extends Node2D

	var vehicle := 56
	var pos_y := 0.0
	var editor_unit_id := 0

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, ua_y: float, stable_id: int) -> void:
		vehicle = vehicle_id
		pos_y = ua_y
		editor_unit_id = stable_id
		position = Vector2(pos_x, pos_z_abs)


class SquadStub:
	extends Node2D

	var vehicle := 143
	var quantity := 1
	var editor_unit_id := 0

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, unit_quantity: int, stable_id: int) -> void:
		vehicle = vehicle_id
		quantity = unit_quantity
		editor_unit_id = stable_id
		position = Vector2(pos_x, pos_z_abs)


class CurrentMapDataStub:
	extends Node

	var host_stations: Node = null
	var squads: Node = null


class UnitRuntimeIndexStub extends RefCounted:
	var units_by_kind := {}

	func units_for_sectors(_current_map_data: Node, kind: String, _affected_sectors: Array) -> Array:
		return Array(units_by_kind.get(kind, [])).duplicate()


var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(actual, expected, msg: String) -> void:
	if actual != expected:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(actual), str(expected)]
		push_error(full_msg)
		_errors.append(full_msg)


func _make_flat_hgt(w: int, h: int, value: int = 0) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize((w + 2) * (h + 2))
	for i in range(arr.size()):
		arr[i] = value
	return arr


func _make_filled_byte_array(size: int, value: int) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(size)
	for i in range(arr.size()):
		arr[i] = value
	return arr


func _instance_keys(descriptors: Array) -> Array:
	var keys: Array = []
	for descriptor_value in descriptors:
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		keys.append(String((descriptor_value as Dictionary).get("instance_key", "")))
	return keys


func test_capture_dynamic_snapshots_matches_direct_producers() -> bool:
	_reset_errors()
	var current_map_data := CurrentMapDataStub.new()
	current_map_data.host_stations = Node.new()
	current_map_data.squads = Node.new()
	current_map_data.host_stations.add_child(HostStationStub.new(56, 1800.0, 1800.0, 0.0, 42))
	current_map_data.squads.add_child(SquadStub.new(143, 2400.0, 2400.0, 2, 77))

	var snapshots := Builder.capture_dynamic_snapshots(current_map_data)
	var expected_host := Producers.snapshot_host_station_nodes(current_map_data.host_stations.get_children())
	var expected_squad := Producers.snapshot_squad_nodes(current_map_data.squads.get_children())
	_check_eq(snapshots.get("host_station_snapshot", []), expected_host, "Overlay plan builder should capture host station snapshots via the shared producer path")
	_check_eq(snapshots.get("squad_snapshot", []), expected_squad, "Overlay plan builder should capture squad snapshots via the shared producer path")
	current_map_data.free()
	return _errors.is_empty()


func test_build_overlay_plan_from_snapshots_matches_direct_descriptor_composition() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var support_descriptors := [{"instance_key": "terrain:1:0:0:test"}]
	var host_snapshot := Producers.snapshot_host_station_nodes([HostStationStub.new(56, 1800.0, 1800.0, 0.0, 42)])
	var squad_snapshot := Producers.snapshot_squad_nodes([SquadStub.new(143, 2400.0, 2400.0, 2, 77)])
	var metrics := {}

	var plan := Builder.build_overlay_plan_from_snapshots(
		host_snapshot,
		squad_snapshot,
		_make_filled_byte_array(w * h, 0),
		_make_filled_byte_array(w * h, 0),
		1,
		hgt,
		w,
		h,
		support_descriptors,
		"original",
		metrics
	)
	var expected_static: Array = support_descriptors.duplicate()
	var expected_dynamic: Array = []
	expected_dynamic.append_array(Producers.build_host_station_descriptors_from_snapshot(host_snapshot, 1, hgt, w, h, support_descriptors, metrics))
	expected_dynamic.append_array(Producers.build_squad_descriptors_from_snapshot(squad_snapshot, 1, hgt, w, h, support_descriptors, "original", metrics))

	_check_eq(_instance_keys(plan.get("static_descriptors", [])), _instance_keys(expected_static), "Overlay plan builder should keep support descriptors as the static overlay baseline")
	_check_eq(_instance_keys(plan.get("dynamic_descriptors", [])), _instance_keys(expected_dynamic), "Overlay plan builder should compose dynamic descriptors in the same order as the direct producer calls")
	_check(metrics.has("overlay_descriptor_generation_ms"), "Overlay plan builder should record descriptor generation timing")
	return _errors.is_empty()


func test_build_overlay_plan_dynamic_only_skips_static_attachments() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var support_descriptors := [{"instance_key": "terrain:1:0:0:test"}]
	var host_snapshot := Producers.snapshot_host_station_nodes([HostStationStub.new(56, 1800.0, 1800.0, 0.0, 42)])
	var metrics := {}

	var plan := Builder.build_overlay_plan_from_snapshots(
		host_snapshot,
		[],
		_make_filled_byte_array(w * h, 255),
		_make_filled_byte_array(w * h, 255),
		1,
		hgt,
		w,
		h,
		support_descriptors,
		"original",
		metrics,
		true
	)

	_check_eq(_instance_keys(plan.get("static_descriptors", [])), _instance_keys(support_descriptors), "Dynamic-only overlay plans should preserve only the support descriptor baseline on the static side")
	_check_eq(int(metrics.get("overlay_descriptor_count", -1)), plan.get("static_descriptors", []).size() + plan.get("dynamic_descriptors", []).size(), "Dynamic-only overlay plans should keep descriptor counts aligned with the produced plan")
	return _errors.is_empty()


func test_build_localized_dynamic_descriptors_uses_unit_runtime_index_selection() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var hgt := _make_flat_hgt(w, h, 10)
	var current_map_data := CurrentMapDataStub.new()
	current_map_data.host_stations = Node.new()
	current_map_data.squads = Node.new()
	var host := HostStationStub.new(56, 1800.0, 1800.0, 0.0, 42)
	var squad := SquadStub.new(143, 2400.0, 2400.0, 2, 77)
	current_map_data.host_stations.add_child(host)
	current_map_data.squads.add_child(squad)

	var unit_runtime_index := UnitRuntimeIndexStub.new()
	unit_runtime_index.units_by_kind = {
		"host": [host],
		"squad": [squad],
	}
	var metrics := {}
	var affected_sectors := [Vector2i(0, 0)]
	var descriptors := Builder.build_localized_dynamic_descriptors(
		current_map_data,
		unit_runtime_index,
		1,
		hgt,
		w,
		h,
		affected_sectors,
		[],
		"original",
		metrics
	)
	var expected: Array = []
	expected.append_array(Producers.build_host_station_descriptors_for_sectors([host], 1, hgt, w, h, affected_sectors, [], metrics))
	expected.append_array(Producers.build_squad_descriptors_for_sectors([squad], 1, hgt, w, h, affected_sectors, [], "original", metrics))
	_check_eq(_instance_keys(descriptors), _instance_keys(expected), "Localized dynamic overlay plans should compose descriptors from the unit runtime index selection")
	current_map_data.free()
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_capture_dynamic_snapshots_matches_direct_producers",
		"test_build_overlay_plan_from_snapshots_matches_direct_descriptor_composition",
		"test_build_overlay_plan_dynamic_only_skips_static_attachments",
		"test_build_localized_dynamic_descriptors_uses_unit_runtime_index_selection",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

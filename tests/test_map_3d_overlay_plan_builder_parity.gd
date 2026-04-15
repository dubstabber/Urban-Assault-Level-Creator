extends RefCounted

const Producers = preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")

var _errors: Array[String] = []


class HostStationStub extends Node2D:
	var vehicle := 0
	var pos_y := 0.0

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, ua_y: float) -> void:
		vehicle = vehicle_id
		pos_y = ua_y
		position = Vector2(pos_x, pos_z_abs)


class SquadStub extends Node2D:
	var vehicle := 0
	var quantity := 1

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, squad_quantity: int = 1) -> void:
		vehicle = vehicle_id
		quantity = squad_quantity
		position = Vector2(pos_x, pos_z_abs)


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


func _make_flat_hgt(w: int, h: int, height_byte: int = 0) -> PackedByteArray:
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	hgt.fill(height_byte)
	return hgt


func _set_hgt_value(hgt: PackedByteArray, w: int, sx: int, sy: int, height_byte: int) -> void:
	var bw := w + 2
	hgt[(sy + 1) * bw + (sx + 1)] = height_byte


func _normalized_descriptors(descriptors: Array) -> Array:
	var normalized: Array = []
	for descriptor_value in descriptors:
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor := descriptor_value as Dictionary
		var summary := {
			"instance_key": String(descriptor.get("instance_key", "")),
			"base_name": String(descriptor.get("base_name", "")),
			"origin": descriptor.get("origin", Vector3.ZERO),
		}
		if descriptor.has("forward"):
			summary["forward"] = descriptor.get("forward", Vector3.ZERO)
		if descriptor.has("y_offset"):
			summary["y_offset"] = descriptor.get("y_offset", 0.0)
		normalized.append(summary)
	normalized.sort_custom(func(a, b) -> bool:
		return String(a.get("instance_key", "")) < String(b.get("instance_key", ""))
	)
	return normalized


func _instance_keys(descriptors: Array) -> Array:
	var keys: Array = []
	for descriptor_value in descriptors:
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor := descriptor_value as Dictionary
		keys.append(String(descriptor.get("instance_key", "")))
	keys.sort()
	return keys


func _build_overlay_payload(dynamic_only: bool, support_descriptors: Array, blg: PackedByteArray, effective_typ: PackedByteArray, hgt: PackedByteArray, host_nodes: Array, squad_nodes: Array) -> Dictionary:
	return {
		"generation_id": 0,
		"dynamic_only": dynamic_only,
		"support_descriptors": support_descriptors,
		"blg": blg,
		"effective_typ": effective_typ,
		"set_id": 1,
		"hgt": hgt,
		"w": 2,
		"h": 2,
		"game_data_type": "original",
		"host_station_snapshot": Producers.snapshot_host_station_nodes(host_nodes),
		"squad_snapshot": Producers.snapshot_squad_nodes(squad_nodes),
	}


func _run_async_overlay_plan(payload: Dictionary) -> Dictionary:
	var renderer := Map3DRendererScript.new()
	renderer._async_overlay_descriptor_worker(payload)
	var state := renderer._get_async_overlay_descriptor_state()
	renderer.free()
	return state


func test_async_overlay_descriptor_worker_matches_full_plan_composition() -> bool:
	_reset_errors()
	var hgt := _make_flat_hgt(2, 2, 0)
	_set_hgt_value(hgt, 2, 0, 0, 8)
	var support_descriptors := [{
		"set_id": 1,
		"raw_id": -1,
		"base_name": "ST_EMPTY",
		"instance_key": "terrain:1:0:0:seed",
		"origin": Vector3(1800.0, 0.0, 1800.0),
	}]
	var blg := PackedByteArray([28, 0, 0, 0])
	var effective_typ := PackedByteArray([205, 12, 12, 12])
	var host_nodes: Array = [HostStationStub.new(56, 1800.0, 1800.0, -700.0)]
	var squad_nodes: Array = [SquadStub.new(1, 1800.0, 1200.0, 2)]
	var payload := _build_overlay_payload(false, support_descriptors, blg, effective_typ, hgt, host_nodes, squad_nodes)
	var state := _run_async_overlay_plan(payload)
	var result: Dictionary = state.get("result", {})
	var metrics: Dictionary = state.get("metrics", {})

	var expected_static: Array = support_descriptors.duplicate(true)
	expected_static.append_array(Producers.build_blg_attachment_descriptors(blg, effective_typ, 1, hgt, 2, 2, support_descriptors, "original"))
	var expected_dynamic: Array = []
	expected_dynamic.append_array(Producers.build_host_station_descriptors_from_snapshot(payload["host_station_snapshot"], 1, hgt, 2, 2, support_descriptors, {}))
	expected_dynamic.append_array(Producers.build_squad_descriptors_from_snapshot(payload["squad_snapshot"], 1, hgt, 2, 2, support_descriptors, "original", {}))

	_check_eq(
		_normalized_descriptors(result.get("static_descriptors", [])),
		_normalized_descriptors(expected_static),
		"Full overlay worker static descriptors should match producer-composed plan output"
	)
	_check_eq(
		_normalized_descriptors(result.get("dynamic_descriptors", [])),
		_normalized_descriptors(expected_dynamic),
		"Full overlay worker dynamic descriptors should match producer-composed plan output"
	)
	_check_eq(
		int(metrics.get("overlay_descriptor_count", -1)),
		expected_static.size() + expected_dynamic.size(),
		"Full overlay worker should report the combined descriptor count"
	)
	return _errors.is_empty()


func test_async_overlay_descriptor_worker_dynamic_only_omits_static_attachments() -> bool:
	_reset_errors()
	var hgt := _make_flat_hgt(2, 2, 0)
	_set_hgt_value(hgt, 2, 0, 0, 8)
	var support_descriptors := [{
		"set_id": 1,
		"raw_id": -1,
		"base_name": "ST_EMPTY",
		"instance_key": "terrain:1:0:0:seed",
		"origin": Vector3(1800.0, 0.0, 1800.0),
	}]
	var blg := PackedByteArray([28, 0, 0, 0])
	var effective_typ := PackedByteArray([205, 12, 12, 12])
	var host_nodes: Array = [HostStationStub.new(56, 1800.0, 1800.0, -700.0)]
	var squad_nodes: Array = [SquadStub.new(1, 1800.0, 1200.0, 2)]
	var full_payload := _build_overlay_payload(false, support_descriptors, blg, effective_typ, hgt, host_nodes, squad_nodes)
	var dynamic_only_payload := _build_overlay_payload(true, support_descriptors, blg, effective_typ, hgt, host_nodes, squad_nodes)
	var full_result: Dictionary = _run_async_overlay_plan(full_payload).get("result", {})
	var dynamic_only_result: Dictionary = _run_async_overlay_plan(dynamic_only_payload).get("result", {})

	_check_eq(
		_normalized_descriptors(dynamic_only_result.get("static_descriptors", [])),
		_normalized_descriptors(support_descriptors),
		"Dynamic-only overlay planning should keep only support descriptors in the static plan"
	)
	_check_eq(
		_normalized_descriptors(dynamic_only_result.get("dynamic_descriptors", [])),
		_normalized_descriptors(full_result.get("dynamic_descriptors", [])),
		"Dynamic-only overlay planning should preserve the full dynamic descriptor set"
	)
	_check(
		Array(full_result.get("static_descriptors", [])).size() > Array(dynamic_only_result.get("static_descriptors", [])).size(),
		"Dynamic-only overlay planning should omit static building attachments from the static plan"
	)
	return _errors.is_empty()


func test_sector_filtered_overlay_components_match_snapshot_and_full_plan_subsets() -> bool:
	_reset_errors()
	var hgt := _make_flat_hgt(2, 2, 0)
	_set_hgt_value(hgt, 2, 0, 0, 8)
	_set_hgt_value(hgt, 2, 1, 1, 7)
	var support_descriptors := [{
		"set_id": 1,
		"raw_id": -1,
		"base_name": "ST_EMPTY",
		"instance_key": "terrain:1:0:0:seed",
		"origin": Vector3(1800.0, 0.0, 1800.0),
	}]
	var blg := PackedByteArray([28, 0, 0, 3])
	var effective_typ := PackedByteArray([205, 12, 12, 204])
	var sectors := [Vector2i(0, 0)]
	var host_nodes: Array = [
		HostStationStub.new(56, 1800.0, 1800.0, -700.0),
		HostStationStub.new(56, 3000.0, 3000.0, -700.0),
	]
	var squad_nodes: Array = [
		SquadStub.new(1, 1800.0, 1800.0, 1),
		SquadStub.new(1, 3000.0, 3000.0, 1),
	]

	var full_static := Producers.build_blg_attachment_descriptors(blg, effective_typ, 1, hgt, 2, 2, support_descriptors, "original")
	var localized_static := Producers.build_blg_attachment_descriptors_for_sectors(blg, effective_typ, 1, hgt, 2, 2, sectors, "original")
	_check_eq(localized_static.size(), 1, "Localized building attachment planning should include only the requested sector attachments")
	for key in _instance_keys(localized_static):
		_check(_instance_keys(full_static).has(key), "Localized building attachment keys should remain a subset of the full static plan")
		_check(key.begins_with("blg_attach:1:0:0:"), "Localized building attachment keys should stay scoped to the requested sector")

	var host_snapshot := Producers.snapshot_host_station_nodes(host_nodes)
	var localized_host_snapshot := Producers.filter_snapshot_to_sectors(host_snapshot, sectors)
	var localized_hosts := Producers.build_host_station_descriptors_for_sectors(host_nodes, 1, hgt, 2, 2, sectors, support_descriptors, {})
	var expected_localized_hosts := Producers.build_host_station_descriptors_from_snapshot(localized_host_snapshot, 1, hgt, 2, 2, support_descriptors, {})
	_check_eq(
		_normalized_descriptors(localized_hosts),
		_normalized_descriptors(expected_localized_hosts),
		"Localized host-station planning should match snapshot filtering plus descriptor generation"
	)
	_check_eq(localized_hosts.size(), 1, "Localized host-station planning should keep only in-sector units")

	var squad_snapshot := Producers.snapshot_squad_nodes(squad_nodes)
	var localized_squad_snapshot := Producers.filter_snapshot_to_sectors(squad_snapshot, sectors)
	var localized_squads := Producers.build_squad_descriptors_for_sectors(squad_nodes, 1, hgt, 2, 2, sectors, support_descriptors, "original", {})
	var expected_localized_squads := Producers.build_squad_descriptors_from_snapshot(localized_squad_snapshot, 1, hgt, 2, 2, support_descriptors, "original", {})
	_check_eq(
		_normalized_descriptors(localized_squads),
		_normalized_descriptors(expected_localized_squads),
		"Localized squad planning should match snapshot filtering plus descriptor generation"
	)
	_check_eq(localized_squads.size(), 1, "Localized squad planning should keep only in-sector units")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_async_overlay_descriptor_worker_matches_full_plan_composition",
		"test_async_overlay_descriptor_worker_dynamic_only_omits_static_attachments",
		"test_sector_filtered_overlay_components_match_snapshot_and_full_plan_subsets",
	]
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

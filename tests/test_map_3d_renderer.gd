extends RefCounted

# Lightweight unit tests for Map3DRenderer.build_mesh()
# Run via: godot4 --headless -s res://tests/test_runner.gd

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0

var _errors: Array[String] = []

func _reset_errors() -> void:
	_errors.clear()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

func _make_hgt(w: int, h: int, value: int) -> PackedByteArray:
	# hgt_map is (w+2)*(h+2)
	var arr := PackedByteArray()
	arr.resize((w + 2) * (h + 2))
	for i in arr.size():
		arr[i] = value
	return arr

func _set_hgt_value(hgt: PackedByteArray, w: int, x: int, y: int, value: int) -> void:
	var bw := w + 2
	hgt[(y + 1) * bw + (x + 1)] = value

func test_build_mesh_2x2_flat() -> bool:
	_reset_errors()
	var w := 2
	var h := 2
	var hgt := _make_hgt(w, h, 0)
	var mesh: ArrayMesh = Map3DRendererScript.build_mesh(hgt, w, h)
	_check(mesh != null, "Mesh is null")
	if mesh:
		_check(mesh.get_surface_count() == 1, "Surface count should be 1")
		if mesh.get_surface_count() == 1:
			var arrays: Array = mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var sectors := (w + 2) * (h + 2)
			var expected_tris := 2 * sectors
			_check(idxs.size() == expected_tris * 3, "Unexpected index count for 2x2 flat (expected %d, got %d)" % [expected_tris * 3, idxs.size()])
			# All Y should be 0 for flat map (unique vertices array)
			for v in verts:
				_check(is_equal_approx(v.y, 0.0), "Flat mesh vertex Y not 0")
	return _errors.is_empty()

func test_build_mesh_1x1_uses_cell_height_not_border_corners() -> bool:
	_reset_errors()
	var w := 1
	var h := 1
	var hgt := _make_hgt(w, h, 0)
	_set_hgt_value(hgt, w, -1, -1, 1)
	_set_hgt_value(hgt, w, 0, -1, 9)
	_set_hgt_value(hgt, w, -1, 0, 7)
	_set_hgt_value(hgt, w, 0, 0, 5)
	var mesh: ArrayMesh = Map3DRendererScript.build_mesh(hgt, w, h)
	_check(mesh != null, "Mesh is null")
	if mesh:
		_check(mesh.get_surface_count() == 1, "Surface count should be 1")
		if mesh.get_surface_count() == 1:
			var arrays: Array = mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var min_x := INF
			var max_x := -INF
			var min_z := INF
			var max_z := -INF
			var playable_vertex_count := 0
			var expected_y := 5.0 * HEIGHT_SCALE
			for v in verts:
				min_x = min(min_x, v.x)
				max_x = max(max_x, v.x)
				min_z = min(min_z, v.z)
				max_z = max(max_z, v.z)
				if is_equal_approx(v.y, expected_y) and v.x >= SECTOR_SIZE and v.x <= 2.0 * SECTOR_SIZE and v.z >= SECTOR_SIZE and v.z <= 2.0 * SECTOR_SIZE:
					playable_vertex_count += 1
			_check(is_equal_approx(min_x, 0.0), "Bordered terrain should start at x=0")
			_check(is_equal_approx(max_x, float(w + 2) * SECTOR_SIZE), "Bordered terrain should end at (w+2)*SECTOR_SIZE")
			_check(is_equal_approx(min_z, 0.0), "Bordered terrain should start at z=0")
			_check(is_equal_approx(max_z, float(h + 2) * SECTOR_SIZE), "Bordered terrain should end at (h+2)*SECTOR_SIZE")
			_check(idxs.size() == 9 * 2 * 3, "A 1x1 map should render the full 3x3 bordered footprint")
			_check(playable_vertex_count >= 4, "The inner playable sector should still use its own hgt_map cell height sample")
	return _errors.is_empty()

func test_invalid_input_returns_empty_mesh() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = Map3DRendererScript.build_mesh(PackedByteArray(), 0, 0)
	_check(mesh is ArrayMesh, "Did not return ArrayMesh instance")
	if mesh is ArrayMesh:
		_check(mesh.get_surface_count() == 0, "Expected 0 surfaces for invalid input")
	return _errors.is_empty()

func test_facade_contract_exposes_expected_runtime_surface() -> bool:
	_reset_errors()
	var renderer := Map3DRendererScript.new()
	var contract: Dictionary = Map3DRendererScript.facade_contract()
	var runtime_fields: Array = Array(contract.get("runtime_fields", []))
	var instance_api: Array = Array(contract.get("instance_api", []))
	var static_api: Array = Array(contract.get("static_api", []))
	var compatibility_instance_api: Array = Array(contract.get("compatibility_instance_api", []))
	var compatibility_static_api: Array = Array(contract.get("compatibility_static_api", []))
	var property_names := {}
	for property_value in renderer.get_property_list():
		if typeof(property_value) != TYPE_DICTIONARY:
			continue
		var property_name := String(Dictionary(property_value).get("name", ""))
		if property_name.is_empty():
			continue
		property_names[property_name] = true
	for field_name in ["is_building_3d", "completed_chunks", "total_chunks", "status_text"]:
		_check(runtime_fields.has(field_name), "Facade contract should list runtime field %s" % field_name)
		_check(property_names.has(field_name), "Renderer should expose runtime field %s" % field_name)
	for method_name in [
		"set_event_system_override",
		"set_current_map_data_override",
		"set_editor_state_override",
		"set_preloads_override",
		"get_build_state_snapshot",
		"has_pending_refresh",
		"get_last_build_metrics",
		"build_from_current_map",
		"clear",
		"mark_sector_dirty",
		"mark_sectors_dirty",
		"get_dirty_chunk_count",
		"is_using_chunked_terrain",
		"set_chunked_terrain_enabled",
	]:
		_check(instance_api.has(method_name), "Facade contract should list instance API %s" % method_name)
		_check(renderer.has_method(method_name), "Renderer should expose instance API %s" % method_name)
	for method_name in [
		"facade_contract",
		"visibility_range_fade_start",
		"visibility_range_config",
		"apply_visibility_range_to_environment",
		"build_mesh",
		"build_mesh_with_textures",
	]:
		_check(static_api.has(method_name), "Facade contract should list static API %s" % method_name)
	for method_name in ["_apply_pending_refresh", "_build_edge_overlay_result"]:
		_check(compatibility_instance_api.has(method_name), "Facade contract should list compatibility instance API %s" % method_name)
		_check(renderer.has_method(method_name), "Renderer should expose compatibility instance API %s" % method_name)
	for method_name in [
		"_building_definition_for_id_and_sec_type",
		"_visproto_base_names_for_set",
		"_base_name_from_visproto_index",
		"_building_attachment_base_name_for_vehicle",
		"_squad_base_name_for_vehicle",
		"_build_host_station_descriptors",
		"_build_squad_descriptors",
	]:
		_check(compatibility_static_api.has(method_name), "Facade contract should list compatibility static API %s" % method_name)
	return _errors.is_empty()

func test_get_build_state_snapshot_reflects_emitted_build_state() -> bool:
	_reset_errors()
	var renderer := Map3DRendererScript.new()
	var initial_snapshot := renderer.get_build_state_snapshot()
	_check(not bool(initial_snapshot.get("is_building_3d", true)), "Initial snapshot should report no active 3D build")
	_check(int(initial_snapshot.get("completed_chunks", -1)) == 0, "Initial snapshot should start with 0 completed chunks")
	_check(int(initial_snapshot.get("total_chunks", -1)) == 0, "Initial snapshot should start with 0 total chunks")
	_check(String(initial_snapshot.get("status_text", "__missing__")) == "", "Initial snapshot should start with empty status text")
	renderer._emit_build_state(true, 2, 5, "Rendering map...")
	var active_snapshot := renderer.get_build_state_snapshot()
	_check(bool(active_snapshot.get("is_building_3d", false)), "Active snapshot should report a running 3D build")
	_check(int(active_snapshot.get("completed_chunks", -1)) == 2, "Active snapshot should report completed chunk count")
	_check(int(active_snapshot.get("total_chunks", -1)) == 5, "Active snapshot should report total chunk count")
	_check(String(active_snapshot.get("status_text", "")) == "Rendering map...", "Active snapshot should report current status text")
	renderer._end_build_state(true, "Done")
	var finished_snapshot := renderer.get_build_state_snapshot()
	_check(not bool(finished_snapshot.get("is_building_3d", true)), "Finished snapshot should report no active 3D build")
	_check(int(finished_snapshot.get("completed_chunks", -1)) == 2, "Finished snapshot should preserve completed chunk count")
	_check(int(finished_snapshot.get("total_chunks", -1)) == 5, "Finished snapshot should preserve total chunk count")
	_check(String(finished_snapshot.get("status_text", "")) == "Done", "Finished snapshot should report final status text")
	return _errors.is_empty()

func run() -> int:
	var failures := 0
	var tests := [
		"test_build_mesh_2x2_flat",
		"test_build_mesh_1x1_uses_cell_height_not_border_corners",
		"test_invalid_input_returns_empty_mesh",
		"test_facade_contract_exposes_expected_runtime_surface",
		"test_get_build_state_snapshot_reflects_emitted_build_state",
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

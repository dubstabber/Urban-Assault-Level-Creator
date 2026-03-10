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

func run() -> int:
	var failures := 0
	var tests := [
		"test_build_mesh_2x2_flat",
		"test_build_mesh_1x1_uses_cell_height_not_border_corners",
		"test_invalid_input_returns_empty_mesh",
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


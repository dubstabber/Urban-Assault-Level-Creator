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

func test_build_mesh_2x2_flat() -> bool:
	_reset_errors()
	var w := 2
	var h := 2
	var hgt := _make_hgt(w, h, 0)
	var mesh := Map3DRendererScript.build_mesh(hgt, w, h)
	_check(mesh != null, "Mesh is null")
	if mesh:
		_check(mesh.get_surface_count() == 1, "Surface count should be 1")
		if mesh.get_surface_count() == 1:
			var arrays := mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			# 18 triangles per sector (center + 4 edges + 4 corners = 9 quads) * (w+2)*(h+2) sectors
			var sectors := (w + 2) * (h + 2)
			var expected_tris := 18 * sectors
			_check(idxs.size() == expected_tris * 3, "Unexpected index count for 2x2 flat (expected %d, got %d)" % [expected_tris * 3, idxs.size()])
			# All Y should be 0 for flat map (unique vertices array)
			for v in verts:
				_check(is_equal_approx(v.y, 0.0), "Flat mesh vertex Y not 0")
	return _errors.is_empty()

func test_build_mesh_1x1_center_height() -> bool:
	_reset_errors()
	var w := 1
	var h := 1
	var bw := w + 2
	var bh := h + 2
	var hgt := PackedByteArray()
	hgt.resize(bw * bh)
	# Set corners for the single tile (x=0,y=0)
	# Indices per Map3DRenderer.build_mesh():
	# bx=1, by=1
	# i_nw=4, i_ne=5, i_se=8, i_sw=7
	hgt[4] = 0
	hgt[5] = 255
	hgt[8] = 255
	hgt[7] = 0
	var mesh := Map3DRendererScript.build_mesh(hgt, w, h)
	_check(mesh != null, "Mesh is null")
	if mesh:
		_check(mesh.get_surface_count() == 1, "Surface count should be 1")
		if mesh.get_surface_count() == 1:
			var arrays := mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# With borders, full grid is (w+2) x (h+2). Check top edge (z = 0) exists and spans 0..(w+2)*SECTOR_SIZE
			var min_x := INF
			var max_x := -INF
			var min_z := INF
			for v in verts:
				min_x = min(min_x, v.x)
				max_x = max(max_x, v.x)
				min_z = min(min_z, v.z)
			# Expect top row at z = 0 and right edge at (w+2)*SECTOR_SIZE
			var expected_max_x := float(w + 2) * SECTOR_SIZE
			var expected_min_z := 0.0
			_check(is_equal_approx(min_x, 0.0), "Min X not 0 with borders")
			_check(is_equal_approx(max_x, expected_max_x), "Max X not (w+2)*SECTOR_SIZE")
			_check(is_equal_approx(min_z, expected_min_z), "Min Z not 0 (should be +Z downward)")
	return _errors.is_empty()

func test_invalid_input_returns_empty_mesh() -> bool:
	_reset_errors()
	var mesh := Map3DRendererScript.build_mesh(PackedByteArray(), 0, 0)
	_check(mesh is ArrayMesh, "Did not return ArrayMesh instance")
	if mesh is ArrayMesh:
		_check(mesh.get_surface_count() == 0, "Expected 0 surfaces for invalid input")
	return _errors.is_empty()

func run() -> int:
	var failures := 0
	var tests := [
		"test_build_mesh_2x2_flat",
		"test_build_mesh_1x1_center_height",
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


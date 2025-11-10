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
			# 4 tris per tile * 4 tiles * 3 verts = 48
			_check(verts.size() == 4 * 4 * 3, "Unexpected vertex count for 2x2 flat")
			# All Y should be 0 for flat map
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
			# First triangle is (nw, ne, c) so index 2 is center
			var center := verts[2]
			var expected_center_y := (float(hgt[4]) + float(hgt[5]) + float(hgt[8]) + float(hgt[7])) * 0.25 * HEIGHT_SCALE
			_check(is_equal_approx(center.y, expected_center_y), "Center Y not average of corners")
			# Also check corner positions scale/orientation
			var nw := verts[0]
			var ne := verts[1]
			_check(is_equal_approx(nw.x, 0.0), "NW x not 0")
			_check(is_equal_approx(ne.x, SECTOR_SIZE), "NE x not sector size")
			_check(is_equal_approx(nw.z, 0.0), "NW z not 0")
			_check(is_equal_approx(ne.z, 0.0), "NE z not 0")
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


extends SceneTree

const TerrainBuilder := preload("res://map/map_3d_terrain_builder.gd")
const SlurpBuilder := preload("res://map/map_3d_slurp_builder.gd")
const RendererScript := preload("res://map/map_3d_renderer.gd")
const PieceLibrary := preload("res://map/terrain/ua_authored_piece_library.gd")

const SET_ID := 1

var _failures := 0


func _initialize() -> void:
	print("[Test3DSeam] Starting seam regression tests")
	_run_vertical_slurp_offset_tests()
	_run_horizontal_slurp_offset_tests()
	if _failures == 0:
		print("[Test3DSeam] PASS")
	else:
		push_error("[Test3DSeam] FAILURES=%d" % _failures)
	quit(_failures)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[Test3DSeam] " + message)


func _make_hgt(w: int, h: int, value: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize((w + 2) * (h + 2))
	for i in out.size():
		out[i] = value
	return out


func _find_authored_slurp_pair(vertical: bool) -> Dictionary:
	for sa in 6:
		for sb in 6:
			var base_name := SlurpBuilder._authored_slurp_base_name(sa, sb, vertical)
			if PieceLibrary.has_piece_source(SET_ID, base_name):
				return {"sa": sa, "sb": sb, "base_name": base_name}
	return {}


func _collect_slurp_descriptors(descriptors: Array, prefix: String) -> Array:
	var out: Array = []
	for d_any in descriptors:
		if typeof(d_any) != TYPE_DICTIONARY:
			continue
		var d := d_any as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.begins_with(prefix):
			out.append(d)
	return out


func _assert_descriptor_offsets(descriptors: Array, label: String) -> void:
	_assert_true(descriptors.size() > 0, "%s should emit slurp descriptors" % label)
	var expected := TerrainBuilder.TERRAIN_AUTHORED_Y_OFFSET
	for d_any in descriptors:
		var d := d_any as Dictionary
		_assert_true(d.has("y_offset"), "%s descriptor missing y_offset: %s" % [label, String(d.get("instance_key", ""))])
		var actual := float(d.get("y_offset", -9999.0))
		_assert_true(is_equal_approx(actual, expected), "%s descriptor y_offset=%s expected=%s key=%s" % [label, str(actual), str(expected), String(d.get("instance_key", ""))])


func _run_vertical_slurp_offset_tests() -> void:
	var pair := _find_authored_slurp_pair(true)
	_assert_true(not pair.is_empty(), "No authored vertical slurp pair found for set %d" % SET_ID)
	if pair.is_empty():
		return
	var sa := int(pair["sa"])
	var sb := int(pair["sb"])
	var w := 2
	var h := 1
	var hgt := _make_hgt(w, h, 12)
	var typ := PackedByteArray([10, 11])
	var mapping := {10: sa, 11: sb}

	var full := SlurpBuilder.build_edge_overlay_result(hgt, w, h, typ, mapping, SET_ID)
	var full_descriptors := _collect_slurp_descriptors(full.get("authored_piece_descriptors", []), "slurp:v:")
	_assert_descriptor_offsets(full_descriptors, "slurp_builder full vertical")

	var chunk := SlurpBuilder.build_chunk_edge_overlay_result(Vector2i(0, 0), hgt, w, h, typ, mapping, SET_ID)
	var chunk_descriptors := _collect_slurp_descriptors(chunk.get("authored_piece_descriptors", []), "slurp:v:")
	_assert_descriptor_offsets(chunk_descriptors, "slurp_builder chunk vertical")

	var renderer := RendererScript.new()
	var renderer_result := renderer._build_edge_overlay_result(hgt, w, h, typ, mapping, SET_ID, null)
	var renderer_descriptors := _collect_slurp_descriptors(renderer_result.get("authored_piece_descriptors", []), "slurp:v:")
	_assert_descriptor_offsets(renderer_descriptors, "renderer full vertical")
	renderer.free()


func _run_horizontal_slurp_offset_tests() -> void:
	var pair := _find_authored_slurp_pair(false)
	_assert_true(not pair.is_empty(), "No authored horizontal slurp pair found for set %d" % SET_ID)
	if pair.is_empty():
		return
	var sa := int(pair["sa"])
	var sb := int(pair["sb"])
	var w := 1
	var h := 2
	var hgt := _make_hgt(w, h, 12)
	var typ := PackedByteArray([10, 11])
	var mapping := {10: sa, 11: sb}

	var full := SlurpBuilder.build_edge_overlay_result(hgt, w, h, typ, mapping, SET_ID)
	var full_descriptors := _collect_slurp_descriptors(full.get("authored_piece_descriptors", []), "slurp:h:")
	_assert_descriptor_offsets(full_descriptors, "slurp_builder full horizontal")

	var chunk := SlurpBuilder.build_chunk_edge_overlay_result(Vector2i(0, 0), hgt, w, h, typ, mapping, SET_ID)
	var chunk_descriptors := _collect_slurp_descriptors(chunk.get("authored_piece_descriptors", []), "slurp:h:")
	_assert_descriptor_offsets(chunk_descriptors, "slurp_builder chunk horizontal")

	var renderer := RendererScript.new()
	var renderer_result := renderer._build_edge_overlay_result(hgt, w, h, typ, mapping, SET_ID, null)
	var renderer_descriptors := _collect_slurp_descriptors(renderer_result.get("authored_piece_descriptors", []), "slurp:h:")
	_assert_descriptor_offsets(renderer_descriptors, "renderer full horizontal")
	renderer.free()

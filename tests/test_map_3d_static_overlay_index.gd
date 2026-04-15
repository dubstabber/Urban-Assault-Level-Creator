extends RefCounted

const StaticOverlayIndex = preload("res://map/3d/services/map_3d_static_overlay_index.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func test_terrain_prefixes_for_chunks_keep_middle_chunk_slurp_ranges_local() -> bool:
	_reset_errors()
	var prefixes: Array[String] = StaticOverlayIndex.terrain_prefixes_for_chunks(1, [Vector2i(1, 0)], 8, 8)
	_check(prefixes.has("slurp:v:1:4:0:"), "Expected middle chunk to invalidate its owned vertical seam prefixes")
	_check(not prefixes.has("slurp:v:1:3:0:"), "Middle chunk should not invalidate vertical seams owned by the left neighbor")
	_check(prefixes.has("slurp:h:1:4:0:"), "Expected middle chunk to invalidate its owned horizontal seam prefixes")
	_check(not prefixes.has("slurp:h:1:3:0:"), "Middle chunk should not invalidate horizontal seams owned by the left neighbor")
	return _errors.is_empty()


func test_terrain_prefixes_for_chunks_keep_top_left_border_ownership() -> bool:
	_reset_errors()
	var prefixes: Array[String] = StaticOverlayIndex.terrain_prefixes_for_chunks(1, [Vector2i(0, 0)], 8, 8)
	_check(prefixes.has("slurp:v:1:-1:-1:"), "Top-left chunk should still invalidate border-owned vertical seams")
	_check(prefixes.has("slurp:h:1:-1:-1:"), "Top-left chunk should still invalidate border-owned horizontal seams")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_terrain_prefixes_for_chunks_keep_middle_chunk_slurp_ranges_local",
		"test_terrain_prefixes_for_chunks_keep_top_left_border_ownership",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

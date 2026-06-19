extends RefCounted

# Validates the pure helpers that back 2D visible-sector culling:
#  - playable_index / border_index must match the original linear-count order
#    used by map_renderer._draw() and input_handler._find_clicked_sector().
#  - compute_visible_sector_range must produce a clamped, margin-padded range.

const MapRenderer := preload("res://map/map_renderer.gd")
const SECTOR := 1200

var _errors: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("[MapRendererCullingTest] " + msg)
		_errors.append(msg)


func run() -> int:
	_errors.clear()
	_test_index_helpers()
	_test_range_degenerate()
	_test_range_full_coverage()
	_test_range_zoomed_subset()
	_test_range_off_map_is_empty()
	if _errors.is_empty():
		print("[MapRendererCullingTest] OK")
	return _errors.size()


# Brute-force the exact counters the original renderer/input used: row-major over
# the (w+2) x (h+2) footprint, incrementing the playable counter only inside the
# 1..w, 1..h playable region.
func _brute(w: int, h: int) -> Dictionary:
	var border := {}
	var playable := {}
	var sector_counter := 0
	var border_counter := 0
	for y in range(0, h + 2):
		for x in range(0, w + 2):
			border[Vector2i(x, y)] = border_counter
			if x > 0 and x <= w and y > 0 and y <= h:
				playable[Vector2i(x, y)] = sector_counter
				sector_counter += 1
			border_counter += 1
	return {"border": border, "playable": playable}


func _test_index_helpers() -> void:
	var sizes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 3), Vector2i(8, 8), Vector2i(16, 9), Vector2i(64, 64)]
	for size in sizes:
		var w := size.x
		var h := size.y
		var expected: Dictionary = _brute(w, h)
		var border: Dictionary = expected["border"]
		var playable: Dictionary = expected["playable"]
		for cell in border:
			var got_b: int = MapRenderer.border_index(cell.x, cell.y, w)
			_check(got_b == border[cell],
				"border_index(%d,%d,w=%d)=%d expected %d" % [cell.x, cell.y, w, got_b, border[cell]])
		for cell in playable:
			var got_p: int = MapRenderer.playable_index(cell.x, cell.y, w)
			_check(got_p == playable[cell],
				"playable_index(%d,%d,w=%d)=%d expected %d" % [cell.x, cell.y, w, got_p, playable[cell]])


func _test_range_degenerate() -> void:
	# Zero/negative zoom or view size => whole grid (safe fallback).
	var total_h := 6
	var total_v := 6
	var r := MapRenderer.compute_visible_sector_range(
		Vector2(3600, 3600), Vector2(0, 0), Vector2(800, 600), total_h, total_v, 1, SECTOR)
	_check(r == Rect2i(0, 0, total_h, total_v), "degenerate zoom should return full grid, got %s" % r)
	var r2 := MapRenderer.compute_visible_sector_range(
		Vector2(3600, 3600), Vector2(0.1, 0.1), Vector2(0, 0), total_h, total_v, 1, SECTOR)
	_check(r2 == Rect2i(0, 0, total_h, total_v), "degenerate view should return full grid, got %s" % r2)


func _test_range_full_coverage() -> void:
	# View far larger than the map => clamps to the full grid.
	var w := 4
	var total_h := w + 2
	var total_v := w + 2
	var center := Vector2(total_h * SECTOR * 0.5, total_v * SECTOR * 0.5)
	var r := MapRenderer.compute_visible_sector_range(
		center, Vector2(1, 1), Vector2(100000, 100000), total_h, total_v, 1, SECTOR)
	_check(r == Rect2i(0, 0, total_h, total_v), "full coverage expected full grid, got %s" % r)


func _test_range_zoomed_subset() -> void:
	# Centered on a 4x4 (footprint 6x6) map, half-extent 300 world units, +1 margin.
	# Visible sectors at 3300..3900 => sectors 2,3; margin expands to 1..4 => [1,5).
	var total := 6
	var r := MapRenderer.compute_visible_sector_range(
		Vector2(3600, 3600), Vector2(2, 2), Vector2(1200, 1200), total, total, 1, SECTOR)
	_check(r == Rect2i(1, 1, 4, 4), "zoomed subset expected Rect2i(1,1,4,4), got %s" % r)

	# Same window, no margin => only sectors 2,3 in each axis => [2,4).
	var r0 := MapRenderer.compute_visible_sector_range(
		Vector2(3600, 3600), Vector2(2, 2), Vector2(1200, 1200), total, total, 0, SECTOR)
	_check(r0 == Rect2i(2, 2, 2, 2), "zoomed subset (no margin) expected Rect2i(2,2,2,2), got %s" % r0)


func _test_range_off_map_is_empty() -> void:
	# Camera fully past the map => clamped, empty (size 0) range, in-bounds origin.
	var total := 6
	var r := MapRenderer.compute_visible_sector_range(
		Vector2(100000, 100000), Vector2(2, 2), Vector2(1200, 1200), total, total, 1, SECTOR)
	_check(r.size.x == 0 and r.size.y == 0, "off-map range should be empty, got %s" % r)
	_check(r.position.x >= 0 and r.position.x <= total and r.position.y >= 0 and r.position.y <= total,
		"off-map range origin should stay in bounds, got %s" % r)

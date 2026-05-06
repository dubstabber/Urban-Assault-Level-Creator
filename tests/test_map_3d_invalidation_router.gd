extends RefCounted

const Router := preload("res://map/3d/services/map_3d_invalidation_router.gd")
const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")

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


func test_hgt_border_indices_expand_to_localized_sectors_and_chunks() -> bool:
	_reset_errors()
	var result := Router.invalidation_for_hgt_border_indices([0], 8, 8)
	var sectors: Array = result.get("dirty_sectors", [])
	var chunks: Array = result.get("dirty_chunks", [])
	_check(bool(result.get("localized", false)), "Expected hgt invalidation to stay localized")
	_check(not bool(result.get("effective_typ_dirty", true)), "Expected hgt invalidation to keep effective typ cache reusable")
	_check(sectors.has(Vector2i(0, 0)), "Expected top-left playable sector to be marked dirty for top-left border edit")
	_check(chunks.has(ChunkGrid.sector_to_chunk(0, 0)), "Expected top-left chunk to be marked dirty for top-left border edit")
	return _errors.is_empty()


func test_typ_indices_mark_effective_typ_dirty_and_primary_chunk() -> bool:
	_reset_errors()
	var result := Router.invalidation_for_typ_indices([4 * 8 + 3], 8, 8)
	var sectors: Array = result.get("dirty_sectors", [])
	var chunks: Array = result.get("dirty_chunks", [])
	_check(bool(result.get("effective_typ_dirty", false)), "Expected typ invalidation to dirty effective typ cache")
	_check(sectors.has(Vector2i(3, 4)), "Expected edited typ sector to be tracked")
	_check(chunks.has(ChunkGrid.sector_to_chunk(3, 4)), "Expected edited typ sector chunk to be tracked")
	return _errors.is_empty()


func test_blg_indices_use_primary_chunk_neighborhood_only() -> bool:
	_reset_errors()
	var result := Router.invalidation_for_blg_indices([1 * 8 + 6], 8, 8)
	var chunks: Array = result.get("dirty_chunks", [])
	_check_eq(chunks.size(), 1, "Expected blg invalidation to target only the primary chunk for a single-sector edit")
	_check(chunks.has(ChunkGrid.sector_to_chunk(6, 1)), "Expected primary chunk for blg edit to be included")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for name in [
		"test_hgt_border_indices_expand_to_localized_sectors_and_chunks",
		"test_typ_indices_mark_effective_typ_dirty_and_primary_chunk",
		"test_blg_indices_use_primary_chunk_neighborhood_only",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

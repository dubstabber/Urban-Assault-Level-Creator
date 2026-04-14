extends RefCounted

# Unit tests for Map3DChunkRuntime
# Run via: godot4 --headless -s res://tests/test_runner.gd

const ChunkRuntimeScript = preload("res://map/map_3d_chunk_runtime.gd")
const TerrainBuilder = preload("res://map/map_3d_terrain_builder.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var detail := "%s  (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(detail)
		_errors.append(detail)


# ---- Tests ----

func test_initial_state() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	_check_eq(rt.chunked_terrain_enabled, true, "chunked_terrain_enabled default")
	_check_eq(rt.has_dirty_chunks(), false, "No dirty chunks initially")
	_check_eq(rt.get_dirty_chunk_count(), 0, "Dirty count is 0")
	_check_eq(rt.last_map_dimensions, Vector2i.ZERO, "last_map_dimensions default")
	_check_eq(rt.last_level_set, -1, "last_level_set default")
	_check_eq(rt.initial_build_in_progress, false, "initial_build default")
	_check_eq(rt.explicit_chunk_invalidation_pending, false, "explicit_chunk_invalidation default")
	_check_eq(rt.get_support_descriptors().size(), 0, "No support descriptors initially")
	return _errors.is_empty()


func test_dirty_chunk_tracking() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.mark_chunk_dirty(Vector2i(0, 0))
	rt.mark_chunk_dirty(Vector2i(1, 0))
	_check_eq(rt.has_dirty_chunks(), true, "Should have dirty chunks")
	_check_eq(rt.get_dirty_chunk_count(), 2, "Should have 2 dirty chunks")
	rt.erase_dirty_chunk(Vector2i(0, 0))
	_check_eq(rt.get_dirty_chunk_count(), 1, "Should have 1 dirty chunk after erase")
	rt.clear_dirty_chunks()
	_check_eq(rt.has_dirty_chunks(), false, "Should have no dirty chunks after clear")
	return _errors.is_empty()


func test_invalidate_all_chunks() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	# For a 4x4 map with CHUNK_SIZE=4, there should be 1 chunk.
	rt.invalidate_all_chunks(4, 4)
	_check(rt.has_dirty_chunks(), "Should have dirty chunks after invalidate_all")
	_check_eq(rt.explicit_chunk_invalidation_pending, true, "explicit_chunk_invalidation should be true")
	# For an 8x8 map with CHUNK_SIZE=4, there should be 2x2=4 chunks.
	rt.invalidate_all_chunks(8, 8)
	_check_eq(rt.get_dirty_chunk_count(), 4, "8x8 map should have 4 chunks")
	return _errors.is_empty()


func test_invalidate_chunks_for_sector_edit_hgt() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	# Editing sector (0,0) as hgt in a 16x16 map should dirty at least the chunk containing (0,0).
	rt.invalidate_chunks_for_sector_edit(0, 0, 16, 16, "hgt")
	_check(rt.has_dirty_chunks(), "Should have dirty chunks after hgt edit")
	var count := rt.get_dirty_chunk_count()
	_check(count >= 1, "At least 1 chunk dirty for hgt edit at (0,0)")
	return _errors.is_empty()


func test_invalidate_chunks_for_sector_edit_typ() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.invalidate_chunks_for_sector_edit(2, 2, 16, 16, "typ")
	_check(rt.has_dirty_chunks(), "Should have dirty chunks after typ edit")
	return _errors.is_empty()


func test_needs_full_rebuild_dimension_change() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.last_map_dimensions = Vector2i(8, 8)
	rt.last_level_set = 1
	# Same dims, same level_set, has chunk nodes, no dirty chunks -> no rebuild needed
	_check_eq(rt.needs_full_rebuild(8, 8, 1, true), false, "No rebuild needed when nothing changed")
	# Different dims -> needs rebuild
	_check_eq(rt.needs_full_rebuild(16, 16, 1, true), true, "Rebuild needed for dimension change")
	return _errors.is_empty()


func test_needs_full_rebuild_level_set_change() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.last_map_dimensions = Vector2i(8, 8)
	rt.last_level_set = 1
	_check_eq(rt.needs_full_rebuild(8, 8, 2, true), true, "Rebuild needed for level_set change")
	return _errors.is_empty()


func test_needs_full_rebuild_no_chunk_nodes_no_dirty() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.last_map_dimensions = Vector2i(8, 8)
	rt.last_level_set = 1
	# No chunk nodes AND no dirty chunks -> needs rebuild (first-time path)
	_check_eq(rt.needs_full_rebuild(8, 8, 1, false), true, "Rebuild needed when no chunk nodes and no dirty chunks")
	# No chunk nodes but has dirty chunks -> no rebuild (incremental path)
	rt.mark_chunk_dirty(Vector2i(0, 0))
	_check_eq(rt.needs_full_rebuild(8, 8, 1, false), false, "No rebuild when dirty chunks exist")
	return _errors.is_empty()


func test_prepare_chunked_full_rebuild_seeds_dirty_chunks_and_dimensions() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.prepare_chunked_full_rebuild(8, 8, 3)
	_check_eq(rt.last_map_dimensions, Vector2i(8, 8), "Chunked full rebuild should seed map dimensions")
	_check_eq(rt.last_level_set, 3, "Chunked full rebuild should seed level set")
	_check_eq(rt.get_dirty_chunk_count(), TerrainBuilder.all_chunks_for_map(8, 8).size(), "Chunked full rebuild should dirty all chunks for seeding")
	_check_eq(rt.explicit_chunk_invalidation_pending, true, "Chunked full rebuild should mark explicit invalidation pending")
	_check_eq(rt.localized_chunk_invalidation_pending, false, "Chunked full rebuild should not mark localized invalidation")
	return _errors.is_empty()


func test_dirty_chunks_sorted_by_priority() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.mark_chunk_dirty(Vector2i(3, 3))
	rt.mark_chunk_dirty(Vector2i(0, 0))
	rt.mark_chunk_dirty(Vector2i(1, 1))
	# Focus at (0,0) should sort (0,0) first
	var sorted := rt.dirty_chunks_sorted_by_priority(Vector2i(0, 0))
	_check_eq(sorted.size(), 3, "Should have 3 sorted chunks")
	if sorted.size() >= 1:
		_check_eq(sorted[0], Vector2i(0, 0), "Closest chunk should be first")
	if sorted.size() >= 3:
		_check_eq(sorted[2], Vector2i(3, 3), "Farthest chunk should be last")
	return _errors.is_empty()


func test_chunk_distance_sq() -> bool:
	_reset_errors()
	_check_eq(ChunkRuntimeScript.chunk_distance_sq(Vector2i(0, 0), Vector2i(0, 0)), 0, "Same point distance is 0")
	_check_eq(ChunkRuntimeScript.chunk_distance_sq(Vector2i(0, 0), Vector2i(3, 4)), 25, "Distance (0,0)-(3,4) is 25")
	_check_eq(ChunkRuntimeScript.chunk_distance_sq(Vector2i(1, 1), Vector2i(4, 5)), 25, "Distance (1,1)-(4,5) is 25")
	return _errors.is_empty()


func test_authored_cache_update_for_chunk() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	var descs: Array = [
		{"instance_key": "terrain:1:0:0:test", "data": "a"},
		{"instance_key": "terrain:1:0:1:test", "data": "b"},
	]
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), descs)
	var support := rt.get_support_descriptors()
	_check_eq(support.size(), 2, "Should have 2 support descriptors")
	# Update same chunk with different descriptors
	var descs2: Array = [
		{"instance_key": "terrain:1:0:0:test", "data": "a_updated"},
	]
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), descs2)
	support = rt.get_support_descriptors()
	_check_eq(support.size(), 1, "Should have 1 descriptor after chunk update (old key removed)")
	return _errors.is_empty()


func test_authored_cache_ref_counting_across_chunks() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	# Two chunks share the same key (border overlap scenario)
	var descs_a: Array = [ {"instance_key": "terrain:1:3:3:shared"}]
	var descs_b: Array = [ {"instance_key": "terrain:1:3:3:shared"}]
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), descs_a)
	rt.update_terrain_authored_cache_for_chunk(Vector2i(1, 0), descs_b)
	_check_eq(rt.get_support_descriptors().size(), 1, "Shared key should appear once in values")
	# Remove from one chunk only; key should still exist due to ref count
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), [])
	_check_eq(rt.get_support_descriptors().size(), 1, "Key survives when ref count > 0")
	# Remove from second chunk; key should be gone
	rt.update_terrain_authored_cache_for_chunk(Vector2i(1, 0), [])
	_check_eq(rt.get_support_descriptors().size(), 0, "Key removed when ref count reaches 0")
	return _errors.is_empty()


func test_clear_authored_caches() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), [ {"instance_key": "terrain:1:0:0:x"}])
	_check_eq(rt.get_support_descriptors().size(), 1, "Should have 1 descriptor")
	rt.clear_authored_caches()
	_check_eq(rt.get_support_descriptors().size(), 0, "Should have 0 after clear")
	return _errors.is_empty()


func test_reset_terrain_authored_cache_from_descriptors() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	# Pre-populate cache to verify it gets cleared
	rt.update_terrain_authored_cache_for_chunk(Vector2i(0, 0), [ {"instance_key": "old:key"}])
	# Reset with new descriptors for a 4x4 map
	var descs: Array = [
		{"instance_key": "terrain:1:0:0:piece_a"},
		{"instance_key": "terrain:1:2:2:piece_b"},
	]
	rt.reset_terrain_authored_cache_from_descriptors(descs, 4, 4)
	var support := rt.get_support_descriptors()
	_check_eq(support.size(), 2, "Should have 2 descriptors after reset")
	# Old key should be gone
	var has_old := false
	for d in support:
		if d is Dictionary and String(d.get("instance_key", "")) == "old:key":
			has_old = true
	_check_eq(has_old, false, "Old key should be gone after reset")
	return _errors.is_empty()


func test_initial_build_state() -> bool:
	_reset_errors()
	var rt := ChunkRuntimeScript.new()
	_check_eq(rt.initial_build_in_progress, false, "Not building initially")
	rt.initial_build_in_progress = true
	rt.initial_build_accumulated_authored_descriptors.append({"instance_key": "test"})
	_check_eq(rt.initial_build_accumulated_authored_descriptors.size(), 1, "Accumulated 1 descriptor")
	rt.initial_build_in_progress = false
	rt.initial_build_accumulated_authored_descriptors.clear()
	_check_eq(rt.initial_build_accumulated_authored_descriptors.size(), 0, "Cleared accumulated descriptors")
	return _errors.is_empty()


# ---- Runner ----

func run() -> int:
	var tests: Array[String] = [
		"test_initial_state",
		"test_dirty_chunk_tracking",
		"test_invalidate_all_chunks",
		"test_invalidate_chunks_for_sector_edit_hgt",
		"test_invalidate_chunks_for_sector_edit_typ",
		"test_needs_full_rebuild_dimension_change",
		"test_needs_full_rebuild_level_set_change",
		"test_needs_full_rebuild_no_chunk_nodes_no_dirty",
		"test_prepare_chunked_full_rebuild_seeds_dirty_chunks_and_dimensions",
		"test_dirty_chunks_sorted_by_priority",
		"test_chunk_distance_sq",
		"test_authored_cache_update_for_chunk",
		"test_authored_cache_ref_counting_across_chunks",
		"test_clear_authored_caches",
		"test_reset_terrain_authored_cache_from_descriptors",
		"test_initial_build_state",
	]
	var failures := 0
	for test_name in tests:
		if has_method(test_name):
			var result: bool = call(test_name)
			if result:
				print("  PASS: %s" % test_name)
			else:
				print("  FAIL: %s" % test_name)
				failures += 1
		else:
			print("  SKIP: %s (method not found)" % test_name)
	return failures

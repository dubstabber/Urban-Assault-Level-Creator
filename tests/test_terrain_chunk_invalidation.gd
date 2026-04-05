extends RefCounted

const TerrainBuilder := preload("res://map/map_3d_terrain_builder.gd")
const RendererScript := preload("res://map/map_3d_renderer.gd")
# Use scaled SECTOR_SIZE from renderer (WORLD_SCALE = 1/1200)
const SECTOR_SIZE := RendererScript.SECTOR_SIZE

var _errors: Array[String] = []


class CurrentMapDataStub:
	extends Node

	var horizontal_sectors := 0
	var vertical_sectors := 0
	var level_set := 1
	var hgt_map := PackedByteArray()
	var typ_map := PackedByteArray()
	var blg_map := PackedByteArray()


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


func _check_has(arr: Array, item, msg: String) -> void:
	if not arr.has(item):
		var full_msg := "%s (array does not contain %s)" % [msg, str(item)]
		push_error(full_msg)
		_errors.append(full_msg)


func test_chunk_constants() -> bool:
	_reset_errors()
	_check_eq(TerrainBuilder.CHUNK_SIZE, 4, "Chunk size should be 4 sectors")
	_check_eq(TerrainBuilder.CHUNK_SHIFT, 2, "Chunk shift should be log2(4) = 2")
	return _errors.is_empty()


func test_sector_to_chunk_basic() -> bool:
	_reset_errors()
	_check_eq(TerrainBuilder.sector_to_chunk(0, 0), Vector2i(0, 0), "sector (0,0)")
	_check_eq(TerrainBuilder.sector_to_chunk(1, 1), Vector2i(0, 0), "sector (1,1)")
	_check_eq(TerrainBuilder.sector_to_chunk(3, 3), Vector2i(0, 0), "sector (3,3)")
	_check_eq(TerrainBuilder.sector_to_chunk(4, 0), Vector2i(1, 0), "sector (4,0)")
	_check_eq(TerrainBuilder.sector_to_chunk(0, 4), Vector2i(0, 1), "sector (0,4)")
	_check_eq(TerrainBuilder.sector_to_chunk(7, 7), Vector2i(1, 1), "sector (7,7)")
	_check_eq(TerrainBuilder.sector_to_chunk(8, 8), Vector2i(2, 2), "sector (8,8)")
	return _errors.is_empty()


func test_chunk_sector_range() -> bool:
	_reset_errors()
	var range_0_0 := TerrainBuilder.chunk_sector_range(0, 0)
	_check_eq(range_0_0.position, Vector2i(0, 0), "chunk (0,0) position")
	_check_eq(range_0_0.size, Vector2i(4, 4), "chunk (0,0) size")
	
	var range_1_0 := TerrainBuilder.chunk_sector_range(1, 0)
	_check_eq(range_1_0.position, Vector2i(4, 0), "chunk (1,0) position")
	_check_eq(range_1_0.size, Vector2i(4, 4), "chunk (1,0) size")
	
	var range_2_3 := TerrainBuilder.chunk_sector_range(2, 3)
	_check_eq(range_2_3.position, Vector2i(8, 12), "chunk (2,3) position")
	_check_eq(range_2_3.size, Vector2i(4, 4), "chunk (2,3) size")
	return _errors.is_empty()


func test_chunk_count_for_map() -> bool:
	_reset_errors()
	_check_eq(TerrainBuilder.chunk_count_for_map(0, 0), Vector2i.ZERO, "0x0 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(4, 4), Vector2i(1, 1), "4x4 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(8, 8), Vector2i(2, 2), "8x8 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(5, 5), Vector2i(2, 2), "5x5 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(16, 16), Vector2i(4, 4), "16x16 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(64, 64), Vector2i(16, 16), "64x64 map")
	_check_eq(TerrainBuilder.chunk_count_for_map(17, 9), Vector2i(5, 3), "17x9 map")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_interior_sector() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(1, 1, 16, 16)
	_check_eq(chunks.size(), 1, "interior sector dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_left_edge() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(4, 2, 16, 16)
	_check_eq(chunks.size(), 2, "left edge dirty count")
	_check_has(chunks, Vector2i(1, 0), "primary chunk")
	_check_has(chunks, Vector2i(0, 0), "left neighbor")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_right_edge() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(3, 2, 16, 16)
	_check_eq(chunks.size(), 2, "right edge dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk")
	_check_has(chunks, Vector2i(1, 0), "right neighbor")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_top_edge() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(2, 4, 16, 16)
	_check_eq(chunks.size(), 2, "top edge dirty count")
	_check_has(chunks, Vector2i(0, 1), "primary chunk")
	_check_has(chunks, Vector2i(0, 0), "top neighbor")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_bottom_edge() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(2, 3, 16, 16)
	_check_eq(chunks.size(), 2, "bottom edge dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk")
	_check_has(chunks, Vector2i(0, 1), "bottom neighbor")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_corner() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(3, 3, 16, 16)
	_check_eq(chunks.size(), 4, "corner dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk")
	_check_has(chunks, Vector2i(1, 0), "right neighbor")
	_check_has(chunks, Vector2i(0, 1), "bottom neighbor")
	_check_has(chunks, Vector2i(1, 1), "diagonal neighbor")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_map_edge_no_neighbor() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(0, 2, 16, 16)
	_check_eq(chunks.size(), 1, "map left edge dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk only")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_map_corner_no_neighbors() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(0, 0, 16, 16)
	_check_eq(chunks.size(), 1, "map corner dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk only")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_last_chunk_right_edge() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(15, 2, 16, 16)
	_check_eq(chunks.size(), 1, "last chunk right edge dirty count")
	_check_has(chunks, Vector2i(3, 0), "primary chunk only")
	return _errors.is_empty()


func test_chunks_for_hgt_edit_out_of_bounds() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_hgt_edit(-1, 0, 16, 16)
	_check_eq(chunks.size(), 0, "out of bounds x<0")
	
	chunks = TerrainBuilder.chunks_for_hgt_edit(16, 0, 16, 16)
	_check_eq(chunks.size(), 0, "out of bounds x>=w")
	
	chunks = TerrainBuilder.chunks_for_hgt_edit(0, -1, 16, 16)
	_check_eq(chunks.size(), 0, "out of bounds y<0")
	
	chunks = TerrainBuilder.chunks_for_hgt_edit(0, 16, 16, 16)
	_check_eq(chunks.size(), 0, "out of bounds y>=h")
	return _errors.is_empty()


func test_chunks_for_typ_edit_same_as_hgt() -> bool:
	_reset_errors()
	var hgt_chunks := TerrainBuilder.chunks_for_hgt_edit(3, 3, 16, 16)
	var typ_chunks := TerrainBuilder.chunks_for_typ_edit(3, 3, 16, 16)
	_check_eq(hgt_chunks.size(), typ_chunks.size(), "typ same size as hgt")
	for chunk in hgt_chunks:
		_check_has(typ_chunks, chunk, "typ contains hgt chunk")
	return _errors.is_empty()


func test_chunks_for_blg_edit_primary_only() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.chunks_for_blg_edit(3, 3, 16, 16)
	_check_eq(chunks.size(), 1, "blg interior dirty count")
	_check_has(chunks, Vector2i(0, 0), "primary chunk")
	
	chunks = TerrainBuilder.chunks_for_blg_edit(4, 4, 16, 16)
	_check_eq(chunks.size(), 1, "blg boundary dirty count")
	_check_has(chunks, Vector2i(1, 1), "primary chunk only")
	return _errors.is_empty()


func test_all_chunks_for_map() -> bool:
	_reset_errors()
	var chunks := TerrainBuilder.all_chunks_for_map(8, 8)
	_check_eq(chunks.size(), 4, "8x8 map chunk count")
	_check_has(chunks, Vector2i(0, 0), "chunk (0,0)")
	_check_has(chunks, Vector2i(1, 0), "chunk (1,0)")
	_check_has(chunks, Vector2i(0, 1), "chunk (0,1)")
	_check_has(chunks, Vector2i(1, 1), "chunk (1,1)")
	
	chunks = TerrainBuilder.all_chunks_for_map(16, 16)
	_check_eq(chunks.size(), 16, "16x16 map chunk count")
	
	chunks = TerrainBuilder.all_chunks_for_map(0, 0)
	_check_eq(chunks.size(), 0, "0x0 map chunk count")
	return _errors.is_empty()


func test_small_map_chunk_coverage() -> bool:
	_reset_errors()
	var chunk_count := TerrainBuilder.chunk_count_for_map(8, 8)
	_check_eq(chunk_count, Vector2i(2, 2), "8x8 chunk count")
	
	for sy in 8:
		for sx in 8:
			var chunk := TerrainBuilder.sector_to_chunk(sx, sy)
			_check(chunk.x >= 0 and chunk.x < chunk_count.x, "Chunk X in bounds for sector (%d, %d)" % [sx, sy])
			_check(chunk.y >= 0 and chunk.y < chunk_count.y, "Chunk Y in bounds for sector (%d, %d)" % [sx, sy])
	return _errors.is_empty()


func test_large_map_chunk_coverage() -> bool:
	_reset_errors()
	var chunk_count := TerrainBuilder.chunk_count_for_map(64, 64)
	_check_eq(chunk_count, Vector2i(16, 16), "64x64 chunk count")
	
	_check_eq(TerrainBuilder.sector_to_chunk(0, 0), Vector2i(0, 0), "corner (0,0)")
	_check_eq(TerrainBuilder.sector_to_chunk(63, 0), Vector2i(15, 0), "corner (63,0)")
	_check_eq(TerrainBuilder.sector_to_chunk(0, 63), Vector2i(0, 15), "corner (0,63)")
	_check_eq(TerrainBuilder.sector_to_chunk(63, 63), Vector2i(15, 15), "corner (63,63)")
	return _errors.is_empty()


func test_non_power_of_two_map() -> bool:
	_reset_errors()
	var chunk_count := TerrainBuilder.chunk_count_for_map(17, 9)
	_check_eq(chunk_count, Vector2i(5, 3), "17x9 chunk count")
	_check_eq(TerrainBuilder.sector_to_chunk(16, 8), Vector2i(4, 2), "sector (16,8)")
	return _errors.is_empty()


func test_chunk_mesh_build_produces_valid_mesh() -> bool:
	_reset_errors()
	var w := 8
	var h := 8
	var hgt := _make_hgt(w, h, 0)
	var typ := _make_typ(w, h, 0)
	var mapping := {0: 0}
	
	var result := TerrainBuilder.build_chunk_mesh_with_textures(
		Vector2i(0, 0),
		hgt,
		typ,
		w,
		h,
		mapping,
		{},
		{},
		{},
		{},
		{},
		1,
		true
	)
	_check(result.has("mesh"), "chunk result should have mesh")
	_check(result.has("surface_to_surface_type"), "chunk result should have surface_to_surface_type")
	_check(result.has("authored_piece_descriptors"), "chunk result should have authored_piece_descriptors")
	var mesh: ArrayMesh = result.get("mesh")
	_check(mesh != null, "chunk mesh should not be null")
	if mesh:
		_check(mesh.get_surface_count() > 0, "chunk mesh should have surfaces")
	return _errors.is_empty()


func test_chunk_mesh_only_covers_chunk_sectors() -> bool:
	_reset_errors()
	var w := 16
	var h := 16
	var hgt := _make_hgt(w, h, 0)
	var typ := _make_typ(w, h, 0)
	var mapping := {0: 0}
	
	var chunk_0_0 := TerrainBuilder.build_chunk_mesh_with_textures(
		Vector2i(0, 0), hgt, typ, w, h, mapping, {}, {}, {}, {}, {}, 1, false
	)
	var chunk_1_1 := TerrainBuilder.build_chunk_mesh_with_textures(
		Vector2i(1, 1), hgt, typ, w, h, mapping, {}, {}, {}, {}, {}, 1, false
	)
	
	var mesh_0_0: ArrayMesh = chunk_0_0.get("mesh")
	var mesh_1_1: ArrayMesh = chunk_1_1.get("mesh")
	
	_check(mesh_0_0 != null, "chunk 0,0 mesh not null")
	_check(mesh_1_1 != null, "chunk 1,1 mesh not null")
	
	if mesh_0_0 and mesh_0_0.get_surface_count() > 0:
		var arrays := mesh_0_0.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			# Chunk 0,0 covers sectors 0-3 (playable rows 1-4 in bordered coords)
			_check(v.x >= 1.0 * SECTOR_SIZE and v.x <= 5.0 * SECTOR_SIZE, "chunk 0,0 vertex X in expected range")
			_check(v.z >= 1.0 * SECTOR_SIZE and v.z <= 5.0 * SECTOR_SIZE, "chunk 0,0 vertex Z in expected range")
	
	if mesh_1_1 and mesh_1_1.get_surface_count() > 0:
		var arrays := mesh_1_1.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			# Chunk 1,1 covers sectors 4-7 (playable rows 5-8 in bordered coords)
			_check(v.x >= 5.0 * SECTOR_SIZE and v.x <= 9.0 * SECTOR_SIZE, "chunk 1,1 vertex X in expected range")
			_check(v.z >= 5.0 * SECTOR_SIZE and v.z <= 9.0 * SECTOR_SIZE, "chunk 1,1 vertex Z in expected range")
	
	return _errors.is_empty()


func _make_hgt(w: int, h: int, value: int) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize((w + 2) * (h + 2))
	for i in arr.size():
		arr[i] = value
	return arr


func _make_typ(w: int, h: int, value: int) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(w * h)
	for i in arr.size():
		arr[i] = value
	return arr


func _make_blg(w: int, h: int, value: int) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(w * h)
	for i in arr.size():
		arr[i] = value
	return arr


func test_needs_full_rebuild_empty_chunks() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	_check(renderer._needs_full_rebuild(8, 8, 1), "empty chunk nodes should require full rebuild")
	renderer.free()
	return _errors.is_empty()


func test_needs_full_rebuild_dimension_change() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	renderer._chunk_rt.last_map_dimensions = Vector2i(8, 8)
	renderer._chunk_rt.last_level_set = 1
	renderer._terrain_chunk_nodes[Vector2i(0, 0)] = null
	_check(renderer._needs_full_rebuild(16, 16, 1), "dimension change should require full rebuild")
	_check(not renderer._needs_full_rebuild(8, 8, 1), "same dimensions should not require full rebuild")
	renderer.free()
	return _errors.is_empty()


func test_needs_full_rebuild_level_set_change() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	renderer._chunk_rt.last_map_dimensions = Vector2i(8, 8)
	renderer._chunk_rt.last_level_set = 1
	renderer._terrain_chunk_nodes[Vector2i(0, 0)] = null
	_check(renderer._needs_full_rebuild(8, 8, 2), "level set change should require full rebuild")
	_check(not renderer._needs_full_rebuild(8, 8, 1), "same level set should not require full rebuild")
	renderer.free()
	return _errors.is_empty()


func test_invalidate_all_chunks_marks_all_dirty() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	renderer._invalidate_all_chunks(8, 8)
	var expected_count := 2 * 2
	var dirty_chunks := renderer._chunk_rt.dirty_chunks_sorted_by_priority(Vector2i.ZERO)
	_check_eq(dirty_chunks.size(), expected_count, "8x8 map should have 4 dirty chunks")
	_check(dirty_chunks.has(Vector2i(0, 0)), "chunk 0,0 should be dirty")
	_check(dirty_chunks.has(Vector2i(1, 1)), "chunk 1,1 should be dirty")
	renderer.free()
	return _errors.is_empty()


func test_map_signature_change_invalidates_all_chunks_without_explicit_sector_signals() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	var map_data := CurrentMapDataStub.new()
	map_data.horizontal_sectors = 6
	map_data.vertical_sectors = 6
	map_data.level_set = 1
	map_data.hgt_map = _make_hgt(6, 6, 0)
	map_data.typ_map = _make_typ(6, 6, 12)
	map_data.blg_map = _make_blg(6, 6, 0)
	renderer.set_current_map_data_override(map_data)

	# Seed signature + partial stale dirty set, then mutate typ_map as if a bulk
	# generator/import path changed map data without per-cell edit signals.
	renderer._record_map_signature(6, 6, 1, map_data.hgt_map, map_data.typ_map, map_data.blg_map)
	renderer._chunk_rt.clear_dirty_chunks()
	renderer._chunk_rt.mark_chunk_dirty(Vector2i(1, 0))
	renderer._effective_typ_service.set_dirty(false)
	map_data.typ_map[0] = 99

	renderer._on_map_changed()

	var expected_chunks := TerrainBuilder.all_chunks_for_map(6, 6).size()
	_check_eq(renderer._chunk_rt.get_dirty_chunk_count(), expected_chunks, "Checksum-signature map changes should invalidate all chunks even without explicit sector edit signals")
	_check(renderer._effective_typ_service.dirty, "Checksum-signature map changes should mark effective typ cache dirty")
	renderer.free()
	return _errors.is_empty()


func test_clear_chunk_nodes_resets_state() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	renderer._terrain_chunk_nodes[Vector2i(0, 0)] = null
	renderer._edge_chunk_nodes[Vector2i(0, 0)] = null
	renderer._chunk_rt.mark_chunk_dirty(Vector2i(0, 0))
	renderer._clear_chunk_nodes()
	_check(renderer._terrain_chunk_nodes.is_empty(), "terrain chunk nodes should be empty after clear")
	_check(renderer._edge_chunk_nodes.is_empty(), "edge chunk nodes should be empty after clear")
	_check(not renderer._chunk_rt.has_dirty_chunks(), "dirty chunks should be empty after clear")
	renderer.free()
	return _errors.is_empty()


func test_chunked_terrain_toggle() -> bool:
	_reset_errors()
	var renderer := RendererScript.new()
	_check(renderer.is_using_chunked_terrain(), "chunked terrain should be enabled by default")
	renderer.set_chunked_terrain_enabled(false)
	_check(not renderer.is_using_chunked_terrain(), "chunked terrain should be disabled after toggle")
	renderer.set_chunked_terrain_enabled(true)
	_check(renderer.is_using_chunked_terrain(), "chunked terrain should be re-enabled")
	renderer.free()
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_chunk_constants",
		"test_sector_to_chunk_basic",
		"test_chunk_sector_range",
		"test_chunk_count_for_map",
		"test_chunks_for_hgt_edit_interior_sector",
		"test_chunks_for_hgt_edit_left_edge",
		"test_chunks_for_hgt_edit_right_edge",
		"test_chunks_for_hgt_edit_top_edge",
		"test_chunks_for_hgt_edit_bottom_edge",
		"test_chunks_for_hgt_edit_corner",
		"test_chunks_for_hgt_edit_map_edge_no_neighbor",
		"test_chunks_for_hgt_edit_map_corner_no_neighbors",
		"test_chunks_for_hgt_edit_last_chunk_right_edge",
		"test_chunks_for_hgt_edit_out_of_bounds",
		"test_chunks_for_typ_edit_same_as_hgt",
		"test_chunks_for_blg_edit_primary_only",
		"test_all_chunks_for_map",
		"test_small_map_chunk_coverage",
		"test_large_map_chunk_coverage",
		"test_non_power_of_two_map",
		"test_chunk_mesh_build_produces_valid_mesh",
		"test_chunk_mesh_only_covers_chunk_sectors",
		"test_needs_full_rebuild_empty_chunks",
		"test_needs_full_rebuild_dimension_change",
		"test_needs_full_rebuild_level_set_change",
		"test_invalidate_all_chunks_marks_all_dirty",
		"test_map_signature_change_invalidates_all_chunks_without_explicit_sector_signals",
		"test_clear_chunk_nodes_resets_state",
		"test_chunked_terrain_toggle",
	]
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	print("__FAILURES:%d__" % failures)
	return failures

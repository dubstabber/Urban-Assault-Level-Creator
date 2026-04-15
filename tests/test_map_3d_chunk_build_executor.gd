extends RefCounted

const Executor := preload("res://map/3d/services/map_3d_chunk_build_executor.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")


class ScenePortStub extends RefCounted:
	var terrain_chunks := {}
	var edge_chunks := {}
	var sector_material_calls := 0
	var edge_material_calls := 0

	func get_or_create_terrain_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
		if terrain_chunks.has(chunk_coord):
			return terrain_chunks[chunk_coord]
		var node := MeshInstance3D.new()
		terrain_chunks[chunk_coord] = node
		return node

	func get_or_create_edge_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
		if edge_chunks.has(chunk_coord):
			return edge_chunks[chunk_coord]
		var node := MeshInstance3D.new()
		edge_chunks[chunk_coord] = node
		return node

	func apply_sector_top_materials(_mesh: ArrayMesh, _preloads, _surface_to_surface_type: Dictionary) -> void:
		sector_material_calls += 1

	func apply_edge_surface_materials(_mesh: ArrayMesh, _preloads, _fallback_horiz_keys: Array, _fallback_vert_keys: Array) -> void:
		edge_material_calls += 1


class ChunkRuntimeStub extends RefCounted:
	var updated_chunk := Vector2i(-1, -1)
	var updated_descriptors: Array = []

	func update_terrain_authored_cache_for_chunk(chunk_coord: Vector2i, chunk_descriptors: Array) -> void:
		updated_chunk = chunk_coord
		updated_descriptors = chunk_descriptors.duplicate(true)


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


func _make_flat_hgt(w: int, h: int, value: int = 0) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize((w + 2) * (h + 2))
	for i in range(arr.size()):
		arr[i] = value
	return arr


func test_build_chunk_result_matches_direct_builders() -> bool:
	_reset_errors()
	var w := 6
	var h := 6
	var chunk_coord := Vector2i(0, 0)
	var hgt := _make_flat_hgt(w, h, 0)
	var effective_typ := PackedByteArray()
	effective_typ.resize(w * h)
	for i in range(effective_typ.size()):
		effective_typ[i] = 0

	var chunk_result := Executor.build_chunk_result(
		chunk_coord,
		hgt,
		effective_typ,
		w,
		h,
		Preloads.surface_type_map,
		Preloads.subsector_patterns,
		Preloads.tile_mapping,
		Preloads.tile_remap,
		Preloads.subsector_idx_remap,
		Preloads.lego_defs,
		1,
		true
	)
	var expected_terrain := TerrainBuilder.build_chunk_mesh_with_textures(
		chunk_coord,
		hgt,
		effective_typ,
		w,
		h,
		Preloads.surface_type_map,
		Preloads.subsector_patterns,
		Preloads.tile_mapping,
		Preloads.tile_remap,
		Preloads.subsector_idx_remap,
		Preloads.lego_defs,
		1,
		true
	)
	var expected_edge := SlurpBuilder.build_chunk_edge_overlay_result(
		chunk_coord,
		hgt,
		w,
		h,
		effective_typ,
		Preloads.surface_type_map,
		1
	)

	var terrain_result: Dictionary = chunk_result.get("terrain_result", {})
	var edge_result: Dictionary = chunk_result.get("edge_result", {})
	_check_eq((terrain_result.get("mesh", ArrayMesh.new()) as ArrayMesh).get_surface_count(), (expected_terrain.get("mesh", ArrayMesh.new()) as ArrayMesh).get_surface_count(), "Chunk executor terrain mesh surface count should match direct terrain builder output")
	_check_eq(terrain_result.get("authored_piece_descriptors", []).size(), expected_terrain.get("authored_piece_descriptors", []).size(), "Chunk executor terrain descriptor count should match direct terrain builder output")
	_check_eq((edge_result.get("mesh", ArrayMesh.new()) as ArrayMesh).get_surface_count(), (expected_edge.get("mesh", ArrayMesh.new()) as ArrayMesh).get_surface_count(), "Chunk executor edge mesh surface count should match direct slurp builder output")
	_check_eq(edge_result.get("authored_piece_descriptors", []).size(), expected_edge.get("authored_piece_descriptors", []).size(), "Chunk executor edge descriptor count should match direct slurp builder output")
	return _errors.is_empty()


func test_apply_chunk_result_assigns_chunk_nodes_and_updates_cache() -> bool:
	_reset_errors()
	var w := 6
	var h := 6
	var chunk_coord := Vector2i(0, 0)
	var hgt := _make_flat_hgt(w, h, 0)
	var effective_typ := PackedByteArray()
	effective_typ.resize(w * h)
	for i in range(effective_typ.size()):
		effective_typ[i] = 0
	var scene := ScenePortStub.new()
	var chunk_runtime := ChunkRuntimeStub.new()
	var chunk_result := Executor.build_chunk_result(
		chunk_coord,
		hgt,
		effective_typ,
		w,
		h,
		Preloads.surface_type_map,
		Preloads.subsector_patterns,
		Preloads.tile_mapping,
		Preloads.tile_remap,
		Preloads.subsector_idx_remap,
		Preloads.lego_defs,
		1,
		true
	)

	var apply_result := Executor.apply_chunk_result(scene, chunk_runtime, chunk_result, Preloads)
	var terrain_node: MeshInstance3D = scene.terrain_chunks.get(chunk_coord)
	var edge_node: MeshInstance3D = scene.edge_chunks.get(chunk_coord)
	var descriptors: Array = apply_result.get("descriptors", [])
	_check(terrain_node != null and terrain_node.mesh != null, "Applying a chunk result should assign the terrain chunk mesh")
	_check(edge_node != null and edge_node.mesh != null, "Applying a chunk result with edge overlay should assign the edge chunk mesh")
	_check_eq(scene.sector_material_calls, 1, "Applying a chunk result should apply terrain materials once")
	_check_eq(scene.edge_material_calls, 1, "Applying a chunk result should apply edge materials once")
	_check_eq(chunk_runtime.updated_chunk, chunk_coord, "Applying a chunk result should update the authored cache for the same chunk")
	_check_eq(chunk_runtime.updated_descriptors.size(), descriptors.size(), "Applying a chunk result should store the returned authored descriptors in the chunk cache")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_build_chunk_result_matches_direct_builders",
		"test_apply_chunk_result_assigns_chunk_nodes_and_updates_cache",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const TerrainBuilder = preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const SlurpBuilder = preload("res://map/3d/terrain/map_3d_slurp_builder.gd")

var _errors: Array[String] = []


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated
	signal map_3d_overlay_animations_changed
	signal hgt_map_cells_edited(border_indices: Array)
	signal typ_map_cells_edited(typ_indices: Array)
	signal blg_map_cells_edited(blg_indices: Array)


class CurrentMapDataStub extends Node:
	var horizontal_sectors := 0
	var vertical_sectors := 0
	var hgt_map := PackedByteArray()
	var typ_map := PackedByteArray()
	var blg_map := PackedByteArray()
	var level_set := 1


class EditorStateStub extends Node:
	var view_mode_3d := true
	var map_3d_visibility_range_enabled := false
	var game_data_type := "original"


class PreloadsStub extends Node:
	var surface_type_map := {}
	var subsector_patterns := {}
	var tile_mapping := {}
	var tile_remap := {}
	var subsector_idx_remap := {}
	var lego_defs := {}
	var _texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))

	func _init(full_data: Dictionary) -> void:
		surface_type_map = Dictionary(full_data.get("surface_types", {}))
		subsector_patterns = Dictionary(full_data.get("subsector_patterns", {}))
		tile_mapping = Dictionary(full_data.get("tile_mapping", {}))
		tile_remap = Dictionary(full_data.get("tile_remap", {}))
		subsector_idx_remap = Dictionary(full_data.get("subsector_idx_remap", {}))
		lego_defs = Dictionary(full_data.get("lego_defs", {}))

	func get_ground_texture(_surface_type: int) -> Texture2D:
		return _texture


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


func _scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _load_set_preloads(set_id: int) -> PreloadsStub:
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(set_id)
	return PreloadsStub.new(full_data)


func _create_renderer_fixture(preloads: Node) -> Dictionary:
	var host := Node3D.new()
	host.name = "ChunkBuildParityHost"
	var renderer := Map3DRendererScript.new()
	renderer.name = "Map3D"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	renderer.add_child(terrain_mesh)
	var edge_mesh := MeshInstance3D.new()
	edge_mesh.name = "EdgeMesh"
	renderer.add_child(edge_mesh)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	renderer.add_child(camera)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	renderer.add_child(world_environment)
	renderer.set_event_system_override(EventSystemStub.new())
	renderer.set_current_map_data_override(CurrentMapDataStub.new())
	renderer.set_editor_state_override(EditorStateStub.new())
	renderer.set_preloads_override(preloads)
	host.add_child(renderer)
	var root := _scene_root()
	if root != null:
		root.add_child(host)
	if not renderer.is_node_ready():
		renderer._ready()
	return {
		"host": host,
		"renderer": renderer,
		"preloads": preloads,
	}


func _dispose_fixture(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()


func _make_flat_hgt(w: int, h: int, height_byte: int) -> PackedByteArray:
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	hgt.fill(height_byte)
	return hgt


func _make_filled_typ(w: int, h: int, typ_value: int) -> PackedByteArray:
	var typ := PackedByteArray()
	typ.resize(w * h)
	typ.fill(typ_value)
	return typ


func _mesh_signature(mesh: Mesh) -> Dictionary:
	if mesh == null or not (mesh is ArrayMesh):
		return {"exists": false}
	var array_mesh := mesh as ArrayMesh
	var surface_vertices: Array = []
	var surface_indices: Array = []
	for surface_index in array_mesh.get_surface_count():
		var arrays: Array = array_mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		surface_vertices.append(vertices.size())
		surface_indices.append(indices.size())
	var aabb := array_mesh.get_aabb()
	return {
		"exists": true,
		"surface_count": array_mesh.get_surface_count(),
		"surface_vertices": surface_vertices,
		"surface_indices": surface_indices,
		"aabb_position": aabb.position,
		"aabb_size": aabb.size,
	}


func _normalized_descriptors(descriptors: Array) -> Array:
	var normalized: Array = []
	for descriptor_value in descriptors:
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor := descriptor_value as Dictionary
		var summary := {
			"instance_key": String(descriptor.get("instance_key", "")),
			"base_name": String(descriptor.get("base_name", "")),
			"origin": descriptor.get("origin", Vector3.ZERO),
		}
		if descriptor.has("forward"):
			summary["forward"] = descriptor.get("forward", Vector3.ZERO)
		if descriptor.has("y_offset"):
			summary["y_offset"] = descriptor.get("y_offset", 0.0)
		normalized.append(summary)
	normalized.sort_custom(func(a, b) -> bool:
		return String(a.get("instance_key", "")) < String(b.get("instance_key", ""))
	)
	return normalized


func _run_sync_chunk_apply(renderer: Map3DRenderer, hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, preloads: PreloadsStub, level_set: int) -> Dictionary:
	renderer._chunk_rt.mark_chunk_dirty(Vector2i.ZERO)
	var metrics := {}
	var result: Dictionary = renderer._rebuild_dirty_chunks(hgt, typ, w, h, preloads, level_set, metrics, 1)
	return {
		"result": result,
		"metrics": metrics,
		"terrain_node": renderer.get_node_or_null("TerrainMesh/TerrainChunk_0_0") as MeshInstance3D,
		"edge_node": renderer.get_node_or_null("EdgeMesh/EdgeChunk_0_0") as MeshInstance3D,
		"support_descriptors": renderer._chunk_rt.get_support_descriptors(),
	}


func _run_async_chunk_apply(renderer: Map3DRenderer, hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, preloads: PreloadsStub, level_set: int, include_edge: bool) -> Dictionary:
	var terrain_result := TerrainBuilder.build_chunk_mesh_with_textures(
		Vector2i.ZERO,
		hgt,
		typ,
		w,
		h,
		preloads.surface_type_map,
		preloads.subsector_patterns,
		preloads.tile_mapping,
		preloads.tile_remap,
		preloads.subsector_idx_remap,
		preloads.lego_defs,
		level_set,
		true
	)
	var edge_result := {}
	if include_edge:
		edge_result = SlurpBuilder.build_chunk_edge_overlay_result(
			Vector2i.ZERO,
			hgt,
			w,
			h,
			typ,
			preloads.surface_type_map,
			level_set
		)
	renderer._apply_async_chunk_payload({
		"chunk_coord": Vector2i.ZERO,
		"terrain_result": terrain_result,
		"edge_result": edge_result,
		"has_edge_result": include_edge,
	})
	return {
		"terrain_node": renderer.get_node_or_null("TerrainMesh/TerrainChunk_0_0") as MeshInstance3D,
		"edge_node": renderer.get_node_or_null("EdgeMesh/EdgeChunk_0_0") as MeshInstance3D,
		"support_descriptors": renderer._chunk_rt.get_support_descriptors(),
	}


func test_sync_and_async_chunk_apply_match_when_edge_overlay_enabled() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var level_set := 1
	var hgt := _make_flat_hgt(w, h, 0)
	var typ := _make_filled_typ(w, h, 185)
	var sync_fixture := _create_renderer_fixture(_load_set_preloads(level_set))
	var async_fixture := _create_renderer_fixture(_load_set_preloads(level_set))
	var sync_renderer := sync_fixture["renderer"] as Map3DRenderer
	var async_renderer := async_fixture["renderer"] as Map3DRenderer
	var sync_preloads := sync_fixture["preloads"] as PreloadsStub
	var async_preloads := async_fixture["preloads"] as PreloadsStub
	sync_renderer._edge_overlay_enabled = true
	async_renderer._edge_overlay_enabled = true

	var sync_state := _run_sync_chunk_apply(sync_renderer, hgt, typ, w, h, sync_preloads, level_set)
	var async_state := _run_async_chunk_apply(async_renderer, hgt, typ, w, h, async_preloads, level_set, true)

	var sync_result: Dictionary = sync_state["result"]
	var sync_metrics: Dictionary = sync_state["metrics"]
	var sync_terrain_node := sync_state["terrain_node"] as MeshInstance3D
	var async_terrain_node := async_state["terrain_node"] as MeshInstance3D
	var sync_edge_node := sync_state["edge_node"] as MeshInstance3D
	var async_edge_node := async_state["edge_node"] as MeshInstance3D
	_check_eq(Array(sync_result.get("processed_chunks", [])), [Vector2i.ZERO], "Sync chunk rebuild should report the single processed chunk")
	_check_eq(int(sync_metrics.get("chunks_rebuilt", 0)), 1, "Sync chunk rebuild should report one rebuilt chunk")
	_check(sync_terrain_node != null and async_terrain_node != null, "Both sync and async paths should create a terrain chunk node")
	_check(sync_edge_node != null and async_edge_node != null, "Both sync and async paths should create an edge chunk node when edge overlays are enabled")

	if sync_terrain_node != null and async_terrain_node != null:
		_check_eq(
			_mesh_signature(sync_terrain_node.mesh),
			_mesh_signature(async_terrain_node.mesh),
			"Terrain chunk mesh signature should match between sync and async apply paths"
		)
	if sync_edge_node != null and async_edge_node != null:
		_check_eq(
			_mesh_signature(sync_edge_node.mesh),
			_mesh_signature(async_edge_node.mesh),
			"Edge chunk mesh signature should match between sync and async apply paths"
		)
	_check_eq(
		_normalized_descriptors(Array(sync_result.get("descriptors", []))),
		_normalized_descriptors(sync_state["support_descriptors"]),
		"Sync rebuild result descriptors should match the chunk support cache"
	)
	_check_eq(
		_normalized_descriptors(sync_state["support_descriptors"]),
		_normalized_descriptors(async_state["support_descriptors"]),
		"Combined terrain and edge support descriptors should match between sync and async apply paths"
	)

	_dispose_fixture(sync_fixture)
	_dispose_fixture(async_fixture)
	return _errors.is_empty()


func test_sync_and_async_chunk_apply_match_when_edge_overlay_is_disabled() -> bool:
	_reset_errors()
	var w := 4
	var h := 4
	var level_set := 1
	var hgt := _make_flat_hgt(w, h, 0)
	var typ := _make_filled_typ(w, h, 185)
	var sync_fixture := _create_renderer_fixture(_load_set_preloads(level_set))
	var async_fixture := _create_renderer_fixture(_load_set_preloads(level_set))
	var sync_renderer := sync_fixture["renderer"] as Map3DRenderer
	var async_renderer := async_fixture["renderer"] as Map3DRenderer
	var sync_preloads := sync_fixture["preloads"] as PreloadsStub
	var async_preloads := async_fixture["preloads"] as PreloadsStub
	sync_renderer._edge_overlay_enabled = false
	async_renderer._edge_overlay_enabled = false

	var sync_state := _run_sync_chunk_apply(sync_renderer, hgt, typ, w, h, sync_preloads, level_set)
	var async_state := _run_async_chunk_apply(async_renderer, hgt, typ, w, h, async_preloads, level_set, false)
	var sync_terrain_node := sync_state["terrain_node"] as MeshInstance3D
	var async_terrain_node := async_state["terrain_node"] as MeshInstance3D

	_check(sync_terrain_node != null and async_terrain_node != null, "Both sync and async paths should create a terrain chunk node when rebuilding a chunk")
	if sync_terrain_node != null and async_terrain_node != null:
		_check_eq(
			_mesh_signature(sync_terrain_node.mesh),
			_mesh_signature(async_terrain_node.mesh),
			"Terrain chunk mesh signature should still match when edge overlays are disabled"
		)
	_check(sync_state["edge_node"] == null, "Sync chunk rebuild should not create an edge chunk node when edge overlays are disabled")
	_check(async_state["edge_node"] == null, "Async chunk apply should not create an edge chunk node when edge overlays are disabled")
	_check_eq(
		_normalized_descriptors(Array(sync_state["result"].get("descriptors", []))),
		_normalized_descriptors(async_state["support_descriptors"]),
		"Terrain-only support descriptors should match between sync and async apply paths"
	)

	_dispose_fixture(sync_fixture)
	_dispose_fixture(async_fixture)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_sync_and_async_chunk_apply_match_when_edge_overlay_enabled",
		"test_sync_and_async_chunk_apply_match_when_edge_overlay_is_disabled",
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

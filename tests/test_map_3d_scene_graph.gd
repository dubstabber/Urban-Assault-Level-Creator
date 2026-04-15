extends RefCounted

const SceneGraphScript = preload("res://map/3d/runtime/map_3d_scene_graph.gd")


class UnitRuntimeIndexStub extends RefCounted:
	var clear_calls := 0

	func clear() -> void:
		clear_calls += 1


class StaticOverlayIndexStub extends RefCounted:
	var replaced_all: Array = []

	func replace_all(descriptors: Array) -> void:
		replaced_all = descriptors.duplicate(true)


class ChunkRuntimeStub extends RefCounted:
	var clear_dirty_chunks_calls := 0
	var last_map_dimensions := Vector2i(8, 8)

	func clear_dirty_chunks() -> void:
		clear_dirty_chunks_calls += 1


class BuildPortStub extends RefCounted:
	var terrain_material_cache_ref := {1: "mat"}
	var edge_material_cache_ref := {"edge": "mat"}
	var unit_runtime_index_ref := UnitRuntimeIndexStub.new()
	var static_overlay_index_ref := StaticOverlayIndexStub.new()
	var chunk_runtime_ref := ChunkRuntimeStub.new()
	var clear_localized_overlay_scope_calls := 0
	var geometry_culling_enabled := false
	var geometry_cull_distance_value := 6000.0
	var debug_shader_mode_value := 0
	var sector_top_shader_value: Shader = null
	var edge_blend_shader_value: Shader = null

	func terrain_material_cache() -> Dictionary:
		return terrain_material_cache_ref

	func edge_material_cache() -> Dictionary:
		return edge_material_cache_ref

	func unit_runtime_index():
		return unit_runtime_index_ref

	func static_overlay_index():
		return static_overlay_index_ref

	func clear_localized_overlay_scope() -> void:
		clear_localized_overlay_scope_calls += 1

	func chunk_runtime():
		return chunk_runtime_ref

	func geometry_distance_culling_enabled() -> bool:
		return geometry_culling_enabled

	func set_geometry_distance_culling_enabled(value: bool) -> void:
		geometry_culling_enabled = value

	func geometry_cull_distance() -> float:
		return geometry_cull_distance_value

	func set_geometry_cull_distance(value: float) -> void:
		geometry_cull_distance_value = value

	func debug_shader_mode() -> int:
		return debug_shader_mode_value

	func sector_top_shader() -> Shader:
		return sector_top_shader_value

	func set_sector_top_shader(shader: Shader) -> void:
		sector_top_shader_value = shader

	func edge_blend_shader() -> Shader:
		return edge_blend_shader_value

	func set_edge_blend_shader(shader: Shader) -> void:
		edge_blend_shader_value = shader


class ContextPortStub extends RefCounted:
	var preview_active := true
	var preloads_ref = null

	func preview_refresh_active() -> bool:
		return preview_active

	func preloads():
		return preloads_ref


class ScenePortStub extends RefCounted:
	const SECTOR_SIZE := 1200.0
	const UA_NORMAL_GEOMETRY_CULL_DISTANCE := 6600.0
	const EDGE_PREVIEW_COLOR := Color(0.82, 0.48, 0.24, 0.55)

	var root := Node3D.new()
	var terrain_mesh_ref := MeshInstance3D.new()
	var edge_mesh_ref := MeshInstance3D.new()
	var authored_overlay_ref: Node3D = null
	var dynamic_overlay_ref: Node3D = null
	var terrain_chunks := {}
	var edge_chunks := {}
	var camera_ref := Camera3D.new()
	var viewport_ref := SubViewport.new()

	func _init() -> void:
		root.name = "Root"
		terrain_mesh_ref.name = "TerrainMesh"
		edge_mesh_ref.name = "EdgeMesh"
		root.add_child(terrain_mesh_ref)
		root.add_child(edge_mesh_ref)
		root.add_child(camera_ref)

	func renderer_node():
		return self

	func terrain_mesh() -> MeshInstance3D:
		return terrain_mesh_ref

	func edge_mesh() -> MeshInstance3D:
		return edge_mesh_ref

	func set_edge_mesh_node(node: MeshInstance3D) -> void:
		edge_mesh_ref = node

	func authored_overlay() -> Node3D:
		return authored_overlay_ref

	func set_authored_overlay_node(node: Node3D) -> void:
		authored_overlay_ref = node

	func dynamic_overlay() -> Node3D:
		return dynamic_overlay_ref

	func set_dynamic_overlay_node(node: Node3D) -> void:
		dynamic_overlay_ref = node

	func terrain_chunk_nodes() -> Dictionary:
		return terrain_chunks

	func edge_chunk_nodes() -> Dictionary:
		return edge_chunks

	func add_child(node: Node) -> void:
		root.add_child(node)

	func camera() -> Camera3D:
		return camera_ref

	func viewport() -> Viewport:
		return viewport_ref

	func is_inside_tree() -> bool:
		return true

	func make_preview_material(color: Color) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		return material

	func apply_untextured_materials(mesh: ArrayMesh) -> void:
		for surface_idx in mesh.get_surface_count():
			mesh.surface_set_material(surface_idx, make_preview_material(Color(1, 1, 1)))

	func compute_tile_scale() -> float:
		return 1.0 / SECTOR_SIZE


var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _bind_scene_graph():
	var graph = SceneGraphScript.new()
	var scene := ScenePortStub.new()
	var context := ContextPortStub.new()
	var build := BuildPortStub.new()
	graph.bind(scene, context, build)
	return {"graph": graph, "scene": scene, "context": context, "build": build}


func test_ensure_overlay_nodes_creates_missing_roots() -> bool:
	_reset_errors()
	var bound: Dictionary = _bind_scene_graph()
	var graph = bound["graph"]
	var scene: ScenePortStub = bound["scene"]
	graph.ensure_overlay_nodes()
	_check(scene.authored_overlay_ref != null, "Expected authored overlay root to be created on demand")
	_check(scene.dynamic_overlay_ref != null, "Expected dynamic overlay root to be created on demand")
	_check(scene.authored_overlay_ref.name == "AuthoredOverlay", "Expected authored overlay root to keep the canonical name")
	_check(scene.dynamic_overlay_ref.name == "DynamicOverlay", "Expected dynamic overlay root to keep the canonical name")
	return _errors.is_empty()


func test_get_or_create_terrain_chunk_node_reuses_existing_node() -> bool:
	_reset_errors()
	var bound: Dictionary = _bind_scene_graph()
	var graph = bound["graph"]
	var scene: ScenePortStub = bound["scene"]
	var first: MeshInstance3D = graph.get_or_create_terrain_chunk_node(Vector2i(1, 2))
	var second: MeshInstance3D = graph.get_or_create_terrain_chunk_node(Vector2i(1, 2))
	_check(first == second, "Expected the same terrain chunk node to be reused for an existing chunk coordinate")
	_check(scene.terrain_chunks.size() == 1, "Expected only one terrain chunk entry for a reused coordinate")
	return _errors.is_empty()


func test_clear_resets_meshes_chunk_nodes_and_runtime_state() -> bool:
	_reset_errors()
	var bound: Dictionary = _bind_scene_graph()
	var graph = bound["graph"]
	var scene: ScenePortStub = bound["scene"]
	var build: BuildPortStub = bound["build"]
	scene.terrain_mesh_ref.mesh = ArrayMesh.new()
	scene.edge_mesh_ref.mesh = ArrayMesh.new()
	scene.terrain_chunks[Vector2i(0, 0)] = MeshInstance3D.new()
	scene.edge_chunks[Vector2i(0, 0)] = MeshInstance3D.new()
	scene.set_authored_overlay_node(Node3D.new())
	scene.set_dynamic_overlay_node(Node3D.new())
	build.static_overlay_index_ref.replace_all([{"instance_key": "terrain:1"}])
	graph.clear()
	_check(scene.terrain_mesh_ref.mesh == null, "Expected terrain mesh to be cleared")
	_check(scene.edge_mesh_ref.mesh == null, "Expected edge mesh to be cleared")
	_check(scene.terrain_chunks.is_empty(), "Expected terrain chunk store to be cleared")
	_check(scene.edge_chunks.is_empty(), "Expected edge chunk store to be cleared")
	_check(build.terrain_material_cache_ref.is_empty(), "Expected terrain material cache to be cleared")
	_check(build.edge_material_cache_ref.is_empty(), "Expected edge material cache to be cleared")
	_check(build.unit_runtime_index_ref.clear_calls == 1, "Expected unit runtime index to be cleared")
	_check(build.chunk_runtime_ref.clear_dirty_chunks_calls >= 1, "Expected chunk runtime dirty state to be cleared")
	_check(build.clear_localized_overlay_scope_calls == 1, "Expected localized overlay scope to be cleared")
	return _errors.is_empty()


func test_bump_3d_viewport_rendering_enables_visible_updates_when_preview_is_active() -> bool:
	_reset_errors()
	var bound: Dictionary = _bind_scene_graph()
	var graph = bound["graph"]
	var scene: ScenePortStub = bound["scene"]
	scene.viewport_ref.render_target_update_mode = SubViewport.UPDATE_DISABLED
	graph.bump_3d_viewport_rendering()
	_check(scene.viewport_ref.render_target_update_mode == SubViewport.UPDATE_WHEN_VISIBLE, "Expected active preview mode to bump the SubViewport render mode")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_ensure_overlay_nodes_creates_missing_roots",
		"test_get_or_create_terrain_chunk_node_reuses_existing_node",
		"test_clear_resets_meshes_chunk_nodes_and_runtime_state",
		"test_bump_3d_viewport_rendering_enables_visible_updates_when_preview_is_active",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

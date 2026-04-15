extends RefCounted


var _renderer = null


func bind(renderer) -> void:
	_renderer = renderer


func renderer_node() -> Node3D:
	return _renderer


func viewport() -> Viewport:
	return _renderer.get_viewport()


func is_inside_tree() -> bool:
	return _renderer.is_inside_tree()


func is_visible_in_tree() -> bool:
	return _renderer.is_visible_in_tree()


func get_node_or_null(path: NodePath) -> Node:
	return _renderer.get_node_or_null(path)


func add_child(node: Node) -> void:
	_renderer.add_child(node)


func camera() -> Camera3D:
	return _renderer._camera


func set_camera_current(current: bool) -> void:
	if _renderer._camera != null and is_instance_valid(_renderer._camera):
		_renderer._camera.current = current


func terrain_mesh() -> MeshInstance3D:
	return _renderer._terrain_mesh


func edge_mesh() -> MeshInstance3D:
	return _renderer._edge_mesh


func set_edge_mesh_node(node: MeshInstance3D) -> void:
	_renderer._edge_mesh = node


func authored_overlay() -> Node3D:
	return _renderer._authored_overlay


func set_authored_overlay_node(node: Node3D) -> void:
	_renderer._authored_overlay = node


func dynamic_overlay() -> Node3D:
	return _renderer._dynamic_overlay


func set_dynamic_overlay_node(node: Node3D) -> void:
	_renderer._dynamic_overlay = node


func terrain_chunk_nodes() -> Dictionary:
	return _renderer._terrain_chunk_nodes


func edge_chunk_nodes() -> Dictionary:
	return _renderer._edge_chunk_nodes


func clear() -> void:
	_renderer._scene_graph.clear()


func clear_chunk_nodes() -> void:
	_renderer._scene_graph.clear_chunk_nodes()


func ensure_overlay_nodes() -> void:
	_renderer._scene_graph.ensure_overlay_nodes()


func apply_dynamic_overlay(dynamic_descriptors: Array) -> void:
	_renderer._scene_graph.apply_dynamic_overlay(dynamic_descriptors)


func get_or_create_terrain_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	return _renderer._scene_graph.get_or_create_terrain_chunk_node(chunk_coord)


func get_or_create_edge_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	return _renderer._scene_graph.get_or_create_edge_chunk_node(chunk_coord)


func set_authored_overlay(descriptors: Array) -> void:
	_renderer._scene_graph.set_authored_overlay(descriptors)


func apply_geometry_distance_culling_state(enabled: bool) -> void:
	_renderer._scene_graph.apply_geometry_distance_culling_state(enabled)


func set_all_distance_culled_nodes_visible(make_visible: bool) -> void:
	_renderer._scene_graph.set_all_distance_culled_nodes_visible(make_visible)


func update_geometry_distance_culling_visibility() -> void:
	_renderer._scene_graph.update_geometry_distance_culling_visibility()


func apply_geometry_distance_culling_to_chunk_node(chunk_node: MeshInstance3D, chunk_coord: Vector2i) -> void:
	_renderer._scene_graph.apply_geometry_distance_culling_to_chunk_node(chunk_node, chunk_coord)


func apply_geometry_distance_culling_to_overlay() -> void:
	_renderer._scene_graph.apply_geometry_distance_culling_to_overlay()


func chunk_center_world_xz(chunk_coord: Vector2i) -> Vector2:
	return _renderer._scene_graph.chunk_center_world_xz(chunk_coord)


func apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	_renderer._scene_graph.apply_sector_top_materials(mesh, preloads, surface_to_surface_type)


func ensure_edge_node() -> void:
	_renderer._scene_graph.ensure_edge_node()


func build_edge_overlay_result(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary, set_id: int, preloads = null) -> Dictionary:
	return _renderer._scene_graph.build_edge_overlay_result(hgt, w, h, typ, mapping, set_id, preloads)


func apply_edge_surface_materials(mesh: ArrayMesh, preloads, fallback_horiz_keys: Array, fallback_vert_keys: Array) -> void:
	_renderer._scene_graph.apply_edge_surface_materials(mesh, preloads, fallback_horiz_keys, fallback_vert_keys)


func get_map_subviewport() -> SubViewport:
	return _renderer._scene_graph.get_map_subviewport()


func bump_3d_viewport_rendering() -> void:
	_renderer._scene_graph.bump_3d_viewport_rendering()


func apply_untextured_materials(mesh: ArrayMesh) -> void:
	_renderer._apply_untextured_materials(mesh)


func make_preview_material(color: Color) -> StandardMaterial3D:
	return _renderer._make_preview_material(color)


func compute_tile_scale() -> float:
	return _renderer._compute_tile_scale()

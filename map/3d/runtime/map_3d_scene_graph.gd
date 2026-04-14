extends RefCounted

const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const PreviewGeometry := preload("res://map/3d/terrain/map_3d_preview_geometry.gd")

const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"

var _renderer = null


func bind(renderer) -> void:
	_renderer = renderer


func clear() -> void:
	_renderer._terrain_material_cache.clear()
	_renderer._edge_material_cache.clear()
	_renderer._unit_runtime_index.clear()
	if _renderer._terrain_mesh:
		_renderer._terrain_mesh.mesh = null
	if _renderer._edge_mesh:
		_renderer._edge_mesh.mesh = null
	clear_chunk_nodes()
	set_authored_overlay([])
	_renderer._clear_localized_overlay_scope()


func clear_chunk_nodes() -> void:
	for chunk_key in _renderer._terrain_chunk_nodes.keys():
		var node: Node = _renderer._terrain_chunk_nodes[chunk_key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_renderer._terrain_chunk_nodes.clear()
	for chunk_key in _renderer._edge_chunk_nodes.keys():
		var node: Node = _renderer._edge_chunk_nodes[chunk_key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_renderer._edge_chunk_nodes.clear()
	_renderer._chunk_rt.clear_dirty_chunks()


func ensure_overlay_nodes() -> void:
	if _renderer._authored_overlay == null or not is_instance_valid(_renderer._authored_overlay):
		_renderer._authored_overlay = Node3D.new()
		_renderer._authored_overlay.name = "AuthoredOverlay"
		_renderer.add_child(_renderer._authored_overlay)
	if _renderer._dynamic_overlay == null or not is_instance_valid(_renderer._dynamic_overlay):
		_renderer._dynamic_overlay = Node3D.new()
		_renderer._dynamic_overlay.name = "DynamicOverlay"
		_renderer.add_child(_renderer._dynamic_overlay)


func apply_dynamic_overlay(dynamic_descriptors: Array) -> void:
	ensure_overlay_nodes()
	AuthoredOverlayManager.apply_overlay_node(_renderer._dynamic_overlay, dynamic_descriptors)
	apply_geometry_distance_culling_to_overlay()


func get_or_create_terrain_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	if _renderer._terrain_chunk_nodes.has(chunk_coord):
		var existing = _renderer._terrain_chunk_nodes[chunk_coord]
		if existing != null and is_instance_valid(existing):
			return existing as MeshInstance3D
	var node := MeshInstance3D.new()
	node.name = "TerrainChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	if _renderer._terrain_mesh:
		_renderer._terrain_mesh.add_child(node)
	_renderer._terrain_chunk_nodes[chunk_coord] = node
	apply_geometry_distance_culling_to_chunk_node(node, chunk_coord)
	return node


func get_or_create_edge_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	if _renderer._edge_chunk_nodes.has(chunk_coord):
		var existing = _renderer._edge_chunk_nodes[chunk_coord]
		if existing != null and is_instance_valid(existing):
			return existing as MeshInstance3D
	var node := MeshInstance3D.new()
	node.name = "EdgeChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	ensure_edge_node()
	if _renderer._edge_mesh:
		_renderer._edge_mesh.add_child(node)
	_renderer._edge_chunk_nodes[chunk_coord] = node
	apply_geometry_distance_culling_to_chunk_node(node, chunk_coord)
	return node


func set_authored_overlay(descriptors: Array) -> void:
	ensure_overlay_nodes()
	var static_descriptors: Array = []
	var dynamic_descriptors: Array = []
	for desc_any in descriptors:
		if typeof(desc_any) != TYPE_DICTIONARY:
			continue
		var desc := desc_any as Dictionary
		var instance_key := String(desc.get("instance_key", ""))
		if instance_key.begins_with("host:") or instance_key.begins_with("host_gun:") or instance_key.begins_with("squad:"):
			dynamic_descriptors.append(desc)
		else:
			static_descriptors.append(desc)
	UATerrainPieceLibrary.reset_piece_overlay_build_counters()
	_renderer._static_overlay_index.replace_all(static_descriptors)
	AuthoredOverlayManager.apply_overlay_node(_renderer._authored_overlay, static_descriptors)
	AuthoredOverlayManager.apply_overlay_node(_renderer._dynamic_overlay, dynamic_descriptors)
	apply_geometry_distance_culling_to_overlay()


func apply_geometry_distance_culling_state(enabled: bool) -> void:
	_renderer._geometry_distance_culling_enabled = enabled
	_renderer._geometry_cull_distance = _renderer.UA_NORMAL_GEOMETRY_CULL_DISTANCE
	if not enabled:
		set_all_distance_culled_nodes_visible(true)
		return
	update_geometry_distance_culling_visibility()


func set_all_distance_culled_nodes_visible(make_visible: bool) -> void:
	for chunk_coord in _renderer._terrain_chunk_nodes.keys():
		var terrain_chunk := _renderer._terrain_chunk_nodes[chunk_coord] as MeshInstance3D
		if terrain_chunk != null and is_instance_valid(terrain_chunk):
			terrain_chunk.visible = make_visible and terrain_chunk.mesh != null
	for chunk_coord in _renderer._edge_chunk_nodes.keys():
		var edge_chunk := _renderer._edge_chunk_nodes[chunk_coord] as MeshInstance3D
		if edge_chunk != null and is_instance_valid(edge_chunk):
			edge_chunk.visible = make_visible and edge_chunk.mesh != null
	if _renderer._authored_overlay != null and is_instance_valid(_renderer._authored_overlay):
		for child in _renderer._authored_overlay.get_children():
			if child is Node3D:
				(child as Node3D).visible = make_visible
	if _renderer._dynamic_overlay != null and is_instance_valid(_renderer._dynamic_overlay):
		for child in _renderer._dynamic_overlay.get_children():
			if child is Node3D:
				(child as Node3D).visible = make_visible


func update_geometry_distance_culling_visibility() -> void:
	if not _renderer._geometry_distance_culling_enabled:
		return
	if _renderer._camera == null or not is_instance_valid(_renderer._camera):
		return
	var cam_pos: Vector3 = _renderer._camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var cull_sq: float = _renderer._geometry_cull_distance * _renderer._geometry_cull_distance
	for chunk_coord_any in _renderer._terrain_chunk_nodes.keys():
		var chunk_coord := Vector2i(chunk_coord_any)
		var terrain_chunk := _renderer._terrain_chunk_nodes[chunk_coord] as MeshInstance3D
		if terrain_chunk == null or not is_instance_valid(terrain_chunk):
			continue
		var center := chunk_center_world_xz(chunk_coord)
		var within_range: bool = cam_xz.distance_squared_to(center) <= cull_sq
		terrain_chunk.visible = within_range and terrain_chunk.mesh != null
	for chunk_coord_any in _renderer._edge_chunk_nodes.keys():
		var chunk_coord := Vector2i(chunk_coord_any)
		var edge_chunk := _renderer._edge_chunk_nodes[chunk_coord] as MeshInstance3D
		if edge_chunk == null or not is_instance_valid(edge_chunk):
			continue
		var center := chunk_center_world_xz(chunk_coord)
		var within_range: bool = cam_xz.distance_squared_to(center) <= cull_sq
		edge_chunk.visible = within_range and edge_chunk.mesh != null
	apply_geometry_distance_culling_to_overlay()


func apply_geometry_distance_culling_to_chunk_node(chunk_node: MeshInstance3D, chunk_coord: Vector2i) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	if not _renderer._geometry_distance_culling_enabled:
		chunk_node.visible = chunk_node.mesh != null
		return
	if _renderer._camera == null or not is_instance_valid(_renderer._camera):
		return
	var center := chunk_center_world_xz(chunk_coord)
	var cam_pos: Vector3 = _renderer._camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	chunk_node.visible = cam_xz.distance_squared_to(center) <= (_renderer._geometry_cull_distance * _renderer._geometry_cull_distance) and chunk_node.mesh != null


func apply_geometry_distance_culling_to_overlay() -> void:
	if not _renderer._geometry_distance_culling_enabled:
		if _renderer._authored_overlay != null and is_instance_valid(_renderer._authored_overlay):
			for child in _renderer._authored_overlay.get_children():
				if child is Node3D:
					(child as Node3D).visible = true
		if _renderer._dynamic_overlay != null and is_instance_valid(_renderer._dynamic_overlay):
			for child in _renderer._dynamic_overlay.get_children():
				if child is Node3D:
					(child as Node3D).visible = true
		return
	if _renderer._camera == null or not is_instance_valid(_renderer._camera):
		return
	var cam_pos: Vector3 = _renderer._camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var cull_sq: float = _renderer._geometry_cull_distance * _renderer._geometry_cull_distance
	if _renderer._authored_overlay != null and is_instance_valid(_renderer._authored_overlay):
		for child in _renderer._authored_overlay.get_children():
			if not (child is Node3D):
				continue
			var node := child as Node3D
			var p := node.global_position
			node.visible = cam_xz.distance_squared_to(Vector2(p.x, p.z)) <= cull_sq
	if _renderer._dynamic_overlay != null and is_instance_valid(_renderer._dynamic_overlay):
		for child in _renderer._dynamic_overlay.get_children():
			if not (child is Node3D):
				continue
			var node := child as Node3D
			var p := node.global_position
			node.visible = cam_xz.distance_squared_to(Vector2(p.x, p.z)) <= cull_sq


func chunk_center_world_xz(chunk_coord: Vector2i) -> Vector2:
	var w := maxi(_renderer._chunk_rt.last_map_dimensions.x, 0)
	var h := maxi(_renderer._chunk_rt.last_map_dimensions.y, 0)
	if w <= 0 or h <= 0:
		return Vector2.ZERO
	var sx_min := chunk_coord.x * TerrainBuilder.CHUNK_SIZE
	var sy_min := chunk_coord.y * TerrainBuilder.CHUNK_SIZE
	var sx_max := mini(sx_min + TerrainBuilder.CHUNK_SIZE, w)
	var sy_max := mini(sy_min + TerrainBuilder.CHUNK_SIZE, h)
	var center_sector_x := (float(sx_min + sx_max) * 0.5) + 1.0
	var center_sector_y := (float(sy_min + sy_max) * 0.5) + 1.0
	return Vector2(center_sector_x * _renderer.SECTOR_SIZE, center_sector_y * _renderer.SECTOR_SIZE)


func apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	if mesh == null:
		return
	if preloads == null:
		_renderer._apply_untextured_materials(mesh)
		return
	if _renderer._sector_top_shader == null:
		_renderer._sector_top_shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	if _renderer._sector_top_shader == null:
		push_warning("[Map3D] Could not load sector_top.gdshader")
		_renderer._apply_untextured_materials(mesh)
		return
	for surface_idx in surface_to_surface_type.keys():
		var surface_type: int = int(surface_to_surface_type[surface_idx])
		if surface_type == -1:
			var dbg := StandardMaterial3D.new()
			dbg.albedo_color = Color(1.0, 0.0, 1.0, 0.45)
			dbg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.surface_set_material(surface_idx, dbg)
			continue
		if _renderer._terrain_material_cache.has(surface_type):
			mesh.surface_set_material(surface_idx, _renderer._terrain_material_cache[surface_type])
			continue
		var mat := ShaderMaterial.new()
		mat.shader = _renderer._sector_top_shader
		mat.set_shader_parameter("ground_texture", preloads.get_ground_texture(clampi(surface_type, 0, 5)))
		for ground_idx in 6:
			mat.set_shader_parameter("ground%d" % ground_idx, preloads.get_ground_texture(ground_idx))
		mat.set_shader_parameter("tile_scale", _renderer._compute_tile_scale())
		mat.set_shader_parameter("use_mesh_uv", true)
		mat.set_shader_parameter("use_multi_textures", true)
		mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
		mat.set_shader_parameter("use_vertex_variant", true)
		mat.set_shader_parameter("variant", 0)
		mat.set_shader_parameter("debug_mode", _renderer._debug_shader_mode)
		_renderer._terrain_material_cache[surface_type] = mat
		mesh.surface_set_material(surface_idx, mat)


func ensure_edge_node() -> void:
	if _renderer._edge_mesh == null:
		var mi := MeshInstance3D.new()
		mi.name = "EdgeMesh"
		_renderer.add_child(mi)
		_renderer._edge_mesh = mi


func build_edge_overlay_result(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary, set_id: int, preloads = null) -> Dictionary:
	if preloads == null and _renderer.is_inside_tree():
		preloads = _renderer._preloads()
	var result := SlurpBuilder.build_edge_overlay_result(hgt, w, h, typ, mapping, set_id)
	var mesh: ArrayMesh = result.get("mesh", null)
	apply_edge_surface_materials(mesh, preloads, result.get("fallback_horiz_keys", []), result.get("fallback_vert_keys", []))
	return {
		"authored_piece_descriptors": result.get("authored_piece_descriptors", []),
		"mesh": mesh,
	}


func make_edge_blend_material(bucket_key: String, preloads, use_uv_y_for_blend: bool) -> Material:
	var pair := PreviewGeometry.surface_pair_from_slurp_bucket_key(bucket_key)
	if pair.is_empty() or preloads == null:
		return _renderer._make_preview_material(_renderer.EDGE_PREVIEW_COLOR)
	if _renderer._edge_blend_shader == null:
		_renderer._edge_blend_shader = load(EDGE_BLEND_SHADER_PATH)
	if _renderer._edge_blend_shader == null:
		push_warning("[Map3D] Could not load edge_blend.gdshader")
		return _renderer._make_preview_material(_renderer.EDGE_PREVIEW_COLOR)
	var cache_key := "%s:%s" % [bucket_key, use_uv_y_for_blend]
	if _renderer._edge_material_cache.has(cache_key):
		return _renderer._edge_material_cache[cache_key]
	var mat := ShaderMaterial.new()
	mat.shader = _renderer._edge_blend_shader
	var texture_a = preloads.get_ground_texture(int(pair["surface_a"]))
	var texture_b = preloads.get_ground_texture(int(pair["surface_b"]))
	if texture_a == null or texture_b == null:
		return _renderer._make_preview_material(_renderer.EDGE_PREVIEW_COLOR)
	mat.set_shader_parameter("texture_a", texture_a)
	mat.set_shader_parameter("texture_b", texture_b)
	mat.set_shader_parameter("vertical_seam", use_uv_y_for_blend)
	mat.set_shader_parameter("tile_scale", _renderer._compute_tile_scale())
	mat.set_shader_parameter("atlas_grid", Vector2(1.0, 1.0))
	mat.set_shader_parameter("variant_a", 0)
	mat.set_shader_parameter("variant_b", 0)
	_renderer._edge_material_cache[cache_key] = mat
	return mat


func apply_edge_surface_materials(mesh: ArrayMesh, preloads, fallback_horiz_keys: Array, fallback_vert_keys: Array) -> void:
	if mesh == null:
		return
	var surface_idx := 0
	for key_h in fallback_horiz_keys:
		if surface_idx >= mesh.get_surface_count():
			return
		mesh.surface_set_material(surface_idx, make_edge_blend_material(String(key_h), preloads, false))
		surface_idx += 1
	for key_v in fallback_vert_keys:
		if surface_idx >= mesh.get_surface_count():
			return
		mesh.surface_set_material(surface_idx, make_edge_blend_material(String(key_v), preloads, true))
		surface_idx += 1


func get_map_subviewport() -> SubViewport:
	var vp: Viewport = _renderer.get_viewport()
	if vp is SubViewport:
		return vp as SubViewport
	return null


func bump_3d_viewport_rendering() -> void:
	if not _renderer._preview_refresh_active():
		return
	var vp := get_map_subviewport()
	if vp == null:
		return
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

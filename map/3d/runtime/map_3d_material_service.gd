extends RefCounted


static func make_preview_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func apply_untextured_materials(mesh: ArrayMesh, color: Color) -> void:
	if mesh == null:
		return
	for surface_idx in mesh.get_surface_count():
		mesh.surface_set_material(surface_idx, make_preview_material(color))


static func apply_debug_mode_to_existing_materials(terrain_material_cache: Dictionary, terrain_chunk_nodes: Dictionary, debug_shader_mode: int) -> void:
	for surface_type in terrain_material_cache:
		var mat: ShaderMaterial = terrain_material_cache[surface_type]
		if mat != null:
			mat.set_shader_parameter("debug_mode", debug_shader_mode)
	for chunk_coord in terrain_chunk_nodes:
		var node: MeshInstance3D = terrain_chunk_nodes[chunk_coord]
		if node == null or node.mesh == null:
			continue
		for surface_idx in node.mesh.get_surface_count():
			var mat := node.mesh.surface_get_material(surface_idx)
			if mat is ShaderMaterial:
				(mat as ShaderMaterial).set_shader_parameter("debug_mode", debug_shader_mode)

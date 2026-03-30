extends RefCounted
class_name UAAuthoredPieceMeshLoader

static func build_piece_mesh(piece_source: Dictionary, set_id: int, surface_extractor: Callable, particle_extractor: Callable, mesh_surface_builder: Callable) -> Dictionary:
	var bas_data: Dictionary = piece_source.get("bas_data", {})
	var points: Array = piece_source.get("points", [])
	var polys: Array = piece_source.get("polys", [])
	var emitters: Array = []
	if particle_extractor.is_valid():
		var emitters_value = particle_extractor.call(bas_data, points, set_id)
		if typeof(emitters_value) == TYPE_ARRAY:
			emitters = Array(emitters_value)
	var has_emitters := emitters.size() > 0
	var mesh := ArrayMesh.new()
	var has_animated_surfaces := false
	var surfaces: Array = []
	if surface_extractor.is_valid():
		var surfaces_value = surface_extractor.call(bas_data, points, polys, set_id)
		if typeof(surfaces_value) == TYPE_ARRAY:
			surfaces = Array(surfaces_value)
	for surface_value in surfaces:
		if typeof(surface_value) != TYPE_DICTIONARY:
			continue
		var surface := surface_value as Dictionary
		var anim_frames: Array = surface.get("animation_frames", [])
		if anim_frames.size() > 0:
			has_animated_surfaces = true
		if not mesh_surface_builder.is_valid():
			continue
		var mesh_surface_value = mesh_surface_builder.call(surface, set_id)
		if typeof(mesh_surface_value) != TYPE_DICTIONARY:
			continue
		var mesh_surface := mesh_surface_value as Dictionary
		var triangles: Array = mesh_surface.get("triangles", [])
		var material: Material = mesh_surface.get("material", null)
		if triangles.is_empty() or material == null:
			continue
		append_surface_to_mesh(mesh, triangles, material)
	return {
		"mesh": mesh if mesh.get_surface_count() > 0 else null,
		"has_animated_surfaces": has_animated_surfaces,
		"has_emitters": has_emitters,
	}

static func build_piece_node(base_name: String, raw_id: int, surfaces: Array, emitters: Array, surface_node_builder: Callable, particle_node_builder: Callable) -> Node3D:
	if surfaces.is_empty() and emitters.is_empty():
		return null
	var piece := Node3D.new()
	piece.name = "%s_%d" % [base_name, raw_id]
	for i in surfaces.size():
		if not surface_node_builder.is_valid():
			continue
		var child = surface_node_builder.call(surfaces[i])
		if child == null or not (child is Node3D):
			continue
		var child_node := child as Node3D
		child_node.name = "Surface_%d" % i
		piece.add_child(child_node)
	for i in emitters.size():
		if not particle_node_builder.is_valid():
			continue
		var emitter = particle_node_builder.call(emitters[i])
		if emitter == null or not (emitter is Node3D):
			continue
		var emitter_node := emitter as Node3D
		emitter_node.name = "ParticleEmitter_%d" % i
		piece.add_child(emitter_node)
	return piece if piece.get_child_count() > 0 else null

static func build_fast_piece_root(base_name: String, raw_id: int, mesh: Mesh) -> Node3D:
	if mesh == null:
		return null
	var root := Node3D.new()
	root.name = "%s_%d" % [base_name, raw_id]
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	root.add_child(mi)
	return root

static func mesh_from_triangles(triangles: Array, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	append_surface_to_mesh(mesh, triangles, material)
	return mesh

static func append_surface_to_mesh(mesh: ArrayMesh, triangles: Array, material: Material) -> void:
	if triangles.is_empty() or material == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in triangles:
		var verts: Array = tri.get("verts", [])
		var uvs: Array = tri.get("uvs", [])
		if verts.size() != 3 or uvs.size() != 3:
			continue
		for i in 3:
			st.set_uv(uvs[i])
			st.add_vertex(verts[i])
	st.index()
	st.generate_normals()
	st.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)

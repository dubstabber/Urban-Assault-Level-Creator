extends RefCounted

const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")


static func build_chunk_result(
		chunk_coord: Vector2i,
		hgt: PackedByteArray,
		effective_typ: PackedByteArray,
		w: int,
		h: int,
		surface_type_map: Dictionary,
		subsector_patterns: Dictionary,
		tile_mapping: Dictionary,
		tile_remap: Dictionary,
		subsector_idx_remap: Dictionary,
		lego_defs: Dictionary,
		level_set: int,
		build_edge_overlay: bool = true
	) -> Dictionary:
	var terrain_result := TerrainBuilder.build_chunk_mesh_with_textures(
		chunk_coord,
		hgt,
		effective_typ,
		w,
		h,
		surface_type_map,
		subsector_patterns,
		tile_mapping,
		tile_remap,
		subsector_idx_remap,
		lego_defs,
		level_set,
		true
	)
	var edge_result := {}
	if build_edge_overlay:
		edge_result = SlurpBuilder.build_chunk_edge_overlay_result(
			chunk_coord,
			hgt,
			w,
			h,
			effective_typ,
			surface_type_map,
			level_set
		)
	return {
		"chunk_coord": chunk_coord,
		"terrain_result": terrain_result,
		"edge_result": edge_result,
		"has_edge_result": build_edge_overlay,
	}


static func apply_chunk_result(scene_port, chunk_runtime, chunk_result: Dictionary, preloads = null) -> Dictionary:
	var chunk_coord := Vector2i(chunk_result.get("chunk_coord", Vector2i.ZERO))
	var terrain_result: Dictionary = chunk_result.get("terrain_result", {})
	var chunk_node: MeshInstance3D = scene_port.get_or_create_terrain_chunk_node(chunk_coord)
	chunk_node.mesh = terrain_result.get("mesh", null)
	if preloads != null and chunk_node.mesh != null:
		scene_port.apply_sector_top_materials(chunk_node.mesh, preloads, terrain_result.get("surface_to_surface_type", {}))
	scene_port.apply_geometry_distance_culling_to_chunk_node(chunk_node, chunk_coord)

	var chunk_authored_descriptors: Array = terrain_result.get("authored_piece_descriptors", []).duplicate()
	if bool(chunk_result.get("has_edge_result", false)):
		var edge_result: Dictionary = chunk_result.get("edge_result", {})
		var edge_chunk_node: MeshInstance3D = scene_port.get_or_create_edge_chunk_node(chunk_coord)
		edge_chunk_node.mesh = edge_result.get("mesh", null)
		if preloads != null and edge_chunk_node.mesh != null:
			scene_port.apply_edge_surface_materials(
				edge_chunk_node.mesh,
				preloads,
				edge_result.get("fallback_horiz_keys", []),
				edge_result.get("fallback_vert_keys", [])
			)
		scene_port.apply_geometry_distance_culling_to_chunk_node(edge_chunk_node, chunk_coord)
		chunk_authored_descriptors.append_array(edge_result.get("authored_piece_descriptors", []))

	chunk_runtime.update_terrain_authored_cache_for_chunk(chunk_coord, chunk_authored_descriptors)
	return {
		"chunk_coord": chunk_coord,
		"descriptors": chunk_authored_descriptors,
	}

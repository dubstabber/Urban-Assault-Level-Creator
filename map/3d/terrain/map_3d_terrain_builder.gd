extends RefCounted

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const PreviewGeometry := preload("res://map/3d/terrain/map_3d_preview_geometry.gd")
const TileResolver := preload("res://map/3d/terrain/map_3d_tile_resolver.gd")
const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const TERRAIN_AUTHORED_Y_OFFSET := SharedConstants.TERRAIN_AUTHORED_Y_OFFSET
const SUBQUAD_UV_INSET := 0.002 # Prevent internal 1/3 and 2/3 seam sampling bleed


static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var bw := w + 2
	if hgt.size() != bw * (h + 2) or w <= 0 or h <= 0:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var sector_y := PreviewGeometry.sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			PreviewGeometry.draw_flat_sector_geometry(st, x0, x1, z0, z1, sector_y)
	st.index()
	return st.commit()


static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	if not _is_valid_map_input(hgt, typ, w, h):
		return _empty_mesh_result()
	return _build_textured_sector_range(
		hgt,
		typ,
		w,
		h,
		mapping,
		subsector_patterns,
		tile_mapping,
		tile_remap,
		subsector_idx_remap,
		lego_defs,
		set_id,
		-1,
		-1,
		w + 1,
		h + 1,
		false
	)


static func build_chunk_mesh_with_textures(
	chunk_coord: Vector2i,
	hgt: PackedByteArray,
	typ: PackedByteArray,
	w: int,
	h: int,
	mapping: Dictionary,
	subsector_patterns: Dictionary = {},
	tile_mapping: Dictionary = {},
	tile_remap: Dictionary = {},
	subsector_idx_remap: Dictionary = {},
	lego_defs: Dictionary = {},
	set_id: int = 1,
	include_border: bool = true
) -> Dictionary:
	if not _is_valid_map_input(hgt, typ, w, h):
		return _empty_mesh_result()

	var chunk_range := ChunkGrid.chunk_sector_range(chunk_coord.x, chunk_coord.y)
	var sx_min := chunk_range.position.x
	var sy_min := chunk_range.position.y
	var sx_max := mini(sx_min + ChunkGrid.CHUNK_SIZE, w)
	var sy_max := mini(sy_min + ChunkGrid.CHUNK_SIZE, h)

	if include_border:
		sx_min = maxi(sx_min - 1, -1)
		sy_min = maxi(sy_min - 1, -1)
		sx_max = mini(sx_max + 1, w + 1)
		sy_max = mini(sy_max + 1, h + 1)

	return _build_textured_sector_range(
		hgt,
		typ,
		w,
		h,
		mapping,
		subsector_patterns,
		tile_mapping,
		tile_remap,
		subsector_idx_remap,
		lego_defs,
		set_id,
		sx_min,
		sy_min,
		sx_max,
		sy_max,
		true
	)


static func _is_valid_map_input(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int) -> bool:
	var bw := w + 2
	var bh := h + 2
	return w > 0 and h > 0 and hgt.size() == bw * bh and typ.size() == w * h


static func _empty_mesh_result() -> Dictionary:
	return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}, "authored_piece_descriptors": []}


static func _build_textured_sector_range(
	hgt: PackedByteArray,
	typ: PackedByteArray,
	w: int,
	h: int,
	mapping: Dictionary,
	subsector_patterns: Dictionary,
	tile_mapping: Dictionary,
	tile_remap: Dictionary,
	subsector_idx_remap: Dictionary,
	lego_defs: Dictionary,
	set_id: int,
	sx_min: int,
	sy_min: int,
	sx_max: int,
	sy_max: int,
	use_raw_id_in_instance_keys: bool
) -> Dictionary:
	var surface_tools := {}
	var surface_type_order: Array[int] = []
	for i in 6:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface_tools[i] = st
		surface_type_order.append(i)
	var st_invalid := SurfaceTool.new()
	st_invalid.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tools[-1] = st_invalid
	surface_type_order.append(-1)

	var authored_piece_descriptors: Array = []
	var authored_descriptor_base_cache := {}
	for y in range(sy_min, sy_max):
		for x in range(sx_min, sx_max):
			_append_sector(
				surface_tools,
				authored_piece_descriptors,
				authored_descriptor_base_cache,
				hgt,
				typ,
				w,
				h,
				mapping,
				subsector_patterns,
				tile_mapping,
				tile_remap,
				subsector_idx_remap,
				lego_defs,
				set_id,
				x,
				y,
				use_raw_id_in_instance_keys
			)

	var committed := _commit_surface_tools(surface_tools, surface_type_order)
	return {
		"mesh": committed["mesh"],
		"surface_to_surface_type": committed["surface_to_surface_type"],
		"authored_piece_descriptors": authored_piece_descriptors
	}


static func _append_sector(
	surface_tools: Dictionary,
	authored_piece_descriptors: Array,
	authored_descriptor_base_cache: Dictionary,
	hgt: PackedByteArray,
	typ: PackedByteArray,
	w: int,
	h: int,
	mapping: Dictionary,
	subsector_patterns: Dictionary,
	tile_mapping: Dictionary,
	tile_remap: Dictionary,
	subsector_idx_remap: Dictionary,
	lego_defs: Dictionary,
	set_id: int,
	x: int,
	y: int,
	use_raw_id_in_instance_keys: bool
) -> void:
	var typ_value := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x, y)
	var surface_type := PreviewGeometry.preview_surface_type_for_typ(mapping, typ_value)
	var st: SurfaceTool = surface_tools[surface_type]
	var sector_y := PreviewGeometry.sample_hgt_height(hgt, w, h, x, y)
	var x0 := float(x + 1) * SECTOR_SIZE
	var x1 := float(x + 2) * SECTOR_SIZE
	var z0 := float(y + 1) * SECTOR_SIZE
	var z1 := float(y + 2) * SECTOR_SIZE
	if surface_type == -1:
		PreviewGeometry.draw_quad(st, x0, x1, z0, z1, sector_y, 0, 1, 0)
		return

	var pattern := TileResolver.sector_pattern_for_typ(subsector_patterns, typ_value, surface_type)
	var sector_type := int(pattern.get("sector_type", 1))
	var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
	if sector_type == 0 and subsectors.size() >= 9:
		_append_complex_sector(
			st,
			authored_piece_descriptors,
			authored_descriptor_base_cache,
			subsectors,
			surface_type,
			tile_mapping,
			tile_remap,
			subsector_idx_remap,
			lego_defs,
			set_id,
			x,
			y,
			x0,
			z0,
			sector_y,
			use_raw_id_in_instance_keys
		)
		return

	_append_compact_sector(
		st,
		authored_piece_descriptors,
		authored_descriptor_base_cache,
		subsectors,
		surface_type,
		tile_mapping,
		tile_remap,
		subsector_idx_remap,
		lego_defs,
		set_id,
		x,
		y,
		x0,
		x1,
		z0,
		z1,
		sector_y,
		use_raw_id_in_instance_keys
	)


static func _append_complex_sector(
	st: SurfaceTool,
	authored_piece_descriptors: Array,
	authored_descriptor_base_cache: Dictionary,
	subsectors: PackedInt32Array,
	surface_type: int,
	tile_mapping: Dictionary,
	tile_remap: Dictionary,
	subsector_idx_remap: Dictionary,
	lego_defs: Dictionary,
	set_id: int,
	x: int,
	y: int,
	x0: float,
	z0: float,
	sector_y: float,
	use_raw_id_in_instance_keys: bool
) -> void:
	var piece_w := SECTOR_SIZE / 3.0
	var piece_h := SECTOR_SIZE / 3.0
	for sub_y in 3:
		for sub_x in 3:
			var sub_idx := sub_y * 3 + sub_x
			var selection := TileResolver.default_piece_selection_for_subsector(surface_type, int(subsectors[sub_idx]), tile_mapping, tile_remap, subsector_idx_remap)
			var piece: Array = selection.get("piece", [surface_type, (16 if surface_type == 4 else 4), 0])
			var authored := TileResolver.authored_descriptor_from_cache(
				authored_descriptor_base_cache,
				set_id,
				int(selection.get("raw_id", -1)),
				lego_defs,
				TileResolver.authored_origin_for_subsector(x0, z0, sector_y, sub_x, sub_y)
			)
			if not authored.is_empty():
				authored["instance_key"] = _terrain_instance_key(set_id, x, y, sub_x, sub_y, authored, use_raw_id_in_instance_keys, true)
				authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
				authored_piece_descriptors.append(authored)
				continue
			PreviewGeometry.draw_quad(
				st,
				x0 + float(sub_x) * piece_w,
				x0 + float(sub_x + 1) * piece_w,
				z0 + float(sub_y) * piece_h,
				z0 + float(sub_y + 1) * piece_h,
				sector_y,
				int(piece[0]),
				int(piece[1]),
				int(piece[2]),
				0,
				clampf(float(sub_x) / 3.0 + SUBQUAD_UV_INSET, 0.0, 1.0),
				clampf(1.0 - float(sub_y + 1) / 3.0 + SUBQUAD_UV_INSET, 0.0, 1.0),
				clampf(float(sub_x + 1) / 3.0 - SUBQUAD_UV_INSET, 0.0, 1.0),
				clampf(1.0 - float(sub_y) / 3.0 - SUBQUAD_UV_INSET, 0.0, 1.0)
			)


static func _append_compact_sector(
	st: SurfaceTool,
	authored_piece_descriptors: Array,
	authored_descriptor_base_cache: Dictionary,
	subsectors: PackedInt32Array,
	surface_type: int,
	tile_mapping: Dictionary,
	tile_remap: Dictionary,
	subsector_idx_remap: Dictionary,
	lego_defs: Dictionary,
	set_id: int,
	x: int,
	y: int,
	x0: float,
	x1: float,
	z0: float,
	z1: float,
	sector_y: float,
	use_raw_id_in_instance_keys: bool
) -> void:
	var piece := [surface_type, (16 if surface_type == 4 else 4), 0]
	var authored := {}
	if subsectors.size() > 0:
		var selection := TileResolver.default_piece_selection_for_subsector(surface_type, int(subsectors[0]), tile_mapping, tile_remap, subsector_idx_remap)
		piece = selection.get("piece", piece)
		authored = TileResolver.authored_descriptor_from_cache(
			authored_descriptor_base_cache,
			set_id,
			int(selection.get("raw_id", -1)),
			lego_defs,
			Vector3((x0 + x1) * 0.5, sector_y, (z0 + z1) * 0.5)
		)
	if authored.is_empty():
		PreviewGeometry.draw_quad(st, x0, x1, z0, z1, sector_y, int(piece[0]), int(piece[1]), int(piece[2]))
		return
	authored["instance_key"] = _terrain_instance_key(set_id, x, y, 0, 0, authored, use_raw_id_in_instance_keys, false)
	authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
	authored_piece_descriptors.append(authored)


static func _terrain_instance_key(set_id: int, x: int, y: int, sub_x: int, sub_y: int, authored: Dictionary, use_raw_id: bool, complex_sector: bool) -> String:
	var key_raw_id := int(authored.get("raw_id", -1)) if use_raw_id else 0
	if complex_sector:
		return "terrain:%d:%d:%d:%d:%d:%d" % [set_id, x, y, sub_x, sub_y, key_raw_id]
	return "terrain:%d:%d:%d:%d" % [set_id, x, y, key_raw_id]


static func _commit_surface_tools(surface_tools: Dictionary, surface_type_order: Array[int]) -> Dictionary:
	var mesh := ArrayMesh.new()
	var surface_to_surface_type := {}
	for i in surface_type_order.size():
		var surface_type: int = surface_type_order[i]
		var st: SurfaceTool = surface_tools[surface_type]
		var before := mesh.get_surface_count()
		st.index()
		st.commit(mesh)
		var after := mesh.get_surface_count()
		if after > before:
			surface_to_surface_type[before] = surface_type
	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type}

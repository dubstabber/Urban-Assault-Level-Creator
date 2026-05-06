extends RefCounted

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const PreviewGeometry := preload("res://map/3d/terrain/map_3d_preview_geometry.gd")
const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE
const EDGE_SLOPE := SharedConstants.EDGE_SLOPE
const TERRAIN_AUTHORED_Y_OFFSET := SharedConstants.TERRAIN_AUTHORED_Y_OFFSET


static func _retail_slurp_bucket_key(surface_a: int, surface_b: int, neighbor_dx: int, neighbor_dy: int) -> String:
	if neighbor_dx != 0:
		return "vside_%d_%d" % [surface_a, surface_b]
	if neighbor_dy != 0:
		return "hside_%d_%d" % [surface_a, surface_b]
	return ""


static func _surface_pair_from_slurp_bucket_key(bucket_key: String) -> Dictionary:
	var parts := bucket_key.split("_")
	if parts.size() != 3:
		return {}
	return {
		"orientation": String(parts[0]),
		"surface_a": clampi(int(parts[1]), 0, 5),
		"surface_b": clampi(int(parts[2]), 0, 5),
	}


static func _authored_slurp_base_name(surface_a: int, surface_b: int, vertical: bool) -> String:
	return "S%d%d%s" % [clampi(surface_a, 0, 5), clampi(surface_b, 0, 5), ("V" if vertical else "H")]


static func _sector_center_origin(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE, sector_y, (float(sy) + 1.5) * SECTOR_SIZE)


static func _sector_center_origin_scaled(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5), sector_y / SECTOR_SIZE, (float(sy) + 1.5))


static func _should_emit_seam_strip(_surface_a: int, _surface_b: int, _outer_a: float, _outer_b: float, _seam_mid_a: float, _seam_mid_b: float) -> bool:
	return true


static func _chunk_owns_vertical_seam(x: int, y: int, sx_min: int, sx_max: int, sy_min: int, sy_max: int, h: int) -> bool:
	var owns_x := (x == -1 and sx_min == 0) or (x >= sx_min and x < sx_max)
	var owns_y := (y == -1 and sy_min == 0) or (y == h and sy_max == h) or (y >= sy_min and y < sy_max)
	return owns_x and owns_y


static func _chunk_owns_horizontal_seam(x: int, y: int, sx_min: int, sx_max: int, sy_min: int, sy_max: int, w: int) -> bool:
	var owns_x := (x == -1 and sx_min == 0) or (x == w and sx_max == w) or (x >= sx_min and x < sx_max)
	var owns_y := (y == -1 and sy_min == 0) or (y >= sy_min and y < sy_max)
	return owns_x and owns_y


static func _append_vertical_seam_strip(st: SurfaceTool, x0: float, seam_x: float, x1: float, z0: float, z1: float, y_left: float, y_right: float, y_top_avg: float, y_bottom_avg: float) -> void:
	var lt := Vector3(x0, y_left, z0)
	var lb := Vector3(x0, y_left, z1)
	var st_top := Vector3(seam_x, y_top_avg, z0)
	var st_bottom := Vector3(seam_x, y_bottom_avg, z1)
	var rt := Vector3(x1, y_right, z0)
	var rb := Vector3(x1, y_right, z1)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(lb)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rt)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)


static func _append_horizontal_seam_strip(st: SurfaceTool, x0: float, x1: float, z0: float, seam_z: float, z1: float, y_top: float, y_bottom: float, y_left_avg: float, y_right_avg: float) -> void:
	var tl := Vector3(x0, y_top, z0)
	var top_right := Vector3(x1, y_top, z0)
	var sl := Vector3(x0, y_left_avg, seam_z)
	var sr := Vector3(x1, y_right_avg, seam_z)
	var bl := Vector3(x0, y_bottom, z1)
	var br := Vector3(x1, y_bottom, z1)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(top_right)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(bl)


static func build_edge_overlay_result(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary, set_id: int) -> Dictionary:
	var authored_piece_descriptors: Array = []
	var fallback_horiz := {}
	var fallback_vert := {}

	for y in range(-1, h + 1):
		for x in range(-1, w):
			var a := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x, y)
			var b := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := PreviewGeometry.center_h(hgt, w, h, x, y)
			var yR := PreviewGeometry.center_h(hgt, w, h, x + 1, y)
			var yTopAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			var base_name := _authored_slurp_base_name(sa, sb, true)
			if UATerrainPieceLibrary.has_piece_source(set_id, base_name):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "slurp:v:%d:%d:%d:%d:%d" % [set_id, x, y, sa, sb],
					"origin": _sector_center_origin(x + 1, y, yR),
					"y_offset": TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "vside",
					"anchor_height": yR,
					"left_height": yL,
					"right_height": yR,
					"top_avg": yTopAvg,
					"bottom_avg": yBottomAvg,
				})
				continue
			if sa == sb:
				continue
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

	for y2 in range(-1, h):
		for x2 in range(-1, w + 1):
			var a2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := PreviewGeometry.center_h(hgt, w, h, x2, y2)
			var yB := PreviewGeometry.center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			var base_name_h := _authored_slurp_base_name(sa2, sb2, false)
			if UATerrainPieceLibrary.has_piece_source(set_id, base_name_h):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name_h,
					"instance_key": "slurp:h:%d:%d:%d:%d:%d" % [set_id, x2, y2, sa2, sb2],
					"origin": _sector_center_origin(x2, y2 + 1, yB),
					"y_offset": TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "hside",
					"anchor_height": yB,
					"top_height": yT,
					"bottom_height": yB,
					"left_avg": yLeftAvg,
					"right_avg": yRightAvg,
				})
				continue
			if sa2 == sb2:
				continue
			_append_horizontal_fallback_group(fallback_vert, _retail_slurp_bucket_key(sa2, sb2, 0, 1), float(x2 + 1) * SECTOR_SIZE, float(x2 + 2) * SECTOR_SIZE, float(y2 + 2) * SECTOR_SIZE, yT, yB, yLeftAvg, yRightAvg)

	var fallback_mesh := ArrayMesh.new()
	var fallback_horiz_keys: Array = fallback_horiz.keys()
	var fallback_vert_keys: Array = fallback_vert.keys()
	for key_h in fallback_horiz_keys:
		var st_h: SurfaceTool = fallback_horiz[key_h]
		st_h.index()
		st_h.generate_normals()
		st_h.commit(fallback_mesh)
	for key_v in fallback_vert_keys:
		var st_v: SurfaceTool = fallback_vert[key_v]
		st_v.index()
		st_v.generate_normals()
		st_v.commit(fallback_mesh)
	return {
		"authored_piece_descriptors": authored_piece_descriptors,
		"mesh": fallback_mesh if fallback_mesh.get_surface_count() > 0 else null,
		"fallback_horiz_keys": fallback_horiz_keys,
		"fallback_vert_keys": fallback_vert_keys,
	}


static func build_preview_edge_mesh_result(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary) -> Dictionary:
	var fallback_horiz := {}
	var fallback_vert := {}

	for y in range(-1, h + 1):
		for x in range(-1, w):
			var a := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x, y)
			var b := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := PreviewGeometry.center_h(hgt, w, h, x, y)
			var yR := PreviewGeometry.center_h(hgt, w, h, x + 1, y)
			var yTopAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			if sa == sb:
				continue
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

	for y2 in range(-1, h):
		for x2 in range(-1, w + 1):
			var a2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := PreviewGeometry.center_h(hgt, w, h, x2, y2)
			var yB := PreviewGeometry.center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			if sa2 == sb2:
				continue
			_append_horizontal_fallback_group(fallback_vert, _retail_slurp_bucket_key(sa2, sb2, 0, 1), float(x2 + 1) * SECTOR_SIZE, float(x2 + 2) * SECTOR_SIZE, float(y2 + 2) * SECTOR_SIZE, yT, yB, yLeftAvg, yRightAvg)

	var mesh := ArrayMesh.new()
	var fallback_horiz_keys: Array = fallback_horiz.keys()
	var fallback_vert_keys: Array = fallback_vert.keys()
	for key_h in fallback_horiz_keys:
		var st_h: SurfaceTool = fallback_horiz[key_h]
		st_h.index()
		st_h.generate_normals()
		st_h.commit(mesh)
	for key_v in fallback_vert_keys:
		var st_v: SurfaceTool = fallback_vert[key_v]
		st_v.index()
		st_v.generate_normals()
		st_v.commit(mesh)
	return {
		"mesh": mesh,
		"fallback_horiz_keys": fallback_horiz_keys,
		"fallback_vert_keys": fallback_vert_keys,
	}


static func _append_vertical_fallback_group(groups: Dictionary, bucket_key: String, seam_x: float, z0: float, z1: float, left_height: float, right_height: float, top_avg: float, bottom_avg: float) -> void:
	if bucket_key.is_empty():
		return
	var st: SurfaceTool = groups.get(bucket_key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[bucket_key] = st
	_append_vertical_seam_strip(st, seam_x - EDGE_SLOPE, seam_x, seam_x + EDGE_SLOPE, z0, z1, left_height, right_height, top_avg, bottom_avg)


static func _append_horizontal_fallback_group(groups: Dictionary, bucket_key: String, x0: float, x1: float, seam_z: float, top_height: float, bottom_height: float, left_avg: float, right_avg: float) -> void:
	if bucket_key.is_empty():
		return
	var st: SurfaceTool = groups.get(bucket_key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[bucket_key] = st
	_append_horizontal_seam_strip(st, x0, x1, seam_z - EDGE_SLOPE, seam_z, seam_z + EDGE_SLOPE, top_height, bottom_height, left_avg, right_avg)


static func build_chunk_edge_overlay_result(
	_chunk_coord: Vector2i,
	hgt: PackedByteArray,
	w: int,
	h: int,
	typ: PackedByteArray,
	mapping: Dictionary,
	_set_id: int
) -> Dictionary:
	var authored_piece_descriptors: Array = []
	var fallback_horiz := {}
	var fallback_vert := {}

	var chunk_range := ChunkGrid.chunk_sector_range(_chunk_coord.x, _chunk_coord.y)
	var sx_min := chunk_range.position.x
	var sy_min := chunk_range.position.y
	var sx_max := mini(sx_min + ChunkGrid.CHUNK_SIZE, w)
	var sy_max := mini(sy_min + ChunkGrid.CHUNK_SIZE, h)

	for y in range(sy_min - 1, sy_max + 1):
		for x in range(sx_min - 1, sx_max):
			if x < -1 or x >= w or y < -1 or y >= h + 1:
				continue
			if not _chunk_owns_vertical_seam(x, y, sx_min, sx_max, sy_min, sy_max, h):
				continue
			var a := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x, y)
			var b := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := PreviewGeometry.center_h(hgt, w, h, x, y)
			var yR := PreviewGeometry.center_h(hgt, w, h, x + 1, y)
			var yTopAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := PreviewGeometry.corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			var base_name := _authored_slurp_base_name(sa, sb, true)
			if UATerrainPieceLibrary.has_piece_source(_set_id, base_name):
				authored_piece_descriptors.append({
					"set_id": _set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "slurp:v:%d:%d:%d:%d:%d" % [_set_id, x, y, sa, sb],
					"origin": _sector_center_origin(x + 1, y, yR),
					"y_offset": TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "vside",
					"anchor_height": yR,
					"left_height": yL,
					"right_height": yR,
					"top_avg": yTopAvg,
					"bottom_avg": yBottomAvg,
				})
				continue
			if sa == sb:
				continue
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

	for y2 in range(sy_min - 1, sy_max):
		for x2 in range(sx_min - 1, sx_max + 1):
			if x2 < -1 or x2 >= w + 1 or y2 < -1 or y2 >= h:
				continue
			if not _chunk_owns_horizontal_seam(x2, y2, sx_min, sx_max, sy_min, sy_max, w):
				continue
			var a2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := PreviewGeometry.typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := PreviewGeometry.center_h(hgt, w, h, x2, y2)
			var yB := PreviewGeometry.center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := PreviewGeometry.corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			var base_name_h := _authored_slurp_base_name(sa2, sb2, false)
			if UATerrainPieceLibrary.has_piece_source(_set_id, base_name_h):
				authored_piece_descriptors.append({
					"set_id": _set_id,
					"raw_id": - 1,
					"base_name": base_name_h,
					"instance_key": "slurp:h:%d:%d:%d:%d:%d" % [_set_id, x2, y2, sa2, sb2],
					"origin": _sector_center_origin(x2, y2 + 1, yB),
					"y_offset": TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "hside",
					"anchor_height": yB,
					"top_height": yT,
					"bottom_height": yB,
					"left_avg": yLeftAvg,
					"right_avg": yRightAvg,
				})
				continue
			if sa2 == sb2:
				continue
			_append_horizontal_fallback_group(fallback_vert, _retail_slurp_bucket_key(sa2, sb2, 0, 1), float(x2 + 1) * SECTOR_SIZE, float(x2 + 2) * SECTOR_SIZE, float(y2 + 2) * SECTOR_SIZE, yT, yB, yLeftAvg, yRightAvg)

	var fallback_mesh := ArrayMesh.new()
	var fallback_horiz_keys: Array = fallback_horiz.keys()
	var fallback_vert_keys: Array = fallback_vert.keys()
	for key_h in fallback_horiz_keys:
		var st_h: SurfaceTool = fallback_horiz[key_h]
		st_h.index()
		st_h.generate_normals()
		st_h.commit(fallback_mesh)
	for key_v in fallback_vert_keys:
		var st_v: SurfaceTool = fallback_vert[key_v]
		st_v.index()
		st_v.generate_normals()
		st_v.commit(fallback_mesh)
	return {
		"authored_piece_descriptors": authored_piece_descriptors,
		"mesh": fallback_mesh if fallback_mesh.get_surface_count() > 0 else null,
		"fallback_horiz_keys": fallback_horiz_keys,
		"fallback_vert_keys": fallback_vert_keys,
	}

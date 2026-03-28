extends RefCounted
class_name Map3DTerrainBuilder

const UATerrainPieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
const TERRAIN_AUTHORED_Y_OFFSET := 0.5
const SUBQUAD_UV_INSET := 0.002 # Prevent internal 1/3 and 2/3 seam sampling bleed

const CHUNK_SIZE := 4
const CHUNK_SHIFT := 2

const BORDER_TYP_TOP_LEFT := 248
const BORDER_TYP_TOP := 252
const BORDER_TYP_TOP_RIGHT := 249
const BORDER_TYP_LEFT := 255
const BORDER_TYP_RIGHT := 253
const BORDER_TYP_BOTTOM_LEFT := 251
const BORDER_TYP_BOTTOM := 254
const BORDER_TYP_BOTTOM_RIGHT := 250


static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var bw := w + 2
	if hgt.size() != bw * (h + 2) or w <= 0 or h <= 0:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var sector_y := _sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			_draw_flat_sector_geometry(st, x0, x1, z0, z1, sector_y)
	st.index()
	st.generate_normals()
	return st.commit()


static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or typ.size() != w * h or w <= 0 or h <= 0:
		return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}, "authored_piece_descriptors": []}

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

	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var typ_value := _typ_value_with_implicit_border(typ, w, h, x, y)
			var surface_type := _preview_surface_type_for_typ(mapping, typ_value)
			var st: SurfaceTool = surface_tools[surface_type]
			var sector_y := _sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			if surface_type == -1:
				_draw_quad(st, x0, x1, z0, z1, sector_y, 0, 1, 0)
				continue

			var pattern := _sector_pattern_for_typ(subsector_patterns, typ_value, surface_type)
			var sector_type := int(pattern.get("sector_type", 1))
			var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
			if sector_type == 0 and subsectors.size() >= 9:
				var piece_w := SECTOR_SIZE / 3.0
				var piece_h := SECTOR_SIZE / 3.0
				for sub_y in 3:
					for sub_x in 3:
						var sub_idx := sub_y * 3 + sub_x
						var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[sub_idx]), tile_mapping, tile_remap, subsector_idx_remap)
						var piece: Array = selection.get("piece", [surface_type, (16 if surface_type == 4 else 4), 0])
						var piece_x0 := x0 + float(sub_x) * piece_w
						var piece_x1 := x0 + float(sub_x + 1) * piece_w
						var piece_z0 := z0 + float(sub_y) * piece_h
						var piece_z1 := z0 + float(sub_y + 1) * piece_h
						var authored := UATerrainPieceLibraryScript.resolve_authored_descriptor(
							set_id,
							int(selection.get("raw_id", -1)),
							lego_defs,
							_authored_origin_for_subsector(x0, z0, sector_y, sub_x, sub_y)
						)
						if not authored.is_empty():
							authored["instance_key"] = "terrain:%d:%d:%d:%d:%d:%d" % [
								set_id, x, y, sub_x, sub_y, int(authored.get("raw_id", -1))
							]
							authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
							authored_piece_descriptors.append(authored)
							continue
						_draw_quad(
							st,
							piece_x0,
							piece_x1,
							piece_z0,
							piece_z1,
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
			else:
				var piece := [surface_type, (16 if surface_type == 4 else 4), 0]
				var authored := {}
				if subsectors.size() > 0:
					var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[0]), tile_mapping, tile_remap, subsector_idx_remap)
					piece = selection.get("piece", piece)
					authored = UATerrainPieceLibraryScript.resolve_authored_descriptor(
						set_id,
						int(selection.get("raw_id", -1)),
						lego_defs,
						Vector3((x0 + x1) * 0.5, sector_y, (z0 + z1) * 0.5)
					)
				if authored.is_empty():
					_draw_quad(st, x0, x1, z0, z1, sector_y, int(piece[0]), int(piece[1]), int(piece[2]))
				else:
					authored["instance_key"] = "terrain:%d:%d:%d:%d" % [set_id, x, y, int(authored.get("raw_id", -1))]
					authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
					authored_piece_descriptors.append(authored)
					continue

	var mesh := ArrayMesh.new()
	var surface_to_surface_type := {}
	for i in surface_type_order.size():
		var surface_type: int = surface_type_order[i]
		var st: SurfaceTool = surface_tools[surface_type]
		var before := mesh.get_surface_count()
		st.index()
		st.generate_normals()
		st.commit(mesh)
		var after := mesh.get_surface_count()
		if after > before:
			surface_to_surface_type[before] = surface_type
	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type, "authored_piece_descriptors": authored_piece_descriptors}


static func _sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	var bh := h + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, bh - 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE


static func _implicit_border_typ_value(w: int, h: int, sx: int, sy: int) -> int:
	var at_left := sx < 0
	var at_right := sx >= w
	var at_top := sy < 0
	var at_bottom := sy >= h
	if at_top:
		if at_left:
			return BORDER_TYP_TOP_LEFT
		if at_right:
			return BORDER_TYP_TOP_RIGHT
		return BORDER_TYP_TOP
	if at_bottom:
		if at_left:
			return BORDER_TYP_BOTTOM_LEFT
		if at_right:
			return BORDER_TYP_BOTTOM_RIGHT
		return BORDER_TYP_BOTTOM
	if at_left:
		return BORDER_TYP_LEFT
	if at_right:
		return BORDER_TYP_RIGHT
	return -1


static func _typ_value_with_implicit_border(typ: PackedByteArray, w: int, h: int, sx: int, sy: int) -> int:
	if sx >= 0 and sx < w and sy >= 0 and sy < h:
		return int(typ[sy * w + sx])
	return _implicit_border_typ_value(w, h, sx, sy)


static func _corner_average_h(hgt: PackedByteArray, w: int, h: int, corner_x: int, corner_y: int) -> float:
	var h_nw := _sample_hgt_height(hgt, w, h, corner_x - 1, corner_y - 1)
	var h_ne := _sample_hgt_height(hgt, w, h, corner_x, corner_y - 1)
	var h_sw := _sample_hgt_height(hgt, w, h, corner_x - 1, corner_y)
	var h_se := _sample_hgt_height(hgt, w, h, corner_x, corner_y)
	return (h_nw + h_ne + h_sw + h_se) * 0.25


static func _center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return _sample_hgt_height(hgt, w, h, sx, sy)


static func _draw_flat_sector_geometry(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var nw := Vector3(x0, y, z0)
	var ne := Vector3(x1, y, z0)
	var se := Vector3(x1, y, z1)
	var sw := Vector3(x0, y, z1)
	st.add_vertex(nw); st.add_vertex(ne); st.add_vertex(se)
	st.add_vertex(nw); st.add_vertex(se); st.add_vertex(sw)


static func _preview_surface_type_for_typ(mapping: Dictionary, typ_value: int) -> int:
	if not mapping.has(typ_value):
		return -1
	return clampi(int(mapping.get(typ_value, 0)), 0, 5)


static func _draw_quad(st: SurfaceTool, xl: float, xr: float, zt: float, zb: float, y: float, f: int, cells: int, v: int, rot_deg: int = 0, u0: float = 0.0, vv0: float = 0.0, u1: float = 1.0, vv1: float = 1.0) -> void:
	var rot := ((rot_deg % 360) + 360) % 360
	var uv_nw := Vector2(u0, vv0)
	var uv_ne := Vector2(u1, vv0)
	var uv_se := Vector2(u1, vv1)
	var uv_sw := Vector2(u0, vv1)
	if rot == 90:
		uv_nw = Vector2(u1, vv0)
		uv_ne = Vector2(u1, vv1)
		uv_se = Vector2(u0, vv1)
		uv_sw = Vector2(u0, vv0)
	elif rot == 180:
		uv_nw = Vector2(u1, vv1)
		uv_ne = Vector2(u0, vv1)
		uv_se = Vector2(u0, vv0)
		uv_sw = Vector2(u1, vv0)
	elif rot == 270:
		uv_nw = Vector2(u0, vv1)
		uv_ne = Vector2(u0, vv0)
		uv_se = Vector2(u1, vv0)
		uv_sw = Vector2(u1, vv1)
	st.set_color(Color((float(v) + 0.5) / float(cells), (float(f) + 0.5) / 6.0, 0.0))
	st.set_uv(uv_nw)
	st.add_vertex(Vector3(xl, y, zt))
	st.set_uv(uv_ne)
	st.add_vertex(Vector3(xr, y, zt))
	st.set_uv(uv_se)
	st.add_vertex(Vector3(xr, y, zb))
	st.set_uv(uv_nw)
	st.add_vertex(Vector3(xl, y, zt))
	st.set_uv(uv_se)
	st.add_vertex(Vector3(xr, y, zb))
	st.set_uv(uv_sw)
	st.add_vertex(Vector3(xl, y, zb))


static func _decode_raw_to_fcv(raw_val: int, default_file: int) -> Array:
	var f: int
	var cells: int
	var v: int
	var n := maxi(raw_val, 0)
	if n <= 3:
		f = default_file
		cells = (16 if f == 4 else 4)
		v = n
	elif n <= 7:
		f = 1
		cells = 4
		v = n - 4
	elif n <= 11:
		f = 2
		cells = 4
		v = n - 8
	elif n <= 15:
		f = 3
		cells = 4
		v = n - 12
	elif n <= 31:
		f = 4
		cells = 16
		v = n - 16
	elif n <= 35:
		f = 5
		cells = 4
		v = n - 32
	elif n <= 127:
		var file_idx := (n - 36) % 6
		f = (default_file if file_idx == 0 else file_idx)
		cells = (16 if f == 4 else 4)
		v = 0
	else:
		f = default_file
		cells = (16 if f == 4 else 4)
		v = 0
	return [f, cells, v]


static func _decode_raw_to_fcv_with_remap(raw_val: int, default_file: int, tile_remap: Dictionary) -> Array:
	if tile_remap:
		var raw_key := str(raw_val)
		if tile_remap.has(raw_key):
			var remap_entry: Dictionary = tile_remap[raw_key]
			var file_idx := int(remap_entry.get("file", default_file))
			var cells := (16 if file_idx == 4 else 4)
			var variant_idx := clampi(int(remap_entry.get("variant", 0)), 0, cells - 1)
			return [file_idx, cells, variant_idx]
	return _decode_raw_to_fcv(raw_val, default_file)


static func _remap_subsector_idx(subsector_idx: int, remap_table: Dictionary) -> int:
	if remap_table:
		var key := str(subsector_idx)
		if remap_table.has(key):
			return int(remap_table[key])
		if remap_table.has(subsector_idx):
			return int(remap_table[subsector_idx])
	return subsector_idx


static func _tile_desc_for_subsector(tile_mapping: Dictionary, subsector_idx: int) -> Dictionary:
	if tile_mapping.is_empty():
		return {}
	if tile_mapping.has(subsector_idx):
		return tile_mapping[subsector_idx]
	var key := str(subsector_idx)
	if tile_mapping.has(key):
		return tile_mapping[key]
	return {}


static func _sector_pattern_for_typ(subsector_patterns: Dictionary, typ_value: int, fallback_surface_type: int) -> Dictionary:
	if subsector_patterns.is_empty():
		return {
			"surface_type": fallback_surface_type,
			"sector_type": 1,
			"subsectors": PackedInt32Array()
		}
	if subsector_patterns.has(typ_value):
		return subsector_patterns[typ_value]
	var key := str(typ_value)
	if subsector_patterns.has(key):
		return subsector_patterns[key]
	return {
		"surface_type": fallback_surface_type,
		"sector_type": 1,
		"subsectors": PackedInt32Array()
	}


static func _default_stage_slot_for_raw(raw_value: int) -> int:
	if raw_value <= 0:
		return 3
	if raw_value <= 99:
		return 2
	if raw_value <= 199:
		return 1
	return 0


static func _selected_raw_id_for_tile_desc(tile_desc: Dictionary) -> int:
	var vals: Array[int] = [
		int(tile_desc.get("val0", 0)),
		int(tile_desc.get("val1", 0)),
		int(tile_desc.get("val2", 0)),
		int(tile_desc.get("val3", 0)),
	]
	if int(tile_desc.get("flag", 0)) == 0 and vals[0] != 0 and vals[0] == vals[1] and vals[1] == vals[2] and vals[3] != 0 and vals[3] != vals[0]:
		return vals[0]
	var raw_val := vals[_default_stage_slot_for_raw(int(tile_desc.get("flag", 0)))]
	if raw_val != 0:
		return raw_val
	var single_nonzero_raw := 0
	for candidate in vals:
		if candidate == 0:
			continue
		if single_nonzero_raw == 0:
			single_nonzero_raw = candidate
			continue
		if candidate != single_nonzero_raw:
			return raw_val
	return single_nonzero_raw


static func _default_piece_selection_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Dictionary:
	var default_file := clampi(surface_type, 0, 5)
	var remapped_idx := _remap_subsector_idx(subsector_idx, subsector_idx_remap)
	var tile_desc := _tile_desc_for_subsector(tile_mapping, remapped_idx)
	if tile_desc.is_empty():
		return {"raw_id": - 1, "piece": [default_file, (16 if default_file == 4 else 4), 0]}
	var raw_val := _selected_raw_id_for_tile_desc(tile_desc)
	return {"raw_id": raw_val, "piece": _decode_raw_to_fcv_with_remap(raw_val, default_file, tile_remap)}


static func _default_file_variant_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Array:
	return _default_piece_selection_for_subsector(surface_type, subsector_idx, tile_mapping, tile_remap, subsector_idx_remap).get("piece", [clampi(surface_type, 0, 5), (16 if surface_type == 4 else 4), 0])


static func _authored_origin_for_subsector(sector_x0: float, sector_z0: float, sector_y: float, sub_x: int, sub_y: int) -> Vector3:
	var sector_center_x := sector_x0 + SECTOR_SIZE * 0.5
	var sector_center_z := sector_z0 + SECTOR_SIZE * 0.5
	var lattice_step := SECTOR_SIZE * 0.25
	return Vector3(
		sector_center_x + (float(sub_x) - 1.0) * lattice_step,
		sector_y,
		sector_center_z + (float(sub_y) - 1.0) * lattice_step
	)


static func sector_to_chunk(sx: int, sy: int) -> Vector2i:
	return Vector2i(sx >> CHUNK_SHIFT, sy >> CHUNK_SHIFT)


static func chunk_sector_range(cx: int, cy: int) -> Rect2i:
	return Rect2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)


static func chunk_count_for_map(map_w: int, map_h: int) -> Vector2i:
	if map_w <= 0 or map_h <= 0:
		return Vector2i.ZERO
	var cx := (map_w + CHUNK_SIZE - 1) >> CHUNK_SHIFT
	var cy := (map_h + CHUNK_SIZE - 1) >> CHUNK_SHIFT
	return Vector2i(cx, cy)


static func chunks_for_hgt_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if sx < 0 or sy < 0 or sx >= map_w or sy >= map_h:
		return result
	var primary := sector_to_chunk(sx, sy)
	var chunk_count := chunk_count_for_map(map_w, map_h)
	var touches_left_boundary := (sx % CHUNK_SIZE) == 0 and primary.x > 0
	var touches_right_boundary := (sx % CHUNK_SIZE) == (CHUNK_SIZE - 1) and (primary.x + 1) < chunk_count.x
	var touches_top_boundary := (sy % CHUNK_SIZE) == 0 and primary.y > 0
	var touches_bottom_boundary := (sy % CHUNK_SIZE) == (CHUNK_SIZE - 1) and (primary.y + 1) < chunk_count.y
	result.append(primary)
	if touches_left_boundary:
		result.append(Vector2i(primary.x - 1, primary.y))
	if touches_right_boundary:
		result.append(Vector2i(primary.x + 1, primary.y))
	if touches_top_boundary:
		result.append(Vector2i(primary.x, primary.y - 1))
	if touches_bottom_boundary:
		result.append(Vector2i(primary.x, primary.y + 1))
	if touches_left_boundary and touches_top_boundary:
		result.append(Vector2i(primary.x - 1, primary.y - 1))
	if touches_right_boundary and touches_top_boundary:
		result.append(Vector2i(primary.x + 1, primary.y - 1))
	if touches_left_boundary and touches_bottom_boundary:
		result.append(Vector2i(primary.x - 1, primary.y + 1))
	if touches_right_boundary and touches_bottom_boundary:
		result.append(Vector2i(primary.x + 1, primary.y + 1))
	return result


static func chunks_for_typ_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	return chunks_for_hgt_edit(sx, sy, map_w, map_h)


static func chunks_for_blg_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if sx < 0 or sy < 0 or sx >= map_w or sy >= map_h:
		return result
	result.append(sector_to_chunk(sx, sy))
	return result


static func all_chunks_for_map(map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_count := chunk_count_for_map(map_w, map_h)
	for cy in chunk_count.y:
		for cx in chunk_count.x:
			result.append(Vector2i(cx, cy))
	return result


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
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or typ.size() != w * h or w <= 0 or h <= 0:
		return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}, "authored_piece_descriptors": []}

	var chunk_range := chunk_sector_range(chunk_coord.x, chunk_coord.y)
	var sx_min := chunk_range.position.x
	var sy_min := chunk_range.position.y
	var sx_max := mini(sx_min + CHUNK_SIZE, w)
	var sy_max := mini(sy_min + CHUNK_SIZE, h)

	if include_border:
		sx_min = maxi(sx_min - 1, -1)
		sy_min = maxi(sy_min - 1, -1)
		sx_max = mini(sx_max + 1, w + 1)
		sy_max = mini(sy_max + 1, h + 1)

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

	for y in range(sy_min, sy_max):
		for x in range(sx_min, sx_max):
			var typ_value := _typ_value_with_implicit_border(typ, w, h, x, y)
			var surface_type := _preview_surface_type_for_typ(mapping, typ_value)
			var st: SurfaceTool = surface_tools[surface_type]
			var sector_y := _sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			if surface_type == -1:
				_draw_quad(st, x0, x1, z0, z1, sector_y, 0, 1, 0)
				continue

			var pattern := _sector_pattern_for_typ(subsector_patterns, typ_value, surface_type)
			var sector_type := int(pattern.get("sector_type", 1))
			var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
			if sector_type == 0 and subsectors.size() >= 9:
				var piece_w := SECTOR_SIZE / 3.0
				var piece_h := SECTOR_SIZE / 3.0
				for sub_y in 3:
					for sub_x in 3:
						var sub_idx := sub_y * 3 + sub_x
						var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[sub_idx]), tile_mapping, tile_remap, subsector_idx_remap)
						var piece: Array = selection.get("piece", [surface_type, (16 if surface_type == 4 else 4), 0])
						var piece_x0 := x0 + float(sub_x) * piece_w
						var piece_x1 := x0 + float(sub_x + 1) * piece_w
						var piece_z0 := z0 + float(sub_y) * piece_h
						var piece_z1 := z0 + float(sub_y + 1) * piece_h
						var authored := UATerrainPieceLibraryScript.resolve_authored_descriptor(
							set_id,
							int(selection.get("raw_id", -1)),
							lego_defs,
							_authored_origin_for_subsector(x0, z0, sector_y, sub_x, sub_y)
						)
						if not authored.is_empty():
							authored["instance_key"] = "terrain:%d:%d:%d:%d:%d:%d" % [
								set_id, x, y, sub_x, sub_y, int(authored.get("raw_id", -1))
							]
							authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
							authored_piece_descriptors.append(authored)
							continue
						_draw_quad(
							st,
							piece_x0,
							piece_x1,
							piece_z0,
							piece_z1,
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
			else:
				var piece := [surface_type, (16 if surface_type == 4 else 4), 0]
				var authored := {}
				if subsectors.size() > 0:
					var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[0]), tile_mapping, tile_remap, subsector_idx_remap)
					piece = selection.get("piece", piece)
					authored = UATerrainPieceLibraryScript.resolve_authored_descriptor(
						set_id,
						int(selection.get("raw_id", -1)),
						lego_defs,
						Vector3((x0 + x1) * 0.5, sector_y, (z0 + z1) * 0.5)
					)
				if authored.is_empty():
					_draw_quad(st, x0, x1, z0, z1, sector_y, int(piece[0]), int(piece[1]), int(piece[2]))
				else:
					authored["instance_key"] = "terrain:%d:%d:%d:%d" % [set_id, x, y, int(authored.get("raw_id", -1))]
					authored["y_offset"] = TERRAIN_AUTHORED_Y_OFFSET
					authored_piece_descriptors.append(authored)
					continue

	var mesh := ArrayMesh.new()
	var surface_to_surface_type := {}
	for i in surface_type_order.size():
		var surface_type: int = surface_type_order[i]
		var st: SurfaceTool = surface_tools[surface_type]
		var before := mesh.get_surface_count()
		st.index()
		st.generate_normals()
		st.commit(mesh)
		var after := mesh.get_surface_count()
		if after > before:
			surface_to_surface_type[before] = surface_type
	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type, "authored_piece_descriptors": authored_piece_descriptors}

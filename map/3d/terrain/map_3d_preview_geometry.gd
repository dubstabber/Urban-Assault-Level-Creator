extends RefCounted

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE
const WORLD_SCALE := SharedConstants.WORLD_SCALE
const EDGE_SLOPE := SharedConstants.EDGE_SLOPE
const BORDER_TYP_TOP_LEFT := SharedConstants.BORDER_TYP_TOP_LEFT
const BORDER_TYP_TOP := SharedConstants.BORDER_TYP_TOP
const BORDER_TYP_TOP_RIGHT := SharedConstants.BORDER_TYP_TOP_RIGHT
const BORDER_TYP_LEFT := SharedConstants.BORDER_TYP_LEFT
const BORDER_TYP_RIGHT := SharedConstants.BORDER_TYP_RIGHT
const BORDER_TYP_BOTTOM_LEFT := SharedConstants.BORDER_TYP_BOTTOM_LEFT
const BORDER_TYP_BOTTOM := SharedConstants.BORDER_TYP_BOTTOM
const BORDER_TYP_BOTTOM_RIGHT := SharedConstants.BORDER_TYP_BOTTOM_RIGHT


static func sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	var bh := h + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, bh - 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE


static func implicit_border_typ_value(w: int, h: int, sx: int, sy: int) -> int:
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


static func typ_value_with_implicit_border(typ: PackedByteArray, w: int, h: int, sx: int, sy: int) -> int:
	if sx >= 0 and sx < w and sy >= 0 and sy < h:
		return int(typ[sy * w + sx])
	return implicit_border_typ_value(w, h, sx, sy)


static func corner_average_h(hgt: PackedByteArray, w: int, h: int, corner_x: int, corner_y: int) -> float:
	var h_nw := sample_hgt_height(hgt, w, h, corner_x - 1, corner_y - 1)
	var h_ne := sample_hgt_height(hgt, w, h, corner_x, corner_y - 1)
	var h_sw := sample_hgt_height(hgt, w, h, corner_x - 1, corner_y)
	var h_se := sample_hgt_height(hgt, w, h, corner_x, corner_y)
	return (h_nw + h_ne + h_sw + h_se) * 0.25


static func draw_flat_sector_geometry(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var nw := Vector3(x0, y, z0)
	var ne := Vector3(x1, y, z0)
	var se := Vector3(x1, y, z1)
	var sw := Vector3(x0, y, z1)
	st.add_vertex(nw)
	st.add_vertex(ne)
	st.add_vertex(se)
	st.add_vertex(nw)
	st.add_vertex(se)
	st.add_vertex(sw)


static func preview_surface_type_for_typ(mapping: Dictionary, typ_value: int) -> int:
	if not mapping.has(typ_value):
		return -1
	return clampi(int(mapping.get(typ_value, 0)), 0, 5)


static func retail_slurp_bucket_key(surface_a: int, surface_b: int, neighbor_dx: int, neighbor_dy: int) -> String:
	if neighbor_dx != 0 and neighbor_dy == 0:
		return "vside_%d_%d" % [surface_a, surface_b]
	if neighbor_dy != 0 and neighbor_dx == 0:
		return "hside_%d_%d" % [surface_a, surface_b]
	return ""


static func surface_pair_from_slurp_bucket_key(bucket_key: String) -> Dictionary:
	var parts := bucket_key.split("_")
	if parts.size() != 3:
		return {}
	if parts[0] != "vside" and parts[0] != "hside":
		return {}
	return {
		"family": parts[0],
		"surface_a": clampi(int(parts[1]), 0, 5),
		"surface_b": clampi(int(parts[2]), 0, 5),
	}


static func authored_slurp_base_name(surface_a: int, surface_b: int, vertical: bool) -> String:
	return "S%d%d%s" % [clampi(surface_a, 0, 5), clampi(surface_b, 0, 5), ("V" if vertical else "H")]


static func sector_center_origin_scaled(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE * WORLD_SCALE, sector_y * WORLD_SCALE, (float(sy) + 1.5) * SECTOR_SIZE * WORLD_SCALE)


static func draw_quad(st: SurfaceTool, xl: float, xr: float, zt: float, zb: float, y: float, f: int, cells: int, v: int, rot_deg: int = 0, u0: float = 0.0, vv0: float = 0.0, u1: float = 1.0, vv1: float = 1.0) -> void:
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


static func decode_raw_to_fcv(raw_val: int, default_file: int) -> Array:
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


static func decode_raw_to_fcv_with_remap(raw_val: int, default_file: int, tile_remap: Dictionary) -> Array:
	if tile_remap:
		var raw_key := str(raw_val)
		if tile_remap.has(raw_key):
			var remap_entry: Dictionary = tile_remap[raw_key]
			var file_idx := int(remap_entry.get("file", default_file))
			var cells := (16 if file_idx == 4 else 4)
			var variant_idx := clampi(int(remap_entry.get("variant", 0)), 0, cells - 1)
			return [file_idx, cells, variant_idx]
	return decode_raw_to_fcv(raw_val, default_file)


static func remap_subsector_idx(subsector_idx: int, remap_table: Dictionary) -> int:
	if remap_table:
		var key := str(subsector_idx)
		if remap_table.has(key):
			return int(remap_table[key])
		if remap_table.has(subsector_idx):
			return int(remap_table[subsector_idx])
	return subsector_idx


static func tile_desc_for_subsector(tile_mapping: Dictionary, subsector_idx: int) -> Dictionary:
	if tile_mapping.is_empty():
		return {}
	if tile_mapping.has(subsector_idx):
		return tile_mapping[subsector_idx]
	var key := str(subsector_idx)
	if tile_mapping.has(key):
		return tile_mapping[key]
	return {}


static func sector_pattern_for_typ(subsector_patterns: Dictionary, typ_value: int, fallback_surface_type: int) -> Dictionary:
	if subsector_patterns.is_empty():
		return {
			"surface_type": fallback_surface_type,
			"sector_type": 1,
			"subsectors": PackedInt32Array(),
		}
	if subsector_patterns.has(typ_value):
		return subsector_patterns[typ_value]
	var key := str(typ_value)
	if subsector_patterns.has(key):
		return subsector_patterns[key]
	return {
		"surface_type": fallback_surface_type,
		"sector_type": 1,
		"subsectors": PackedInt32Array(),
	}


static func default_stage_slot_for_raw(raw_value: int) -> int:
	if raw_value <= 0:
		return 3
	if raw_value <= 99:
		return 2
	if raw_value <= 199:
		return 1
	return 0


static func selected_raw_id_for_tile_desc(tile_desc: Dictionary) -> int:
	var vals: Array[int] = [
		int(tile_desc.get("val0", 0)),
		int(tile_desc.get("val1", 0)),
		int(tile_desc.get("val2", 0)),
		int(tile_desc.get("val3", 0)),
	]
	if int(tile_desc.get("flag", 0)) == 0 and vals[0] != 0 and vals[0] == vals[1] and vals[1] == vals[2] and vals[3] != 0 and vals[3] != vals[0]:
		return vals[0]
	var raw_val := vals[default_stage_slot_for_raw(int(tile_desc.get("flag", 0)))]
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


static func default_piece_selection_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Dictionary:
	var default_file := clampi(surface_type, 0, 5)
	var remapped_idx := remap_subsector_idx(subsector_idx, subsector_idx_remap)
	var tile_desc := tile_desc_for_subsector(tile_mapping, remapped_idx)
	if tile_desc.is_empty():
		return {"raw_id": -1, "piece": [default_file, (16 if default_file == 4 else 4), 0]}
	var raw_val := selected_raw_id_for_tile_desc(tile_desc)
	return {"raw_id": raw_val, "piece": decode_raw_to_fcv_with_remap(raw_val, default_file, tile_remap)}


static func default_file_variant_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Array:
	return default_piece_selection_for_subsector(surface_type, subsector_idx, tile_mapping, tile_remap, subsector_idx_remap).get("piece", [clampi(surface_type, 0, 5), (16 if surface_type == 4 else 4), 0])


static func authored_origin_for_subsector(x0: float, z0: float, sector_y: float, sub_x: int, sub_y: int) -> Vector3:
	var sector_center_x := x0 + SECTOR_SIZE * 0.5
	var sector_center_z := z0 + SECTOR_SIZE * 0.5
	var lattice_step := SECTOR_SIZE * 0.25
	return Vector3(
		sector_center_x + (float(sub_x) - 1.0) * lattice_step,
		sector_y,
		sector_center_z + (float(sub_y) - 1.0) * lattice_step
	)


static func append_vertical_seam_strip(st: SurfaceTool, x0: float, seam_x: float, x1: float, z0: float, z1: float, y_left: float, y_right: float, y_top_avg: float, y_bottom_avg: float) -> void:
	var lt := Vector3(x0, y_left, z0)
	var st_top := Vector3(seam_x, y_top_avg, z0)
	var rt := Vector3(x1, y_right, z0)
	var lb := Vector3(x0, y_left, z1)
	var st_bottom := Vector3(seam_x, y_bottom_avg, z1)
	var rb := Vector3(x1, y_right, z1)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(st_top)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(lb)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(rt)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(st_bottom)


static func append_horizontal_seam_strip(st: SurfaceTool, x0: float, x1: float, z0: float, seam_z: float, z1: float, y_top: float, y_bottom: float, y_left_avg: float, y_right_avg: float) -> void:
	var tl := Vector3(x0, y_top, z0)
	var top_right := Vector3(x1, y_top, z0)
	var sl := Vector3(x0, y_left_avg, seam_z)
	var sr := Vector3(x1, y_right_avg, seam_z)
	var bl := Vector3(x0, y_bottom, z1)
	var br := Vector3(x1, y_bottom, z1)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(top_right)
	st.set_uv(Vector2(1.0, 0.5))
	st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.5))
	st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.5))
	st.add_vertex(sl)
	st.set_uv(Vector2(0.0, 0.5))
	st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 0.5))
	st.add_vertex(sr)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(br)
	st.set_uv(Vector2(0.0, 0.5))
	st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(br)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(bl)


static func should_emit_seam_strip(_surface_a: int, _surface_b: int, _outer_a: float, _outer_b: float, _seam_mid_a: float, _seam_mid_b: float) -> bool:
	return true


static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	return TerrainBuilder.build_mesh(hgt, w, h)


static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	return TerrainBuilder.build_mesh_with_textures(hgt, typ, w, h, mapping, subsector_patterns, tile_mapping, tile_remap, subsector_idx_remap, lego_defs, set_id)


static func center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return sample_hgt_height(hgt, w, h, sx, sy)

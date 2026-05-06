extends RefCounted

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
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
	st.set_normal(Vector3.UP)
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
	st.set_normal(Vector3.UP)
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


static func center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return sample_hgt_height(hgt, w, h, sx, sy)

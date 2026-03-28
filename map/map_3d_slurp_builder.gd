extends RefCounted
class_name Map3DSlurpBuilder

const UATerrainPieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")
const TerrainBuilder := preload("res://map/map_3d_terrain_builder.gd")

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
const EDGE_SLOPE := 150.0

#region agent log
const _AGENT_DEBUG_LOG_PATH := "/run/media/ydro/WDC/gamedev-workspace/Urban Assault Level Creator/.cursor/debug-324b35.log"
static var _agent_debug_log_count: int = 0
static func _agent_debug_log_once(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	if _agent_debug_log_count >= 200:
		return
	_agent_debug_log_count += 1
	var payload := {
		"sessionId": "324b35",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	var f := FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek(f.get_length())
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion


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
			var a := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x, y)
			var b := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := TerrainBuilder._center_h(hgt, w, h, x, y)
			var yR := TerrainBuilder._center_h(hgt, w, h, x + 1, y)
			var yTopAvg := TerrainBuilder._corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := TerrainBuilder._corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			var base_name := _authored_slurp_base_name(sa, sb, true)
			if UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "slurp:v:%d:%d:%d:%d:%d" % [set_id, x, y, sa, sb],
					"origin": _sector_center_origin(x + 1, y, yR),
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
			var a2 := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := TerrainBuilder._center_h(hgt, w, h, x2, y2)
			var yB := TerrainBuilder._center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := TerrainBuilder._corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := TerrainBuilder._corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			var base_name_h := _authored_slurp_base_name(sa2, sb2, false)
			if UATerrainPieceLibraryScript.has_piece_source(set_id, base_name_h):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name_h,
					"instance_key": "slurp:h:%d:%d:%d:%d:%d" % [set_id, x2, y2, sa2, sb2],
					"origin": _sector_center_origin(x2, y2 + 1, yB),
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
	chunk_coord: Vector2i,
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
	var vertical_checked := 0
	var vertical_rejected_by_ownership := 0
	var vertical_emitted := 0
	var vertical_same_surface_emitted := 0
	var horizontal_checked := 0
	var horizontal_rejected_by_ownership := 0
	var horizontal_emitted := 0
	var horizontal_same_surface_emitted := 0
	var vertical_same_surface_samples: Array = []
	var horizontal_same_surface_samples: Array = []
	var vertical_emitted_samples: Array = []
	var horizontal_emitted_samples: Array = []

	var chunk_range := TerrainBuilder.chunk_sector_range(chunk_coord.x, chunk_coord.y)
	var sx_min := chunk_range.position.x
	var sy_min := chunk_range.position.y
	var sx_max := mini(sx_min + TerrainBuilder.CHUNK_SIZE, w)
	var sy_max := mini(sy_min + TerrainBuilder.CHUNK_SIZE, h)

	for y in range(sy_min - 1, sy_max + 1):
		for x in range(sx_min - 1, sx_max):
			if x < -1 or x >= w or y < -1 or y >= h + 1:
				continue
			vertical_checked += 1
			if not _chunk_owns_vertical_seam(x, y, sx_min, sx_max, sy_min, sy_max, h):
				vertical_rejected_by_ownership += 1
				continue
			var a := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x, y)
			var b := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := TerrainBuilder._center_h(hgt, w, h, x, y)
			var yR := TerrainBuilder._center_h(hgt, w, h, x + 1, y)
			var yTopAvg := TerrainBuilder._corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := TerrainBuilder._corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			var base_name := _authored_slurp_base_name(sa, sb, true)
			if UATerrainPieceLibraryScript.has_piece_source(_set_id, base_name):
				authored_piece_descriptors.append({
					"set_id": _set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "slurp:v:%d:%d:%d:%d:%d" % [_set_id, x, y, sa, sb],
					"origin": _sector_center_origin(x + 1, y, yR),
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
			vertical_emitted += 1
			if vertical_emitted_samples.size() < 6:
				vertical_emitted_samples.append({
					"x": x,
					"y": y,
					"typ_a": a,
					"typ_b": b,
					"surface_a": sa,
					"surface_b": sb,
					"at_border": (x < 0 or x + 1 >= w or y < 0 or y >= h)
				})
			if sa == sb:
				vertical_same_surface_emitted += 1
				if vertical_same_surface_samples.size() < 4:
					vertical_same_surface_samples.append({
						"x": x,
						"y": y,
						"typ_a": a,
						"typ_b": b,
						"surface": sa,
						"outer_left": yL,
						"outer_right": yR,
						"corner_top_avg": yTopAvg,
						"corner_bottom_avg": yBottomAvg
					})
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

	for y2 in range(sy_min - 1, sy_max):
		for x2 in range(sx_min - 1, sx_max + 1):
			if x2 < -1 or x2 >= w + 1 or y2 < -1 or y2 >= h:
				continue
			horizontal_checked += 1
			if not _chunk_owns_horizontal_seam(x2, y2, sx_min, sx_max, sy_min, sy_max, w):
				horizontal_rejected_by_ownership += 1
				continue
			var a2 := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := TerrainBuilder._typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := TerrainBuilder._center_h(hgt, w, h, x2, y2)
			var yB := TerrainBuilder._center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := TerrainBuilder._corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := TerrainBuilder._corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			var base_name_h := _authored_slurp_base_name(sa2, sb2, false)
			if UATerrainPieceLibraryScript.has_piece_source(_set_id, base_name_h):
				authored_piece_descriptors.append({
					"set_id": _set_id,
					"raw_id": - 1,
					"base_name": base_name_h,
					"instance_key": "slurp:h:%d:%d:%d:%d:%d" % [_set_id, x2, y2, sa2, sb2],
					"origin": _sector_center_origin(x2, y2 + 1, yB),
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
			horizontal_emitted += 1
			if horizontal_emitted_samples.size() < 6:
				horizontal_emitted_samples.append({
					"x": x2,
					"y": y2,
					"typ_a": a2,
					"typ_b": b2,
					"surface_a": sa2,
					"surface_b": sb2,
					"at_border": (x2 < 0 or x2 >= w or y2 < 0 or y2 + 1 >= h)
				})
			if sa2 == sb2:
				horizontal_same_surface_emitted += 1
				if horizontal_same_surface_samples.size() < 4:
					horizontal_same_surface_samples.append({
						"x": x2,
						"y": y2,
						"typ_a": a2,
						"typ_b": b2,
						"surface": sa2,
						"outer_top": yT,
						"outer_bottom": yB,
						"corner_left_avg": yLeftAvg,
						"corner_right_avg": yRightAvg
					})
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
	#region agent log
	_agent_debug_log_once(
		"pre_fix",
		"H2_chunk_ownership_or_duplication",
		"Map3DSlurpBuilder.build_chunk_edge_overlay_result",
		"Collected chunk edge/slurp seam ownership statistics",
		{
			"chunk_x": chunk_coord.x,
			"chunk_y": chunk_coord.y,
			"map_w": w,
			"map_h": h,
			"vertical_checked": vertical_checked,
			"vertical_rejected_by_ownership": vertical_rejected_by_ownership,
			"vertical_emitted": vertical_emitted,
			"vertical_same_surface_emitted": vertical_same_surface_emitted,
			"horizontal_checked": horizontal_checked,
			"horizontal_rejected_by_ownership": horizontal_rejected_by_ownership,
			"horizontal_emitted": horizontal_emitted,
			"horizontal_same_surface_emitted": horizontal_same_surface_emitted,
			"vertical_same_surface_samples": vertical_same_surface_samples,
			"horizontal_same_surface_samples": horizontal_same_surface_samples,
			"vertical_emitted_samples": vertical_emitted_samples,
			"horizontal_emitted_samples": horizontal_emitted_samples,
			"fallback_horiz_group_count": fallback_horiz_keys.size(),
			"fallback_vert_group_count": fallback_vert_keys.size(),
			"mesh_surface_count": fallback_mesh.get_surface_count()
		}
	)
	#endregion
	return {
		"authored_piece_descriptors": authored_piece_descriptors,
		"mesh": fallback_mesh if fallback_mesh.get_surface_count() > 0 else null,
		"fallback_horiz_keys": fallback_horiz_keys,
		"fallback_vert_keys": fallback_vert_keys,
	}

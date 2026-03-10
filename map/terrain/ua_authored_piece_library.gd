extends RefCounted
class_name UATerrainPieceLibrary

const ASSET_ROOT := "res://urban_assault_decompiled-master/assets/sets"
const MODEL_SCALE := 4.0 / 3.0
const AnimatedSurfaceMeshInstanceScript = preload("res://map/terrain/ua_animated_surface_mesh_instance.gd")
const AREA_POL_FLAG_CLEARTRACY := 0x40
const AREA_POL_FLAG_FLATTRACY := 0x80
const AREA_POL_FLAG_TRACY_MASK := 0xC0
const UA_LUMTRACY_ALPHA := 192.0 / 255.0

static var _mesh_cache := {}
static var _material_cache := {}
static var _texture_cache := {}
static var _dir_cache := {}
static var _anim_cache := {}

static func resolve_authored_descriptor(set_id: int, raw_id: int, lego_defs: Dictionary, origin: Vector3) -> Dictionary:
	var lego := _lego_for_raw_id(lego_defs, raw_id)
	if lego.is_empty():
		return {}
	var base_name := String(lego.get("base_name", ""))
	var mesh: ArrayMesh = _load_piece_mesh(set_id, base_name)
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	return {"set_id": set_id, "raw_id": raw_id, "base_name": base_name, "origin": origin}

static func build_overlay_node(descriptors: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredOverlay"
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var set_id := int(desc.get("set_id", 1))
		var base_name := String(desc.get("base_name", ""))
		var piece_node := _build_piece_node(set_id, base_name, int(desc.get("raw_id", -1)))
		if piece_node == null:
			continue
		piece_node.position = desc.get("origin", Vector3.ZERO)
		root.add_child(piece_node)
	return root

static func _lego_for_raw_id(lego_defs: Dictionary, raw_id: int) -> Dictionary:
	if lego_defs.has(raw_id):
		return lego_defs[raw_id]
	var key := str(raw_id)
	return lego_defs.get(key, {})

static func _load_piece_mesh(set_id: int, base_name: String) -> ArrayMesh:
	if base_name.is_empty():
		return null
	var cache_key := "%d:%s" % [set_id, base_name.to_lower()]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	var piece_source := _load_piece_source(set_id, base_name)
	var bas_data: Dictionary = piece_source.get("bas_data", {})
	var points: Array = piece_source.get("points", [])
	var polys: Array = piece_source.get("polys", [])
	var mesh := ArrayMesh.new()
	for surface in _extract_surfaces(bas_data, points, polys, set_id):
		var mesh_surface := _mesh_surface_from_surface(surface, set_id)
		var triangles: Array = mesh_surface.get("triangles", [])
		if triangles.is_empty() or mesh_surface.get("material", null) == null:
			continue
		_append_surface_to_mesh(mesh, triangles, mesh_surface.get("material", null))
	_mesh_cache[cache_key] = mesh if mesh.get_surface_count() > 0 else null
	return _mesh_cache[cache_key]

static func _build_piece_node(set_id: int, base_name: String, raw_id: int) -> Node3D:
	if base_name.is_empty():
		return null
	var piece_source := _load_piece_source(set_id, base_name)
	var bas_data: Dictionary = piece_source.get("bas_data", {})
	var points: Array = piece_source.get("points", [])
	var polys: Array = piece_source.get("polys", [])
	var surfaces := _extract_surfaces(bas_data, points, polys, set_id)
	if surfaces.is_empty():
		return null
	var piece := Node3D.new()
	piece.name = "%s_%d" % [base_name, raw_id]
	for i in surfaces.size():
		var child := _surface_node_from_surface(surfaces[i], set_id)
		if child == null:
			continue
		child.name = "Surface_%d" % i
		piece.add_child(child)
	return piece if piece.get_child_count() > 0 else null

static func _extract_surfaces(node, points: Array, polys: Array, set_id: int) -> Array:
	var result: Array = []
	_collect_surfaces(node, result, points, polys, set_id)
	return result

static func _collect_surfaces(node, out: Array, points: Array, polys: Array, set_id: int) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("AREA"):
			var area_surface := _surface_from_area(node["AREA"], points, polys, set_id)
			if not area_surface.is_empty():
				out.append(area_surface)
			return
		if node.has("AMSH"):
			for surface in _surfaces_from_amsh(node["AMSH"], points, polys, set_id):
				out.append(surface)
			return
		for value in node.values():
			_collect_surfaces(value, out, points, polys, set_id)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_collect_surfaces(item, out, points, polys, set_id)

static func _surface_from_area(area_data: Array, points: Array, polys: Array, set_id: int) -> Dictionary:
	var poly_id := _first_poly_id(area_data)
	var polygon := _polygon_vertices(points, polys, poly_id)
	if polygon.is_empty():
		return {}
	var render_hints := _render_hints_from_area(area_data)
	var anim_name := _find_first_anim_name(area_data)
	if not anim_name.is_empty():
		var anim_frames := _load_anim_frames(set_id, anim_name, polygon)
		if not anim_frames.is_empty():
			var first_frame: Dictionary = anim_frames[0]
			return {
				"texture_name": String(first_frame.get("texture_name", "")),
				"triangles": first_frame.get("triangles", []),
				"animation_frames": anim_frames,
				"anim_name": anim_name,
				"render_hints": render_hints,
			}
	var texture_name := _find_first_name(area_data, "NAM2")
	var uv_points := _find_first_points(area_data, "OTL2")
	return {
		"texture_name": texture_name,
		"triangles": _triangulate(polygon, _coerce_uvs(uv_points, polygon, set_id, texture_name)),
		"render_hints": render_hints,
	}

static func _surfaces_from_amsh(amsh_data: Array, points: Array, polys: Array, set_id: int) -> Array:
	var triangles: Array = []
	var atts_entries := _find_first_atts_entries(amsh_data)
	var olpl_points := _find_first_points(amsh_data, "OLPL")
	var texture_name := _find_first_name(amsh_data, "NAM2")
	for i in atts_entries.size():
		var poly_id := int(atts_entries[i].get("poly_id", -1))
		var polygon := _polygon_vertices(points, polys, poly_id)
		if polygon.is_empty():
			continue
		var uv_points: Array = olpl_points[i] if i < olpl_points.size() else []
		triangles.append_array(_triangulate(polygon, _coerce_uvs(uv_points, polygon, set_id, texture_name)))
	if triangles.is_empty():
		return []
	return [{"texture_name": texture_name, "triangles": triangles}]

static func _triangulate(polygon: Array, uvs: Array) -> Array:
	var tris: Array = []
	for i in range(1, polygon.size() - 1):
		tris.append({"verts": [polygon[0], polygon[i], polygon[i + 1]], "uvs": [uvs[0], uvs[i], uvs[i + 1]]})
	return tris

static func _polygon_vertices(points: Array, polys: Array, poly_id: int) -> Array:
	if poly_id < 0 or poly_id >= polys.size():
		return []
	var polygon: Array = []
	for point_idx in polys[poly_id]:
		if int(point_idx) < 0 or int(point_idx) >= points.size():
			return []
		var p: Dictionary = points[int(point_idx)]
		polygon.append(Vector3(float(p.get("x", 0.0)) * MODEL_SCALE, -float(p.get("y", 0.0)) * MODEL_SCALE, float(p.get("z", 0.0)) * MODEL_SCALE))
	return polygon

static func _coerce_uvs(raw_uvs: Array, polygon: Array, set_id: int = 0, texture_name: String = "") -> Array:
	var uvs: Array = []
	var uv_scale := _uv_scale_for_texture(set_id, texture_name)
	for item in raw_uvs:
		var uv: Variant = _uv_point_to_vector2(item)
		if uv != null:
			uvs.append(Vector2(uv.x / uv_scale.x, uv.y / uv_scale.y))
	if uvs.size() == polygon.size():
		return uvs
	var min_x: float = polygon[0].x
	var max_x: float = polygon[0].x
	var min_z: float = polygon[0].z
	var max_z: float = polygon[0].z
	for v in polygon:
		min_x = min(min_x, v.x)
		max_x = max(max_x, v.x)
		min_z = min(min_z, v.z)
		max_z = max(max_z, v.z)
	var dx: float = max(max_x - min_x, 1.0)
	var dz: float = max(max_z - min_z, 1.0)
	for v in polygon:
		uvs.append(Vector2((v.x - min_x) / dx, (v.z - min_z) / dz))
	return uvs

static func _uv_point_to_vector2(item):
	if typeof(item) == TYPE_VECTOR2:
		return item
	if typeof(item) == TYPE_DICTIONARY:
		return Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
	if typeof(item) == TYPE_ARRAY and item.size() >= 2:
		return Vector2(float(item[0]), float(item[1]))
	return null

static func _uv_scale_for_texture(set_id: int, texture_name: String) -> Vector2:
	var tex := _texture_for_name(set_id, texture_name)
	if tex != null:
		return Vector2(max(tex.get_width() - 1, 1), max(tex.get_height() - 1, 1))
	return Vector2(255.0, 255.0)

static func _first_poly_id(node) -> int:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("STRC"):
			return int(node["STRC"].get("poly", -1))
		for value in node.values():
			var found := _first_poly_id(value)
			if found >= 0:
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _first_poly_id(item)
			if found >= 0:
				return found
	return -1

static func _find_first_name(node, target_key: String) -> String:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has(target_key):
			return String(node[target_key].get("name", ""))
		for value in node.values():
			var found := _find_first_name(value, target_key)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_name(item, target_key)
			if not found.is_empty():
				return found
	return ""

static func _find_first_anim_name(node) -> String:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("STRC") and typeof(node["STRC"]) == TYPE_DICTIONARY and node["STRC"].has("anim_name"):
			return String(node["STRC"].get("anim_name", ""))
		for value in node.values():
			var found := _find_first_anim_name(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_anim_name(item)
			if not found.is_empty():
				return found
	return ""

static func _find_first_area_strc(node) -> Dictionary:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("STRC") and typeof(node["STRC"]) == TYPE_DICTIONARY:
			var strc: Dictionary = node["STRC"]
			if strc.has("polFlags") or strc.has("trcVal") or strc.has("shdVal"):
				return strc
		for value in node.values():
			var found := _find_first_area_strc(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_area_strc(item)
			if not found.is_empty():
				return found
	return {}

static func _render_hints_from_area(node) -> Dictionary:
	var strc := _find_first_area_strc(node)
	if strc.is_empty():
		return {}
	var pol_flags := int(strc.get("polFlags", 0))
	var tracy_mode := pol_flags & AREA_POL_FLAG_TRACY_MASK
	if tracy_mode == AREA_POL_FLAG_FLATTRACY:
		return {
			"transparency_mode": "lumtracy",
			"tracy_val": int(strc.get("trcVal", 192)),
		}
	if tracy_mode == AREA_POL_FLAG_CLEARTRACY:
		return {"transparency_mode": "cutout"}
	return {}

static func _find_first_skeleton_ref(node) -> String:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("SKLC"):
			return _find_first_name(node["SKLC"], "NAME")
		for value in node.values():
			var found := _find_first_skeleton_ref(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_skeleton_ref(item)
			if not found.is_empty():
				return found
	return ""

static func _find_first_points(node, key: String) -> Array:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has(key):
			return node[key].get("points", [])
		for value in node.values():
			var found: Array = _find_first_points(value, key)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found: Array = _find_first_points(item, key)
			if not found.is_empty():
				return found
	return []

static func _find_first_edges(node, key: String) -> Array:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has(key):
			return node[key].get("edges", [])
		for value in node.values():
			var found: Array = _find_first_edges(value, key)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found: Array = _find_first_edges(item, key)
			if not found.is_empty():
				return found
	return []

static func _find_first_atts_entries(node) -> Array:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("ATTS"):
			return node["ATTS"].get("atts_entries", [])
		for value in node.values():
			var found: Array = _find_first_atts_entries(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found: Array = _find_first_atts_entries(item)
			if not found.is_empty():
				return found
	return []

static func _material_for_texture(set_id: int, texture_name: String, render_hints: Dictionary = {}) -> Material:
	var texture_file := _normalize_texture_name(texture_name)
	var hints := _normalized_render_hints(render_hints)
	var cache_key := _render_cache_key(set_id, texture_file, hints)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	var tex := _texture_for_name(set_id, texture_name, hints)
	if tex != null:
		mat.albedo_texture = tex
		var image := tex.get_image()
		var has_alpha := image != null and image.detect_alpha() != Image.ALPHA_NONE
		var transparency_mode := String(hints.get("transparency_mode", "auto"))
		if transparency_mode == "lumtracy":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mat.albedo_color = Color(1.0, 1.0, 1.0, UA_LUMTRACY_ALPHA)
		elif has_alpha:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
	if mat.albedo_texture == null:
		mat.albedo_color = Color(1.0, 0.0, 1.0, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_cache[cache_key] = mat
	return mat

static func _texture_for_name(set_id: int, texture_name: String, render_hints: Dictionary = {}) -> Texture2D:
	var texture_file := _normalize_texture_name(texture_name)
	if texture_file.is_empty():
		return null
	var hints := _normalized_render_hints(render_hints)
	var cache_key := _render_cache_key(set_id, texture_file, hints)
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var texture_path := _find_file(_set_root(set_id), texture_file)
	if texture_path.is_empty():
		_texture_cache[cache_key] = null
		return null
	var tex := load(texture_path)
	if tex is Texture2D:
		var image: Image = tex.get_image()
		if image != null:
			var converted := _apply_color_key_transparency(image)
			_texture_cache[cache_key] = ImageTexture.create_from_image(converted)
			return _texture_cache[cache_key]
	_texture_cache[cache_key] = tex if tex is Texture2D else null
	return _texture_cache[cache_key]

static func _normalized_render_hints(render_hints: Dictionary) -> Dictionary:
	var mode := String(render_hints.get("transparency_mode", "auto"))
	if mode != "cutout" and mode != "lumtracy":
		mode = "auto"
	return {
		"transparency_mode": mode,
		"tracy_val": clampi(int(render_hints.get("tracy_val", 0)), 0, 255),
	}

static func _render_cache_key(set_id: int, texture_file: String, render_hints: Dictionary) -> String:
	return "%d:%s:%s:%d" % [
		set_id,
		texture_file.to_lower(),
		String(render_hints.get("transparency_mode", "auto")),
		int(render_hints.get("tracy_val", 0)),
	]

static func _apply_color_key_transparency(image: Image) -> Image:
	var converted := image.duplicate()
	if converted.get_format() != Image.FORMAT_RGBA8:
		converted.convert(Image.FORMAT_RGBA8)
	for y in converted.get_height():
		for x in converted.get_width():
			var px: Color = converted.get_pixel(x, y)
			if is_equal_approx(px.r, 1.0) and is_equal_approx(px.g, 1.0) and is_equal_approx(px.b, 0.0):
				converted.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return converted

static func _load_anim_frames(set_id: int, anim_name: String, polygon: Array) -> Array:
	var cache_key := "%d:%s" % [set_id, anim_name.to_lower()]
	if _anim_cache.has(cache_key):
		return _clone_anim_frames(_anim_cache[cache_key], polygon, set_id)
	var anim_path := _find_anim_json_path(set_id, anim_name)
	var anim_data := _load_json(anim_path)
	var raw_frames := _find_frames_list(anim_data)
	var compiled: Array = []
	for frame in raw_frames:
		if typeof(frame) != TYPE_DICTIONARY:
			continue
		var texture_name := String(frame.get("vbmp_name", ""))
		var uv_points: Array = frame.get("vbmp_coords", [])
		compiled.append({
			"texture_name": texture_name,
			"raw_uv_points": uv_points.duplicate(true),
			"duration_sec": max(float(frame.get("frame_time", 40.0)) / 1000.0, 0.01),
		})
	_anim_cache[cache_key] = compiled
	return _clone_anim_frames(compiled, polygon, set_id)

static func _clone_anim_frames(compiled_frames: Array, polygon: Array, set_id: int) -> Array:
	var frames: Array = []
	for frame in compiled_frames:
		if typeof(frame) != TYPE_DICTIONARY:
			continue
		var texture_name := String(frame.get("texture_name", ""))
		var uvs := _coerce_uvs(frame.get("raw_uv_points", []), polygon, set_id, texture_name)
		frames.append({
			"texture_name": texture_name,
			"triangles": _triangulate(polygon, uvs),
			"duration_sec": float(frame.get("duration_sec", 0.04)),
		})
	return frames

static func _find_anim_json_path(set_id: int, anim_name: String) -> String:
	var cleaned := anim_name.strip_edges().get_file()
	if cleaned.is_empty():
		return ""
	var candidates: Array = []
	_push_unique(candidates, cleaned)
	if not cleaned.to_lower().ends_with(".json"):
		_push_unique(candidates, "%s.json" % cleaned)
	if not cleaned.to_lower().ends_with(".anm"):
		_push_unique(candidates, "%s.ANM.json" % cleaned)
	for candidate in candidates:
		var path := _find_file(_rsrcpool_dir(set_id), String(candidate))
		if not path.is_empty():
			return path
	return ""

static func _push_unique(items: Array, value) -> void:
	if not items.has(value):
		items.append(value)

static func _find_frames_list(node) -> Array:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("frames"):
			return node.get("frames", [])
		for value in node.values():
			var found: Array = _find_frames_list(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found: Array = _find_frames_list(item)
			if not found.is_empty():
				return found
	return []

static func _load_piece_source(set_id: int, base_name: String) -> Dictionary:
	var bas_path := _find_file(_buildings_dir(set_id), "%s.bas.json" % base_name)
	var bas_data := _load_json(bas_path)
	var skel_ref := _find_first_skeleton_ref(bas_data)
	var skel_name := skel_ref.get_file().get_basename() if not skel_ref.is_empty() else base_name
	var skel_data := _load_json(_find_file(_skeleton_dir(set_id), "%s.skl.json" % skel_name))
	return {
		"bas_data": bas_data,
		"points": _find_first_points(skel_data, "POO2"),
		"polys": _find_first_edges(skel_data, "POL2"),
	}

static func _surface_node_from_surface(surface: Dictionary, set_id: int) -> Node3D:
	var animation_frames: Array = surface.get("animation_frames", [])
	var render_hints: Dictionary = surface.get("render_hints", {})
	if not animation_frames.is_empty():
		var animated := AnimatedSurfaceMeshInstanceScript.new()
		var prepared_frames: Array = []
		for frame in animation_frames:
			var prepared: Dictionary = frame.duplicate(true)
			prepared["material"] = _material_for_texture(set_id, String(frame.get("texture_name", "")), render_hints)
			prepared_frames.append(prepared)
		animated.setup_animation(prepared_frames)
		animated.set_meta("ua_authored_animated", true)
		return animated
	var mi := MeshInstance3D.new()
	var mesh_surface := _mesh_surface_from_surface(surface, set_id)
	if mesh_surface.get("material", null) == null:
		return null
	mi.mesh = _mesh_from_triangles(mesh_surface.get("triangles", []), mesh_surface.get("material", null))
	return mi

static func _mesh_surface_from_surface(surface: Dictionary, set_id: int) -> Dictionary:
	var animation_frames: Array = surface.get("animation_frames", [])
	var render_hints: Dictionary = surface.get("render_hints", {})
	if not animation_frames.is_empty():
		var first_frame: Dictionary = animation_frames[0]
		return {
			"triangles": first_frame.get("triangles", []),
			"material": _material_for_texture(set_id, String(first_frame.get("texture_name", "")), render_hints),
		}
	return {
		"triangles": surface.get("triangles", []),
		"material": _material_for_texture(set_id, String(surface.get("texture_name", "")), render_hints),
	}

static func _mesh_from_triangles(triangles: Array, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_append_surface_to_mesh(mesh, triangles, material)
	return mesh

static func _append_surface_to_mesh(mesh: ArrayMesh, triangles: Array, material: Material) -> void:
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

static func _normalize_texture_name(texture_name: String) -> String:
	var cleaned := texture_name.strip_edges()
	if cleaned.is_empty():
		return ""
	var base := cleaned.get_basename()
	return "%s.ILB.bmp" % base

static func _load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func _find_file(dir_path: String, filename: String) -> String:
	if dir_path.is_empty() or filename.is_empty():
		return ""
	if not _dir_cache.has(dir_path):
		var index := {}
		for entry in DirAccess.get_files_at(dir_path):
			index[String(entry).to_lower()] = "%s/%s" % [dir_path, entry]
		_dir_cache[dir_path] = index
	return _dir_cache[dir_path].get(filename.to_lower(), "")

static func _set_root(set_id: int) -> String:
	return "%s/set%d" % [ASSET_ROOT, set_id]

static func _buildings_dir(set_id: int) -> String:
	return "%s/objects/buildings" % _set_root(set_id)

static func _skeleton_dir(set_id: int) -> String:
	return "%s/Skeleton" % _set_root(set_id)

static func _rsrcpool_dir(set_id: int) -> String:
	return "%s/rsrcpool" % _set_root(set_id)
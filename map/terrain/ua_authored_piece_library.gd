extends RefCounted
class_name UATerrainPieceLibrary

const _UAProjectDataRoots = preload("res://map/ua_project_data_roots.gd")
const _UALegacyText = preload("res://map/ua_legacy_text.gd")
## Optional override for tests/tools (`set_external_source_root`); runtime uses UAProjectDataRoots when unset.
# Raw BAS/SKLT terrain-piece coordinates already use UA world-space sector units:
# - 3x3 top pieces are authored as 300x300 footprints
# - full border-ring pieces are authored around 1200-unit sector spans
# Keep a 1:1 scale here so the later source-backed 300-unit lattice placement does not
# expand each subsector into a 400x400 overlap region and cause cross-piece z-fighting.
const MODEL_SCALE := 1.0
const OVERLAY_Y_BIAS := 8.0
const UA_SECTOR_SPAN := 1200.0
const UA_SECTOR_HALF := UA_SECTOR_SPAN * 0.5
const UA_SLURP_HALF_WIDTH := 150.0
const SUPPORT_BUCKET_CELL_SIZE := 300.0
const AnimatedSurfaceMeshInstanceScript = preload("res://map/terrain/ua_animated_surface_mesh_instance.gd")
const AREA_POL_FLAG_GRADIENTSHADE := 0x30
const AREA_POL_FLAG_SHADE_MASK := 0x30
const AREA_POL_FLAG_CLEARTRACY := 0x40
const AREA_POL_FLAG_FLATTRACY := 0x80
const AREA_POL_FLAG_TRACY_MASK := 0xC0
const UA_LUMTRACY_ALPHA := 192.0 / 255.0
const ILBM_MASK_HAS_MASK := 1
const ILBM_MASK_TRANSPARENT_COLOR := 2
const BMPANIM_UV_SCALE := 256.0

static var _mesh_cache := {}
static var _animated_overlay_cache := {}
static var _piece_overlay_emitters_cache := {}
static var _json_cache := {}
static var _piece_overlay_fast_path_count := 0
static var _piece_overlay_slow_path_count := 0
static var _material_cache := {}
static var _texture_cache := {}
static var _dir_cache := {}
static var _anim_cache := {}
static var _support_sampler_cache := {}
static var _deformed_slurp_mesh_cache := {}
static var _printed_piece_uv_diagnostics := {}
static var _external_source_loading_enabled := true
static var _external_source_root: String = ""
static var _piece_game_data_type := "original"
## When true, overlay pieces always use the static mesh fast path (skips BMP anim + PTCL).
static var _force_static_terrain_overlays := false

static func set_force_static_terrain_overlays(force: bool) -> void:
	_force_static_terrain_overlays = force

static func is_force_static_terrain_overlays() -> bool:
	return _force_static_terrain_overlays

static func set_piece_game_data_type(game_data_type: String) -> void:
	var n := game_data_type.strip_edges()
	if n.is_empty():
		n = "original"
	if n == _piece_game_data_type:
		return
	_piece_game_data_type = n
	_mesh_cache.clear()
	_animated_overlay_cache.clear()
	_piece_overlay_emitters_cache.clear()
	_json_cache.clear()
	_material_cache.clear()
	_texture_cache.clear()
	_dir_cache.clear()
	_anim_cache.clear()
	_support_sampler_cache.clear()
	_deformed_slurp_mesh_cache.clear()


static func reset_piece_overlay_build_counters() -> void:
	_piece_overlay_fast_path_count = 0
	_piece_overlay_slow_path_count = 0


static func get_piece_overlay_build_counters() -> Dictionary:
	return {
		"piece_overlay_fast_path": _piece_overlay_fast_path_count,
		"piece_overlay_slow_path": _piece_overlay_slow_path_count,
	}


static func set_external_source_loading_enabled(enabled: bool) -> void:
	_external_source_loading_enabled = enabled

static func set_external_source_root(path: String) -> void:
	_external_source_root = path.strip_edges()

static func _clear_runtime_caches_for_tests() -> void:
	_mesh_cache.clear()
	_animated_overlay_cache.clear()
	_piece_overlay_emitters_cache.clear()
	_json_cache.clear()
	_material_cache.clear()
	_texture_cache.clear()
	_dir_cache.clear()
	_anim_cache.clear()
	_support_sampler_cache.clear()
	_deformed_slurp_mesh_cache.clear()
	_external_source_loading_enabled = true
	_external_source_root = ""
	_piece_game_data_type = "original"
	_force_static_terrain_overlays = false

static func _vector3_from_json(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return Vector3(value)
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var d := Dictionary(value)
	return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))

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
	var overlay_manager = load("res://map/map_3d_authored_overlay_manager.gd")
	return overlay_manager.build_overlay_node(descriptors)

static func apply_overlay_node(root: Node3D, descriptors: Array) -> void:
	var overlay_manager = load("res://map/map_3d_authored_overlay_manager.gd")
	overlay_manager.apply_overlay_node(root, descriptors)

static func _warp_signature(desc: Dictionary) -> String:
	var warp_mode := String(desc.get("warp_mode", ""))
	if warp_mode.is_empty():
		return ""
	var parts: Array[String] = [warp_mode]
	for key in [
		"anchor_height",
		"left_height",
		"right_height",
		"top_avg",
		"bottom_avg",
		"top_height",
		"bottom_height",
		"left_avg",
		"right_avg"
	]:
		if desc.has(key):
			parts.append("%s=%.3f" % [key, float(desc.get(key, 0.0))])
	return "|".join(parts)

static func _str_position_key(pos: Vector3) -> String:
	# Coarse quantization is enough to stabilize keys for preview usage.
	return "%.2f,%.2f,%.2f" % [pos.x, pos.y, pos.z]

func apply_overlay_node_to(root: Node3D, descriptors: Array) -> void:
	var overlay_manager = load("res://map/map_3d_authored_overlay_manager.gd")
	overlay_manager.apply_overlay_node(root, descriptors)

static func _piece_position_from_desc(desc: Dictionary) -> Vector3:
	return Vector3(desc.get("origin", Vector3.ZERO)) + Vector3(0.0, OVERLAY_Y_BIAS + float(desc.get("y_offset", 0.0)), 0.0)

static func support_height_at_world_position(descriptors: Array, world_x: float, world_z: float):
	var seeded := false
	var best_y := 0.0
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var set_id := int(desc.get("set_id", 1))
		var base_name := String(desc.get("base_name", ""))
		var basis := _piece_basis_from_desc(desc)
		var origin := _piece_position_from_desc(desc)
		var sampled_height = null
		var warp_sig := _warp_signature(desc)
		var sampler := _piece_support_sampler(set_id, base_name, warp_sig, desc)
		if not sampler.is_empty():
			sampled_height = _support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)
		if sampled_height == null:
			continue
		var sampled_height_float := float(sampled_height)
		if not seeded or sampled_height_float > best_y:
			best_y = sampled_height_float
			seeded = true
	if not seeded:
		return null
	return best_y

static func _apply_optional_piece_orientation(piece_node: Node3D, desc: Dictionary) -> void:
	var basis := _piece_basis_from_desc(desc)
	if basis == Basis.IDENTITY:
		return
	piece_node.transform.basis = basis

static func _piece_basis_from_desc(desc: Dictionary) -> Basis:
	var forward_value = desc.get("forward", null)
	if typeof(forward_value) != TYPE_VECTOR3:
		return Basis.IDENTITY
	var forward := Vector3(forward_value)
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() <= 0.000001:
		return Basis.IDENTITY
	return Basis(Vector3.UP, atan2(-horizontal_forward.x, -horizontal_forward.z))

static func _mesh_support_height_at_world_position(mesh: Mesh, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	var sampler := _support_sampler_from_mesh(mesh)
	return _support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)

static func _piece_support_sampler(set_id: int, base_name: String, warp_sig: String = "", desc: Dictionary = {}) -> Dictionary:
	var cleaned := base_name.strip_edges().to_lower()
	if cleaned.is_empty():
		return {}
	var cache_key := "piece:%d:%s:%s:%s" % [maxi(set_id, 1), cleaned, warp_sig, _piece_game_data_type.to_lower()]
	if _support_sampler_cache.has(cache_key):
		var cached = _support_sampler_cache[cache_key]
		return cached if typeof(cached) == TYPE_DICTIONARY else {}
	var mesh: Mesh = _load_piece_mesh(set_id, base_name)
	if mesh == null or mesh.get_surface_count() == 0:
		_support_sampler_cache[cache_key] = {}
		return {}
	if not warp_sig.is_empty():
		mesh = _deformed_slurp_mesh(mesh, desc)
	if mesh == null or mesh.get_surface_count() == 0:
		_support_sampler_cache[cache_key] = {}
		return {}
	var sampler := _support_sampler_from_mesh(mesh)
	_support_sampler_cache[cache_key] = sampler
	return sampler

static func _support_sampler_from_mesh(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	var triangles: Array = []
	for surface_idx in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(0, verts.size(), 3):
				if i + 2 >= verts.size():
					break
				_append_support_triangle_record(triangles, verts[i], verts[i + 1], verts[i + 2])
			continue
		for i in range(0, indices.size(), 3):
			if i + 2 >= indices.size():
				break
			_append_support_triangle_record(triangles, verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]])
	return _support_sampler_from_triangle_records(triangles)

static func _append_support_triangle_record(out: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	if absf(normal.normalized().y) <= 0.0001:
		return
	var denominator := ((b.z - c.z) * (a.x - c.x)) + ((c.x - b.x) * (a.z - c.z))
	if absf(denominator) <= 0.000001:
		return
	out.append({
		"a": a,
		"b": b,
		"c": c,
		"denominator": denominator,
		"min_x": minf(a.x, minf(b.x, c.x)),
		"max_x": maxf(a.x, maxf(b.x, c.x)),
		"min_z": minf(a.z, minf(b.z, c.z)),
		"max_z": maxf(a.z, maxf(b.z, c.z)),
	})

static func _support_sampler_from_triangle_records(triangles: Array) -> Dictionary:
	if triangles.is_empty():
		return {}
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	var buckets := {}
	for tri_index in triangles.size():
		var tri_value = triangles[tri_index]
		if typeof(tri_value) != TYPE_DICTIONARY:
			continue
		var tri := tri_value as Dictionary
		var a := Vector3(tri.get("a", Vector3.ZERO))
		var b := Vector3(tri.get("b", Vector3.ZERO))
		var c := Vector3(tri.get("c", Vector3.ZERO))
		min_v = min_v.min(a).min(b).min(c)
		max_v = max_v.max(a).max(b).max(c)
		var min_cell_x := _support_bucket_coord(float(tri.get("min_x", 0.0)))
		var max_cell_x := _support_bucket_coord(float(tri.get("max_x", 0.0)))
		var min_cell_z := _support_bucket_coord(float(tri.get("min_z", 0.0)))
		var max_cell_z := _support_bucket_coord(float(tri.get("max_z", 0.0)))
		for cell_x in range(min_cell_x, max_cell_x + 1):
			for cell_z in range(min_cell_z, max_cell_z + 1):
				var bucket_key := _support_bucket_key(cell_x, cell_z)
				var bucket: Array = buckets.get(bucket_key, [])
				bucket.append(tri_index)
				buckets[bucket_key] = bucket
	if min_v == Vector3(INF, INF, INF) or max_v == Vector3(-INF, -INF, -INF):
		return {}
	return {
		"bounds_min": min_v,
		"bounds_max": max_v,
		"buckets": buckets,
		"triangles": triangles,
	}

static func _support_sampler_height_at_world_position(sampler: Dictionary, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	if sampler.is_empty():
		return null
	var local := basis.inverse() * Vector3(world_x - origin.x, 0.0, world_z - origin.z)
	var local_y = _support_sampler_height_at_local_position(sampler, local.x, local.z)
	if local_y == null:
		return null
	return origin.y + float(local_y)

static func _support_sampler_height_at_local_position(sampler: Dictionary, local_x: float, local_z: float):
	var bounds_min := Vector3(sampler.get("bounds_min", Vector3.ZERO))
	var bounds_max := Vector3(sampler.get("bounds_max", Vector3.ZERO))
	if local_x < bounds_min.x - 0.001 or local_x > bounds_max.x + 0.001 or local_z < bounds_min.z - 0.001 or local_z > bounds_max.z + 0.001:
		return null
	var bucket_key := _support_bucket_key(_support_bucket_coord(local_x), _support_bucket_coord(local_z))
	var candidate_indices_value = sampler.get("buckets", {}).get(bucket_key, [])
	if typeof(candidate_indices_value) != TYPE_ARRAY:
		return null
	var triangles_value = sampler.get("triangles", [])
	if typeof(triangles_value) != TYPE_ARRAY:
		return null
	var triangles := Array(triangles_value)
	var seeded := false
	var best_y := 0.0
	for index_value in Array(candidate_indices_value):
		var tri_index := int(index_value)
		if tri_index < 0 or tri_index >= triangles.size():
			continue
		var tri_value = triangles[tri_index]
		if typeof(tri_value) != TYPE_DICTIONARY:
			continue
		var tri := tri_value as Dictionary
		if local_x < float(tri.get("min_x", 0.0)) - 0.001 or local_x > float(tri.get("max_x", 0.0)) + 0.001 or local_z < float(tri.get("min_z", 0.0)) - 0.001 or local_z > float(tri.get("max_z", 0.0)) + 0.001:
			continue
		var sampled = _triangle_support_height_at_local_position(tri, local_x, local_z)
		if sampled == null:
			continue
		var sampled_f := float(sampled)
		if not seeded or sampled_f > best_y:
			best_y = sampled_f
			seeded = true
	if not seeded:
		return null
	return best_y

static func _support_bucket_coord(value: float) -> int:
	return int(floor(value / SUPPORT_BUCKET_CELL_SIZE))

static func _support_bucket_key(cell_x: int, cell_z: int) -> String:
	return "%d:%d" % [cell_x, cell_z]

static func _triangle_support_height_at_local_position(tri: Dictionary, local_x: float, local_z: float):
	var a := Vector3(tri.get("a", Vector3.ZERO))
	var b := Vector3(tri.get("b", Vector3.ZERO))
	var c := Vector3(tri.get("c", Vector3.ZERO))
	var denominator := float(tri.get("denominator", 0.0))
	if absf(denominator) <= 0.000001:
		return null
	var alpha := (((b.z - c.z) * (local_x - c.x)) + ((c.x - b.x) * (local_z - c.z))) / denominator
	var beta := (((c.z - a.z) * (local_x - c.x)) + ((a.x - c.x) * (local_z - c.z))) / denominator
	var gamma := 1.0 - alpha - beta
	if alpha < -0.001 or beta < -0.001 or gamma < -0.001:
		return null
	return (alpha * a.y) + (beta * b.y) + (gamma * c.y)

static func _triangle_support_height_at_world_position(a: Vector3, b: Vector3, c: Vector3, world_x: float, world_z: float):
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return null
	if absf(normal.normalized().y) <= 0.0001:
		return null
	var denominator := ((b.z - c.z) * (a.x - c.x)) + ((c.x - b.x) * (a.z - c.z))
	if absf(denominator) <= 0.000001:
		return null
	var alpha := (((b.z - c.z) * (world_x - c.x)) + ((c.x - b.x) * (world_z - c.z))) / denominator
	var beta := (((c.z - a.z) * (world_x - c.x)) + ((a.x - c.x) * (world_z - c.z))) / denominator
	var gamma := 1.0 - alpha - beta
	if alpha < -0.001 or beta < -0.001 or gamma < -0.001:
		return null
	return (alpha * a.y) + (beta * b.y) + (gamma * c.y)

static func has_piece_source(set_id: int, base_name: String) -> bool:
	if base_name.is_empty():
		return false
	if not _external_source_loading_enabled:
		return false
	var bas_path := _find_piece_bas_path(set_id, base_name)
	if bas_path.is_empty():
		return false
	var bas_data := _load_json(bas_path)
	var skel_ref := _find_first_skeleton_ref(bas_data)
	var skel_name := skel_ref.get_file().get_basename() if not skel_ref.is_empty() else base_name
	return not _find_file(_skeleton_dir(set_id), "%s.skl.json" % skel_name).is_empty()

static func _lego_for_raw_id(lego_defs: Dictionary, raw_id: int) -> Dictionary:
	if lego_defs.has(raw_id):
		return lego_defs[raw_id]
	var key := str(raw_id)
	return lego_defs.get(key, {})

static func _load_piece_mesh(set_id: int, base_name: String) -> ArrayMesh:
	if base_name.is_empty():
		return null
	var cache_key := "%d:%s:%s" % [set_id, base_name.to_lower(), _piece_game_data_type.to_lower()]
	if _mesh_cache.has(cache_key):
		return _mesh_cache[cache_key]
	if not _external_source_loading_enabled:
		_mesh_cache[cache_key] = null
		_animated_overlay_cache[cache_key] = false
		_piece_overlay_emitters_cache[cache_key] = false
		return null
	var piece_source := _load_piece_source(set_id, base_name)
	var bas_data: Dictionary = piece_source.get("bas_data", {})
	var points: Array = piece_source.get("points", [])
	var polys: Array = piece_source.get("polys", [])
	var emitters := _extract_particle_emitters(bas_data, points, set_id)
	var has_emitters := emitters.size() > 0
	var mesh := ArrayMesh.new()
	var has_animated_surfaces := false
	for surface in _extract_surfaces(bas_data, points, polys, set_id):
		var anim_frames: Array = surface.get("animation_frames", [])
		if anim_frames.size() > 0:
			has_animated_surfaces = true
		var mesh_surface := _mesh_surface_from_surface(surface, set_id)
		var triangles: Array = mesh_surface.get("triangles", [])
		if triangles.is_empty() or mesh_surface.get("material", null) == null:
			continue
		_append_surface_to_mesh(mesh, triangles, mesh_surface.get("material", null))
	_animated_overlay_cache[cache_key] = has_animated_surfaces
	_piece_overlay_emitters_cache[cache_key] = has_emitters
	if mesh.get_surface_count() > 0:
		# Minimal UV-range diagnostics for the specific ground pieces that visually
		# exhibit black stripe artifacts in the live editor.
		# This is intentionally gated and runs at most once per base_name.
		var bn_upper := base_name.strip_edges().to_upper()
		if (bn_upper == "GR_248" or bn_upper == "GR_252") and not _printed_piece_uv_diagnostics.has(bn_upper):
			_printed_piece_uv_diagnostics[bn_upper] = true
			var arrays0 := mesh.surface_get_arrays(0)
			var uvs: PackedVector2Array = arrays0[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var min_u: float = 0.0
			var max_u: float = 0.0
			var min_v: float = 0.0
			var max_v: float = 0.0
			if not uvs.is_empty():
				min_u = uvs[0].x
				max_u = uvs[0].x
				min_v = uvs[0].y
				max_v = uvs[0].y
				for uv in uvs:
					min_u = min(min_u, uv.x)
					max_u = max(max_u, uv.x)
					min_v = min(min_v, uv.y)
					max_v = max(max_v, uv.y)
			print(
				"[AuthoredPiece] piece=", base_name,
				" set_id=", set_id,
				" surfaces=", mesh.get_surface_count(),
				" uv_range=[", min_u, ",", max_u, "]x[", min_v, ",", max_v, "]"
			)
		_mesh_cache[cache_key] = mesh
		return _mesh_cache[cache_key]
	_mesh_cache[cache_key] = null
	return _mesh_cache[cache_key]

static func _build_piece_node(set_id: int, base_name: String, raw_id: int) -> Node3D:
	if base_name.is_empty():
		return null
	if _external_source_loading_enabled:
		var piece_source := _load_piece_source(set_id, base_name)
		var bas_data: Dictionary = piece_source.get("bas_data", {})
		var points: Array = piece_source.get("points", [])
		var polys: Array = piece_source.get("polys", [])
		var surfaces := _extract_surfaces(bas_data, points, polys, set_id)
		var emitters := _extract_particle_emitters(bas_data, points, set_id)
		if not surfaces.is_empty() or not emitters.is_empty():
			var piece := Node3D.new()
			piece.name = "%s_%d" % [base_name, raw_id]
			for i in surfaces.size():
				var child := _surface_node_from_surface(surfaces[i], set_id)
				if child == null:
					continue
				child.name = "Surface_%d" % i
				piece.add_child(child)
			for i in emitters.size():
				var emitter := _particle_node_from_definition(emitters[i])
				if emitter == null:
					continue
				emitter.name = "ParticleEmitter_%d" % i
				piece.add_child(emitter)
			if piece.get_child_count() > 0:
				return piece
	return null

static func build_piece_scene_root(set_id: int, base_name: String, raw_id: int = -1) -> Node3D:
	if base_name.is_empty():
		return null
	if not _external_source_loading_enabled:
		return _build_piece_node(set_id, base_name, raw_id)
	var mesh: ArrayMesh = _load_piece_mesh(set_id, base_name)
	var cache_key := "%d:%s:%s" % [set_id, base_name.to_lower(), _piece_game_data_type.to_lower()]
	var use_animated := bool(_animated_overlay_cache.get(cache_key, false))
	var has_emitters := bool(_piece_overlay_emitters_cache.get(cache_key, false))
	# Animated surfaces and particle emitters need the full piece node unless the editor
	# explicitly requests static overlays for performance (`set_force_static_terrain_overlays`).
	if mesh != null and mesh.get_surface_count() > 0 and (_force_static_terrain_overlays or (not use_animated and not has_emitters)):
		_piece_overlay_fast_path_count += 1
		var root := Node3D.new()
		root.name = "%s_%d" % [base_name, raw_id]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		root.add_child(mi)
		return root
	_piece_overlay_slow_path_count += 1
	return _build_piece_node(set_id, base_name, raw_id)

static func _apply_optional_piece_deform(piece_node: Node3D, desc: Dictionary) -> void:
	var warp_mode := String(desc.get("warp_mode", ""))
	if warp_mode.is_empty():
		return
	for child in piece_node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh != null:
				mi.mesh = _deformed_slurp_mesh(mi.mesh, desc)

static func _deformed_slurp_mesh(source_mesh: Mesh, desc: Dictionary) -> ArrayMesh:
	var warp_sig := _warp_signature(desc)
	if warp_sig.is_empty():
		return source_mesh as ArrayMesh

	var set_id := int(desc.get("set_id", 1))
	var base_name := String(desc.get("base_name", "")).strip_edges().to_lower()
	var raw_id := int(desc.get("raw_id", -1))
	# Source mesh identity + warp params fully determines the deformed result.
	var cache_key := "slurp_def:%s:%d:%s:%d:%s" % [str(source_mesh.get_rid()), set_id, base_name, raw_id, warp_sig]

	if _deformed_slurp_mesh_cache.has(cache_key):
		var cached := _deformed_slurp_mesh_cache[cache_key] as ArrayMesh
		return cached if cached != null else null

	var out := ArrayMesh.new()
	for surface_idx in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var deformed := PackedVector3Array()
		deformed.resize(verts.size())
		for i in verts.size():
			deformed[i] = _deformed_slurp_vertex(verts[i], desc)
		arrays[Mesh.ARRAY_VERTEX] = deformed
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, source_mesh.surface_get_material(surface_idx))
	_deformed_slurp_mesh_cache[cache_key] = out
	return out

static func _deformed_slurp_vertex(vertex: Vector3, desc: Dictionary) -> Vector3:
	var result := vertex
	var warp_mode := String(desc.get("warp_mode", ""))
	var anchor_height := float(desc.get("anchor_height", 0.0))
	if warp_mode == "vside":
		var seam_y := lerpf(
			float(desc.get("top_avg", anchor_height)) - anchor_height,
			float(desc.get("bottom_avg", anchor_height)) - anchor_height,
			_inverse_lerp_clamped(-UA_SECTOR_HALF, UA_SECTOR_HALF, vertex.z)
		)
		if vertex.x <= -UA_SECTOR_HALF:
			result.y = lerpf(
			float(desc.get("left_height", anchor_height)) - anchor_height,
			seam_y,
			_inverse_lerp_clamped(-UA_SECTOR_HALF - UA_SLURP_HALF_WIDTH, -UA_SECTOR_HALF, vertex.x)
			)
		else:
			result.y = lerpf(
			seam_y,
			float(desc.get("right_height", anchor_height)) - anchor_height,
			_inverse_lerp_clamped(-UA_SECTOR_HALF, -UA_SECTOR_HALF + UA_SLURP_HALF_WIDTH, vertex.x)
			)
	elif warp_mode == "hside":
		var seam_y_h := lerpf(
			float(desc.get("left_avg", anchor_height)) - anchor_height,
			float(desc.get("right_avg", anchor_height)) - anchor_height,
			_inverse_lerp_clamped(-UA_SECTOR_HALF, UA_SECTOR_HALF, vertex.x)
		)
		if vertex.z <= -UA_SECTOR_HALF:
			result.y = lerpf(
			float(desc.get("top_height", anchor_height)) - anchor_height,
			seam_y_h,
			_inverse_lerp_clamped(-UA_SECTOR_HALF - UA_SLURP_HALF_WIDTH, -UA_SECTOR_HALF, vertex.z)
			)
		else:
			result.y = lerpf(
			seam_y_h,
			float(desc.get("bottom_height", anchor_height)) - anchor_height,
			_inverse_lerp_clamped(-UA_SECTOR_HALF, -UA_SECTOR_HALF + UA_SLURP_HALF_WIDTH, vertex.z)
			)
	return result

static func _inverse_lerp_clamped(a: float, b: float, value: float) -> float:
	if is_equal_approx(a, b):
		return 0.0
	return clampf((value - a) / (b - a), 0.0, 1.0)

static func _extract_surfaces(node, points: Array, polys: Array, set_id: int) -> Array:
	var result: Array = []
	_collect_surfaces(node, result, points, polys, set_id)
	return result

static func _collect_surfaces(node, out: Array, points: Array, polys: Array, set_id: int) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("PTCL"):
			return
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

static func _extract_particle_emitters(node, points: Array, set_id: int) -> Array:
	var result: Array = []
	_collect_particle_emitters(node, result, points, set_id)
	return result

static func _collect_particle_emitters(node, out: Array, points: Array, set_id: int) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("PTCL"):
			var emitter := _particle_emitter_from_ptcl(node["PTCL"], points, set_id)
			if not emitter.is_empty():
				out.append(emitter)
			return
		for value in node.values():
			_collect_particle_emitters(value, out, points, set_id)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_collect_particle_emitters(item, out, points, set_id)

static func _particle_emitter_from_ptcl(ptcl_data: Array, points: Array, set_id: int) -> Dictionary:
	if not _external_source_loading_enabled:
		return {}

	var point_id := _find_first_ade_point(ptcl_data)
	var anchor = _point_position(points, point_id)
	if anchor == null:
		return {}
	var atts := _find_first_particle_atts(ptcl_data)
	if atts.is_empty():
		return {}
	var stages := _particle_stages_from_ptcl(ptcl_data, set_id)
	if stages.is_empty():
		return {}
	return {
		"point_id": point_id,
		"anchor": anchor,
		"context_life_time_ms": max(int(atts.get("context_life_time", 0)), 1),
		"context_start_gen_ms": max(int(atts.get("context_start_gen", 0)), 0),
		"context_stop_gen_ms": max(int(atts.get("context_stop_gen", 0)), 0),
		"gen_rate": max(int(atts.get("gen_rate", 0)), 0),
		"lifetime_ms": max(int(atts.get("lifetime", 0)), 1),
		"start_speed": float(atts.get("start_speed", 0.0)),
		"start_size": float(atts.get("start_size", 1.0)),
		"end_size": float(atts.get("end_size", atts.get("start_size", 1.0))),
		"noise": float(atts.get("noise", 0.0)),
		"accel_start": _vector3_from_components(atts, "accel_start"),
		"accel_end": _vector3_from_components(atts, "accel_end"),
		"magnify_start": _vector3_from_components(atts, "magnify_start"),
		"magnify_end": _vector3_from_components(atts, "magnify_end"),
		"stages": stages,
	}

static func _particle_stages_from_ptcl(ptcl_data: Array, set_id: int) -> Array:
	var area_stages: Array = []
	_collect_ptcl_stage_areas(ptcl_data, area_stages)
	var stages: Array = []
	for area_data in area_stages:
		var stage := _particle_stage_from_area(area_data, set_id)
		if not stage.is_empty():
			stages.append(stage)
	return stages

static func _collect_ptcl_stage_areas(node, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("AREA"):
			out.append(node["AREA"])
			return
		for value in node.values():
			_collect_ptcl_stage_areas(value, out)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			_collect_ptcl_stage_areas(item, out)

static func _particle_stage_from_area(area_data: Array, set_id: int) -> Dictionary:
	var polygon := _unit_billboard_polygon()
	var render_hints := _render_hints_from_area(area_data)
	var frames: Array = []
	var anim_name := _find_first_anim_name(area_data)
	if not anim_name.is_empty():
		for frame in _load_anim_frames(set_id, anim_name, polygon):
			var material := _billboard_material_for_texture(set_id, String(frame.get("texture_name", "")), render_hints)
			if material == null:
				continue
			frames.append({
				"triangles": frame.get("triangles", []),
				"material": material,
				"duration_sec": float(frame.get("duration_sec", 0.04)),
			})
	else:
		var texture_name := _find_first_name(area_data, "NAM2")
		var material := _billboard_material_for_texture(set_id, texture_name, render_hints)
		if material == null:
			return {}
		frames.append({
			"triangles": _triangulate(polygon, _coerce_uvs(_find_first_points(area_data, "OTL2"), polygon, set_id, texture_name)),
			"material": material,
			"duration_sec": 0.04,
		})
	return {"frames": frames} if not frames.is_empty() else {}

static func _particle_node_from_definition(definition: Dictionary) -> Node3D:
	if definition.is_empty():
		return null
	var emitter_script = load("res://map/terrain/ua_authored_particle_emitter.gd")
	if emitter_script == null:
		return null
	var emitter: Node3D = emitter_script.new()
	emitter.setup_emitter(definition)
	return emitter if emitter.has_meta("ua_authored_particle_emitter") else null

static func _unit_billboard_polygon() -> Array:
	return [
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0),
	]

static func _billboard_material_for_texture(set_id: int, texture_name: String, render_hints: Dictionary = {}) -> Material:
	var base_material := _material_for_texture(set_id, texture_name, render_hints)
	if base_material == null:
		return null
	var duplicated := base_material.duplicate()
	if duplicated is BaseMaterial3D:
		var billboarded := duplicated as BaseMaterial3D
		billboarded.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		billboarded.billboard_keep_scale = true
		return billboarded
	return duplicated

static func _point_position(points: Array, point_id: int):
	if point_id < 0 or point_id >= points.size():
		return null
	var p: Dictionary = points[point_id]
	return Vector3(float(p.get("x", 0.0)) * MODEL_SCALE, -float(p.get("y", 0.0)) * MODEL_SCALE, -float(p.get("z", 0.0)) * MODEL_SCALE)

static func _find_first_ade_point(node, require_root_flag: bool = true) -> int:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("STRC") and typeof(node["STRC"]) == TYPE_DICTIONARY:
			var strc: Dictionary = node["STRC"]
			if String(strc.get("strc_type", "")).begins_with("STRC_ADE"):
				if not require_root_flag or int(strc.get("flags", -1)) == 0:
					return int(strc.get("point", -1))
		for value in node.values():
			var found := _find_first_ade_point(value, require_root_flag)
			if found >= 0:
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_ade_point(item, require_root_flag)
			if found >= 0:
				return found
	if require_root_flag:
		return _find_first_ade_point(node, false)
	return -1

static func _find_first_particle_atts(node) -> Dictionary:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("ATTS") and typeof(node["ATTS"]) == TYPE_DICTIONARY:
			var atts: Dictionary = node["ATTS"]
			if bool(atts.get("is_particle_atts", false)):
				return atts
		for value in node.values():
			var found := _find_first_particle_atts(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found := _find_first_particle_atts(item)
			if not found.is_empty():
				return found
	return {}

static func _vector3_from_components(values: Dictionary, prefix: String) -> Vector3:
	return Vector3(
		float(values.get("%s_x" % prefix, 0.0)),
		- float(values.get("%s_y" % prefix, 0.0)),
		- float(values.get("%s_z" % prefix, 0.0))
	)

static func _surface_from_area(area_data: Array, points: Array, polys: Array, set_id: int) -> Dictionary:
	var poly_id := _first_poly_id(area_data)
	var polygon := _polygon_vertices(points, polys, poly_id)
	if polygon.is_empty():
		return {}
	# `_polygon_vertices` returns editor-preview-space coordinates (scaled by UA_SECTOR_SPAN).
	# Piece mesh geometry must remain in UA-space so that piece placement + support sampling
	# stay consistent with the rest of the authored pipeline.
	var poly_to_ua := UA_SECTOR_SPAN / MODEL_SCALE
	for i in range(polygon.size()):
		polygon[i] = polygon[i] * poly_to_ua
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
	var grouped_surfaces := {}
	var atts_entries := _find_first_atts_entries(amsh_data)
	var olpl_points := _find_first_points(amsh_data, "OLPL")
	var texture_name := _find_first_name(amsh_data, "NAM2")
	var render_hints := _render_hints_from_area(amsh_data)
	var uses_shading := _area_uses_gradient_shade(_find_first_area_strc(amsh_data))
	for i in atts_entries.size():
		var att_entry: Dictionary = atts_entries[i]
		var poly_id := int(att_entry.get("poly_id", -1))
		var polygon := _polygon_vertices(points, polys, poly_id)
		if polygon.is_empty():
			continue
		# See `_surface_from_area` for why preview-space -> UA-space is needed here.
		var poly_to_ua := UA_SECTOR_SPAN / MODEL_SCALE
		for j in range(polygon.size()):
			polygon[j] = polygon[j] * poly_to_ua
		var uv_points: Array = olpl_points[i] if i < olpl_points.size() else []
		var triangles := _triangulate(polygon, _coerce_uvs(uv_points, polygon, set_id, texture_name))
		if triangles.is_empty():
			continue
		var surface_hints: Dictionary = render_hints.duplicate(true)
		if uses_shading:
			surface_hints["shade_value"] = clampi(int(att_entry.get("shade_val", 0)), 0, 255)
		var key := _surface_group_key(texture_name, surface_hints)
		if not grouped_surfaces.has(key):
			grouped_surfaces[key] = {
				"texture_name": texture_name,
				"triangles": [],
				"render_hints": surface_hints,
			}
		grouped_surfaces[key]["triangles"].append_array(triangles)
	return grouped_surfaces.values()

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
		# Retail UA sector rows advance toward negative world-Z. The editor preview keeps map
		# rows growing toward positive Z, so authored local geometry must mirror Z as well or
		# directional pieces/borders appear globally flipped relative to the terrain grid.
		# Convert from UA-space (sector span = 1200) into editor-preview-space (sector span = 1).
		var ua_to_preview := MODEL_SCALE / UA_SECTOR_SPAN
		polygon.append(Vector3(
			float(p.get("x", 0.0)) * ua_to_preview,
			-float(p.get("y", 0.0)) * ua_to_preview,
			-float(p.get("z", 0.0)) * ua_to_preview
		))
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

static func _coerce_bmpanim_uvs(raw_uvs: Array, polygon: Array) -> Array:
	var uvs: Array = []
	for item in raw_uvs:
		var uv: Variant = _uv_point_to_vector2(item)
		if uv != null:
			# Retail UA bmpanim stores dynamic-frame UVs as raw u8 atlas coordinates and
			# normalizes them as uv / 256.0 when loading the ANM payload. Reusing the generic
			# authored-texture path here shifts edge-heavy frames outward and can expose a
			# thin border line on some animation steps.
			uvs.append(Vector2(uv.x / BMPANIM_UV_SCALE, uv.y / BMPANIM_UV_SCALE))
	if uvs.size() == polygon.size():
		return uvs
	return _coerce_uvs(raw_uvs, polygon)

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

static func _area_uses_gradient_shade(strc: Dictionary) -> bool:
	if strc.is_empty():
		return false
	return (int(strc.get("polFlags", 0)) & AREA_POL_FLAG_SHADE_MASK) == AREA_POL_FLAG_GRADIENTSHADE

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
	if texture_file.is_empty():
		return null
	var hints := _normalized_render_hints(render_hints)
	var cache_key := _render_cache_key(set_id, texture_file, hints)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.metallic = 0.0
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tex := _texture_for_name(set_id, texture_name, hints)
	if tex != null:
		mat.albedo_texture = tex
		var image := tex.get_image()
		var has_alpha := image != null and image.detect_alpha() != Image.ALPHA_NONE
		var transparency_mode := String(hints.get("transparency_mode", "auto"))
		var shade_multiplier := _shade_multiplier_from_value(int(hints.get("shade_value", 0)))
		if transparency_mode == "lumtracy":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			# UA luminous/additive surfaces can remain readable farther out than normal
			# world geometry. Keep them out of the preview visibility fog so animated
			# effects match the user's reported retail behavior more closely.
			mat.disable_fog = true
			mat.albedo_color = Color(1.0, 1.0, 1.0, UA_LUMTRACY_ALPHA)
		elif has_alpha:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
		if not is_equal_approx(shade_multiplier, 1.0):
			mat.albedo_color = Color(
				mat.albedo_color.r * shade_multiplier,
				mat.albedo_color.g * shade_multiplier,
				mat.albedo_color.b * shade_multiplier,
				mat.albedo_color.a
			)
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
	var cache_key := _texture_cache_key(set_id, texture_file, hints)
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	if _external_source_loading_enabled:
		var raw_image := _raw_image_for_texture(set_id, texture_name, hints)
		if raw_image != null:
			var converted_raw := _apply_color_key_transparency(raw_image)
			_texture_cache[cache_key] = ImageTexture.create_from_image(converted_raw)
			return _texture_cache[cache_key]

		var texture_path := _find_file(_set_root(set_id), texture_file)
		if not texture_path.is_empty():
			var tex = load(texture_path)
			if tex is Texture2D:
				var image: Image = tex.get_image()
				if image != null:
					var converted := _apply_color_key_transparency(image)
					_texture_cache[cache_key] = ImageTexture.create_from_image(converted)
					return _texture_cache[cache_key]
				_texture_cache[cache_key] = tex
				if _texture_cache[cache_key] != null:
					return _texture_cache[cache_key]
			# Filenames like BODEN1.ILB.bmp confuse ResourceLoader (no bmp importer match);
			# Image.load_from_file still decodes standard PC bitmaps.
			var img_fallback := Image.load_from_file(texture_path)
			if img_fallback != null:
				var converted_fb := _apply_color_key_transparency(img_fallback)
				_texture_cache[cache_key] = ImageTexture.create_from_image(converted_fb)
				return _texture_cache[cache_key]

	_texture_cache[cache_key] = null
	return _texture_cache[cache_key]

static func _normalized_render_hints(render_hints: Dictionary) -> Dictionary:
	var mode := String(render_hints.get("transparency_mode", "auto"))
	if mode != "cutout" and mode != "lumtracy":
		mode = "auto"
	return {
		"transparency_mode": mode,
		"tracy_val": clampi(int(render_hints.get("tracy_val", 0)), 0, 255),
		"shade_value": clampi(int(render_hints.get("shade_value", 0)), 0, 255),
	}

static func _render_cache_key(set_id: int, texture_file: String, render_hints: Dictionary) -> String:
	return "%d:%s:%s:%d:%d:%s" % [
		set_id,
		texture_file.to_lower(),
		String(render_hints.get("transparency_mode", "auto")),
		int(render_hints.get("tracy_val", 0)),
		int(render_hints.get("shade_value", 0)),
		_piece_game_data_type.to_lower(),
	]

static func _texture_cache_key(set_id: int, texture_file: String, render_hints: Dictionary) -> String:
	return "%d:%s:%s:%s" % [
		set_id,
		texture_file.to_lower(),
		String(render_hints.get("transparency_mode", "auto")),
		_piece_game_data_type.to_lower(),
	]

static func _surface_group_key(texture_name: String, render_hints: Dictionary) -> String:
	var hints := _normalized_render_hints(render_hints)
	return "%s:%s:%d:%d" % [
		texture_name.to_lower(),
		String(hints.get("transparency_mode", "auto")),
		int(hints.get("tracy_val", 0)),
		int(hints.get("shade_value", 0)),
	]

static func _shade_multiplier_from_value(shade_value: int) -> float:
	return clampf(1.0 - float(clampi(shade_value, 0, 255)) / 256.0, 0.0, 1.0)

static func _raw_image_for_texture(set_id: int, texture_name: String, render_hints: Dictionary) -> Image:
	var raw_path := _raw_texture_override_path(set_id, texture_name, render_hints)
	if raw_path.is_empty():
		return null
	return _load_ilbm_image(raw_path)

static func _raw_texture_override_path(set_id: int, texture_name: String, render_hints: Dictionary) -> String:
	if String(render_hints.get("transparency_mode", "auto")) != "lumtracy":
		return ""
	var base := texture_name.strip_edges().get_file().get_basename().to_lower()
	if base != "fx1" and base != "fx2" and base != "fx3":
		return ""
	return _find_file(_hi_alpha_dir(set_id), "%s.ilb" % base)

static func _load_ilbm_image(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 12:
		return null
	if _ascii_from_bytes(data, 0, 4) != "FORM":
		return null
	var form_type := _ascii_from_bytes(data, 8, 4)
	if form_type != "ILBM" and form_type != "PBM ":
		return null
	var width := 0
	var height := 0
	var nplanes := 0
	var masking := 0
	var compression := 0
	var transparent_color := -1
	var palette: Array = []
	palette.resize(256)
	for i in palette.size():
		palette[i] = Color(0.0, 0.0, 0.0, 1.0)
	var body := PackedByteArray()
	var pos := 12
	while pos + 8 <= data.size():
		var tag := _ascii_from_bytes(data, pos, 4)
		var chunk_size := _read_u32_be(data, pos + 4)
		var chunk_start := pos + 8
		var chunk_end := chunk_start + chunk_size
		if chunk_end > data.size():
			break
		if tag == "BMHD" and chunk_size >= 20:
			width = _read_u16_be(data, chunk_start)
			height = _read_u16_be(data, chunk_start + 2)
			nplanes = int(data[chunk_start + 8])
			masking = int(data[chunk_start + 9])
			compression = int(data[chunk_start + 10])
			transparent_color = _read_u16_be(data, chunk_start + 12)
		elif tag == "CMAP":
			var color_count := mini(int(float(chunk_size) / 3.0), 256)
			for i in color_count:
				var color_offset := chunk_start + i * 3
				palette[i] = Color(
					float(data[color_offset]) / 255.0,
					float(data[color_offset + 1]) / 255.0,
					float(data[color_offset + 2]) / 255.0,
					1.0
				)
		elif tag == "BODY":
			body.resize(chunk_size)
			for i in chunk_size:
				body[i] = data[chunk_start + i]
		pos = chunk_end + (chunk_size & 1)
	if width <= 0 or height <= 0 or nplanes <= 0 or body.is_empty():
		return null
	if compression == 1:
		body = _byte_run1_decode(body)
	var plane_row_bytes := int(ceili(float(width) / 8.0))
	if (plane_row_bytes & 1) != 0:
		plane_row_bytes += 1
	var total_planes := nplanes + (1 if masking == ILBM_MASK_HAS_MASK else 0)
	var row_bytes := plane_row_bytes * total_planes
	if row_bytes <= 0 or body.size() < row_bytes * height:
		return null
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var row_offset := y * row_bytes
		var mask_offset := row_offset + plane_row_bytes * nplanes
		for x in width:
			var byte_index := int(x) >> 3
			var bit_mask := 1 << (7 - (x & 7))
			var color_index := 0
			for plane in nplanes:
				var plane_byte_offset := row_offset + plane * plane_row_bytes + byte_index
				if (int(body[plane_byte_offset]) & bit_mask) != 0:
					color_index |= 1 << plane
			var color: Color = palette[color_index] if color_index < palette.size() else Color(0.0, 0.0, 0.0, 1.0)
			if masking == ILBM_MASK_HAS_MASK:
				var mask_byte := int(body[mask_offset + byte_index])
				if (mask_byte & bit_mask) == 0:
					color = Color(0.0, 0.0, 0.0, 0.0)
			elif masking == ILBM_MASK_TRANSPARENT_COLOR and color_index == transparent_color:
				color = Color(0.0, 0.0, 0.0, 0.0)
			image.set_pixel(x, y, color)
	return image

static func _byte_run1_decode(src: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < src.size():
		var control := int(src[i])
		if control > 127:
			control -= 256
		i += 1
		if control >= 0:
			var literal_count := control + 1
			for j in literal_count:
				if i + j >= src.size():
					break
				out.append(src[i + j])
			i += literal_count
		elif control >= -127:
			if i >= src.size():
				break
			var repeat_count := 1 - control
			var repeated := src[i]
			for _j in repeat_count:
				out.append(repeated)
			i += 1
	return out

static func _ascii_from_bytes(data: PackedByteArray, start: int, size: int) -> String:
	var chars := PackedByteArray()
	chars.resize(size)
	for i in size:
		chars[i] = data[start + i]
	return chars.get_string_from_ascii()

static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])

static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(int(data[offset]) << 24)
		| (int(data[offset + 1]) << 16)
		| (int(data[offset + 2]) << 8)
		| int(data[offset + 3])
	)

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
	if _external_source_loading_enabled:
		var cache_key := "%d:%s:%s" % [set_id, anim_name.to_lower(), _piece_game_data_type.to_lower()]
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
		if compiled.size() > 0:
			return _clone_anim_frames(compiled, polygon, set_id)
	return []

static func _clone_anim_frames(compiled_frames: Array, polygon: Array, _set_id: int) -> Array:
	var frames: Array = []
	for frame in compiled_frames:
		if typeof(frame) != TYPE_DICTIONARY:
			continue
		var texture_name := String(frame.get("texture_name", ""))
		var uvs := _coerce_bmpanim_uvs(frame.get("raw_uv_points", []), polygon)
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
	if not _external_source_loading_enabled:
		return {}
	var bas_path := _find_piece_bas_path(set_id, base_name)
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
			if prepared.get("material", null) == null:
				continue
			prepared_frames.append(prepared)
		if prepared_frames.is_empty():
			return null
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
		for frame in animation_frames:
			var material := _material_for_texture(set_id, String(frame.get("texture_name", "")), render_hints)
			if material == null:
				continue
			return {
				"triangles": frame.get("triangles", []),
				"material": material,
			}
		return {
			"triangles": [],
			"material": null,
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
	if _json_cache.has(path):
		var cached = _json_cache[path]
		return cached if typeof(cached) == TYPE_DICTIONARY else {}
	var txt := _UALegacyText.read_file(path)
	if txt.is_empty():
		return {}
	var parsed = JSON.parse_string(txt)
	var out: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_json_cache[path] = out
	return out

static func _find_file(dir_path: String, filename: String) -> String:
	if dir_path.is_empty() or filename.is_empty():
		return ""
	if not _dir_cache.has(dir_path):
		var index := {}
		for entry in DirAccess.get_files_at(dir_path):
			index[String(entry).to_lower()] = "%s/%s" % [dir_path, entry]
		_dir_cache[dir_path] = index
	return _dir_cache[dir_path].get(filename.to_lower(), "")

static func _first_existing_set_under_base(base: String, resolved_set_id: int, game_data_type: String) -> String:
	var norm := _UAProjectDataRoots.normalized_game_data_type(game_data_type)
	var suffix := "_xp" if norm == "metropolisDawn" else ""
	var candidate := "%s/set%d%s" % [base, resolved_set_id, suffix]
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	if suffix == "_xp":
		var retail := "%s/set%d" % [base, resolved_set_id]
		if DirAccess.dir_exists_absolute(retail):
			return retail
	return candidate


static func _set_root(set_id: int) -> String:
	var resolved_set_id: int = max(set_id, 1)
	if not _external_source_root.is_empty():
		return _first_existing_set_under_base(_external_source_root, resolved_set_id, _piece_game_data_type)
	return _UAProjectDataRoots.first_existing_set_directory(set_id, _piece_game_data_type)

static func _find_piece_bas_path(set_id: int, base_name: String) -> String:
	var filename := "%s.bas.json" % base_name
	var bas_path := _find_file(_buildings_dir(set_id), filename)
	if not bas_path.is_empty():
		return bas_path
	bas_path = _find_file(_ground_dir(set_id), filename)
	if not bas_path.is_empty():
		return bas_path
	return _find_file(_vehicles_dir(set_id), filename)

static func _buildings_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/objects/buildings" % root

static func _ground_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/objects/ground" % root

static func _vehicles_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/objects/vehicles" % root

static func _hi_alpha_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/hi/alpha" % root

static func _skeleton_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/Skeleton" % root

static func _rsrcpool_dir(set_id: int) -> String:
	var root := _set_root(set_id)
	return "" if root.is_empty() else "%s/rsrcpool" % root

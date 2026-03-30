extends RefCounted
class_name UATerrainPieceLibrary

const SupportSampler = preload("res://map/terrain/ua_authored_support_sampler.gd")
const SourceResolver = preload("res://map/terrain/ua_authored_piece_source_resolver.gd")
const MeshLoader = preload("res://map/terrain/ua_authored_piece_mesh_loader.gd")
const MaterialFactory = preload("res://map/terrain/ua_authored_material_factory.gd")
const AnimationBuilder = preload("res://map/terrain/ua_authored_animation_builder.gd")
const ParticleBuilder = preload("res://map/terrain/ua_authored_particle_builder.gd")
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
static var _piece_overlay_fast_path_count := 0
static var _piece_overlay_slow_path_count := 0
static var _material_cache := {}
static var _texture_cache := {}
static var _support_sampler_cache := {}
static var _deformed_slurp_mesh_cache := {}
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
	SourceResolver.clear_runtime_caches_for_tests()
	MaterialFactory.clear_runtime_caches_for_tests()
	_material_cache.clear()
	_texture_cache.clear()
	AnimationBuilder.clear_runtime_caches_for_tests()
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
	SourceResolver.clear_runtime_caches_for_tests()
	MaterialFactory.clear_runtime_caches_for_tests()
	_material_cache.clear()
	_texture_cache.clear()
	AnimationBuilder.clear_runtime_caches_for_tests()
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
	return SupportSampler.piece_position_from_desc(desc, OVERLAY_Y_BIAS)

static func support_height_at_world_position(descriptors: Array, world_x: float, world_z: float):
	var sampler_provider := func(desc: Dictionary) -> Dictionary:
		var set_id := int(desc.get("set_id", 1))
		var base_name := String(desc.get("base_name", ""))
		var warp_sig := _warp_signature(desc)
		return _piece_support_sampler(set_id, base_name, warp_sig, desc)
	return SupportSampler.support_height_at_world_position(descriptors, world_x, world_z, sampler_provider, OVERLAY_Y_BIAS)

static func _apply_optional_piece_orientation(piece_node: Node3D, desc: Dictionary) -> void:
	var basis := SupportSampler.piece_basis_from_desc(desc)
	if basis == Basis.IDENTITY:
		return
	piece_node.transform.basis = basis

static func _piece_basis_from_desc(desc: Dictionary) -> Basis:
	return SupportSampler.piece_basis_from_desc(desc)

static func _mesh_support_height_at_world_position(mesh: Mesh, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	return SupportSampler.mesh_support_height_at_world_position(mesh, basis, origin, world_x, world_z)

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
	var sampler := SupportSampler.support_sampler_from_mesh(mesh)
	_support_sampler_cache[cache_key] = sampler
	return sampler

static func _support_sampler_from_mesh(mesh: Mesh) -> Dictionary:
	return SupportSampler.support_sampler_from_mesh(mesh)

static func _append_support_triangle_record(out: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	SupportSampler.append_support_triangle_record(out, a, b, c)

static func _support_sampler_from_triangle_records(triangles: Array) -> Dictionary:
	return SupportSampler.support_sampler_from_triangle_records(triangles)

static func _support_sampler_height_at_world_position(sampler: Dictionary, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	return SupportSampler.support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)

static func _support_sampler_height_at_local_position(sampler: Dictionary, local_x: float, local_z: float):
	return SupportSampler.support_sampler_height_at_local_position(sampler, local_x, local_z)

static func _triangle_support_height_at_world_position(a: Vector3, b: Vector3, c: Vector3, world_x: float, world_z: float):
	return SupportSampler.triangle_support_height_at_world_position(a, b, c, world_x, world_z)

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
	var surface_extractor := func(bas_data: Dictionary, points: Array, polys: Array, resolved_set_id: int) -> Array:
		return _extract_surfaces(bas_data, points, polys, resolved_set_id)
	var particle_extractor := func(bas_data: Dictionary, points: Array, resolved_set_id: int) -> Array:
		return _extract_particle_emitters(bas_data, points, resolved_set_id)
	var mesh_surface_builder := func(surface: Dictionary, resolved_set_id: int) -> Dictionary:
		return _mesh_surface_from_surface(surface, resolved_set_id)
	var built := MeshLoader.build_piece_mesh(piece_source, set_id, surface_extractor, particle_extractor, mesh_surface_builder)
	var mesh: ArrayMesh = built.get("mesh", null)
	_animated_overlay_cache[cache_key] = bool(built.get("has_animated_surfaces", false))
	_piece_overlay_emitters_cache[cache_key] = bool(built.get("has_emitters", false))
	if mesh != null and mesh.get_surface_count() > 0:
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
		var surface_node_builder := func(surface: Dictionary) -> Node3D:
			return _surface_node_from_surface(surface, set_id)
		var particle_node_builder := func(emitter_definition: Dictionary) -> Node3D:
			return _particle_node_from_definition(emitter_definition)
		return MeshLoader.build_piece_node(base_name, raw_id, surfaces, emitters, surface_node_builder, particle_node_builder)
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
		return MeshLoader.build_fast_piece_root(base_name, raw_id, mesh)
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
	var emitter_from_ptcl := func(ptcl_data: Array, resolved_points: Array, resolved_set_id: int) -> Dictionary:
		return _particle_emitter_from_ptcl(ptcl_data, resolved_points, resolved_set_id)
	return ParticleBuilder.extract_particle_emitters(node, points, set_id, emitter_from_ptcl)

static func _collect_particle_emitters(node, out: Array, points: Array, set_id: int) -> void:
	var emitter_from_ptcl := func(ptcl_data: Array, resolved_points: Array, resolved_set_id: int) -> Dictionary:
		return _particle_emitter_from_ptcl(ptcl_data, resolved_points, resolved_set_id)
	ParticleBuilder.collect_particle_emitters(node, out, points, set_id, emitter_from_ptcl)

static func _particle_emitter_from_ptcl(ptcl_data: Array, points: Array, set_id: int) -> Dictionary:
	var ade_point_finder := func(node_value) -> int:
		return _find_first_ade_point(node_value)
	var point_position_resolver := func(resolved_points: Array, point_id: int):
		return _point_position(resolved_points, point_id)
	var particle_atts_finder := func(node_value) -> Dictionary:
		return _find_first_particle_atts(node_value)
	var stages_builder := func(resolved_ptcl_data: Array, resolved_set_id: int) -> Array:
		return _particle_stages_from_ptcl(resolved_ptcl_data, resolved_set_id)
	var vector3_components := func(atts: Dictionary, key_prefix: String) -> Vector3:
		return _vector3_from_components(atts, key_prefix)
	return ParticleBuilder.particle_emitter_from_ptcl(ptcl_data, points, set_id, _external_source_loading_enabled, ade_point_finder, point_position_resolver, particle_atts_finder, stages_builder, vector3_components)

static func _particle_stages_from_ptcl(ptcl_data: Array, set_id: int) -> Array:
	var stage_from_area := func(area_data: Array, resolved_set_id: int) -> Dictionary:
		return _particle_stage_from_area(area_data, resolved_set_id)
	return ParticleBuilder.particle_stages_from_ptcl(ptcl_data, set_id, stage_from_area)

static func _collect_ptcl_stage_areas(node, out: Array) -> void:
	ParticleBuilder.collect_ptcl_stage_areas(node, out)

static func _particle_stage_from_area(area_data: Array, set_id: int) -> Dictionary:
	var load_anim_frames := func(resolved_set_id: int, anim_name: String, polygon: Array) -> Array:
		return _load_anim_frames(resolved_set_id, anim_name, polygon)
	var billboard_material_resolver := func(resolved_set_id: int, texture_name: String, render_hints: Dictionary):
		return _billboard_material_for_texture(resolved_set_id, texture_name, render_hints)
	var render_hints_from_area := func(node_value) -> Dictionary:
		return _render_hints_from_area(node_value)
	var first_anim_name_finder := func(node_value) -> String:
		return _find_first_anim_name(node_value)
	var first_name_finder := func(node_value, key: String) -> String:
		return _find_first_name(node_value, key)
	var triangulator := func(polygon: Array, uvs: Array) -> Array:
		return _triangulate(polygon, uvs)
	var coerce_uvs := func(uv_points: Array, polygon: Array, resolved_set_id: int, texture_name: String) -> Array:
		return _coerce_uvs(uv_points, polygon, resolved_set_id, texture_name)
	var first_points_finder := func(node_value, key: String) -> Array:
		return _find_first_points(node_value, key)
	var unit_billboard_polygon_builder := func() -> Array:
		return _unit_billboard_polygon()
	return ParticleBuilder.particle_stage_from_area(area_data, set_id, load_anim_frames, billboard_material_resolver, render_hints_from_area, first_anim_name_finder, first_name_finder, triangulator, coerce_uvs, first_points_finder, unit_billboard_polygon_builder)

static func _particle_node_from_definition(definition: Dictionary) -> Node3D:
	return ParticleBuilder.particle_node_from_definition(definition)

static func _unit_billboard_polygon() -> Array:
	return ParticleBuilder.unit_billboard_polygon()

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
			- float(p.get("y", 0.0)) * ua_to_preview,
			- float(p.get("z", 0.0)) * ua_to_preview
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
	var hints := MaterialFactory.normalized_render_hints(render_hints)
	var cache_key := MaterialFactory.render_cache_key(set_id, texture_file, hints, _piece_game_data_type)
	if MaterialFactory.has_material_cache(cache_key):
		return MaterialFactory.get_cached_material(cache_key)
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
		var shade_multiplier := MaterialFactory.shade_multiplier_from_value(int(hints.get("shade_value", 0)))
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
	return MaterialFactory.store_material(cache_key, mat)

static func _texture_for_name(set_id: int, texture_name: String, render_hints: Dictionary = {}) -> Texture2D:
	var texture_file := _normalize_texture_name(texture_name)
	if texture_file.is_empty():
		return null
	var hints := MaterialFactory.normalized_render_hints(render_hints)
	var cache_key := MaterialFactory.texture_cache_key(set_id, texture_file, hints, _piece_game_data_type)
	if MaterialFactory.has_texture_cache(cache_key):
		return MaterialFactory.get_cached_texture(cache_key)
	if _external_source_loading_enabled:
		var raw_image := MaterialFactory.raw_image_for_texture(set_id, texture_name, hints, _piece_game_data_type, _external_source_root)
		if raw_image != null:
			var converted_raw := MaterialFactory.apply_color_key_transparency(raw_image)
			return MaterialFactory.store_texture(cache_key, ImageTexture.create_from_image(converted_raw))

		var texture_path := _find_file(_set_root(set_id), texture_file)
		if not texture_path.is_empty():
			var tex = load(texture_path)
			if tex is Texture2D:
				var image: Image = tex.get_image()
				if image != null:
					var converted := MaterialFactory.apply_color_key_transparency(image)
					return MaterialFactory.store_texture(cache_key, ImageTexture.create_from_image(converted))
				MaterialFactory.store_texture(cache_key, tex)
				if MaterialFactory.get_cached_texture(cache_key) != null:
					return MaterialFactory.get_cached_texture(cache_key)
			# Filenames like BODEN1.ILB.bmp confuse ResourceLoader (no bmp importer match);
			# Image.load_from_file still decodes standard PC bitmaps.
			var img_fallback := Image.load_from_file(texture_path)
			if img_fallback != null:
				var converted_fb := MaterialFactory.apply_color_key_transparency(img_fallback)
				return MaterialFactory.store_texture(cache_key, ImageTexture.create_from_image(converted_fb))

	return MaterialFactory.store_texture(cache_key, null)

static func _normalized_render_hints(render_hints: Dictionary) -> Dictionary:
	return MaterialFactory.normalized_render_hints(render_hints)

static func _render_cache_key(set_id: int, texture_file: String, render_hints: Dictionary) -> String:
	return MaterialFactory.render_cache_key(set_id, texture_file, render_hints, _piece_game_data_type)

static func _texture_cache_key(set_id: int, texture_file: String, render_hints: Dictionary) -> String:
	return MaterialFactory.texture_cache_key(set_id, texture_file, render_hints, _piece_game_data_type)

static func _surface_group_key(texture_name: String, render_hints: Dictionary) -> String:
	return MaterialFactory.surface_group_key(texture_name, render_hints)

static func _shade_multiplier_from_value(shade_value: int) -> float:
	return MaterialFactory.shade_multiplier_from_value(shade_value)

static func _raw_image_for_texture(set_id: int, texture_name: String, render_hints: Dictionary) -> Image:
	return MaterialFactory.raw_image_for_texture(set_id, texture_name, render_hints, _piece_game_data_type, _external_source_root)

static func _raw_texture_override_path(set_id: int, texture_name: String, render_hints: Dictionary) -> String:
	return MaterialFactory.raw_texture_override_path(set_id, texture_name, render_hints, _piece_game_data_type, _external_source_root)

static func _load_ilbm_image(path: String) -> Image:
	return MaterialFactory.load_ilbm_image(path)

static func _byte_run1_decode(src: PackedByteArray) -> PackedByteArray:
	return MaterialFactory.byte_run1_decode(src)

static func _ascii_from_bytes(data: PackedByteArray, start: int, size: int) -> String:
	return MaterialFactory.ascii_from_bytes(data, start, size)

static func _read_u16_be(data: PackedByteArray, offset: int) -> int:
	return MaterialFactory.read_u16_be(data, offset)

static func _read_u32_be(data: PackedByteArray, offset: int) -> int:
	return MaterialFactory.read_u32_be(data, offset)

static func _apply_color_key_transparency(image: Image) -> Image:
	return MaterialFactory.apply_color_key_transparency(image)

static func _load_anim_frames(set_id: int, anim_name: String, polygon: Array) -> Array:
	var anim_path_finder := func(resolved_set_id: int, resolved_anim_name: String) -> String:
		return _find_anim_json_path(resolved_set_id, resolved_anim_name)
	var json_loader := func(path: String) -> Dictionary:
		return _load_json(path)
	var triangulator := func(poly: Array, uvs: Array) -> Array:
		return _triangulate(poly, uvs)
	var bmpanim_uv_coercer := func(raw_uvs: Array, poly: Array) -> Array:
		return _coerce_bmpanim_uvs(raw_uvs, poly)
	return AnimationBuilder.load_anim_frames(
		set_id,
		anim_name,
		polygon,
		_piece_game_data_type,
		_external_source_loading_enabled,
		anim_path_finder,
		json_loader,
		triangulator,
		bmpanim_uv_coercer
	)

static func _clone_anim_frames(compiled_frames: Array, polygon: Array, _set_id: int) -> Array:
	var triangulator := func(poly: Array, uvs: Array) -> Array:
		return _triangulate(poly, uvs)
	var bmpanim_uv_coercer := func(raw_uvs: Array, poly: Array) -> Array:
		return _coerce_bmpanim_uvs(raw_uvs, poly)
	return AnimationBuilder.clone_anim_frames(compiled_frames, polygon, triangulator, bmpanim_uv_coercer)

static func _find_anim_json_path(set_id: int, anim_name: String) -> String:
	return SourceResolver.find_anim_json_path(set_id, anim_name, _piece_game_data_type, _external_source_root)

static func _push_unique(items: Array, value) -> void:
	if not items.has(value):
		items.append(value)

static func _find_frames_list(node) -> Array:
	return AnimationBuilder.find_frames_list(node)

static func _load_piece_source(set_id: int, base_name: String) -> Dictionary:
	if not _external_source_loading_enabled:
		return {}
	var bas_path := _find_piece_bas_path(set_id, base_name)
	var bas_data := _load_json(bas_path)
	var skel_ref := _find_first_skeleton_ref(bas_data)
	var skel_name := skel_ref.get_file().get_basename() if not skel_ref.is_empty() else base_name
	return {
		"bas_data": bas_data,
		"points": _find_first_points(_load_json(_find_file(_skeleton_dir(set_id), "%s.skl.json" % skel_name)), "POO2"),
		"polys": _find_first_edges(_load_json(_find_file(_skeleton_dir(set_id), "%s.skl.json" % skel_name)), "POL2"),
	}

static func _surface_node_from_surface(surface: Dictionary, set_id: int) -> Node3D:
	var animation_frames: Array = surface.get("animation_frames", [])
	if not animation_frames.is_empty():
		var material_resolver := func(resolved_set_id: int, texture_name: String, render_hints: Dictionary):
			return _material_for_texture(resolved_set_id, texture_name, render_hints)
		return AnimationBuilder.build_animated_surface_node(surface, set_id, material_resolver)
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
	return MeshLoader.mesh_from_triangles(triangles, material)

static func _append_surface_to_mesh(mesh: ArrayMesh, triangles: Array, material: Material) -> void:
	MeshLoader.append_surface_to_mesh(mesh, triangles, material)

static func _normalize_texture_name(texture_name: String) -> String:
	var cleaned := texture_name.strip_edges()
	if cleaned.is_empty():
		return ""
	var base := cleaned.get_basename()
	return "%s.ILB.bmp" % base

static func _load_json(path: String) -> Dictionary:
	return SourceResolver.load_json(path)

static func _find_file(dir_path: String, filename: String) -> String:
	return SourceResolver.find_file(dir_path, filename)

static func _first_existing_set_under_base(base: String, resolved_set_id: int, game_data_type: String) -> String:
	return SourceResolver.first_existing_set_under_base(base, resolved_set_id, game_data_type)

static func _set_root(set_id: int) -> String:
	return SourceResolver.set_root(set_id, _piece_game_data_type, _external_source_root)

static func _dir_with_retail_fallback(root: String, relative_dir: String) -> String:
	return SourceResolver.dir_with_retail_fallback(root, relative_dir, _piece_game_data_type)

static func _find_piece_bas_path(set_id: int, base_name: String) -> String:
	return SourceResolver.find_piece_bas_path(set_id, base_name, _piece_game_data_type, _external_source_root)

static func _buildings_dir(set_id: int) -> String:
	return SourceResolver.buildings_dir(set_id, _piece_game_data_type, _external_source_root)

static func _ground_dir(set_id: int) -> String:
	return SourceResolver.ground_dir(set_id, _piece_game_data_type, _external_source_root)

static func _vehicles_dir(set_id: int) -> String:
	return SourceResolver.vehicles_dir(set_id, _piece_game_data_type, _external_source_root)

static func _hi_alpha_dir(set_id: int) -> String:
	return SourceResolver.hi_alpha_dir(set_id, _piece_game_data_type, _external_source_root)

static func _skeleton_dir(set_id: int) -> String:
	return SourceResolver.skeleton_dir(set_id, _piece_game_data_type, _external_source_root)

static func _rsrcpool_dir(set_id: int) -> String:
	return SourceResolver.rsrcpool_dir(set_id, _piece_game_data_type, _external_source_root)

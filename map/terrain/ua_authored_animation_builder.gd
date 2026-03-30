extends RefCounted
class_name UAAuthoredAnimationBuilder

const AnimatedSurfaceMeshInstanceScript = preload("res://map/terrain/ua_animated_surface_mesh_instance.gd")

static var _anim_cache := {}

static func clear_runtime_caches() -> void:
	_anim_cache.clear()

static func clear_runtime_caches_for_tests() -> void:
	clear_runtime_caches()

static func load_anim_frames(set_id: int, anim_name: String, polygon: Array, game_data_type: String, external_source_loading_enabled: bool, anim_path_finder: Callable, json_loader: Callable, triangulator: Callable, bmpanim_uv_coercer: Callable) -> Array:
	if not external_source_loading_enabled:
		return []
	var cache_key := "%d:%s:%s" % [set_id, anim_name.to_lower(), game_data_type.to_lower()]
	if _anim_cache.has(cache_key):
		return clone_anim_frames(_anim_cache[cache_key], polygon, triangulator, bmpanim_uv_coercer)
	if not anim_path_finder.is_valid() or not json_loader.is_valid():
		return []
	var anim_path_value = anim_path_finder.call(set_id, anim_name)
	var anim_path := String(anim_path_value)
	var anim_data_value = json_loader.call(anim_path)
	var anim_data: Dictionary = anim_data_value if typeof(anim_data_value) == TYPE_DICTIONARY else {}
	var raw_frames := find_frames_list(anim_data)
	var compiled: Array = []
	for frame_value in raw_frames:
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		var frame := frame_value as Dictionary
		var texture_name := String(frame.get("vbmp_name", ""))
		var uv_points: Array = frame.get("vbmp_coords", [])
		compiled.append({
			"texture_name": texture_name,
			"raw_uv_points": uv_points.duplicate(true),
			"duration_sec": max(float(frame.get("frame_time", 40.0)) / 1000.0, 0.01),
		})
	_anim_cache[cache_key] = compiled
	if compiled.size() > 0:
		return clone_anim_frames(compiled, polygon, triangulator, bmpanim_uv_coercer)
	return []

static func clone_anim_frames(compiled_frames: Array, polygon: Array, triangulator: Callable, bmpanim_uv_coercer: Callable) -> Array:
	if not triangulator.is_valid() or not bmpanim_uv_coercer.is_valid():
		return []
	var frames: Array = []
	for frame_value in compiled_frames:
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		var frame := frame_value as Dictionary
		var texture_name := String(frame.get("texture_name", ""))
		var uvs_value = bmpanim_uv_coercer.call(frame.get("raw_uv_points", []), polygon)
		if typeof(uvs_value) != TYPE_ARRAY:
			continue
		var triangles_value = triangulator.call(polygon, Array(uvs_value))
		if typeof(triangles_value) != TYPE_ARRAY:
			continue
		frames.append({
			"texture_name": texture_name,
			"triangles": Array(triangles_value),
			"duration_sec": float(frame.get("duration_sec", 0.04)),
		})
	return frames

static func find_frames_list(node) -> Array:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("frames"):
			return node.get("frames", [])
		for value in node.values():
			var found: Array = find_frames_list(value)
			if not found.is_empty():
				return found
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			var found: Array = find_frames_list(item)
			if not found.is_empty():
				return found
	return []

static func build_animated_surface_node(surface: Dictionary, set_id: int, material_resolver: Callable) -> Node3D:
	var animation_frames: Array = surface.get("animation_frames", [])
	if animation_frames.is_empty() or not material_resolver.is_valid():
		return null
	var render_hints: Dictionary = surface.get("render_hints", {})
	var animated := AnimatedSurfaceMeshInstanceScript.new()
	var prepared_frames: Array = []
	for frame_value in animation_frames:
		if typeof(frame_value) != TYPE_DICTIONARY:
			continue
		var frame := frame_value as Dictionary
		var prepared: Dictionary = frame.duplicate(true)
		prepared["material"] = material_resolver.call(set_id, String(frame.get("texture_name", "")), render_hints)
		if prepared.get("material", null) == null:
			continue
		prepared_frames.append(prepared)
	if prepared_frames.is_empty():
		return null
	animated.setup_animation(prepared_frames)
	animated.set_meta("ua_authored_animated", true)
	return animated

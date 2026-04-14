extends Node3D
class_name UASkyRuntime

const DEFAULT_REGISTRY_PATH := "res://resources/ua/sky/registry.json"
const NOSKY_CANONICAL_ID := "nosky"
# UA source defaults `_skyHeight` to -550 in UA coordinates.
# Converted preview geometry already flips UA-down Y into Godot-up Y,
# so the Godot-side runtime equivalent is the sign-flipped +550.
const DEFAULT_SKY_VERTICAL_OFFSET := 550.0
const DEFAULT_MIN_SKY_RADIUS := 22500.0
const DEFAULT_MIN_SKY_TOP_EXTENT := 12000.0
const MAP_SECTOR_WORLD_SIZE := 1200.0
const DEFAULT_SKY_VIZ_LIMIT := 4200.0
const DEFAULT_SKY_FADE_LENGTH := 1100.0

@export var registry_path := DEFAULT_REGISTRY_PATH
@export var sky_vertical_offset := DEFAULT_SKY_VERTICAL_OFFSET

var _registry_entries: Dictionary = {}
var _alias_to_canonical: Dictionary = {}
var _manifest_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _warning_cache: Dictionary = {}
var _active_sky_instance: Node3D = null
var _active_canonical_id := ""
var _active_family := ""
var _active_base_radius := 0.0
var _active_base_top_extent := 0.0
var _event_system_override: Node = null
var _current_map_data_override: Node = null
var _editor_state_override: Node = null
var _queued_request_kind := ""
var _queued_request_sky_name := ""
var _sky_request_deferred := false

var _last_camera_for_sky: Transform3D = Transform3D.IDENTITY
var _last_cam_far_for_sky: float = -1.0
var _last_map_sectors_for_sky: Vector2i = Vector2i(-999, -999)

@onready var _sky_container: Node3D = $SkyContainer if has_node("SkyContainer") else null


func _ready() -> void:
	_ensure_sky_container()
	var event_system := _event_system()
	if event_system:
		event_system.map_created.connect(_on_map_changed)
		event_system.map_updated.connect(_on_map_changed)
		if event_system.has_signal("map_view_updated"):
			event_system.map_view_updated.connect(_on_map_view_updated)
		if event_system.has_signal("sky_preview_requested"):
			event_system.sky_preview_requested.connect(_on_sky_preview_requested)
		if event_system.has_signal("sky_preview_reset_requested"):
			event_system.sky_preview_reset_requested.connect(_on_sky_preview_reset_requested)
	_apply_preview_activity_state()
	request_refresh_from_current_map()
	if _preview_updates_active():
		call_deferred("update_active_sky_transform")


func _process(_delta: float) -> void:
	update_active_sky_transform()


func _on_map_changed() -> void:
	request_refresh_from_current_map()


func _on_map_view_updated() -> void:
	_apply_preview_activity_state()
	if _preview_updates_active():
		if _queued_request_kind != "":
			_schedule_queued_sky_request()
		else:
			call_deferred("update_active_sky_transform")


func _on_sky_preview_requested(sky_name: String) -> void:
	request_sky_preview(sky_name)


func _on_sky_preview_reset_requested() -> void:
	request_refresh_from_current_map()


func request_sky_preview(sky_name: String) -> void:
	_queue_sky_request("show", sky_name)


func request_refresh_from_current_map() -> void:
	_queue_sky_request("refresh")


func _queue_sky_request(kind: String, sky_name: String = "") -> void:
	_queued_request_kind = kind
	_queued_request_sky_name = sky_name
	if not _preview_updates_active():
		return
	_schedule_queued_sky_request()


func _schedule_queued_sky_request() -> void:
	if _sky_request_deferred:
		return
	_sky_request_deferred = true
	call_deferred("_apply_queued_sky_request")


func _apply_queued_sky_request() -> void:
	_sky_request_deferred = false
	if not _preview_updates_active():
		return
	var kind := _queued_request_kind
	var sky_name := _queued_request_sky_name
	_queued_request_kind = ""
	_queued_request_sky_name = ""
	if kind == "refresh":
		refresh_from_current_map()
	elif kind == "show":
		show_sky(sky_name)


func refresh_from_current_map() -> bool:
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return clear_active_sky()
	return show_sky(String(current_map_data.sky))


func show_sky(sky_name: String) -> bool:
	_ensure_sky_container()
	if not _ensure_registry_loaded():
		_warn_once("registry:%s" % registry_path, "[SkyRuntime] Failed to load registry: %s. Falling back to WorldEnvironment background only." % registry_path)
		return clear_active_sky()
	var normalized := sky_name.strip_edges().to_lower()
	if normalized.is_empty():
		print("[SkyRuntime] Empty sky name resolved to NOSKY.")
		return _show_nosky_entry(false)
	var entry := resolve_registry_entry(sky_name)
	if entry.is_empty():
		return _activate_fallback_nosky(
			"unknown:%s" % normalized,
			"[SkyRuntime] No converted sky entry found for '%s'. Falling back to NOSKY." % sky_name
		)
	return _show_resolved_entry(entry, sky_name, false)


func _show_nosky_entry(treat_as_failure: bool) -> bool:
	var nosky_entry := resolve_registry_entry(NOSKY_CANONICAL_ID)
	if nosky_entry.is_empty():
		_warn_once(
			"missing_nosky_entry",
			"[SkyRuntime] NOSKY fallback entry is unavailable in %s. Falling back to WorldEnvironment background only." % registry_path
		)
		return clear_active_sky()
	return _show_resolved_entry(nosky_entry, NOSKY_CANONICAL_ID, treat_as_failure)


func _activate_fallback_nosky(cache_key: String, message: String) -> bool:
	_warn_once(cache_key, message)
	return _show_nosky_entry(true)


func _show_resolved_entry(entry: Dictionary, requested_sky_name: String, treat_as_failure: bool) -> bool:
	var canonical_id := String(entry.get("canonical_id", ""))
	if canonical_id == _active_canonical_id and is_instance_valid(_active_sky_instance):
		update_active_sky_transform()
		return not treat_as_failure
	var manifest := _manifest_for_entry(entry)
	var metrics := _sky_metrics_from_manifest(manifest)
	var instance := instantiate_sky_for_entry(entry)
	if instance == null:
		if canonical_id == NOSKY_CANONICAL_ID:
			_warn_once(
				"nosky_instance_failure",
				"[SkyRuntime] Failed to instantiate NOSKY fallback bundle. Falling back to WorldEnvironment background only."
			)
			return clear_active_sky()
		return _activate_fallback_nosky(
			"broken:%s" % canonical_id,
			"[SkyRuntime] Failed to instantiate converted sky '%s' for request '%s'. Falling back to NOSKY." % [canonical_id, requested_sky_name]
		)
	_replace_active_sky(
		instance,
		canonical_id,
		String(manifest.get("family", "")),
		float(metrics.get("base_radius", 0.0)),
		float(metrics.get("top_extent", 0.0))
	)
	update_active_sky_transform()
	return not treat_as_failure


func clear_active_sky() -> bool:
	_active_canonical_id = ""
	_active_family = ""
	_active_base_radius = 0.0
	_active_base_top_extent = 0.0
	if is_instance_valid(_active_sky_instance):
		_destroy_node(_active_sky_instance)
	_active_sky_instance = null
	_set_sky_container_transform(Vector3.ZERO)
	_invalidate_sky_camera_cache()
	return false


func resolve_registry_entry(sky_name: String) -> Dictionary:
	if not _ensure_registry_loaded():
		return {}
	var normalized := sky_name.strip_edges().to_lower()
	if normalized.is_empty():
		return {}
	var canonical_id := String(_alias_to_canonical.get(normalized, ""))
	if canonical_id.is_empty():
		return {}
	if not _registry_entries.has(canonical_id):
		return {}
	var entry: Variant = _registry_entries[canonical_id]
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	var resolved := (entry as Dictionary).duplicate(true)
	resolved["canonical_id"] = canonical_id
	return resolved


func instantiate_sky_for_entry(entry: Dictionary) -> Node3D:
	var manifest := _manifest_for_entry(entry)
	if _should_try_scene_load(entry, manifest):
		var packed_scene := load_scene_for_entry(entry)
		if packed_scene != null:
			var scene_instance := packed_scene.instantiate()
			if scene_instance is Node3D:
				return scene_instance as Node3D
			if scene_instance is Node:
				(scene_instance as Node).free()
	return _build_instance_from_manifest(manifest)


func load_scene_for_entry(entry: Dictionary) -> PackedScene:
	var scene_path := _scene_path_for_entry(entry)
	if scene_path.is_empty():
		return null
	if _scene_cache.has(scene_path):
		var cached = _scene_cache[scene_path]
		return cached as PackedScene if cached is PackedScene else null
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return null
	var loaded = load(scene_path)
	if loaded is PackedScene:
		_scene_cache[scene_path] = loaded
		return loaded as PackedScene
	return null


func _manifest_for_entry(entry: Dictionary) -> Dictionary:
	if entry.has("geometry_path") or entry.has("textures") or entry.has("flags"):
		return entry.duplicate(true)
	var manifest_path := String(entry.get("manifest_path", ""))
	if manifest_path.is_empty():
		return {}
	if not _manifest_cache.has(manifest_path):
		_manifest_cache[manifest_path] = load_json_file(manifest_path)
	var manifest: Variant = _manifest_cache.get(manifest_path, {})
	return (manifest as Dictionary).duplicate(true) if typeof(manifest) == TYPE_DICTIONARY else {}


func _should_try_scene_load(entry: Dictionary, manifest: Dictionary) -> bool:
	var scene_path := _scene_path_for_entry(entry)
	if scene_path.is_empty():
		return false
	var mesh_paths = manifest.get("mesh_paths", [])
	if typeof(mesh_paths) == TYPE_ARRAY:
		for mesh_path in mesh_paths:
			if String(mesh_path).to_lower().ends_with(".obj"):
				return false
	return true


func _build_instance_from_manifest(manifest: Dictionary) -> Node3D:
	if manifest.is_empty():
		return null
	var root := Node3D.new()
	root.name = "SkyRoot"
	var debug_sky_id := String(manifest.get("canonical_id", ""))
	var flags = manifest.get("flags", {})
	var has_geometry := false
	if typeof(flags) == TYPE_DICTIONARY:
		has_geometry = bool((flags as Dictionary).get("has_geometry", false))
	if not has_geometry:
		return root
	var geometry_path := String(manifest.get("geometry_path", ""))
	var geometry := load_json_file(geometry_path)
	if geometry.is_empty():
		_warn_once(
			"missing_geometry:%s" % debug_sky_id,
			"[SkyRuntime] Geometry payload is missing or unreadable for sky '%s': %s" % [debug_sky_id, geometry_path]
		)
		root.free()
		return null
	var mesh_instance := _build_mesh_instance_from_geometry(geometry, manifest, debug_sky_id)
	if mesh_instance == null:
		root.free()
		return null
	root.add_child(mesh_instance)
	return root


func _build_mesh_instance_from_geometry(geometry: Dictionary, manifest: Dictionary, debug_sky_id: String) -> MeshInstance3D:
	var points = geometry.get("points", [])
	var surfaces = geometry.get("surfaces", [])
	if typeof(points) != TYPE_ARRAY or typeof(surfaces) != TYPE_ARRAY:
		return null
	var texture_lookup := _manifest_texture_lookup(manifest)
	var flags := _normalized_sky_flags(manifest.get("flags", {}))
	var material_cache: Dictionary = {}
	var mesh := ArrayMesh.new()
	var fog_vis_limit := DEFAULT_SKY_VIZ_LIMIT
	var fog_fade_length := DEFAULT_SKY_FADE_LENGTH
	var surface_index := 0
	for surface in surfaces:
		if typeof(surface) != TYPE_DICTIONARY:
			continue
		var surface_dict := surface as Dictionary
		var point_indices = surface_dict.get("point_indices", [])
		var uvs = surface_dict.get("uvs", [])
		if typeof(point_indices) != TYPE_ARRAY or typeof(uvs) != TYPE_ARRAY:
			continue
		if point_indices.size() < 3 or point_indices.size() != uvs.size():
			continue
		var surface_tool := SurfaceTool.new()
		surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var wrote_geometry := false
		for i in range(1, point_indices.size() - 1):
			var ok := _append_triangle(
				surface_tool,
				points,
				int(point_indices[0]), uvs[0],
				int(point_indices[i]), uvs[i],
				int(point_indices[i + 1]), uvs[i + 1],
				fog_vis_limit,
				fog_fade_length
			)
			if ok:
				wrote_geometry = true
		if not wrote_geometry:
			continue
		surface_tool.commit(mesh)
		var material := _material_for_texture(
			String(surface_dict.get("texture_name", "")),
			texture_lookup,
			flags,
			material_cache,
			debug_sky_id
		)
		if material != null:
			mesh.surface_set_material(surface_index, material)
		surface_index += 1
	if surface_index == 0:
		return null
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SkyMesh"
	mesh_instance.mesh = mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance


func _manifest_texture_lookup(manifest: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	var textures = manifest.get("textures", [])
	if typeof(textures) != TYPE_ARRAY:
		return lookup
	for texture_entry in textures:
		if typeof(texture_entry) != TYPE_DICTIONARY:
			continue
		var entry_dict := texture_entry as Dictionary
		var bundle_path := String(entry_dict.get("bundle_path", ""))
		if bundle_path.is_empty():
			continue
		var source_name := String(entry_dict.get("source_name", ""))
		if not source_name.is_empty():
			lookup[source_name] = bundle_path
			lookup[source_name.to_lower()] = bundle_path
		var source_file := String(entry_dict.get("source_file", ""))
		if not source_file.is_empty():
			lookup[source_file] = bundle_path
			lookup[source_file.to_lower()] = bundle_path
	return lookup


func _material_for_texture(texture_name: String, texture_lookup: Dictionary, flags: Dictionary, material_cache: Dictionary, debug_sky_id: String = "") -> StandardMaterial3D:
	var cache_key := texture_name.to_lower()
	var sky_label := debug_sky_id if not debug_sky_id.is_empty() else "<unknown>"
	if material_cache.has(cache_key):
		var cached: Variant = material_cache[cache_key]
		return cached as StandardMaterial3D if cached is StandardMaterial3D else null
	var material := StandardMaterial3D.new()
	material.metallic = 0.0
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if bool(flags.get("unshaded", true)) else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if bool(flags.get("double_sided", true)) else BaseMaterial3D.CULL_BACK
	material.vertex_color_use_as_albedo = true
	# `fog_sky_affect` only excludes the background sky. The approved UA sky path in
	# this editor is runtime mesh geometry, so it must opt out of preview distance fog
	# explicitly to preserve the original-game behavior.
	material.disable_fog = true
	material.disable_receive_shadows = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = false
	var texture_path := String(texture_lookup.get(texture_name, texture_lookup.get(cache_key, "")))
	if texture_path.is_empty() and not texture_name.is_empty():
		_warn_once(
			"missing_texture_ref:%s:%s" % [debug_sky_id, cache_key],
			"[SkyRuntime] Sky '%s' references missing bundle texture '%s'. Rendering that surface without a texture." % [sky_label, texture_name]
		)
	elif not texture_path.is_empty():
		var loaded_texture := _load_texture_from_bundle(texture_path)
		if loaded_texture != null:
			material.albedo_texture = loaded_texture
		else:
			_warn_once(
				"missing_texture_file:%s" % texture_path,
				"[SkyRuntime] Failed to load sky texture '%s' for sky '%s'. Rendering that surface without a texture." % [texture_path, sky_label]
			)
	_configure_material_transparency(material, flags)
	material_cache[cache_key] = material
	return material


func _load_texture_from_bundle(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if _texture_cache.has(texture_path):
		var cached: Variant = _texture_cache[texture_path]
		return cached as Texture2D if cached is Texture2D else null
	var absolute_path := ProjectSettings.globalize_path(texture_path)
	if not absolute_path.is_empty() and FileAccess.file_exists(absolute_path):
		var image := Image.load_from_file(absolute_path)
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			var image_texture := ImageTexture.create_from_image(image)
			if image_texture != null:
				_texture_cache[texture_path] = image_texture
				return image_texture
	var resource := load(texture_path)
	if resource is Texture2D:
		_texture_cache[texture_path] = resource
		return resource as Texture2D
	return null


func _normalized_sky_flags(flags: Variant) -> Dictionary:
	if typeof(flags) != TYPE_DICTIONARY:
		return {
			"double_sided": true,
			"unshaded": true,
			"uses_alpha": false,
			"blend_mode": "mix",
		}
	var flag_dict := flags as Dictionary
	var blend_mode := String(flag_dict.get("blend_mode", "mix")).to_lower()
	if blend_mode != "add":
		blend_mode = "mix"
	return {
		"double_sided": bool(flag_dict.get("double_sided", true)),
		"unshaded": bool(flag_dict.get("unshaded", true)),
		"uses_alpha": bool(flag_dict.get("uses_alpha", false)),
		"blend_mode": blend_mode,
	}


func _configure_material_transparency(material: StandardMaterial3D, flags: Dictionary) -> void:
	if material == null:
		return
	var use_alpha_blend := bool(flags.get("uses_alpha", false))
	var has_texture_alpha := _material_texture_has_alpha(material)
	if has_texture_alpha and not use_alpha_blend:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	elif use_alpha_blend:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if String(flags.get("blend_mode", "mix")) == "add":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


func _material_texture_has_alpha(material: StandardMaterial3D) -> bool:
	if material == null or material.albedo_texture == null:
		return false
	var image := material.albedo_texture.get_image()
	return image != null and image.detect_alpha() != Image.ALPHA_NONE


func _static_fog_factor_for_distance(distance: float, vis_limit: float = DEFAULT_SKY_VIZ_LIMIT, fade_length: float = DEFAULT_SKY_FADE_LENGTH) -> float:
	if vis_limit <= 0.0:
		return 0.0
	var clamped_distance: float = distance if distance > 0.0 else 0.0
	if fade_length <= 0.0:
		return 1.0 if clamped_distance <= vis_limit else 0.0
	var fade_start: float = vis_limit - fade_length
	if is_equal_approx(fade_start, vis_limit):
		return 1.0 if clamped_distance <= vis_limit else 0.0
	return clamp((vis_limit - clamped_distance) / (vis_limit - fade_start), 0.0, 1.0)


func _static_fog_color_for_vertex(vertex: Vector3, vis_limit: float = DEFAULT_SKY_VIZ_LIMIT, fade_length: float = DEFAULT_SKY_FADE_LENGTH) -> Color:
	var factor := _static_fog_factor_for_distance(vertex.length(), vis_limit, fade_length)
	return Color(factor, factor, factor, 1.0)


func _append_triangle(
		surface_tool: SurfaceTool,
		points: Array,
		point_index_a: int,
		uv_a: Variant,
		point_index_b: int,
		uv_b: Variant,
		point_index_c: int,
			uv_c: Variant,
			fog_vis_limit: float = DEFAULT_SKY_VIZ_LIMIT,
			fog_fade_length: float = DEFAULT_SKY_FADE_LENGTH) -> bool:
	var vertex_a: Variant = _vector3_from_point_index(points, point_index_a)
	var vertex_b: Variant = _vector3_from_point_index(points, point_index_b)
	var vertex_c: Variant = _vector3_from_point_index(points, point_index_c)
	var tex_uv_a: Variant = _vector2_from_value(uv_a)
	var tex_uv_b: Variant = _vector2_from_value(uv_b)
	var tex_uv_c: Variant = _vector2_from_value(uv_c)
	if not (vertex_a is Vector3 and vertex_b is Vector3 and vertex_c is Vector3):
		return false
	if not (tex_uv_a is Vector2 and tex_uv_b is Vector2 and tex_uv_c is Vector2):
		return false
	var pos_a: Vector3 = vertex_a as Vector3
	var pos_b: Vector3 = vertex_b as Vector3
	var pos_c: Vector3 = vertex_c as Vector3
	surface_tool.set_color(_static_fog_color_for_vertex(pos_a, fog_vis_limit, fog_fade_length))
	surface_tool.set_uv(tex_uv_a as Vector2)
	surface_tool.add_vertex(pos_a)
	surface_tool.set_color(_static_fog_color_for_vertex(pos_b, fog_vis_limit, fog_fade_length))
	surface_tool.set_uv(tex_uv_b as Vector2)
	surface_tool.add_vertex(pos_b)
	surface_tool.set_color(_static_fog_color_for_vertex(pos_c, fog_vis_limit, fog_fade_length))
	surface_tool.set_uv(tex_uv_c as Vector2)
	surface_tool.add_vertex(pos_c)
	return true


func _vector3_from_point_index(points: Array, point_index: int) -> Variant:
	if point_index < 0 or point_index >= points.size():
		return null
	var point_value: Variant = points[point_index]
	if typeof(point_value) != TYPE_DICTIONARY:
		return null
	var point_dict := point_value as Dictionary
	return Vector3(
		float(point_dict.get("x", 0.0)),
		float(point_dict.get("y", 0.0)),
		float(point_dict.get("z", 0.0))
	)


func _vector2_from_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var value_array := value as Array
		if value_array.size() < 2:
			return null
		return Vector2(float(value_array[0]), float(value_array[1]))
	if typeof(value) == TYPE_DICTIONARY:
		var value_dict := value as Dictionary
		return Vector2(float(value_dict.get("x", 0.0)), float(value_dict.get("y", 0.0)))
	return null


func _vector3_from_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var value_array := value as Array
		if value_array.size() < 3:
			return null
		return Vector3(float(value_array[0]), float(value_array[1]), float(value_array[2]))
	if typeof(value) == TYPE_DICTIONARY:
		var value_dict := value as Dictionary
		return Vector3(
			float(value_dict.get("x", 0.0)),
			float(value_dict.get("y", 0.0)),
			float(value_dict.get("z", 0.0))
		)
	return null


func set_registry_data(registry: Dictionary) -> void:
	_registry_entries.clear()
	_alias_to_canonical.clear()
	_manifest_cache.clear()
	_scene_cache.clear()
	_texture_cache.clear()
	_warning_cache.clear()
	var entries = registry.get("entries", {})
	if typeof(entries) != TYPE_DICTIONARY:
		return
	for canonical_id in entries.keys():
		var entry = entries[canonical_id]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var canonical := String(canonical_id)
		_registry_entries[canonical] = (entry as Dictionary).duplicate(true)
		_alias_to_canonical[canonical.to_lower()] = canonical
		var aliases = _registry_entries[canonical].get("aliases", [])
		if typeof(aliases) != TYPE_ARRAY:
			continue
		for alias in aliases:
			_alias_to_canonical[String(alias).to_lower()] = canonical


func set_event_system_override(event_system: Node) -> void:
	_event_system_override = event_system


func set_current_map_data_override(current_map_data: Node) -> void:
	_current_map_data_override = current_map_data


func set_editor_state_override(editor_state: Node) -> void:
	_editor_state_override = editor_state


func has_pending_sky_request() -> bool:
	return _queued_request_kind != "" or _sky_request_deferred


func _apply_preview_activity_state() -> void:
	set_process(_preview_updates_active())


func _preview_updates_active() -> bool:
	var editor_state := _editor_state()
	if editor_state != null:
		return bool(editor_state.get("view_mode_3d"))
	return true


func _editor_state() -> Node:
	if _editor_state_override != null and is_instance_valid(_editor_state_override):
		return _editor_state_override
	return get_node_or_null("/root/EditorState")


func get_active_canonical_id() -> String:
	return _active_canonical_id


func get_active_instance() -> Node3D:
	return _active_sky_instance


func get_active_base_radius() -> float:
	return _active_base_radius


func get_active_base_top_extent() -> float:
	return _active_base_top_extent


func get_active_effective_radius() -> float:
	if not is_instance_valid(_active_sky_instance):
		return 0.0
	return _active_base_radius * _active_sky_instance.scale.x


func get_active_effective_top_extent() -> float:
	if not is_instance_valid(_active_sky_instance):
		return 0.0
	return _active_base_top_extent * _active_sky_instance.scale.y


func get_active_effective_vertical_offset() -> float:
	if not is_instance_valid(_active_sky_instance):
		return sky_vertical_offset
	return sky_vertical_offset * _sky_offset_scale_factor()


func _invalidate_sky_camera_cache() -> void:
	_last_cam_far_for_sky = -1.0
	_last_map_sectors_for_sky = Vector2i(-999, -999)


func update_active_sky_transform() -> void:
	if _sky_container == null or not is_instance_valid(_active_sky_instance):
		return
	var cam := _current_camera()
	if cam == null:
		return
	var cmd := _current_map_data()
	var mw := int(cmd.horizontal_sectors) if cmd != null else 0
	var mh := int(cmd.vertical_sectors) if cmd != null else 0
	var sectors := Vector2i(mw, mh)
	var cam_xform := cam.global_transform if cam.is_inside_tree() else cam.transform
	if cam_xform.is_equal_approx(_last_camera_for_sky) and is_equal_approx(_last_cam_far_for_sky, cam.far) and sectors == _last_map_sectors_for_sky:
		return
	_last_camera_for_sky = cam_xform
	_last_cam_far_for_sky = cam.far
	_last_map_sectors_for_sky = sectors
	_apply_active_sky_scale()
	_set_sky_container_transform(_sky_anchor_position())


static func load_json_file(json_path: String) -> Dictionary:
	if json_path.is_empty() or not ResDir.file_exists(json_path):
		return {}
	return ResDir.load_json_dict(json_path)


func _ensure_registry_loaded() -> bool:
	if not _registry_entries.is_empty():
		return true
	set_registry_data(load_json_file(registry_path))
	return not _registry_entries.is_empty()


func _scene_path_for_entry(entry: Dictionary) -> String:
	var scene_path := String(entry.get("scene_path", ""))
	if not scene_path.is_empty():
		return scene_path
	var manifest_path := String(entry.get("manifest_path", ""))
	if manifest_path.is_empty():
		return ""
	if not _manifest_cache.has(manifest_path):
		_manifest_cache[manifest_path] = load_json_file(manifest_path)
	var manifest = _manifest_cache.get(manifest_path, {})
	return String(manifest.get("scene_path", "")) if typeof(manifest) == TYPE_DICTIONARY else ""


func _replace_active_sky(instance: Node3D, canonical_id: String, family: String, base_radius: float, base_top_extent: float) -> void:
	clear_active_sky()
	_active_canonical_id = canonical_id
	_active_family = family.to_lower()
	_active_base_radius = max(base_radius, 0.0)
	_active_base_top_extent = max(base_top_extent, 0.0)
	_active_sky_instance = instance
	_active_sky_instance.name = "ActiveSky"
	_sky_container.add_child(_active_sky_instance)


func _ensure_sky_container() -> void:
	if _sky_container != null:
		return
	_sky_container = Node3D.new()
	_sky_container.name = "SkyContainer"
	add_child(_sky_container)


func _current_camera_position() -> Vector3:
	var camera := get_parent().get_node_or_null("Camera3D") if get_parent() else null
	if camera is Camera3D:
		var camera_node := camera as Camera3D
		return camera_node.global_position if camera_node.is_inside_tree() else camera_node.position
	return global_position if is_inside_tree() else position


func _sky_anchor_position() -> Vector3:
	var camera_position := _current_camera_position()
	return camera_position + Vector3(0.0, get_active_effective_vertical_offset(), 0.0)


func _set_sky_container_transform(target_position: Vector3) -> void:
	if _sky_container == null:
		return
	var sky_transform := Transform3D(Basis.IDENTITY, target_position)
	if _sky_container.is_inside_tree():
		_sky_container.global_transform = sky_transform
	else:
		_sky_container.transform = sky_transform


func _apply_active_sky_scale() -> void:
	if not is_instance_valid(_active_sky_instance):
		return
	var scale_factor := _sky_scale_factor()
	_active_sky_instance.scale = Vector3.ONE * scale_factor


func _sky_scale_factor() -> float:
	var scale_factor := 1.0
	if _active_base_radius > 0.0:
		scale_factor = max(scale_factor, _desired_sky_radius() / _active_base_radius)
	if _should_enforce_top_coverage() and _active_base_top_extent > 0.0:
		scale_factor = max(scale_factor, _desired_sky_top_extent() / _active_base_top_extent)
	return scale_factor


func _sky_offset_scale_factor() -> float:
	if _active_base_radius > 0.0:
		return maxf(1.0, _desired_sky_radius() / _active_base_radius)
	if is_instance_valid(_active_sky_instance):
		return maxf(1.0, _active_sky_instance.scale.y)
	return 1.0


func _desired_sky_radius() -> float:
	var desired_radius := DEFAULT_MIN_SKY_RADIUS
	var camera := _current_camera()
	if camera != null:
		desired_radius = max(desired_radius, camera.far * 0.45)
	var current_map_data := _current_map_data()
	if current_map_data != null:
		var width := float(int(current_map_data.horizontal_sectors)) * MAP_SECTOR_WORLD_SIZE
		var height := float(int(current_map_data.vertical_sectors)) * MAP_SECTOR_WORLD_SIZE
		var half_diagonal := Vector2(width, height).length() * 0.5
		desired_radius = max(desired_radius, half_diagonal * 2.5)
	return desired_radius


func _desired_sky_top_extent() -> float:
	var desired_top_extent := DEFAULT_MIN_SKY_TOP_EXTENT
	var camera := _current_camera()
	if camera != null:
		desired_top_extent = max(desired_top_extent, camera.far * 0.24)
	return desired_top_extent


func _should_enforce_top_coverage() -> bool:
	return _active_family != "custom"


func _sky_metrics_from_manifest(manifest: Dictionary) -> Dictionary:
	var bounds = manifest.get("bounds", {})
	if typeof(bounds) != TYPE_DICTIONARY:
		return {}
	var bounds_dict := bounds as Dictionary
	var min_corner: Variant = _vector3_from_value(bounds_dict.get("min", []))
	var max_corner: Variant = _vector3_from_value(bounds_dict.get("max", []))
	if not (min_corner is Vector3 and max_corner is Vector3):
		return {}
	var min_vec := min_corner as Vector3
	var max_vec := max_corner as Vector3
	var horizontal_radius := 0.0
	horizontal_radius = maxf(horizontal_radius, Vector2(min_vec.x, min_vec.z).length())
	horizontal_radius = maxf(horizontal_radius, Vector2(min_vec.x, max_vec.z).length())
	horizontal_radius = maxf(horizontal_radius, Vector2(max_vec.x, min_vec.z).length())
	horizontal_radius = maxf(horizontal_radius, Vector2(max_vec.x, max_vec.z).length())
	return {
		"base_radius": horizontal_radius,
		"top_extent": max(max_vec.y, 0.0),
	}


func _current_camera() -> Camera3D:
	var camera := get_parent().get_node_or_null("Camera3D") if get_parent() else null
	return camera as Camera3D if camera is Camera3D else null


func _event_system() -> Node:
	if _event_system_override != null and is_instance_valid(_event_system_override):
		return _event_system_override
	return get_node_or_null("/root/EventSystem")


func _current_map_data() -> Node:
	if _current_map_data_override != null and is_instance_valid(_current_map_data_override):
		return _current_map_data_override
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("CurrentMapData")


func _destroy_node(node: Node) -> void:
	if node == null:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	if node.is_inside_tree():
		node.queue_free()
	else:
		node.free()


func _warn_once(key: String, message: String) -> void:
	if key.is_empty() or _warning_cache.has(key):
		return
	_warning_cache[key] = true
	push_warning(message)

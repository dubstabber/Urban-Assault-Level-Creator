extends SceneTree

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const OUT_ROOT := "res://resources/ua/sets"
const SCHEMA_VERSION := 1


func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var base_names := _csv_arg(args, "--base_names")
	if base_names.is_empty():
		base_names = _csv_arg(args, "--base")
	if base_names.is_empty():
		_fail("No base names provided. Use --base_names=vp_robo,s11v,...")
		return

	var set_dir := "%s/set%d" % [OUT_ROOT, maxi(set_id, 1)]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)

	var registry_path := "%s/support_registry.json" % metadata_dir
	var registry := _load_registry(registry_path)
	if not registry.has("schema_version"):
		registry["schema_version"] = SCHEMA_VERSION
	if typeof(registry.get("supports", {})) != TYPE_DICTIONARY:
		registry["supports"] = {}
	var supports: Dictionary = registry["supports"]

	var baked := 0
	for raw_name in base_names:
		var base_name := String(raw_name).strip_edges()
		if base_name.is_empty():
			continue
		var cleaned := base_name.to_lower()

		var scene_path := PieceLibraryScript.baked_piece_scene_path(set_id, base_name)
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			push_warning("[BakeSupport] Skipped %s (no baked scene; bake pieces first)." % base_name)
			continue
		var scene := load(scene_path)
		if not (scene is PackedScene):
			push_warning("[BakeSupport] Skipped %s (not a PackedScene): %s" % [base_name, scene_path])
			continue
		var scene_root := (scene as PackedScene).instantiate()
		if scene_root == null:
			push_warning("[BakeSupport] Skipped %s (instantiate failed): %s" % [base_name, scene_path])
			continue
		if not (scene_root is Node3D):
			scene_root.queue_free()
			push_warning("[BakeSupport] Skipped %s (root not Node3D): %s" % [base_name, scene_path])
			continue

		var triangles := _collect_support_triangles(scene_root as Node3D)
		var entry := _support_entry_from_triangles(triangles)
		scene_root.queue_free()
		if entry.is_empty():
			push_warning("[BakeSupport] Skipped %s (no usable support triangles): %s" % [base_name, scene_path])
			continue
		supports[cleaned] = entry
		baked += 1
		var tri_count: int = int(entry.get("triangle_count", 0))
		print("[BakeSupport] Wrote support for ", cleaned, " triangles=", tri_count)

	registry["supports"] = supports
	_save_registry(registry_path, registry)
	print("[BakeSupport] Done. baked=", baked, " set=", set_id, " registry=", registry_path)
	quit(0)


func _collect_support_triangles(root_node: Node3D) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null:
			continue
		for child in node.get_children():
			if child != null:
				stack.append(child)
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			continue

		var xf := root_node.global_transform.affine_inverse() * mi.global_transform
		var basis := xf.basis
		var origin := xf.origin

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
					_append_triangle_if_support(out, origin + basis * verts[i], origin + basis * verts[i + 1], origin + basis * verts[i + 2])
				continue
			for i in range(0, indices.size(), 3):
				if i + 2 >= indices.size():
					break
				_append_triangle_if_support(out, origin + basis * verts[indices[i]], origin + basis * verts[indices[i + 1]], origin + basis * verts[indices[i + 2]])
	return out


func _append_triangle_if_support(out: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	if absf(normal.normalized().y) <= 0.0001:
		return
	out.append([a, b, c])


func _support_entry_from_triangles(triangles: Array) -> Dictionary:
	if triangles.is_empty():
		return {}
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	var max_height := -INF
	for tri in triangles:
		if typeof(tri) != TYPE_ARRAY:
			continue
		var t := Array(tri)
		if t.size() < 3:
			continue
		for v in [t[0], t[1], t[2]]:
			if typeof(v) != TYPE_VECTOR3:
				continue
			var p := Vector3(v)
			min_v = min_v.min(p)
			max_v = max_v.max(p)
			max_height = maxf(max_height, p.y)

	var triangles_json: Array = []
	triangles_json.resize(triangles.size())
	var written := 0
	for tri in triangles:
		if typeof(tri) != TYPE_ARRAY:
			continue
		var t := Array(tri)
		if t.size() < 3:
			continue
		if typeof(t[0]) != TYPE_VECTOR3 or typeof(t[1]) != TYPE_VECTOR3 or typeof(t[2]) != TYPE_VECTOR3:
			continue
		triangles_json[written] = {"verts": [_v3_json(t[0]), _v3_json(t[1]), _v3_json(t[2])]}
		written += 1
	if written <= 0:
		return {}
	if written != triangles_json.size():
		triangles_json.resize(written)

	return {
		"bounds_aabb": {"min": _v3_json(min_v), "max": _v3_json(max_v)},
		"max_height": max_height if max_height != -INF else 0.0,
		"surfaces": [{"triangles": triangles_json}],
		"triangle_count": written,
	}


func _v3_json(v: Vector3) -> Dictionary:
	return {"x": float(v.x), "y": float(v.y), "z": float(v.z)}


func _int_arg(args: PackedStringArray, name: String, default_value: int) -> int:
	for arg in args:
		if arg.begins_with(name + "="):
			return int(arg.get_slice("=", 1))
	return default_value


func _csv_arg(args: PackedStringArray, name: String) -> PackedStringArray:
	for arg in args:
		if arg.begins_with(name + "="):
			var raw := arg.get_slice("=", 1)
			var parts := PackedStringArray()
			for token in raw.split(",", false):
				var cleaned := String(token).strip_edges()
				if not cleaned.is_empty():
					parts.append(cleaned)
			return parts
	return PackedStringArray()


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		_fail("DirAccess.open(res://) failed; cannot create output directories.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakeSupport] make_dir_recursive failed (%d) for %s" % [err, path])


func _load_registry(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_registry(path: String, registry: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Failed to open registry for write: %s" % path)
		return
	f.store_string(JSON.stringify(registry, "\t", false))
	f.store_string("\n")
	f.close()


func _fail(message: String) -> void:
	push_error("[BakeSupport] " + message)
	quit(1)


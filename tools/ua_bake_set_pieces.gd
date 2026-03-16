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
	var scenes_dir := "%s/pieces/scenes" % set_dir
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(scenes_dir)
	_ensure_dir(metadata_dir)

	var registry_path := "%s/piece_registry.json" % metadata_dir
	var registry := _load_registry(registry_path)
	if not registry.has("schema_version"):
		registry["schema_version"] = SCHEMA_VERSION
	if not registry.has("pieces") or typeof(registry.get("pieces", {})) != TYPE_DICTIONARY:
		registry["pieces"] = {}
	var pieces: Dictionary = registry["pieces"]

	var baked := 0
	for raw_name in base_names:
		var base_name := String(raw_name).strip_edges()
		if base_name.is_empty():
			continue
		var desc := {
			"set_id": set_id,
			"raw_id": -1,
			"base_name": base_name,
			"origin": Vector3.ZERO,
		}
		var piece_root: Node3D = UATerrainPieceLibrary.build_overlay_node([desc])
		if piece_root == null or piece_root.get_child_count() == 0:
			push_warning("[BakePieces] Skipped %s (no source or empty piece)." % base_name)
			continue
		var scene := PackedScene.new()
		var pack_err := scene.pack(piece_root)
		piece_root.queue_free()
		if pack_err != OK:
			push_warning("[BakePieces] Failed to pack %s (err %d)." % [base_name, pack_err])
			continue

		var out_name := base_name.to_lower()
		var out_path := "%s/%s.tscn" % [scenes_dir, out_name]
		var save_err := ResourceSaver.save(scene, out_path)
		if save_err != OK:
			push_warning("[BakePieces] Failed to save %s (err %d) -> %s" % [base_name, save_err, out_path])
			continue

		pieces[out_name] = {
			"scene_path": out_path,
			"mesh_path": "",
			"kind": "static",
			"default_material_overrides": {},
			"support_ref": out_name,
			"particle_ref": out_name,
			"animation_ref": out_name,
		}
		baked += 1
		print("[BakePieces] Wrote ", out_path)

	registry["pieces"] = pieces
	_save_registry(registry_path, registry)
	print("[BakePieces] Done. baked=", baked, " set=", set_id, " registry=", registry_path)
	quit(0)


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
		push_warning("[BakePieces] make_dir_recursive failed (%d) for %s" % [err, path])


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
	push_error("[BakePieces] " + message)
	quit(1)


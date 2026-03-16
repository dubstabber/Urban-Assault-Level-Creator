extends SceneTree

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const OUT_ROOT := "res://resources/ua/sets"
const SCHEMA_VERSION := 1
const LEGACY_SET_ROOT := "res://urban_assault_decompiled-master/assets/sets"

func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var anim_names := _csv_arg(args, "--anims")
	PieceLibraryScript.set_external_source_loading_enabled(true)
	PieceLibraryScript.set_external_source_root(LEGACY_SET_ROOT)
	if anim_names.is_empty():
		anim_names = _csv_arg(args, "--animations")
	if anim_names.is_empty():
		_fail("No animations provided. Use --anims=anim1,anim2,...")
		return

	var set_dir := "%s/set%d" % [OUT_ROOT, maxi(set_id, 1)]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)

	var registry_path := "%s/animations.json" % metadata_dir
	var registry := _load_registry(registry_path)
	if not registry.has("schema_version"):
		registry["schema_version"] = SCHEMA_VERSION
	if typeof(registry.get("animations", {})) != TYPE_DICTIONARY:
		registry["animations"] = {}
	var anims: Dictionary = registry["animations"]

	var baked := 0
	for raw_name in anim_names:
		var anim_name := String(raw_name).strip_edges()
		if anim_name.is_empty():
			continue
		# Dummy quad for polygon; the UVs from compiled frames are already normalized.
		var polygon := [
			Vector3.ZERO,
			Vector3(1.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 1.0),
			Vector3(0.0, 0.0, 1.0),
		]
		var frames := PieceLibraryScript._load_anim_frames(set_id, anim_name, polygon)
		if frames.is_empty():
			push_warning("[BakeAnims] Skipped %s (no frames found)." % anim_name)
			continue
		var key := anim_name.strip_edges().to_lower()
		anims[key] = {
			"name": anim_name,
			"frames": frames,
		}
		baked += 1
		print("[BakeAnims] Baked ", anim_name)

	registry["animations"] = anims
	_save_registry(registry_path, registry)
	print("[BakeAnims] Done. baked=", baked, " set=", set_id, " registry=", registry_path)
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
		push_warning("[BakeAnims] make_dir_recursive failed (%d) for %s" % [err, path])


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
	push_error("[BakeAnims] " + message)
	quit(1)

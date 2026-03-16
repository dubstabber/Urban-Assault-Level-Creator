extends SceneTree

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const OUT_ROOT := "res://resources/ua/sets"
const LEGACY_SET_ROOT := "res://urban_assault_decompiled-master/assets/sets"

func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var names := _csv_arg(args, "--textures")
	PieceLibraryScript.set_external_source_loading_enabled(true)
	PieceLibraryScript.set_external_source_root(LEGACY_SET_ROOT)
	if names.is_empty():
		names = _csv_arg(args, "--texture_names")
	if names.is_empty():
		_fail("No textures provided. Use --textures=tex1,tex2,...")
		return

	var out_dir := "%s/set%d/textures/albedo" % [OUT_ROOT, maxi(set_id, 1)]
	_ensure_dir(out_dir)

	var baked := 0
	for raw_name in names:
		var texture_name := String(raw_name).strip_edges()
		if texture_name.is_empty():
			continue
		var tex: Texture2D = PieceLibraryScript._texture_for_name(set_id, texture_name, {})
		if tex == null:
			push_warning("[BakeTextures] Skipped %s (no runtime texture)." % texture_name)
			continue
		var img: Image = tex.get_image()
		if img == null:
			push_warning("[BakeTextures] Texture has no image: %s" % texture_name)
			continue

		var normalized := PieceLibraryScript._normalize_texture_name(texture_name)
		var base := normalized.strip_edges().get_basename().to_lower()
		if base.is_empty():
			push_warning("[BakeTextures] Could not derive base name for %s" % texture_name)
			continue
		var out_path := "%s/%s.png" % [out_dir, base]
		var err := img.save_png(out_path)
		if err != OK:
			push_warning("[BakeTextures] Failed to save %s (err %d)." % [out_path, err])
			continue
		print("[BakeTextures] Wrote ", out_path)
		baked += 1

	print("[BakeTextures] Done. baked=", baked, " set=", set_id, " out_dir=", out_dir)
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
		push_warning("[BakeTextures] make_dir_recursive failed (%d) for %s" % [err, path])


func _fail(message: String) -> void:
	push_error("[BakeTextures] " + message)
	quit(1)

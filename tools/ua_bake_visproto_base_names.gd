extends SceneTree

const OUT_ROOT := "res://resources/ua/sets"
const SCHEMA_VERSION := 1

const VISPROTO_PATH_PATTERNS := {
	"original": "res://urban_assault_decompiled-master/assets/sets/set%d/scripts/visproto.lst",
	"metropolisDawn": "res://urban_assault_decompiled-master/assets/sets/set%d_xp/scripts/visproto.lst",
}


func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var game_data_type := _string_arg(args, "--game_data_type", "original")
	if game_data_type.is_empty():
		game_data_type = "original"
	game_data_type = "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"

	var src_path := _visproto_path_for_set(set_id, game_data_type)
	if src_path.is_empty() or not FileAccess.file_exists(src_path):
		_fail("visproto.lst not found for set=%d type=%s at %s" % [set_id, game_data_type, src_path])
		return

	var set_dir := "%s/set%d%s" % [OUT_ROOT, maxi(set_id, 1), ("_xp" if game_data_type == "metropolisDawn" else "")]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)

	var out_path := "%s/visproto_base_names.json" % metadata_dir
	var base_names := _parse_visproto_base_names(src_path)
	var registry := {
		"schema_version": SCHEMA_VERSION,
		"set_id": maxi(set_id, 1),
		"game_data_type": game_data_type,
		"base_names": base_names,
	}
	_save_json(out_path, registry)
	print("[BakeVisproto] Wrote ", out_path, " entries=", base_names.size())
	quit(0)


func _visproto_path_for_set(set_id: int, game_data_type: String) -> String:
	var pattern := String(VISPROTO_PATH_PATTERNS.get(game_data_type, VISPROTO_PATH_PATTERNS["original"]))
	return pattern % max(set_id, 1)


func _parse_visproto_base_names(path: String) -> Array:
	var result: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges()
		if line.is_empty():
			continue
		var base := line.get_basename()
		# Bake the dummy filter into the registry as empty strings.
		result.append("" if base.to_lower().begins_with("dummy") else base)
	return result


func _int_arg(args: PackedStringArray, name: String, default_value: int) -> int:
	for arg in args:
		if arg.begins_with(name + "="):
			return int(arg.get_slice("=", 1))
	return default_value


func _string_arg(args: PackedStringArray, name: String, default_value: String) -> String:
	for arg in args:
		if arg.begins_with(name + "="):
			return String(arg.get_slice("=", 1))
	return default_value


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		_fail("DirAccess.open(res://) failed; cannot create output directories.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakeVisproto] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


func _fail(message: String) -> void:
	push_error("[BakeVisproto] " + message)
	quit(1)


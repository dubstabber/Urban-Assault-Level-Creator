extends SceneTree

const OUT_ROOT := "res://resources/ua/sets"
const SCHEMA_VERSION := 1

const SCRIPT_ROOTS := {
	"original": "res://.usor/openua/DATA/SCRIPTS",
	"metropolisDawn": "res://.usor/openua/dataxp/Scripts",
}


func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var game_data_type := _string_arg(args, "--game_data_type", "original")
	if game_data_type.is_empty():
		game_data_type = "original"
	game_data_type = "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"

	var script_paths := _script_paths_for_game_data_type(game_data_type)
	if script_paths.is_empty():
		_fail("No script files found under %s" % _script_root_for_game_data_type(game_data_type))
		return

	var vehicles := _merge_vehicle_visual_entries(script_paths)
	var set_dir := "%s/set%d%s" % [OUT_ROOT, maxi(set_id, 1), ("_xp" if game_data_type == "metropolisDawn" else "")]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)
	var out_path := "%s/vehicle_visuals.json" % metadata_dir

	var registry := {
		"schema_version": SCHEMA_VERSION,
		"set_id": maxi(set_id, 1),
		"game_data_type": game_data_type,
		"vehicles": vehicles,
	}
	_save_json(out_path, registry)
	print("[BakeVehicleVisuals] Wrote ", out_path, " vehicles=", vehicles.size())
	quit(0)


func _script_root_for_game_data_type(game_data_type: String) -> String:
	return String(SCRIPT_ROOTS.get(game_data_type, SCRIPT_ROOTS["original"]))


func _script_paths_for_game_data_type(game_data_type: String) -> Array:
	var script_root := _script_root_for_game_data_type(game_data_type)
	var result: Array = []
	var dir := DirAccess.open(script_root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "scr":
			result.append("%s/%s" % [script_root, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func _script_assignment_text(raw_line: String, prefix: String) -> String:
	var equals_index := raw_line.find("=")
	if equals_index >= 0:
		return raw_line.substr(equals_index + 1).strip_edges()
	return raw_line.replacen(prefix, "").strip_edges()


func _append_vehicle_visual_entry(result: Dictionary, vehicle_id: int, entry: Dictionary) -> void:
	if vehicle_id < 0:
		return
	var slots_value = entry.get("slots", {})
	if typeof(slots_value) != TYPE_DICTIONARY:
		return
	var slots := slots_value as Dictionary
	if not slots.has("wait") and not slots.has("normal"):
		return
	result[vehicle_id] = entry.duplicate(true)


func _parse_vehicle_visual_entries(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return result
	var current_vehicle_id := -1
	var current_entry: Dictionary = {}
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_vehicle"):
			_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
			var vehicle_text := line.replacen("new_vehicle", "").strip_edges()
			current_vehicle_id = int(vehicle_text)
			current_entry = {"model": "", "slots": {}}
			continue
		if line == "end":
			_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
			current_vehicle_id = -1
			current_entry = {}
			continue
		if current_vehicle_id < 0:
			continue
		if line.begins_with("model"):
			current_entry["model"] = _script_assignment_text(line, "model")
			continue
		if line.begins_with("vp_wait") or line.begins_with("vp_normal"):
			var slot_name := "wait" if line.begins_with("vp_wait") else "normal"
			var slot_prefix := "vp_wait" if slot_name == "wait" else "vp_normal"
			var vp_text := line.replacen(slot_prefix, "").replacen("=", "").strip_edges()
			if not vp_text.is_empty():
				var slots: Dictionary = current_entry.get("slots", {})
				slots[slot_name] = int(vp_text)
				current_entry["slots"] = slots
	_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
	return result


func _merge_vehicle_visual_entries(script_paths: Array) -> Dictionary:
	var merged := {}
	for script_path in script_paths:
		var parsed: Dictionary = _parse_vehicle_visual_entries(String(script_path))
		for vehicle_id in parsed.keys():
			# Keep the first definition encountered per id (script_paths are sorted).
			if merged.has(int(vehicle_id)):
				continue
			var entry_value = parsed[vehicle_id]
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			merged[int(vehicle_id)] = Dictionary(entry_value).duplicate(true)
	return merged


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
		push_warning("[BakeVehicleVisuals] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


func _fail(message: String) -> void:
	push_error("[BakeVehicleVisuals] " + message)
	quit(1)


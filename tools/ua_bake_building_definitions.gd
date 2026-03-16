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

	var definitions := _merge_building_definitions(script_paths)
	var set_dir := "%s/set%d%s" % [OUT_ROOT, maxi(set_id, 1), ("_xp" if game_data_type == "metropolisDawn" else "")]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)
	var out_path := "%s/building_definitions.json" % metadata_dir

	var registry := {
		"schema_version": SCHEMA_VERSION,
		"set_id": maxi(set_id, 1),
		"game_data_type": game_data_type,
		"definitions": definitions,
	}
	_save_json(out_path, registry)
	print("[BakeBuildingDefinitions] Wrote ", out_path, " definitions=", definitions.size())
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


func _empty_building_attachment() -> Dictionary:
	return {
		"act": -1,
		"vehicle_id": -1,
		"ua_offset": {"x": 0.0, "y": 0.0, "z": 0.0},
		"ua_direction": {"x": 0.0, "y": 0.0, "z": 0.0},
	}


func _append_building_attachment(target_building: Dictionary, attachment: Dictionary) -> void:
	if target_building.is_empty() or attachment.is_empty():
		return
	var attachments_value = target_building.get("attachments", [])
	if typeof(attachments_value) != TYPE_ARRAY:
		attachments_value = []
	var attachments := attachments_value as Array
	attachments.append(attachment.duplicate(true))
	target_building["attachments"] = attachments


func _append_building_definition(result: Array, building: Dictionary) -> void:
	if building.is_empty():
		return
	if int(building.get("building_id", -1)) < 0 or int(building.get("sec_type", -1)) < 0:
		return
	result.append(building.duplicate(true))


func _parse_building_definitions(script_path: String) -> Array:
	var result: Array = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return result
	var current_building := {}
	var current_attachment := {}
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_building"):
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {
				"building_id": int(_script_assignment_text(line, "new_building")),
				"sec_type": -1,
				"attachments": [],
			}
			current_attachment = {}
			continue
		if line == "end":
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {}
			current_attachment = {}
			continue
		if current_building.is_empty():
			continue
		if line.begins_with("sec_type"):
			current_building["sec_type"] = int(_script_assignment_text(line, "sec_type"))
		elif line.begins_with("sbact_act"):
			_append_building_attachment(current_building, current_attachment)
			current_attachment = _empty_building_attachment()
			current_attachment["act"] = int(_script_assignment_text(line, "sbact_act"))
		elif line.begins_with("sbact_vehicle"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["vehicle_id"] = int(_script_assignment_text(line, "sbact_vehicle"))
		elif line.begins_with("sbact_pos_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset := Dictionary(current_attachment.get("ua_offset", {}))
			ua_offset["x"] = float(_script_assignment_text(line, "sbact_pos_x"))
			current_attachment["ua_offset"] = ua_offset
		elif line.begins_with("sbact_pos_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset := Dictionary(current_attachment.get("ua_offset", {}))
			ua_offset["y"] = float(_script_assignment_text(line, "sbact_pos_y"))
			current_attachment["ua_offset"] = ua_offset
		elif line.begins_with("sbact_pos_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset := Dictionary(current_attachment.get("ua_offset", {}))
			ua_offset["z"] = float(_script_assignment_text(line, "sbact_pos_z"))
			current_attachment["ua_offset"] = ua_offset
		elif line.begins_with("sbact_dir_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction := Dictionary(current_attachment.get("ua_direction", {}))
			ua_direction["x"] = float(_script_assignment_text(line, "sbact_dir_x"))
			current_attachment["ua_direction"] = ua_direction
		elif line.begins_with("sbact_dir_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction := Dictionary(current_attachment.get("ua_direction", {}))
			ua_direction["y"] = float(_script_assignment_text(line, "sbact_dir_y"))
			current_attachment["ua_direction"] = ua_direction
		elif line.begins_with("sbact_dir_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction := Dictionary(current_attachment.get("ua_direction", {}))
			ua_direction["z"] = float(_script_assignment_text(line, "sbact_dir_z"))
			current_attachment["ua_direction"] = ua_direction
	_append_building_attachment(current_building, current_attachment)
	_append_building_definition(result, current_building)
	return result


func _merge_building_definitions(script_paths: Array) -> Array:
	var result: Array = []
	for script_path in script_paths:
		result.append_array(_parse_building_definitions(String(script_path)))
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
		push_warning("[BakeBuildingDefinitions] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


func _fail(message: String) -> void:
	push_error("[BakeBuildingDefinitions] " + message)
	quit(1)


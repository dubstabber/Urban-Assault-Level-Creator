extends RefCounted

const Parser := preload("res://map/map_3d_legacy_script_parser.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


func _write_temp_script(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open temp script for writing: %s" % path)
		_errors.append("Failed to open temp script for writing: %s" % path)
		return false
	file.store_string(content)
	file.close()
	return true


func test_parse_building_definitions_extracts_attachment_vectors() -> bool:
	_reset_errors()
	var path := "user://temp_building_parser.scr"
	var content := """
new_building = 12
sec_type = 34
sbact_act = 2
sbact_vehicle = 77
sbact_pos_x = 10
sbact_pos_y = -20
sbact_pos_z = 30
sbact_dir_x = 0
sbact_dir_y = 1
sbact_dir_z = -1
end
"""
	if not _write_temp_script(path, content):
		return false
	var definitions := Parser.parse_building_definitions(path)
	_check_eq(definitions.size(), 1, "Expected one parsed building definition")
	if definitions.size() == 1:
		var definition := definitions[0] as Dictionary
		_check_eq(int(definition.get("building_id", -1)), 12, "Expected building id to parse")
		_check_eq(int(definition.get("sec_type", -1)), 34, "Expected sec_type to parse")
		var attachments: Array = definition.get("attachments", [])
		_check_eq(attachments.size(), 1, "Expected one attachment to parse")
		if attachments.size() == 1:
			var attachment := attachments[0] as Dictionary
			_check_eq(int(attachment.get("act", -1)), 2, "Expected attachment act to parse")
			_check_eq(int(attachment.get("vehicle_id", -1)), 77, "Expected attachment vehicle id to parse")
			_check_eq(attachment.get("ua_offset", Vector3.ZERO), Vector3(10.0, -20.0, 30.0), "Expected attachment ua_offset to parse")
			_check_eq(attachment.get("ua_direction", Vector3.ZERO), Vector3(0.0, 1.0, -1.0), "Expected attachment ua_direction to parse")
	return _errors.is_empty()


func test_parse_vehicle_visual_entries_groups_models_per_vehicle() -> bool:
	_reset_errors()
	var path := "user://temp_vehicle_entries_parser.scr"
	var content := """
new_vehicle = 5
model = tank
vp_wait = 3
vp_normal = 4
model = heli
vp_wait = 8
end
"""
	if not _write_temp_script(path, content):
		return false
	var entries := Parser.parse_vehicle_visual_entries(path)
	_check(entries.has(5), "Expected vehicle entries to contain vehicle 5")
	if entries.has(5):
		var vehicle_entries: Array = entries[5]
		_check_eq(vehicle_entries.size(), 2, "Expected two model entries for vehicle 5")
		if vehicle_entries.size() == 2:
			var first := vehicle_entries[0] as Dictionary
			var second := vehicle_entries[1] as Dictionary
			_check_eq(String(first.get("model", "")), "tank", "Expected first model to parse")
			_check_eq(int(first.get("wait", -1)), 3, "Expected first wait visual to parse")
			_check_eq(int(first.get("normal", -1)), 4, "Expected first normal visual to parse")
			_check_eq(String(second.get("model", "")), "heli", "Expected second model to parse")
			_check_eq(int(second.get("wait", -1)), 8, "Expected second wait visual to parse")
	return _errors.is_empty()


func test_parse_vehicle_visual_pairs_tracks_wait_and_normal_slots() -> bool:
	_reset_errors()
	var path := "user://temp_vehicle_pairs_parser.scr"
	var content := """
new_vehicle = 9
vp_wait = 7
vp_normal = 11
end
new_vehicle = 12
vp_wait = 1
end
"""
	if not _write_temp_script(path, content):
		return false
	var pairs := Parser.parse_vehicle_visual_pairs(path)
	_check(pairs.has(9), "Expected vehicle pairs to contain vehicle 9")
	_check(pairs.has(12), "Expected vehicle pairs to contain vehicle 12")
	if pairs.has(9):
		var vehicle_nine := pairs[9] as Dictionary
		_check_eq(int(vehicle_nine.get("wait", -1)), 7, "Expected wait slot for vehicle 9")
		_check_eq(int(vehicle_nine.get("normal", -1)), 11, "Expected normal slot for vehicle 9")
	if pairs.has(12):
		var vehicle_twelve := pairs[12] as Dictionary
		_check_eq(int(vehicle_twelve.get("wait", -1)), 1, "Expected wait slot for vehicle 12")
		_check(not vehicle_twelve.has("normal"), "Expected missing normal slot to stay absent")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_parse_building_definitions_extracts_attachment_vectors",
		"test_parse_vehicle_visual_entries_groups_models_per_vehicle",
		"test_parse_vehicle_visual_pairs_tracks_wait_and_normal_slots",
	]
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	print("__FAILURES:%d__" % failures)
	return failures

extends RefCounted
class_name Map3DLegacyScriptParser

const _UALegacyText = preload("res://map/ua_legacy_text.gd")
const _ResDir = preload("res://scripts/res_dir.gd")

static func script_assignment_text(raw_line: String, prefix: String) -> String:
	var equals_index := raw_line.find("=")
	if equals_index >= 0:
		return raw_line.substr(equals_index + 1).strip_edges()
	return raw_line.replacen(prefix, "").strip_edges()

static func _vector3_from_variant(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return Vector3(value)
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var dict := Dictionary(value)
	return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))

static func _empty_building_attachment() -> Dictionary:
	return {
		"act": -1,
		"vehicle_id": -1,
		"ua_offset": Vector3.ZERO,
		"ua_direction": Vector3.ZERO,
	}

static func _append_building_attachment(target_building: Dictionary, attachment: Dictionary) -> void:
	if target_building.is_empty() or attachment.is_empty():
		return
	var attachments: Array = target_building.get("attachments", [])
	attachments.append(attachment.duplicate(true))
	target_building["attachments"] = attachments

static func _append_building_definition(result: Array, building: Dictionary) -> void:
	if building.is_empty():
		return
	if int(building.get("building_id", -1)) < 0 or int(building.get("sec_type", -1)) < 0:
		return
	result.append(building.duplicate(true))

static func _append_vehicle_visual_entry(result: Dictionary, vehicle_id: int, entry: Dictionary) -> void:
	if vehicle_id < 0:
		return
	if not entry.has("wait") and not entry.has("normal"):
		return
	var entries: Array = result.get(vehicle_id, [])
	entries.append(entry.duplicate(true))
	result[vehicle_id] = entries

static func parse_building_definitions(script_path: String) -> Array:
	var result: Array = []
	if script_path.is_empty() or not _ResDir.file_exists(script_path):
		return result
	var full := _UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_building := {}
	var current_attachment := {}
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_building"):
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {
				"building_id": int(script_assignment_text(line, "new_building")),
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
			current_building["sec_type"] = int(script_assignment_text(line, "sec_type"))
		elif line.begins_with("sbact_act"):
			_append_building_attachment(current_building, current_attachment)
			current_attachment = _empty_building_attachment()
			current_attachment["act"] = int(script_assignment_text(line, "sbact_act"))
		elif line.begins_with("sbact_vehicle"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["vehicle_id"] = int(script_assignment_text(line, "sbact_vehicle"))
		elif line.begins_with("sbact_pos_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_x := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_x.x = float(script_assignment_text(line, "sbact_pos_x"))
			current_attachment["ua_offset"] = ua_offset_x
		elif line.begins_with("sbact_pos_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_y := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_y.y = float(script_assignment_text(line, "sbact_pos_y"))
			current_attachment["ua_offset"] = ua_offset_y
		elif line.begins_with("sbact_pos_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_z := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_z.z = float(script_assignment_text(line, "sbact_pos_z"))
			current_attachment["ua_offset"] = ua_offset_z
		elif line.begins_with("sbact_dir_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_x := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_x.x = float(script_assignment_text(line, "sbact_dir_x"))
			current_attachment["ua_direction"] = ua_direction_x
		elif line.begins_with("sbact_dir_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_y := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_y.y = float(script_assignment_text(line, "sbact_dir_y"))
			current_attachment["ua_direction"] = ua_direction_y
		elif line.begins_with("sbact_dir_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_z := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_z.z = float(script_assignment_text(line, "sbact_dir_z"))
			current_attachment["ua_direction"] = ua_direction_z
	_append_building_attachment(current_building, current_attachment)
	_append_building_definition(result, current_building)
	return result

static func parse_vehicle_visual_entries(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not _ResDir.file_exists(script_path):
		return result
	var full := _UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_vehicle_id := -1
	var current_entries: Array = []
	var current_entry := {}
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_vehicle"):
			if current_vehicle_id >= 0 and not current_entries.is_empty():
				result[current_vehicle_id] = current_entries.duplicate(true)
			current_vehicle_id = int(script_assignment_text(line, "new_vehicle"))
			current_entries = []
			current_entry = {}
			continue
		if line == "end":
			if not current_entry.is_empty():
				current_entries.append(current_entry.duplicate(true))
			if current_vehicle_id >= 0 and not current_entries.is_empty():
				result[current_vehicle_id] = current_entries.duplicate(true)
			current_vehicle_id = -1
			current_entries = []
			current_entry = {}
			continue
		if current_vehicle_id < 0:
			continue
		if line.begins_with("vp_wait"):
			current_entry["wait"] = int(script_assignment_text(line, "vp_wait"))
		elif line.begins_with("vp_normal"):
			current_entry["normal"] = int(script_assignment_text(line, "vp_normal"))
		elif line.begins_with("model"):
			if not current_entry.is_empty():
				current_entries.append(current_entry.duplicate(true))
			current_entry = {"model": script_assignment_text(line, "model")}
	if not current_entry.is_empty():
		current_entries.append(current_entry.duplicate(true))
	if current_vehicle_id >= 0 and not current_entries.is_empty():
		result[current_vehicle_id] = current_entries.duplicate(true)
	return result

static func parse_vehicle_visual_pairs(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not _ResDir.file_exists(script_path):
		return result
	var full := _UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_vehicle_id := -1
	var current_visuals := {}
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_vehicle"):
			if current_vehicle_id >= 0 and not current_visuals.is_empty():
				result[current_vehicle_id] = current_visuals.duplicate(true)
			current_vehicle_id = int(script_assignment_text(line, "new_vehicle"))
			current_visuals = {}
			continue
		if line == "end":
			if current_vehicle_id >= 0 and not current_visuals.is_empty():
				result[current_vehicle_id] = current_visuals.duplicate(true)
			current_vehicle_id = -1
			current_visuals = {}
			continue
		if current_vehicle_id < 0:
			continue
		if line.begins_with("vp_wait"):
			current_visuals["wait"] = int(script_assignment_text(line, "vp_wait"))
		elif line.begins_with("vp_normal"):
			current_visuals["normal"] = int(script_assignment_text(line, "vp_normal"))
	if current_vehicle_id >= 0 and not current_visuals.is_empty():
		result[current_vehicle_id] = current_visuals.duplicate(true)
	return result

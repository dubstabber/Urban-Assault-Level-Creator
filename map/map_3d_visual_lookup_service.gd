extends RefCounted
class_name Map3DVisualLookupService

const _UAProjectDataRoots = preload("res://map/ua_project_data_roots.gd")
const _UALegacyText = preload("res://map/ua_legacy_text.gd")
const HOST_STATION_BASE_NAMES := {
	56: "VP_ROBO",
	57: "VP_KROBO",
	58: "VP_BRGRO",
	59: "VP_GIGNT",
	60: "VP_TAERO",
	61: "VP_SULG1",
	62: "VP_BSECT",
	132: "VP_TRAIN",
	176: "VP_GIGNT",
	177: "VP_KROBO",
	178: "VP_TAERO",
}
const HOST_STATION_VISIBLE_GUN_BASE_NAMES := {
	90: "VP_MFLAK",
	91: "VP_MFLAK",
	92: "VP_MFLAK",
	93: "VP_FLAK2",
	94: "VP_FLAK2",
	95: "VP_FLAK2",
}
const HOST_STATION_GUN_ATTACHMENTS := {
	56: [
		{"gun_type": 90, "ua_offset": Vector3(0.0, -200.0, 55.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 91, "ua_offset": Vector3(0.0, -180.0, -80.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
	57: [
		{"gun_type": 93, "ua_offset": Vector3(0.0, -250.0, 70.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -230.0, -100.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
	58: [
		{"gun_type": 90, "ua_offset": Vector3(0.0, -180.0, 50.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
	],
	59: [
		{"gun_type": 93, "ua_offset": Vector3(0.0, -320.0, 80.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -300.0, -120.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
	176: [
		{"gun_type": 93, "ua_offset": Vector3(0.0, -320.0, 80.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -300.0, -120.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
	177: [
		{"gun_type": 93, "ua_offset": Vector3(0.0, -250.0, 70.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -230.0, -100.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
}
const TECH_UPGRADE_EDITOR_TYP_OVERRIDES := {
	4: 100,
	7: 73,
	15: 104,
	16: 103,
	50: 102,
	51: 101,
	60: 106,
	61: 113,
	65: 110,
}
const MD_SQUAD_DIRECT_BASE_NAMES := {
	# MD-only squads not present as `new_vehicle` entries in bundled/shared SCR scripts.
	# Use XPACK-specific visproto base names from set*_xp payloads.
	143: "VP_TODIN", # Thor's Hammer
	144: "VP_TKATJ", # Ostwind
	145: "VP_MMYKO", # Crusher
}
const MD_SQUAD_VEHICLE_ALIASES := {
	# Some MD-only units are absent from shared SCR `new_vehicle` mappings.
	# Alias them to close visual equivalents so they still render in 3D preview.
	143: 32, # Thor's Hammer -> Eisenhans
	144: 37, # Ostwind -> Leonid
	145: 64, # Crusher -> X01 Quadda
}
const MD_BUILDING_DEFINITION_ALIASES := {
	# Metropolis Dawn includes building IDs that share BUILD.SCR definitions
	# with legacy IDs (same typ_map/icon role) but do not have their own
	# `new_building` blocks in shared scripts.
	74: 31, # Taerkasten flak station variant -> TAERFLAK definition
}
const UA_DATA_JSON = preload("res://resources/UAdata.json")

static var _squad_vehicle_visuals_cache: Dictionary = {}
static var _squad_visproto_base_name_cache: Dictionary = {}
static var _vehicle_visual_entries_cache: Dictionary = {}
static var _blg_typ_override_cache: Dictionary = {}
static var _building_definitions_cache: Dictionary = {}
static var _building_sec_type_override_cache: Dictionary = {}


static func _clear_runtime_lookup_caches_for_tests() -> void:
	_squad_vehicle_visuals_cache.clear()
	_squad_visproto_base_name_cache.clear()
	_vehicle_visual_entries_cache.clear()
	_blg_typ_override_cache.clear()
	_building_definitions_cache.clear()
	_building_sec_type_override_cache.clear()


static func _host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return String(HOST_STATION_BASE_NAMES.get(vehicle_id, ""))


static func _host_station_gun_base_name_for_type(gun_type: int) -> String:
	return String(HOST_STATION_VISIBLE_GUN_BASE_NAMES.get(gun_type, ""))


static func _host_station_gun_attachments_for_vehicle(vehicle_id: int) -> Array:
	return Array(HOST_STATION_GUN_ATTACHMENTS.get(vehicle_id, []))


static func _normalized_game_data_type(game_data_type: String) -> String:
	return "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"


static func _source_set_dir_for_set(set_id: int, game_data_type: String) -> String:
	return _UAProjectDataRoots.first_existing_set_directory(set_id, game_data_type)


static func _first_existing_file(candidates: Array) -> String:
	for candidate_value in candidates:
		var candidate := String(candidate_value)
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			return candidate
	return String(candidates[0]) if not candidates.is_empty() else ""


static func _script_root_for_game_data_type(set_id_or_game_data_type = 1, game_data_type: String = "original") -> String:
	var resolved_set_id := 1
	var resolved_game_data_type := game_data_type
	if typeof(set_id_or_game_data_type) == TYPE_STRING:
		resolved_game_data_type = String(set_id_or_game_data_type)
	else:
		resolved_set_id = int(set_id_or_game_data_type)
	var shared_root := _UAProjectDataRoots.shared_script_root_for_game_data_type(resolved_game_data_type)
	var candidates: Array = []
	if not shared_root.is_empty():
		candidates.append(shared_root)
	candidates.append("%s/script_sources" % _source_set_dir_for_set(resolved_set_id, resolved_game_data_type))
	candidates.append("%s/scripts" % _source_set_dir_for_set(resolved_set_id, resolved_game_data_type))
	for candidate_value in candidates:
		var candidate := String(candidate_value)
		if not candidate.is_empty() and DirAccess.dir_exists_absolute(candidate):
			return candidate
	return String(candidates[0]) if not candidates.is_empty() else ""


static func _visproto_path_for_set(set_id: int, game_data_type: String) -> String:
	var set_dir := _source_set_dir_for_set(set_id, game_data_type)
	return _first_existing_file([
		"%s/lookup/visproto.lst" % set_dir,
		"%s/script_sources/visproto.lst" % set_dir,
		"%s/scripts/visproto.lst" % set_dir,
		"%s/lookup/VISPROTO.LST" % set_dir,
		"%s/script_sources/VISPROTO.LST" % set_dir,
		"%s/scripts/VISPROTO.LST" % set_dir,
	])


static func _metadata_file_candidates(set_id: int, game_data_type: String, metadata_filename: String) -> Array[String]:
	var filename := metadata_filename.strip_edges().trim_prefix("/")
	if filename.is_empty():
		return []
	var normalized_game_data_type := _UAProjectDataRoots.normalized_game_data_type(game_data_type)
	var sid := maxi(set_id, 1)
	var relative_path := "metadata/%s" % filename
	var out: Array[String] = []
	var seen := {}
	var primary := _UAProjectDataRoots.first_existing_path_under_set_roots(sid, normalized_game_data_type, relative_path)
	if not primary.is_empty():
		out.append(primary)
		seen[primary] = true
	var legacy_root := "res://resources/ua/sets"
	var xp_suffix := "_xp" if normalized_game_data_type == "metropolisDawn" else ""
	var legacy_candidates: Array[String] = [
		"%s/set%d%s/%s" % [legacy_root, sid, xp_suffix, relative_path],
	]
	if normalized_game_data_type == "metropolisDawn":
		legacy_candidates.append("%s/set%d/%s" % [legacy_root, sid, relative_path])
	for candidate in legacy_candidates:
		if seen.has(candidate):
			continue
		if FileAccess.file_exists(candidate):
			out.append(candidate)
			seen[candidate] = true
	return out


static func _metadata_json_dictionary(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var txt: String = _UALegacyText.read_file(path)
	if txt.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func _metadata_visproto_base_names_for_set(set_id: int, game_data_type: String) -> Array:
	for meta_path in _metadata_file_candidates(set_id, game_data_type, "visproto_base_names.json"):
		var parsed := _metadata_json_dictionary(String(meta_path))
		if parsed.has("base_names") and typeof(parsed["base_names"]) == TYPE_ARRAY:
			return Array(parsed["base_names"]).duplicate(true)
	return []


static func _metadata_vehicle_visual_entries_for_set(set_id: int, game_data_type: String) -> Dictionary:
	var out := {}
	for meta_path in _metadata_file_candidates(set_id, game_data_type, "vehicle_visuals.json"):
		var parsed := _metadata_json_dictionary(String(meta_path))
		if not parsed.has("vehicles") or typeof(parsed["vehicles"]) != TYPE_DICTIONARY:
			continue
		var vehicles: Dictionary = parsed["vehicles"]
		for vid_key in vehicles.keys():
			var vid := int(vid_key)
			if out.has(vid):
				continue
			var info_variant: Variant = vehicles[vid_key]
			if typeof(info_variant) != TYPE_DICTIONARY:
				continue
			var info: Dictionary = info_variant
			var model := String(info.get("model", ""))
			var slots_variant: Variant = info.get("slots", {})
			if typeof(slots_variant) != TYPE_DICTIONARY:
				continue
			var slots: Dictionary = slots_variant
			var entry: Dictionary = {"model": model}
			if slots.has("wait"):
				entry["wait"] = int(slots.get("wait", 0))
			if slots.has("normal"):
				entry["normal"] = int(slots.get("normal", 0))
			out[vid] = [entry]
	return out


static func _metadata_squad_vehicle_visuals_for_set(set_id: int, game_data_type: String) -> Dictionary:
	var metadata_entries := _metadata_vehicle_visual_entries_for_set(set_id, game_data_type)
	var out := {}
	for vehicle_id in metadata_entries.keys():
		var entries := Array(metadata_entries[vehicle_id])
		if entries.is_empty():
			continue
		var first_entry_variant: Variant = entries[0]
		if typeof(first_entry_variant) != TYPE_DICTIONARY:
			continue
		var first_entry := first_entry_variant as Dictionary
		var slots := {}
		if first_entry.has("wait"):
			slots["wait"] = int(first_entry["wait"])
		if first_entry.has("normal"):
			slots["normal"] = int(first_entry["normal"])
		if slots.is_empty():
			continue
		out[int(vehicle_id)] = slots
	return out


static func _append_unique_building_definitions(target: Array, incoming: Array) -> void:
	var seen_keys := {}
	for definition_value in target:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var building_id := int(definition.get("building_id", -1))
		var sec_type := int(definition.get("sec_type", -1))
		if building_id < 0 or sec_type < 0:
			continue
		seen_keys["%d:%d" % [building_id, sec_type]] = true
	for definition_value in incoming:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var building_id := int(definition.get("building_id", -1))
		var sec_type := int(definition.get("sec_type", -1))
		if building_id < 0 or sec_type < 0:
			continue
		var key := "%d:%d" % [building_id, sec_type]
		if seen_keys.has(key):
			continue
		target.append(definition.duplicate(true))
		seen_keys[key] = true


static func _metadata_building_definitions_for_set(set_id: int, game_data_type: String) -> Array:
	var out: Array = []
	for meta_path in _metadata_file_candidates(set_id, game_data_type, "building_definitions.json"):
		var parsed := _metadata_json_dictionary(String(meta_path))
		if not parsed.has("definitions") or typeof(parsed["definitions"]) != TYPE_ARRAY:
			continue
		_append_unique_building_definitions(out, Array(parsed["definitions"]))
	return out


static func _script_paths_for_game_data_type(set_id: int, game_data_type: String) -> Array:
	var script_root := _script_root_for_game_data_type(set_id, game_data_type)
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


static func _append_blg_typ_entries_from_building_list(target: Dictionary, buildings_value: Variant) -> void:
	if not (buildings_value is Array):
		return
	for entry in buildings_value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var building := entry as Dictionary
		var building_id := int(building.get("id", -1))
		var typ_map := int(building.get("typ_map", -1))
		if building_id >= 0 and typ_map >= 0:
			target[building_id] = typ_map


static func _blg_typ_overrides_for_game_data_type(game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if _blg_typ_override_cache.has(normalized_game_data_type):
		return _blg_typ_override_cache[normalized_game_data_type]
	var result := {}
	if UA_DATA_JSON == null or typeof(UA_DATA_JSON.data) != TYPE_DICTIONARY:
		_blg_typ_override_cache[normalized_game_data_type] = result
		return result
	var root_data: Dictionary = UA_DATA_JSON.data
	if not root_data.has(normalized_game_data_type):
		_blg_typ_override_cache[normalized_game_data_type] = result
		return result
	var game_data: Dictionary = root_data[normalized_game_data_type]
	var hoststations_value = game_data.get("hoststations", {})
	if typeof(hoststations_value) == TYPE_DICTIONARY:
		for station_name in hoststations_value.keys():
			var station_value = hoststations_value[station_name]
			if typeof(station_value) != TYPE_DICTIONARY:
				continue
			_append_blg_typ_entries_from_building_list(result, Dictionary(station_value).get("buildings", []))
	var other_value = game_data.get("other", {})
	if typeof(other_value) == TYPE_DICTIONARY:
		_append_blg_typ_entries_from_building_list(result, Dictionary(other_value).get("buildings", []))
	_blg_typ_override_cache[normalized_game_data_type] = result
	return result


static func _visproto_base_names_for_set(set_id: int, game_data_type: String) -> Array:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	if _squad_visproto_base_name_cache.has(cache_key):
		return _squad_visproto_base_name_cache[cache_key]
	var metadata_base_names := _metadata_visproto_base_names_for_set(set_id, normalized_game_data_type)
	if not metadata_base_names.is_empty():
		_squad_visproto_base_name_cache[cache_key] = metadata_base_names
		return _squad_visproto_base_name_cache[cache_key]

	var result: Array = []
	var visproto_path := _visproto_path_for_set(set_id, normalized_game_data_type)
	if FileAccess.file_exists(visproto_path):
		var full := _UALegacyText.read_file(visproto_path)
		for line_raw in full.split("\n"):
			var line := line_raw.get_slice(";", 0).strip_edges()
			if line.is_empty():
				continue
			result.append(line.get_basename())
	_squad_visproto_base_name_cache[cache_key] = result
	return result


static func _base_name_from_visproto_index(visproto_base_names: Array, visual_index: int) -> String:
	if visual_index < 0 or visual_index >= visproto_base_names.size():
		return ""
	var base_name := String(visproto_base_names[visual_index])
	if base_name.is_empty():
		return ""
	if base_name.to_lower().begins_with("dummy"):
		return ""
	return base_name


static func _preferred_squad_visual_base_name(vehicle_visuals: Dictionary, visproto_base_names: Array) -> String:
	for slot_name in ["wait", "normal"]:
		if not vehicle_visuals.has(slot_name):
			continue
		var base_name := _base_name_from_visproto_index(visproto_base_names, int(vehicle_visuals[slot_name]))
		if not base_name.is_empty():
			return base_name
	return ""


static func _parse_vehicle_visual_pairs(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
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
			current_vehicle_id = int(_script_assignment_text(line, "new_vehicle"))
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
			current_visuals["wait"] = int(_script_assignment_text(line, "vp_wait"))
		elif line.begins_with("vp_normal"):
			current_visuals["normal"] = int(_script_assignment_text(line, "vp_normal"))
	if current_vehicle_id >= 0 and not current_visuals.is_empty():
		result[current_vehicle_id] = current_visuals.duplicate(true)
	return result


static func _parse_vehicle_visual_entries(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
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
			current_vehicle_id = int(_script_assignment_text(line, "new_vehicle"))
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
			current_entry["wait"] = int(_script_assignment_text(line, "vp_wait"))
		elif line.begins_with("vp_normal"):
			current_entry["normal"] = int(_script_assignment_text(line, "vp_normal"))
		elif line.begins_with("model"):
			if not current_entry.is_empty():
				current_entries.append(current_entry.duplicate(true))
			current_entry = {"model": _script_assignment_text(line, "model")}
	if not current_entry.is_empty():
		current_entries.append(current_entry.duplicate(true))
	if current_vehicle_id >= 0 and not current_entries.is_empty():
		result[current_vehicle_id] = current_entries.duplicate(true)
	return result


static func _script_assignment_text(raw_line: String, prefix: String) -> String:
	var equals_index := raw_line.find("=")
	if equals_index >= 0:
		return raw_line.substr(equals_index + 1).strip_edges()
	return raw_line.replacen(prefix, "").strip_edges()


static func _squad_vehicle_visuals_for_game_data_type(set_id: int, game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	if _squad_vehicle_visuals_cache.has(cache_key):
		return _squad_vehicle_visuals_cache[cache_key]
	var merged := {}
	for script_path in _script_paths_for_game_data_type(set_id, normalized_game_data_type):
		var parsed: Dictionary = _parse_vehicle_visual_pairs(String(script_path))
		for vehicle_id in parsed.keys():
			merged[int(vehicle_id)] = Dictionary(parsed[vehicle_id]).duplicate(true)
	var metadata_visuals := _metadata_squad_vehicle_visuals_for_set(set_id, normalized_game_data_type)
	for vehicle_id in metadata_visuals.keys():
		if merged.has(vehicle_id):
			continue
		merged[int(vehicle_id)] = Dictionary(metadata_visuals[vehicle_id]).duplicate(true)
	_squad_vehicle_visuals_cache[cache_key] = merged
	return merged


static func _vehicle_visual_entries_for_game_data_type(set_id: int, game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	if _vehicle_visual_entries_cache.has(cache_key):
		return _vehicle_visual_entries_cache[cache_key]

	var merged := {}
	for script_path in _script_paths_for_game_data_type(set_id, normalized_game_data_type):
		var parsed: Dictionary = _parse_vehicle_visual_entries(String(script_path))
		for vehicle_id in parsed.keys():
			var vid := int(vehicle_id)
			var incoming: Array = Array(parsed[vehicle_id]).duplicate(true)
			if merged.has(vid):
				var existing: Array = merged[vid]
				if typeof(existing) != TYPE_ARRAY:
					existing = []
				# Preserve deterministic ordering across multiple SCR sources.
				existing.append_array(incoming)
				merged[vid] = existing
			else:
				merged[vid] = incoming
	var metadata_entries := _metadata_vehicle_visual_entries_for_set(set_id, normalized_game_data_type)
	for vehicle_id in metadata_entries.keys():
		if merged.has(vehicle_id):
			continue
		merged[int(vehicle_id)] = Array(metadata_entries[vehicle_id]).duplicate(true)
	_vehicle_visual_entries_cache[cache_key] = merged
	return merged


static func _squad_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if normalized_game_data_type == "metropolisDawn" and MD_SQUAD_DIRECT_BASE_NAMES.has(vehicle_id):
		var direct_base_name := String(MD_SQUAD_DIRECT_BASE_NAMES[vehicle_id])
		var direct_has_source := (not direct_base_name.is_empty()) and UATerrainPieceLibrary.has_piece_source(set_id, direct_base_name)
		if direct_has_source:
			return direct_base_name
	var vehicle_visuals: Dictionary = _squad_vehicle_visuals_for_game_data_type(set_id, game_data_type)
	if not vehicle_visuals.has(vehicle_id):
		if normalized_game_data_type == "metropolisDawn" and MD_SQUAD_VEHICLE_ALIASES.has(vehicle_id):
			var alias_id := int(MD_SQUAD_VEHICLE_ALIASES[vehicle_id])
			if vehicle_visuals.has(alias_id):
				vehicle_id = alias_id
			else:
				return ""
		else:
			return ""
	var visproto_base_names := _visproto_base_names_for_set(set_id, game_data_type)
	var selected_base_name := _preferred_squad_visual_base_name(Dictionary(vehicle_visuals[vehicle_id]), visproto_base_names)
	return selected_base_name


static func _building_attachment_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	var vehicle_entries: Dictionary = _vehicle_visual_entries_for_game_data_type(set_id, game_data_type)
	if not vehicle_entries.has(vehicle_id):
		return _squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)
	var visproto_base_names := _visproto_base_names_for_set(set_id, game_data_type)
	var fallback := ""
	for entry_value in Array(vehicle_entries[vehicle_id]):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var vehicle_visuals := entry_value as Dictionary
		var base_name := _preferred_squad_visual_base_name(vehicle_visuals, visproto_base_names)
		if base_name.is_empty():
			continue
		var model_name := String(vehicle_visuals.get("model", "")).to_lower()
		if model_name != "plane" and model_name != "heli":
			return base_name
		if fallback.is_empty():
			fallback = base_name
	return fallback


static func _empty_building_attachment() -> Dictionary:
	return {
		"act": - 1,
		"vehicle_id": - 1,
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


static func _parse_building_definitions(script_path: String) -> Array:
	var result: Array = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
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
				"building_id": int(_script_assignment_text(line, "new_building")),
				"sec_type": - 1,
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
			current_attachment["ua_offset"].x = float(_script_assignment_text(line, "sbact_pos_x"))
		elif line.begins_with("sbact_pos_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["ua_offset"].y = float(_script_assignment_text(line, "sbact_pos_y"))
		elif line.begins_with("sbact_pos_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["ua_offset"].z = float(_script_assignment_text(line, "sbact_pos_z"))
		elif line.begins_with("sbact_dir_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["ua_direction"].x = float(_script_assignment_text(line, "sbact_dir_x"))
		elif line.begins_with("sbact_dir_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["ua_direction"].y = float(_script_assignment_text(line, "sbact_dir_y"))
		elif line.begins_with("sbact_dir_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["ua_direction"].z = float(_script_assignment_text(line, "sbact_dir_z"))
	_append_building_attachment(current_building, current_attachment)
	_append_building_definition(result, current_building)
	return result


static func _building_definitions_for_game_data_type(set_id: int, game_data_type: String) -> Array:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	if _building_definitions_cache.has(cache_key):
		return _building_definitions_cache[cache_key]
	var result: Array = []
	for script_path in _script_paths_for_game_data_type(set_id, normalized_game_data_type):
		result.append_array(_parse_building_definitions(String(script_path)))
	_append_unique_building_definitions(result, _metadata_building_definitions_for_set(set_id, normalized_game_data_type))
	_building_definitions_cache[cache_key] = result
	return result


static func _building_definition_for_id_and_sec_type(building_id: int, sec_type: int, set_id_or_game_data_type = 1, game_data_type: String = "original") -> Dictionary:
	var resolved_set_id := 1
	var resolved_game_data_type := game_data_type
	if typeof(set_id_or_game_data_type) == TYPE_STRING:
		resolved_game_data_type = String(set_id_or_game_data_type)
	else:
		resolved_set_id = int(set_id_or_game_data_type)
	var definitions := _building_definitions_for_game_data_type(resolved_set_id, resolved_game_data_type)
	for definition_value in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		if int(definition.get("building_id", -1)) != building_id:
			continue
		if int(definition.get("sec_type", -1)) != sec_type:
			continue
		return definition.duplicate(true)
	var normalized_game_data_type := _normalized_game_data_type(resolved_game_data_type)
	if normalized_game_data_type == "metropolisDawn" and MD_BUILDING_DEFINITION_ALIASES.has(building_id):
		var alias_id := int(MD_BUILDING_DEFINITION_ALIASES[building_id])
		for definition_value in definitions:
			if typeof(definition_value) != TYPE_DICTIONARY:
				continue
			var definition := definition_value as Dictionary
			if int(definition.get("building_id", -1)) != alias_id:
				continue
			if int(definition.get("sec_type", -1)) != sec_type:
				continue
			var aliased := definition.duplicate(true)
			aliased["building_id"] = building_id
			return aliased
	return {}


static func _building_sec_type_overrides_from_definitions(definitions: Array) -> Dictionary:
	var result := {}
	var ambiguous_building_ids := {}
	for definition_value in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var building_id := int(definition.get("building_id", -1))
		var sec_type := int(definition.get("sec_type", -1))
		if building_id < 0 or sec_type < 0:
			continue
		if ambiguous_building_ids.has(building_id):
			continue
		if result.has(building_id) and int(result[building_id]) != sec_type:
			result.erase(building_id)
			ambiguous_building_ids[building_id] = true
			continue
		result[building_id] = sec_type
	return result


static func _building_sec_type_overrides_for_script_names(set_id: int, game_data_type: String, script_names: Array[String]) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	for script_name in script_names:
		cache_key += ":%s" % script_name
	if _building_sec_type_override_cache.has(cache_key):
		return _building_sec_type_override_cache[cache_key]
	var result := {}
	var script_root := _script_root_for_game_data_type(set_id, game_data_type)
	for script_name in script_names:
		var script_path := script_root.path_join(script_name)
		var script_overrides := _building_sec_type_overrides_from_definitions(_parse_building_definitions(script_path))
		for building_id in script_overrides.keys():
			if result.has(building_id):
				continue
			result[building_id] = int(script_overrides[building_id])
	_building_sec_type_override_cache[cache_key] = result
	return result


static func _tech_upgrade_typ_overrides_for_3d(set_id: int, game_data_type: String) -> Dictionary:
	var overrides := _building_sec_type_overrides_for_script_names(set_id, game_data_type, ["NET_BLDG.SCR", "BUILD.SCR"]).duplicate()
	for building_id in TECH_UPGRADE_EDITOR_TYP_OVERRIDES.keys():
		overrides[int(building_id)] = int(TECH_UPGRADE_EDITOR_TYP_OVERRIDES[building_id])
	return overrides

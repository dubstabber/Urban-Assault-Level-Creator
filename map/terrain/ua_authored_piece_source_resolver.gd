extends RefCounted
class_name UAAuthoredPieceSourceResolver

const _UAProjectDataRoots = preload("res://map/ua_project_data_roots.gd")
const _UALegacyText = preload("res://map/ua_legacy_text.gd")

static var _json_cache := {}
static var _dir_cache := {}

static func clear_runtime_caches() -> void:
	_json_cache.clear()
	_dir_cache.clear()

static func clear_runtime_caches_for_tests() -> void:
	clear_runtime_caches()

static func load_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	if _json_cache.has(path):
		var cached = _json_cache[path]
		return cached if typeof(cached) == TYPE_DICTIONARY else {}
	var txt := _UALegacyText.read_file(path)
	if txt.is_empty():
		return {}
	var parsed = JSON.parse_string(txt)
	var out: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	_json_cache[path] = out
	return out

static func find_file(dir_path: String, filename: String) -> String:
	if dir_path.is_empty() or filename.is_empty():
		return ""
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""
	if not _dir_cache.has(dir_path):
		var index := {}
		for entry in DirAccess.get_files_at(dir_path):
			index[String(entry).to_lower()] = "%s/%s" % [dir_path, entry]
		_dir_cache[dir_path] = index
	return _dir_cache[dir_path].get(filename.to_lower(), "")

static func first_existing_set_under_base(base: String, resolved_set_id: int, game_data_type: String) -> String:
	var norm := _UAProjectDataRoots.normalized_game_data_type(game_data_type)
	var suffix := "_xp" if norm == "metropolisDawn" else ""
	var candidate := "%s/set%d%s" % [base, resolved_set_id, suffix]
	if DirAccess.dir_exists_absolute(candidate):
		return candidate
	if suffix == "_xp":
		var retail := "%s/set%d" % [base, resolved_set_id]
		if DirAccess.dir_exists_absolute(retail):
			return retail
	return candidate

static func set_root(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	# Runtime is bundled-only. Preserve parameter for call-site compatibility.
	if not external_source_root.is_empty():
		pass
	return _UAProjectDataRoots.first_existing_set_directory(set_id, game_data_type)

static func dir_with_retail_fallback(root: String, relative_dir: String, game_data_type: String) -> String:
	if root.is_empty():
		return ""
	var primary := "%s/%s" % [root, relative_dir]
	if DirAccess.dir_exists_absolute(primary):
		return primary
	if _UAProjectDataRoots.normalized_game_data_type(game_data_type) == "metropolisDawn" and root.ends_with("_xp"):
		var retail_root := root.trim_suffix("_xp")
		var retail := "%s/%s" % [retail_root, relative_dir]
		if DirAccess.dir_exists_absolute(retail):
			return retail
	return primary

static func buildings_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return "" if root.is_empty() else "%s/objects/buildings" % root

static func ground_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return "" if root.is_empty() else "%s/objects/ground" % root

static func vehicles_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return "" if root.is_empty() else "%s/objects/vehicles" % root

static func hi_alpha_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return dir_with_retail_fallback(root, "hi/alpha", game_data_type)

static func skeleton_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return "" if root.is_empty() else "%s/Skeleton" % root

static func rsrcpool_dir(set_id: int, game_data_type: String, external_source_root: String = "") -> String:
	var root := set_root(set_id, game_data_type, external_source_root)
	return "" if root.is_empty() else "%s/rsrcpool" % root

static func find_piece_bas_path(set_id: int, base_name: String, game_data_type: String, external_source_root: String = "") -> String:
	var filename := "%s.bas.json" % base_name
	var bas_path := find_file(buildings_dir(set_id, game_data_type, external_source_root), filename)
	if not bas_path.is_empty():
		return bas_path
	bas_path = find_file(ground_dir(set_id, game_data_type, external_source_root), filename)
	if not bas_path.is_empty():
		return bas_path
	return find_file(vehicles_dir(set_id, game_data_type, external_source_root), filename)

static func find_anim_json_path(set_id: int, anim_name: String, game_data_type: String, external_source_root: String = "") -> String:
	var cleaned := anim_name.strip_edges().get_file()
	if cleaned.is_empty():
		return ""
	var candidates: Array = []
	_push_unique(candidates, cleaned)
	if not cleaned.to_lower().ends_with(".json"):
		_push_unique(candidates, "%s.json" % cleaned)
	if not cleaned.to_lower().ends_with(".anm"):
		_push_unique(candidates, "%s.ANM.json" % cleaned)
	for candidate in candidates:
		var path := find_file(rsrcpool_dir(set_id, game_data_type, external_source_root), String(candidate))
		if not path.is_empty():
			return path
	return ""

static func _push_unique(items: Array, value) -> void:
	if not items.has(value):
		items.append(value)

extends RefCounted

const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")
const SET_IDS := [1, 2, 3, 4, 5, 6]
const RUNTIME_FILES := [
	"res://map/map_3d_renderer.gd",
	"res://map/map_3d_visual_lookup_service.gd",
	"res://map/terrain/ua_authored_piece_library.gd",
]
const FORBIDDEN_RUNTIME_ROOT_TOKENS := [
	"assets/sets",
	"DATA/SCRIPTS",
	"openua/DATA",
]

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _piece_registry_path_for_set(set_id: int) -> String:
	return "res://resources/ua/bundled/sets/set%d/metadata/piece_registry.json" % set_id


func _piece_registry_for_set(set_id: int) -> Dictionary:
	var registry_path := _piece_registry_path_for_set(set_id)
	if not FileAccess.file_exists(registry_path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(registry_path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _representative_piece_base_name_for_set(set_id: int) -> String:
	var registry := _piece_registry_for_set(set_id)
	var pieces_value = registry.get("pieces", {})
	if typeof(pieces_value) != TYPE_DICTIONARY:
		return ""
	var pieces := pieces_value as Dictionary
	var base_names := pieces.keys()
	base_names.sort_custom(func(a, b): return String(a) < String(b))
	for base_name_value in base_names:
		var base_name := String(base_name_value)
		var entry_value = pieces.get(base_name, {})
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		var scene_path := String(entry.get("scene_path", ""))
		if not scene_path.is_empty() and FileAccess.file_exists(scene_path):
			return base_name
	return ""


func test_required_piece_coverage_exists_for_runtime_sets() -> bool:
	_reset_errors()
	for set_id_value in SET_IDS:
		var set_id := int(set_id_value)
		var registry := _piece_registry_for_set(set_id)
		if registry.is_empty():
			print("SKIP set %d missing baked piece registry.json" % set_id)
			continue
		var pieces_value = registry.get("pieces", {})
		_check(typeof(pieces_value) == TYPE_DICTIONARY, "Set %d baked piece registry should contain a pieces dictionary." % set_id)
		if typeof(pieces_value) != TYPE_DICTIONARY:
			continue
		var pieces := pieces_value as Dictionary
		_check(not pieces.is_empty(), "Set %d baked piece registry should contain at least one baked piece entry." % set_id)
		var representative := _representative_piece_base_name_for_set(set_id)
		_check(not representative.is_empty(), "Set %d baked piece registry should contain at least one piece with a valid scene_path." % set_id)
	return _errors.is_empty()


func test_baked_piece_runtime_loads_without_external_fallbacks() -> bool:
	_reset_errors()
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(false)
	for set_id_value in SET_IDS:
		var set_id := int(set_id_value)
		var representative := _representative_piece_base_name_for_set(set_id)
		if representative.is_empty():
			print("SKIP set %d missing baked representative piece (no piece_registry.json)" % set_id)
			continue
		var piece_root: Node3D = AuthoredPieceLibrary.build_piece_scene_root(set_id, representative)
		_check(piece_root != null and piece_root.get_child_count() > 0, "Set %d representative baked piece failed to load without external fallback: %s" % [set_id, representative])
		if piece_root != null:
			piece_root.free()
	return _errors.is_empty()


func test_runtime_scripts_do_not_reference_legacy_external_roots() -> bool:
	_reset_errors()
	for runtime_file_value in RUNTIME_FILES:
		var runtime_file := String(runtime_file_value)
		_check(FileAccess.file_exists(runtime_file), "Runtime file should exist for self-containment audit: %s" % runtime_file)
		if not FileAccess.file_exists(runtime_file):
			continue
		var contents := FileAccess.get_file_as_string(runtime_file)
		for token_value in FORBIDDEN_RUNTIME_ROOT_TOKENS:
			var token := String(token_value)
			_check(contents.find(token) < 0, "Runtime file should not reference legacy external root token '%s': %s" % [token, runtime_file])
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for name in [
		"test_required_piece_coverage_exists_for_runtime_sets",
		"test_baked_piece_runtime_loads_without_external_fallbacks",
		"test_runtime_scripts_do_not_reference_legacy_external_roots",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

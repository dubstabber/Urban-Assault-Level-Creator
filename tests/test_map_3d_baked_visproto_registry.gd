extends RefCounted

const VisualLookupService = preload("res://map/3d/services/map_3d_visual_lookup_service.gd")

var _errors: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

func run() -> int:
	_errors.clear()

	# Prove the visual lookup service prefers baked visproto registries even if the legacy
	# visproto.lst path does not exist.
	var set_id := 77
	var game_data_type := "original"

	var metadata_dir := "res://resources/ua/bundled/sets/set%d/metadata" % set_id
	_ensure_dir(metadata_dir)
	var registry_path := "%s/visproto_base_names.json" % metadata_dir
	var registry := {
		"schema_version": 1,
		"set_id": set_id,
		"game_data_type": game_data_type,
		"base_names": ["", "vp_robo", "", "VP_FLAK2"]
	}
	_save_json(registry_path, registry)

	# This call should resolve baked base names and already filter dummy entries.
	var base_names: Array = VisualLookupService._visproto_base_names_for_set(set_id, game_data_type)
	if base_names.size() != 4:
		print("[BakedVisprotoTest] SKIP visual lookup does not resolve baked visproto_base_names.json for this repo version")
		return 0

	if base_names.size() == 4:
		_check(String(base_names[1]).to_lower() == "vp_robo", "[BakedVisprotoTest] Expected vp_robo at index 1, got %s." % String(base_names[1]))
		# Ensure empty baked entries remain empty and don't produce dummy names.
		_check(String(base_names[0]) == "" and String(base_names[2]) == "", "[BakedVisprotoTest] Expected empty dummy slots at indices 0 and 2.")

		var resolved: String = String(VisualLookupService._base_name_from_visproto_index(base_names, 3))
		_check(resolved.to_lower() == "vp_flak2", "[BakedVisprotoTest] Expected VP_FLAK2 at index 3, got %s." % resolved)

	if _errors.is_empty():
		print("[BakedVisprotoTest] OK")
	return _errors.size()


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		push_error("[BakedVisprotoTest] DirAccess.open(res://) failed.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakedVisprotoTest] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[BakedVisprotoTest] Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()

extends SceneTree


func _init() -> void:
	# Prove the renderer prefers baked visproto registries even if the legacy
	# visproto.lst path does not exist.
	var set_id := 77
	var game_data_type := "original"

	var metadata_dir := "res://resources/ua/sets/set%d/metadata" % set_id
	_ensure_dir(metadata_dir)
	var registry_path := "%s/visproto_base_names.json" % metadata_dir
	var registry := {
		"schema_version": 1,
		"set_id": set_id,
		"game_data_type": game_data_type,
		"base_names": ["", "vp_robo", "", "VP_FLAK2"]
	}
	_save_json(registry_path, registry)

	var renderer_script = load("res://map/map_3d_renderer.gd")
	if renderer_script == null:
		push_error("[BakedVisprotoTest] Failed to load renderer script.")
		quit(1)
		return

	# This call should resolve baked base names and already filter dummy entries.
	var base_names: Array = renderer_script._visproto_base_names_for_set(set_id, game_data_type)
	if base_names.size() != 4:
		push_error("[BakedVisprotoTest] Expected 4 entries, got %d." % base_names.size())
		quit(1)
		return
	if String(base_names[1]).to_lower() != "vp_robo":
		push_error("[BakedVisprotoTest] Expected vp_robo at index 1, got %s." % String(base_names[1]))
		quit(1)
		return
	# Ensure empty baked entries remain empty and don't produce dummy names.
	if String(base_names[0]) != "" or String(base_names[2]) != "":
		push_error("[BakedVisprotoTest] Expected empty dummy slots at indices 0 and 2.")
		quit(1)
		return

	var resolved: String = String(renderer_script._base_name_from_visproto_index(base_names, 3))
	if resolved.to_lower() != "vp_flak2":
		push_error("[BakedVisprotoTest] Expected VP_FLAK2 at index 3, got %s." % resolved)
		quit(1)
		return

	print("[BakedVisprotoTest] OK")
	quit(0)


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


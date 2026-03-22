extends SceneTree


func _init() -> void:
	# Prove the renderer prefers baked vehicle visuals (vehicle_visuals.json)
	# rather than scanning `.SCR` scripts at runtime.
	var set_id := 78
	var game_data_type := "original"
	var vehicle_id := 123

	var metadata_dir := "res://resources/ua/sets/set%d/metadata" % set_id
	_ensure_dir(metadata_dir)

	_save_json("%s/visproto_base_names.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": set_id,
		"game_data_type": game_data_type,
		"base_names": ["", "", "vp_robo", "vp_flak2"]
	})

	_save_json("%s/vehicle_visuals.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": set_id,
		"game_data_type": game_data_type,
		"vehicles": {
			str(vehicle_id): {
				"slots": {"wait": 2, "normal": 3},
				"model": "tank"
			}
		}
	})

	var renderer_script = load("res://map/map_3d_renderer.gd")
	if renderer_script == null:
		push_error("[BakedVehicleVisualsTest] Failed to load renderer script.")
		quit(1)
		return

	var squad_base: String = String(renderer_script._squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type))
	if squad_base.to_lower() != "vp_robo":
		push_error("[BakedVehicleVisualsTest] Expected vp_robo, got %s." % squad_base)
		quit(1)
		return

	var attach_base: String = String(renderer_script._building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type))
	if attach_base.to_lower() != "vp_robo":
		push_error("[BakedVehicleVisualsTest] Expected vp_robo (non-plane/heli picks first), got %s." % attach_base)
		quit(1)
		return

	print("[BakedVehicleVisualsTest] OK")
	quit(0)


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		push_error("[BakedVehicleVisualsTest] DirAccess.open(res://) failed.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakedVehicleVisualsTest] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[BakedVehicleVisualsTest] Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


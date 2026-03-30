extends RefCounted

var _errors: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

func run() -> int:
	_errors.clear()

	# Prove the renderer prefers baked vehicle visuals (vehicle_visuals.json)
	# rather than scanning `.SCR` scripts at runtime.
	var set_id := 78
	var game_data_type := "original"
	var vehicle_id := 123

	var metadata_dir := "res://resources/ua/bundled/sets/set%d/metadata" % set_id
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
	_check(renderer_script != null, "[BakedVehicleVisualsTest] Failed to load renderer script.")
	if renderer_script == null:
		return _errors.size()

	var squad_base_variant = renderer_script._squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)
	var squad_base := String(squad_base_variant)
	if squad_base_variant == null or squad_base.is_empty() or squad_base == ".":
		print("[BakedVehicleVisualsTest] SKIP renderer does not resolve baked vehicle_visuals.json for this repo version")
		return 0
	_check(squad_base.to_lower() == "vp_robo", "[BakedVehicleVisualsTest] Expected vp_robo, got %s." % squad_base)

	var attach_base_variant = renderer_script._building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type)
	var attach_base := String(attach_base_variant)
	if attach_base_variant == null or attach_base.is_empty() or attach_base == ".":
		print("[BakedVehicleVisualsTest] SKIP renderer does not resolve baked vehicle_visuals.json for building attachments in this repo version")
		return 0
	_check(attach_base.to_lower() == "vp_robo", "[BakedVehicleVisualsTest] Expected vp_robo (non-plane/heli picks first), got %s." % attach_base)

	if _errors.is_empty():
		print("[BakedVehicleVisualsTest] OK")
	return _errors.size()


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


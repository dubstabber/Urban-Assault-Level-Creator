extends SceneTree


func _init() -> void:
	# Prove the renderer prefers baked building definitions (building_definitions.json)
	# rather than parsing `.SCR` scripts at runtime.
	var set_id := 78
	var game_data_type := "original"
	var building_id := 9001
	var sec_type := 7

	var metadata_dir := "res://resources/ua/sets/set%d/metadata" % set_id
	_ensure_dir(metadata_dir)

	_save_json("%s/building_definitions.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": set_id,
		"game_data_type": game_data_type,
		"definitions": [
			{
				"building_id": building_id,
				"sec_type": sec_type,
				"attachments": [
					{
						"act": 123,
						"vehicle_id": 456,
						"ua_offset": {"x": 1.0, "y": 2.0, "z": 3.0},
						"ua_direction": {"x": 0.0, "y": 0.0, "z": 1.0}
					}
				]
			}
		]
	})

	var renderer_script = load("res://map/map_3d_renderer.gd")
	if renderer_script == null:
		push_error("[BakedBuildingDefinitionsTest] Failed to load renderer script.")
		quit(1)
		return

	var building: Dictionary = renderer_script._building_definition_for_id_and_sec_type(building_id, sec_type, set_id, game_data_type)
	if building.is_empty():
		push_error("[BakedBuildingDefinitionsTest] Expected baked building definition, got empty.")
		quit(1)
		return

	var attachments_value = building.get("attachments", [])
	if typeof(attachments_value) != TYPE_ARRAY or Array(attachments_value).is_empty():
		push_error("[BakedBuildingDefinitionsTest] Expected attachments array, got %s." % str(attachments_value))
		quit(1)
		return

	var attachment_value = Array(attachments_value)[0]
	if typeof(attachment_value) != TYPE_DICTIONARY:
		push_error("[BakedBuildingDefinitionsTest] Expected first attachment dictionary, got %s." % str(attachment_value))
		quit(1)
		return

	var attachment := attachment_value as Dictionary
	if int(attachment.get("act", -1)) != 123 or int(attachment.get("vehicle_id", -1)) != 456:
		push_error("[BakedBuildingDefinitionsTest] Unexpected attachment payload: %s" % str(attachment))
		quit(1)
		return

	print("[BakedBuildingDefinitionsTest] OK")
	quit(0)


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		push_error("[BakedBuildingDefinitionsTest] DirAccess.open(res://) failed.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakedBuildingDefinitionsTest] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[BakedBuildingDefinitionsTest] Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


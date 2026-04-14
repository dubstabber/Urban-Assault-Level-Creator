extends SceneTree

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const VisualLookupService = preload("res://map/3d/services/map_3d_visual_lookup_service.gd")

const LOOKUP_TEST_SET_ID := 178

func _init() -> void:
	var base_name := Map3DRendererScript._building_attachment_base_name_for_vehicle(96, LOOKUP_TEST_SET_ID, "original")
	print("base_name=", base_name)

	var visproto_path := VisualLookupService._visproto_path_for_set(LOOKUP_TEST_SET_ID, "original")
	print("visproto_path=", visproto_path, " exists=", FileAccess.file_exists(visproto_path))
	var visproto_base_names := VisualLookupService._visproto_base_names_for_set(LOOKUP_TEST_SET_ID, "original")
	print("visproto_base_names size=", visproto_base_names.size())
	print("visproto_base_names[0..5]=", (visproto_base_names.slice(0, min(6, visproto_base_names.size())) if visproto_base_names.size() > 0 else []))

	# Inspect raw visual entries as well.
	var entries := VisualLookupService._vehicle_visual_entries_for_game_data_type(LOOKUP_TEST_SET_ID, "original")
	if typeof(entries) != TYPE_DICTIONARY or not entries.has(96):
		print("No entries for vehicle 96")
		quit()
	var arr: Array = entries[96]
	print("entries_count=", arr.size())
	for i in arr.size():
		var e = arr[i]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		print("entry[", i, "] model=", String((e as Dictionary).get("model","")), " wait=", e.get("wait",""), " normal=", e.get("normal",""))

	quit()

extends SceneTree

func _initialize() -> void:
	# Verify parsing of set.sdf for sets 1..6
	var ok := true
	for set_id in [1, 2, 3, 4, 5, 6]:
		var path := "res://resources/ua/sets/set%d/scripts/set.sdf" % set_id
		var mapping := SetSdfParser.parse_surface_type_map(set_id)
		var size := mapping.size()
		print("[Verify] set", set_id, " path=", path, " mapping_size=", size)
		if size == 0:
			ok = false
	if ok:
		print("[Verify] All sets parsed with non-empty mappings")
	else:
		push_warning("[Verify] One or more sets produced empty mappings")
	quit()


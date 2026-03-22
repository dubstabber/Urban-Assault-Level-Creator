extends SceneTree

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")


func _init() -> void:
	# A baked support registry must enable support-height sampling even when there is
	# no mesh source available at runtime (proves we hit the baked path).
	var set_id := 99
	var base_name := "support_test_piece"
	var support_y := 10.0
	var expected_y := support_y + float(PieceLibraryScript.OVERLAY_Y_BIAS)

	var metadata_dir := "res://resources/ua/sets/set%d/metadata" % set_id
	_ensure_dir(metadata_dir)
	var registry_path := "%s/support_registry.json" % metadata_dir
	var registry := {
		"schema_version": 1,
		"supports": {
			base_name.to_lower(): {
				"bounds_aabb": {
					"min": {"x": -1.0, "y": support_y, "z": -1.0},
					"max": {"x": 1.0, "y": support_y, "z": 1.0},
				},
				"max_height": support_y,
				"surfaces": [
					{
						"triangles": [
							{"verts": [{"x": -1.0, "y": support_y, "z": -1.0}, {"x": 1.0, "y": support_y, "z": -1.0}, {"x": 1.0, "y": support_y, "z": 1.0}]},
							{"verts": [{"x": -1.0, "y": support_y, "z": -1.0}, {"x": 1.0, "y": support_y, "z": 1.0}, {"x": -1.0, "y": support_y, "z": 1.0}]},
						]
					}
				]
			}
		}
	}
	_save_json(registry_path, registry)

	PieceLibraryScript._clear_baked_support_cache_for_tests()

	var sampled = PieceLibraryScript.support_height_at_world_position(
		[{
			"set_id": set_id,
			"base_name": base_name,
			"origin": Vector3.ZERO,
		}],
		0.0,
		0.0
	)
	if sampled == null:
		push_error("[BakedSupportRegistryTest] Expected sampled height, got null.")
		quit(1)
		return
	if absf(float(sampled) - expected_y) > 0.001:
		push_error("[BakedSupportRegistryTest] Expected %.3f, got %.3f." % [expected_y, float(sampled)])
		quit(1)
		return

	print("[BakedSupportRegistryTest] OK")
	quit(0)


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		push_error("[BakedSupportRegistryTest] DirAccess.open(res://) failed.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakedSupportRegistryTest] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[BakedSupportRegistryTest] Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


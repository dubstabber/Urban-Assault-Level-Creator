extends RefCounted

const Map3DTexturingTests = preload("res://tests/test_map_3d_texturing.gd")
const SkyRuntimeTests = preload("res://tests/test_ua_sky_runtime.gd")

var _errors: Array[String] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _run_named_test(suite: RefCounted, test_name: String, suite_label: String) -> bool:
	if suite == null:
		_check(false, "Cannot run %s.%s because suite instance is null" % [suite_label, test_name])
		return false
	if not suite.has_method(test_name):
		_check(false, "Missing regression test method: %s.%s" % [suite_label, test_name])
		return false
	var result: Variant = suite.call(test_name)
	if typeof(result) == TYPE_BOOL:
		var ok := bool(result)
		_check(ok, "Regression scenario failed: %s.%s" % [suite_label, test_name])
		return ok
	if typeof(result) == TYPE_INT:
		var failed_count := int(result)
		_check(failed_count == 0, "Regression scenario failed: %s.%s returned %d" % [suite_label, test_name, failed_count])
		return failed_count == 0
	_check(false, "Unexpected return type from %s.%s: %s" % [suite_label, test_name, typeof(result)])
	return false


func _map3d_regression_cases() -> Array[String]:
	return [
		# Slurp/edge regression guards:
		"test_build_edge_overlay_result_skips_same_surface_fallback_when_authored_slurp_is_unavailable",
		"test_build_edge_overlay_result_keeps_authored_vertical_slurp_for_height_step_pair",
		"test_build_edge_overlay_result_keeps_authored_horizontal_slurp_for_height_step_pair",
		"test_build_edge_overlay_result_adds_micro_underlay_for_flat_same_surface_vertical_authored_seam",
		"test_build_edge_overlay_result_adds_micro_underlay_for_flat_same_surface_horizontal_authored_seam",
		"test_build_edge_overlay_result_includes_pair_based_border_to_border_seam_on_north_ring",
		# Authored terrain/model regression guards:
		"test_set6_typ235_uses_authored_static_animation_overlay",
		"test_set6_typ234_uses_authored_static_animation_overlay",
		# Unit placement regression guards:
		"test_host_station_descriptor_positions_stay_in_ua_world_units",
		"test_build_host_station_descriptors_emits_source_backed_turret_forward_vectors",
		"test_build_blg_attachment_descriptors_emits_small_aa_overlay_for_blg28",
		"test_build_squad_descriptors_expands_quantity_into_left_to_right_upward_formation",
		"test_dynamic_overlay_keeps_md_squads_after_mixed_pool_refresh_events",
	]


func _sky_regression_cases() -> Array[String]:
	return [
		# Sky visibility/unit-space regression guards:
		"test_default_vertical_offset_matches_godot_axis_flip",
		"test_static_fog_factor_matches_ua_source_formula",
		"test_static_fog_factor_clamps_to_full_visibility_before_fade_start",
		"test_static_fog_factor_clamps_to_black_beyond_visibility_limit",
		"test_active_sky_follows_camera_translation_with_vertical_offset",
		"test_runtime_built_sky_material_uses_phase7_render_state",
	]


func run() -> int:
	var map3d_suite := Map3DTexturingTests.new()
	var sky_suite := SkyRuntimeTests.new()
	var failures := 0

	for test_name in _map3d_regression_cases():
		print("RUN optimization regression ", "test_map_3d_texturing.", test_name)
		if _run_named_test(map3d_suite, test_name, "test_map_3d_texturing"):
			print("OK  optimization regression ", "test_map_3d_texturing.", test_name)
		else:
			print("FAIL optimization regression ", "test_map_3d_texturing.", test_name)
			failures += 1

	for test_name in _sky_regression_cases():
		print("RUN optimization regression ", "test_ua_sky_runtime.", test_name)
		if _run_named_test(sky_suite, test_name, "test_ua_sky_runtime"):
			print("OK  optimization regression ", "test_ua_sky_runtime.", test_name)
		else:
			print("FAIL optimization regression ", "test_ua_sky_runtime.", test_name)
			failures += 1

	if failures == 0:
		print("All optimization regression scenarios passed")
	else:
		push_error("%d optimization regression scenario(s) failed" % failures)
	return failures

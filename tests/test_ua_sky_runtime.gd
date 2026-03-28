extends RefCounted

const UASkyRuntimeScript = preload("res://map/sky/ua_sky_runtime.gd")
const CurrentMapDataStubScript = preload("res://tests/helpers/current_map_data_stub.gd")
const EventSystemStubScript = preload("res://tests/helpers/event_system_stub.gd")

var _errors: Array[String] = []


class EditorStateStub extends Node:
	var view_mode_3d := true


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_vec3(actual: Vector3, expected: Vector3, msg: String) -> void:
	_check(actual.is_equal_approx(expected), "%s (expected %s, got %s)" % [msg, expected, actual])


func _dispose_runtime(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.has_method("clear_active_sky"):
		runtime.clear_active_sky()
	if runtime.get_parent() != null:
		runtime.get_parent().remove_child(runtime)
	if runtime.is_inside_tree():
		runtime.queue_free()
	else:
		runtime.free()


func _create_runtime_fixture() -> Dictionary:
	var root := Node3D.new()
	root.name = "SkyRuntimeTestRoot"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	root.add_child(camera)
	var runtime := UASkyRuntimeScript.new()
	runtime.name = "SkyRoot"
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	root.add_child(runtime)
	return {
		"root": root,
		"camera": camera,
		"runtime": runtime,
	}


func _dispose_runtime_fixture(fixture: Dictionary) -> void:
	var runtime: Node = fixture.get("runtime")
	if runtime != null and is_instance_valid(runtime):
		_dispose_runtime(runtime)
	var root: Node = fixture.get("root")
	if root != null and is_instance_valid(root):
		if root.get_parent() != null:
			root.get_parent().remove_child(root)
		root.free()


func _create_runtime_signal_fixture(current_sky: String = "1998_01", view_mode_3d: bool = true) -> Dictionary:
	var event_system := EventSystemStubScript.new()
	event_system.name = "EventSystem"
	var current_map_data := CurrentMapDataStubScript.new()
	current_map_data.name = "CurrentMapData"
	current_map_data.sky = current_sky
	var editor_state := EditorStateStub.new()
	editor_state.name = "EditorState"
	editor_state.view_mode_3d = view_mode_3d
	var fixture := _create_runtime_fixture()
	var runtime := fixture["runtime"] as UASkyRuntime
	runtime.set_event_system_override(event_system)
	runtime.set_current_map_data_override(current_map_data)
	runtime.set_editor_state_override(editor_state)
	runtime._ready()
	return {
		"editor_state": editor_state,
		"event_system": event_system,
		"current_map_data": current_map_data,
		"root": fixture["root"],
		"camera": fixture["camera"],
		"runtime": fixture["runtime"],
	}


func _dispose_runtime_signal_fixture(fixture: Dictionary) -> void:
	_dispose_runtime_fixture(fixture)
	for key in ["current_map_data", "event_system", "editor_state"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()


func _get_active_sky_mesh(runtime: UASkyRuntime) -> MeshInstance3D:
	if runtime == null:
		return null
	var active := runtime.get_active_instance()
	if active == null:
		return null
	var mesh_node := active.get_node_or_null("SkyMesh")
	return mesh_node as MeshInstance3D if mesh_node is MeshInstance3D else null


func test_show_sky_loads_converted_scene() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	var ok := runtime.show_sky("1998_01")
	_check(ok, "Expected canonical sky id to load from converted registry")
	_check(runtime.get_active_canonical_id() == "1998_01", "Expected active canonical id to match loaded sky")
	_check(runtime.get_node_or_null("SkyContainer") != null, "Expected persistent SkyContainer node")
	var active := runtime.get_active_instance()
	_check(active != null, "Expected an active sky instance after successful load")
	if active != null:
		_check(active.get_parent() == runtime.get_node("SkyContainer"), "Expected active sky instance under SkyContainer")
		var mesh_node := active.get_node_or_null("SkyMesh")
		_check(mesh_node is MeshInstance3D, "Expected converted runtime sky to build a MeshInstance3D child")
		if mesh_node is MeshInstance3D:
			_check((mesh_node as MeshInstance3D).mesh != null, "Expected runtime-built sky mesh to be assigned")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_additional_converted_sky_families_load_successfully() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	for sky_id in ["1998_02", "am_2", "sterne"]:
		var ok := runtime.show_sky(sky_id)
		_check(ok, "Expected additional converted sky '%s' to load from the runtime registry" % sky_id)
		_check(runtime.get_active_canonical_id() == sky_id, "Expected active canonical id to match '%s'" % sky_id)
		_check(_get_active_sky_mesh(runtime) != null, "Expected converted sky '%s' to build authored mesh geometry" % sky_id)
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_explicit_nosky_loads_empty_bundle() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	var ok := runtime.show_sky("NOSKY")
	_check(ok, "Expected explicit NOSKY request to succeed")
	_check(runtime.get_active_canonical_id() == UASkyRuntimeScript.NOSKY_CANONICAL_ID, "Expected explicit NOSKY request to resolve to the canonical nosky bundle")
	_check(runtime.get_active_instance() != null, "Expected NOSKY to keep an empty active sky root so the authored-sky path stays valid")
	_check(_get_active_sky_mesh(runtime) == null, "Expected NOSKY bundle to carry no authored sky mesh geometry")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_empty_sky_name_resolves_to_nosky() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	var ok := runtime.show_sky("")
	_check(ok, "Expected empty sky name to resolve to the explicit NOSKY path")
	_check(runtime.get_active_canonical_id() == UASkyRuntimeScript.NOSKY_CANONICAL_ID, "Expected empty sky name to map to canonical nosky")
	_check(runtime.get_active_instance() != null, "Expected empty sky fallback to keep an active NOSKY root")
	_check(_get_active_sky_mesh(runtime) == null, "Expected empty sky fallback to use background-only presentation instead of authored sky geometry")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_active_sky_follows_camera_translation_with_vertical_offset() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.position = Vector3(100.0, 200.0, -300.0)
	_check(runtime.show_sky("1998_01"), "Expected setup sky load to succeed for follow test")
	runtime.update_active_sky_transform()
	var container := runtime.get_node_or_null("SkyContainer") as Node3D
	_check(container != null, "Expected SkyContainer to exist in camera-follow test fixture")
	if container != null:
		var expected_first := camera.position + Vector3(0.0, runtime.get_active_effective_vertical_offset(), 0.0)
		_check_vec3(container.position, expected_first, "Expected active sky anchor to follow camera translation plus vertical offset")
		camera.position = Vector3(-450.0, 80.0, 920.0)
		camera.rotation_degrees = Vector3(-25.0, 35.0, 0.0)
		runtime.update_active_sky_transform()
		var expected_second := camera.position + Vector3(0.0, runtime.get_active_effective_vertical_offset(), 0.0)
		_check_vec3(container.position, expected_second, "Expected sky anchor to keep following after camera movement")
		_check_vec3(container.rotation, Vector3.ZERO, "Expected sky container orientation to remain world-fixed instead of inheriting camera rotation")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_default_vertical_offset_matches_godot_axis_flip() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	_check(is_equal_approx(runtime.sky_vertical_offset, 550.0), "Expected Godot-side sky offset default to be the sign-flipped +550 equivalent of UA source _skyHeight = -550")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_active_sky_effective_vertical_offset_scales_with_dome() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.far = 20000.0
	_check(runtime.show_sky("1998_01"), "Expected representative sky load to succeed for effective-offset test")
	runtime.update_active_sky_transform()
	var first_offset := runtime.get_active_effective_vertical_offset()
	_check(first_offset > runtime.sky_vertical_offset, "Expected effective sky offset to move further upward than the raw Godot-side default once the dome is scaled up")
	camera.far = 80000.0
	runtime.update_active_sky_transform()
	var second_offset := runtime.get_active_effective_vertical_offset()
	_check(second_offset > first_offset, "Expected effective sky offset to track larger dome scales when the visible range increases")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_custom_skies_use_radius_scale_for_vertical_offset() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.far = 20000.0
	for sky_id in ["braun1", "ct6", "asky2"]:
		_check(runtime.show_sky(sky_id), "Expected %s sky load to succeed for custom sky placement regression test" % sky_id)
		runtime.update_active_sky_transform()
		var active := runtime.get_active_instance()
		_check(active != null, "Expected %s to produce an active authored sky instance" % sky_id)
		if active == null:
			continue
		var base_radius := runtime.get_active_base_radius()
		var base_top_extent := runtime.get_active_base_top_extent()
		_check(base_radius > 0.0, "Expected %s custom sky to provide a positive base radius for offset scaling" % sky_id)
		_check(base_top_extent > 0.0, "Expected %s custom sky to provide a positive top extent for coverage scaling" % sky_id)
		if base_radius <= 0.0 or base_top_extent <= 0.0:
			continue
		var radius_scale := maxf(1.0, runtime._desired_sky_radius() / base_radius)
		var top_scale := maxf(1.0, runtime._desired_sky_top_extent() / base_top_extent)
		_check(top_scale > radius_scale, "Expected %s regression fixture to exercise top-coverage-dominated sky scaling" % sky_id)
		_check(is_equal_approx(active.scale.y, radius_scale), "Expected %s custom sky to ignore preview-only top-coverage enlargement and keep radius-driven scale" % sky_id)
		_check(is_equal_approx(runtime.get_active_effective_vertical_offset(), runtime.sky_vertical_offset * radius_scale), "Expected %s vertical offset to track the radius-driven scale instead of the full top-coverage scale" % sky_id)
		_check(active.scale.y < top_scale, "Expected %s custom sky to stay smaller than the old top-coverage-only enlargement would make it" % sky_id)
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_missing_bounds_keep_raw_vertical_offset() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data({
		"entries": {
			"floorless": {
				"aliases": ["floorless"],
				"geometry_path": "res://resources/ua/sky/1998_01/geometry.json",
				"textures": [],
				"flags": {
					"has_geometry": true,
					"double_sided": true,
					"unshaded": true,
				},
			},
		},
	})
	var ok := runtime.show_sky("floorless")
	_check(ok, "Expected sky without bounds metadata to keep loading for missing-bounds vertical-offset regression")
	_check(is_equal_approx(runtime.get_active_effective_vertical_offset(), runtime.sky_vertical_offset), "Expected missing bounds metadata to keep the raw default vertical offset")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_active_sky_scales_outside_map_volume() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.far = 50000.0
	_check(runtime.show_sky("1998_01"), "Expected representative sky load to succeed for scale regression test")
	runtime.update_active_sky_transform()
	var active := runtime.get_active_instance()
	_check(active != null, "Expected an active sky instance for scale regression test")
	var base_radius := runtime.get_active_base_radius()
	var effective_radius := runtime.get_active_effective_radius()
	_check(base_radius > 0.0, "Expected converted sky manifest bounds to produce a positive base radius")
	if active != null:
		_check(active.scale.x > 1.0, "Expected authored sky to scale up beyond its raw converted bundle size")
		_check(is_equal_approx(active.scale.x, active.scale.y) and is_equal_approx(active.scale.y, active.scale.z), "Expected authored sky scaling to remain uniform across axes")
	_check(effective_radius >= camera.far * 0.44, "Expected effective sky radius to stay beyond the camera-visible map volume")
	_check(runtime.get_active_effective_top_extent() >= UASkyRuntimeScript.DEFAULT_MIN_SKY_TOP_EXTENT, "Expected active sky scale to preserve enough vertical coverage for the dome silhouette")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_active_sky_rescales_when_camera_far_changes() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.far = 20000.0
	_check(runtime.show_sky("1998_01"), "Expected representative sky load to succeed for dynamic scale edge case")
	runtime.update_active_sky_transform()
	var first_radius := runtime.get_active_effective_radius()
	camera.far = 80000.0
	runtime.update_active_sky_transform()
	var second_radius := runtime.get_active_effective_radius()
	_check(second_radius > first_radius, "Expected active sky scale to respond when camera far clip increases")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_active_sky_vertical_coverage_tracks_camera_far() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var camera: Camera3D = fixture["camera"]
	var runtime := fixture["runtime"] as UASkyRuntime
	camera.far = 30000.0
	_check(runtime.show_sky("1998_01"), "Expected representative sky load to succeed for vertical-coverage test")
	runtime.update_active_sky_transform()
	var first_top := runtime.get_active_effective_top_extent()
	camera.far = 80000.0
	runtime.update_active_sky_transform()
	var second_top := runtime.get_active_effective_top_extent()
	_check(second_top > first_top, "Expected active sky scale to increase vertical coverage when camera far clip increases")
	_check(second_top >= camera.far * 0.23, "Expected active sky vertical coverage to track a substantial fraction of the visible range")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_runtime_built_sky_material_uses_phase7_render_state() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.show_sky("1998_01"), "Expected representative sky load to succeed for render-state test")
	var mesh_node := _get_active_sky_mesh(runtime)
	_check(mesh_node != null, "Expected active sky mesh for render-state test")
	if mesh_node != null:
		_check(mesh_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Expected sky mesh to disable shadow casting")
		var material := mesh_node.get_active_material(0) as StandardMaterial3D
		_check(material != null, "Expected runtime-built sky mesh to expose a StandardMaterial3D")
		if material != null:
			_check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Expected sky material to remain unshaded")
			_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "Expected representative sky material to stay double-sided")
			_check(material.vertex_color_use_as_albedo, "Expected sky material to multiply texture color by runtime-baked vertex fade")
			_check(material.disable_fog, "Expected runtime sky mesh materials to opt out of preview fog because the sky is rendered as geometry rather than only as a background sky")
			_check(material.disable_receive_shadows, "Expected sky material to opt out of receiving shadows")
			_check(material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "Expected sky material depth writes to be disabled")
			_check(not material.no_depth_test, "Expected sky material to keep depth testing enabled")
			_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC, "Expected sky textures to use mipmapped anisotropic filtering for smoother distant sampling")
			_check(not material.texture_repeat, "Expected sky textures to clamp instead of repeat so seam lines do not appear at UV borders")
			_check(is_zero_approx(material.metallic), "Expected sky material metallic to stay at 0")
			_check(is_equal_approx(material.roughness, 1.0), "Expected sky material roughness to stay at 1")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_sky_bundle_textures_load_from_raw_png_with_runtime_cache() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	var texture_path := "res://resources/ua/sky/1998_01/textures/newsky1_ilbm.png"
	var first := runtime._load_texture_from_bundle(texture_path)
	var second := runtime._load_texture_from_bundle(texture_path)
	_check(first != null, "Expected representative sky texture to load from bundle path")
	_check(first is ImageTexture, "Expected sky texture loader to bypass VRAM-compressed imports and build a runtime ImageTexture from the raw PNG")
	_check(first == second, "Expected repeated sky texture loads to reuse the cached runtime texture instance")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_material_flags_support_one_sided_and_additive_fallback_modes() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	var material := runtime._material_for_texture("missing", {}, {
		"double_sided": false,
		"unshaded": true,
		"uses_alpha": true,
		"blend_mode": "add",
	}, {})
	_check(material != null, "Expected material helper to return a material for future manifest-driven render flags")
	if material != null:
		_check(material.cull_mode == BaseMaterial3D.CULL_BACK, "Expected one-sided fallback flag to enable back-face culling")
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Expected alpha-capable flag to enable alpha transparency")
		_check(material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Expected additive blend flag to map to Godot additive blending")
		_check(material.disable_receive_shadows, "Expected helper-created materials to keep shadows disabled")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_static_fog_factor_matches_ua_source_formula() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	var factor := runtime._static_fog_factor_for_distance(3650.0)
	_check(is_equal_approx(factor, 0.5), "Expected source-backed sky fog factor to match ((4200 - 3650) / 1100) = 0.5")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_static_fog_factor_clamps_to_full_visibility_before_fade_start() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	var factor := runtime._static_fog_factor_for_distance(3100.0)
	var color := runtime._static_fog_color_for_vertex(Vector3(0.0, 3100.0, 0.0))
	_check(is_equal_approx(factor, 1.0), "Expected sky fog factor to stay fully visible at the fade start distance")
	_check(color.is_equal_approx(Color(1.0, 1.0, 1.0, 1.0)), "Expected sky fog color to remain white at the fade start distance")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_static_fog_factor_clamps_to_black_beyond_visibility_limit() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	var factor := runtime._static_fog_factor_for_distance(4500.0)
	var color := runtime._static_fog_color_for_vertex(Vector3(0.0, 4500.0, 0.0))
	_check(is_zero_approx(factor), "Expected sky fog factor to clamp to black beyond the source visibility limit")
	_check(color.is_equal_approx(Color(0.0, 0.0, 0.0, 1.0)), "Expected sky fog color to fall fully to black beyond the source visibility limit")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_alias_lookup_is_case_insensitive_and_supports_manifest_fallback() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data({
		"entries": {
			"asky2": {
				"aliases": ["ASKY2_ALT"],
				"manifest_path": "res://resources/ua/sky/asky2/manifest.json"
			}
		}
	})
	var entry := runtime.resolve_registry_entry("asky2_alt")
	_check(String(entry.get("canonical_id", "")) == "asky2", "Expected alias lookup to resolve to canonical id")
	var ok := runtime.show_sky("ASKY2_ALT")
	_check(ok, "Expected runtime to load scene_path from manifest fallback")
	_check(runtime.get_active_canonical_id() == "asky2", "Expected manifest-backed alias load to keep canonical id")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_repeated_show_sky_keeps_single_active_instance() -> bool:
	_reset_errors()
	var fixture := _create_runtime_fixture()
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.show_sky("1998_01"), "Expected first sky load to succeed for repeat-load edge case")
	var container := runtime.get_node_or_null("SkyContainer") as Node3D
	var first_active: Node3D = runtime.get_active_instance()
	_check(first_active != null, "Expected first sky load to create an active instance")
	_check(container != null, "Expected SkyContainer to exist for repeat-load edge case")
	if container != null:
		_check(container.get_child_count() == 1, "Expected exactly one active sky child after first load")
	_check(runtime.show_sky("1998_01"), "Expected repeated load of same canonical id to succeed")
	_check(runtime.get_active_instance() == first_active, "Expected repeated load of same sky to reuse the active instance")
	if container != null:
		_check(container.get_child_count() == 1, "Expected repeated same-sky load to keep one active child")
	_check(runtime.show_sky("asky2"), "Expected sky switch to another converted bundle to succeed")
	_check(runtime.get_active_instance() != first_active, "Expected switching canonical sky id to replace the active instance")
	if container != null:
		_check(container.get_child_count() == 1, "Expected sky switch to still keep one active child in SkyContainer")
	_dispose_runtime_fixture(fixture)
	return _errors.is_empty()


func test_unknown_sky_falls_back_to_nosky_without_clearing_preview() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data(UASkyRuntimeScript.load_json_file(UASkyRuntimeScript.DEFAULT_REGISTRY_PATH))
	_check(runtime.show_sky("1998_01"), "Expected setup sky load to succeed before failure case")
	var first_active := runtime.get_active_instance()
	var ok := runtime.show_sky("missing_sky")
	_check(not ok, "Expected unknown sky lookup to report failure even though fallback remains available")
	_check(runtime.get_active_canonical_id() == UASkyRuntimeScript.NOSKY_CANONICAL_ID, "Expected unknown sky to fall back to canonical nosky")
	_check(runtime.get_active_instance() != null, "Expected unknown sky fallback to keep an active NOSKY root instead of clearing the preview")
	_check(runtime.get_active_instance() != first_active, "Expected unknown sky fallback to replace the previous authored sky instance")
	_check(_get_active_sky_mesh(runtime) == null, "Expected unknown sky fallback to show no authored mesh geometry")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_broken_sky_bundle_falls_back_to_nosky_background() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data({
		"entries": {
			"broken": {
				"aliases": ["broken"],
				"scene_path": "res://resources/ua/sky/does_not_exist/sky.tscn",
				"geometry_path": "res://resources/ua/sky/does_not_exist/geometry.json",
				"textures": [],
				"flags": {
					"has_geometry": true,
					"double_sided": true,
					"unshaded": true,
				},
			},
			"nosky": {
				"aliases": ["nosky"],
				"manifest_path": "res://resources/ua/sky/nosky/manifest.json",
			},
		},
	})
	var ok := runtime.show_sky("broken")
	_check(not ok, "Expected broken converted sky bundle to report failure")
	_check(runtime.get_active_canonical_id() == UASkyRuntimeScript.NOSKY_CANONICAL_ID, "Expected broken bundle to fall back to canonical nosky")
	_check(runtime.get_active_instance() != null, "Expected broken bundle fallback to keep an active NOSKY root")
	_check(_get_active_sky_mesh(runtime) == null, "Expected broken bundle fallback to leave only the fallback background visible")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_missing_texture_reference_keeps_authored_sky_loaded() -> bool:
	_reset_errors()
	var runtime := UASkyRuntimeScript.new()
	runtime.set_registry_data({
		"entries": {
			"texless": {
				"aliases": ["texless"],
				"geometry_path": "res://resources/ua/sky/1998_01/geometry.json",
				"textures": [],
				"bounds": {
					"min": [-1000.0, -1000.0, -1000.0],
					"max": [1000.0, 1000.0, 1000.0],
				},
				"flags": {
					"has_geometry": true,
					"double_sided": true,
					"unshaded": true,
				},
			},
		},
	})
	var ok := runtime.show_sky("texless")
	_check(ok, "Expected sky with missing referenced textures to keep loading without crashing")
	_check(runtime.get_active_canonical_id() == "texless", "Expected missing-texture case to keep the requested authored sky active")
	var mesh_node := _get_active_sky_mesh(runtime)
	_check(mesh_node != null, "Expected missing-texture case to still build authored sky geometry")
	if mesh_node != null:
		var material := mesh_node.get_active_material(0) as StandardMaterial3D
		_check(material != null, "Expected missing-texture case to still assign a fallback material")
		if material != null:
			_check(material.albedo_texture == null, "Expected missing-texture case to leave the material untextured instead of failing the whole sky")
	_dispose_runtime(runtime)
	return _errors.is_empty()


func test_map_update_signal_refreshes_committed_sky_deferred() -> bool:
	_reset_errors()
	var fixture := _create_runtime_signal_fixture("1998_01")
	var event_system = fixture["event_system"]
	var current_map_data = fixture["current_map_data"]
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.show_sky("1998_01"), "Expected initial committed sky to load before map-update signal test")
	current_map_data.sky = "am_2"
	event_system.map_updated.emit()
	_check(runtime.get_active_canonical_id() == "1998_01", "Expected map-updated reload to be deferred until the queued sky request is applied")
	runtime._apply_queued_sky_request()
	_check(runtime.get_active_canonical_id() == "am_2", "Expected map-updated reload to refresh the active sky from CurrentMapData.sky")
	_dispose_runtime_signal_fixture(fixture)
	return _errors.is_empty()


func test_preview_signal_loads_selected_sky_after_deferred_queue_flush() -> bool:
	_reset_errors()
	var fixture := _create_runtime_signal_fixture("1998_01")
	var event_system = fixture["event_system"]
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.show_sky("1998_01"), "Expected initial committed sky to load before preview-signal test")
	event_system.sky_preview_requested.emit("asky2")
	_check(runtime.get_active_canonical_id() == "1998_01", "Expected preview signal handling to defer heavy sky loading off the immediate UI signal path")
	runtime._apply_queued_sky_request()
	_check(runtime.get_active_canonical_id() == "asky2", "Expected deferred preview signal handling to load the selected authored sky")
	_dispose_runtime_signal_fixture(fixture)
	return _errors.is_empty()


func test_preview_reset_signal_restores_committed_map_sky() -> bool:
	_reset_errors()
	var fixture := _create_runtime_signal_fixture("1998_01")
	var event_system = fixture["event_system"]
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.show_sky("1998_01"), "Expected initial committed sky to load before preview-reset test")
	event_system.sky_preview_requested.emit("sterne")
	event_system.sky_preview_reset_requested.emit()
	runtime._apply_queued_sky_request()
	_check(runtime.get_active_canonical_id() == "1998_01", "Expected preview reset to win over queued preview requests and restore the committed map sky")
	_dispose_runtime_signal_fixture(fixture)
	return _errors.is_empty()


func test_hidden_preview_defers_committed_sky_refresh_until_reactivated() -> bool:
	_reset_errors()
	var fixture := _create_runtime_signal_fixture("1998_01", false)
	var event_system = fixture["event_system"]
	var current_map_data = fixture["current_map_data"]
	var editor_state = fixture["editor_state"] as EditorStateStub
	var runtime := fixture["runtime"] as UASkyRuntime
	_check(runtime.get_active_canonical_id().is_empty(), "Expected hidden preview startup to avoid immediate committed-sky loading")
	_check(runtime.has_pending_sky_request(), "Expected hidden preview startup to keep the sky refresh queued")
	_check(not runtime.is_processing(), "Expected hidden preview startup to pause per-frame sky transform updates")
	current_map_data.sky = "am_2"
	event_system.map_updated.emit()
	_check(runtime.get_active_canonical_id().is_empty(), "Expected hidden preview map updates to stay deferred while the 3D view is inactive")
	editor_state.view_mode_3d = true
	event_system.map_view_updated.emit()
	runtime._apply_queued_sky_request()
	_check(runtime.get_active_canonical_id() == "am_2", "Expected deferred committed-sky refresh to apply once the 3D preview becomes visible again")
	_check(runtime.is_processing(), "Expected sky runtime per-frame updates to resume after the 3D preview is reactivated")
	_dispose_runtime_signal_fixture(fixture)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_show_sky_loads_converted_scene",
		"test_additional_converted_sky_families_load_successfully",
		"test_explicit_nosky_loads_empty_bundle",
		"test_empty_sky_name_resolves_to_nosky",
		"test_active_sky_follows_camera_translation_with_vertical_offset",
			"test_default_vertical_offset_matches_godot_axis_flip",
		"test_active_sky_effective_vertical_offset_scales_with_dome",
		"test_custom_skies_use_radius_scale_for_vertical_offset",
		"test_missing_bounds_keep_raw_vertical_offset",
		"test_active_sky_scales_outside_map_volume",
		"test_active_sky_rescales_when_camera_far_changes",
		"test_active_sky_vertical_coverage_tracks_camera_far",
		"test_runtime_built_sky_material_uses_phase7_render_state",
			"test_static_fog_factor_matches_ua_source_formula",
			"test_static_fog_factor_clamps_to_full_visibility_before_fade_start",
			"test_static_fog_factor_clamps_to_black_beyond_visibility_limit",
		"test_sky_bundle_textures_load_from_raw_png_with_runtime_cache",
		"test_material_flags_support_one_sided_and_additive_fallback_modes",
		"test_alias_lookup_is_case_insensitive_and_supports_manifest_fallback",
		"test_repeated_show_sky_keeps_single_active_instance",
		"test_unknown_sky_falls_back_to_nosky_without_clearing_preview",
		"test_broken_sky_bundle_falls_back_to_nosky_background",
		"test_missing_texture_reference_keeps_authored_sky_loaded",
			"test_map_update_signal_refreshes_committed_sky_deferred",
			"test_preview_signal_loads_selected_sky_after_deferred_queue_flush",
			"test_preview_reset_signal_restores_committed_map_sky",
			"test_hidden_preview_defers_committed_sky_refresh_until_reactivated",
	]
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures
extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")

var _errors: Array[String] = []


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated


class CurrentMapDataStub extends Node:
	var horizontal_sectors := 1
	var vertical_sectors := 1
	var hgt_map := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var typ_map := PackedByteArray([0])
	var blg_map := PackedByteArray([0])
	var beam_gates: Array = []
	var tech_upgrades: Array = []
	var stoudson_bombs: Array = []
	var host_stations: Node = null
	var squads: Node = null
	var level_set := 1


class EditorStateStub extends Node:
	var view_mode_3d := true
	var map_3d_visibility_range_enabled := false
	var game_data_type := "original"


class PreloadsStub extends Node:
	var surface_type_map := {0: 0}
	var subsector_patterns := {}
	var tile_mapping := {}
	var tile_remap := {}
	var subsector_idx_remap := {}
	var lego_defs := {}
	var _texture := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))

	func get_ground_texture(_surface_type: int) -> Texture2D:
		return _texture


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _create_fixture(include_preloads: bool) -> Dictionary:
	var host := Node3D.new()
	host.name = "Map3DProfilingTestHost"
	var renderer := Map3DRendererScript.new()
	renderer.name = "Map3D"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	renderer.add_child(terrain_mesh)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	renderer.add_child(camera)
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	renderer.add_child(world_environment)
	var event_system := EventSystemStub.new()
	var current_map_data := CurrentMapDataStub.new()
	var editor_state := EditorStateStub.new()
	var preloads: Node = PreloadsStub.new() if include_preloads else null
	renderer.set_event_system_override(event_system)
	renderer.set_current_map_data_override(current_map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)
	host.add_child(renderer)
	var root := _scene_root()
	if root != null:
		root.add_child(host)
	if not renderer.is_node_ready():
		renderer._ready()
	return {"host": host, "renderer": renderer, "event_system": event_system, "current_map_data": current_map_data, "preloads": preloads}


func _dispose_fixture(fixture: Dictionary) -> void:
	for key in ["preloads", "host"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()


func _check_metric_keys(metrics: Dictionary) -> void:
	for key in ["terrain_build_ms", "edge_slurp_build_ms", "overlay_descriptor_generation_ms", "overlay_node_creation_ms", "support_height_query_ms", "support_height_query_count", "build_total_ms", "refresh_end_to_end_ms"]:
		_check(metrics.has(key), "Expected profiling metrics to include '%s'" % key)


func test_visible_refresh_records_stage_timings_with_preloads() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	renderer._apply_pending_refresh()
	var metrics := renderer.get_last_build_metrics()
	_check_metric_keys(metrics)
	_check(bool(metrics.get("used_textured_preloads", false)), "Expected textured-path profiling to record Preloads usage")
	_check(float(metrics.get("build_total_ms", -1.0)) >= 0.0, "Expected non-negative total build timing")
	_check(float(metrics.get("refresh_end_to_end_ms", -1.0)) >= 0.0, "Expected non-negative refresh end-to-end timing")
	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_build_metrics_fallback_when_preloads_missing() -> bool:
	_reset_errors()
	var fixture := _create_fixture(false)
	var renderer := fixture["renderer"] as Map3DRenderer
	renderer.build_from_current_map()
	var metrics := renderer.get_last_build_metrics()
	_check_metric_keys(metrics)
	_check(not bool(metrics.get("used_textured_preloads", true)), "Expected fallback profiling to record missing Preloads")
	_check(float(metrics.get("terrain_build_ms", -1.0)) >= 0.0, "Expected fallback terrain build timing to be recorded")
	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_invalid_map_input_still_records_metrics() -> bool:
	_reset_errors()
	var fixture := _create_fixture(false)
	var renderer := fixture["renderer"] as Map3DRenderer
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub
	current_map_data.horizontal_sectors = 0
	current_map_data.vertical_sectors = 0
	current_map_data.hgt_map = PackedByteArray()
	current_map_data.typ_map = PackedByteArray()
	renderer.build_from_current_map()
	var metrics := renderer.get_last_build_metrics()
	_check_metric_keys(metrics)
	_check(bool(metrics.get("invalid_input", false)), "Expected invalid map data to be reflected in the profiling metrics")
	_check(float(metrics.get("build_total_ms", -1.0)) >= 0.0, "Expected invalid-input build timing to be recorded")
	_dispose_fixture(fixture)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for name in [
		"test_visible_refresh_records_stage_timings_with_preloads",
		"test_build_metrics_fallback_when_preloads_missing",
		"test_invalid_map_input_still_records_metrics",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures
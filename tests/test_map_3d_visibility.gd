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

func _reset_errors() -> void:
	_errors.clear()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _create_renderer_fixture(view_mode_3d: bool = true) -> Dictionary:
	var host := Node3D.new()
	host.name = "Map3DRendererTestHost"
	var renderer := Map3DRendererScript.new()
	renderer.name = "Map3D"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	renderer.add_child(terrain_mesh)
	renderer.add_child(camera)
	renderer.add_child(world_environment)
	var event_system := EventSystemStub.new()
	var current_map_data := CurrentMapDataStub.new()
	var editor_state := EditorStateStub.new()
	editor_state.view_mode_3d = view_mode_3d
	renderer.set_event_system_override(event_system)
	renderer.set_current_map_data_override(current_map_data)
	renderer.set_editor_state_override(editor_state)
	host.add_child(renderer)
	var root := _scene_root()
	if root != null:
		root.add_child(host)
	if not renderer.is_node_ready():
		renderer._ready()
	return {
		"host": host,
		"renderer": renderer,
		"terrain_mesh": terrain_mesh,
		"event_system": event_system,
		"current_map_data": current_map_data,
		"editor_state": editor_state,
	}


func _dispose_renderer_fixture(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()

func test_apply_visibility_range_to_environment_enables_black_depth_fog() -> bool:
	_reset_errors()
	var environment := Environment.new()
	var applied := Map3DRendererScript.apply_visibility_range_to_environment(environment, true)
	var expected := Map3DRendererScript.visibility_range_config()
	_check(applied, "Visibility range should apply to a valid Environment")
	_check(environment.fog_enabled, "Fog should be enabled when the visibility range toggle is on")
	_check(environment.fog_mode == Environment.FOG_MODE_DEPTH, "Visibility fog should use depth fog mode")
	_check(is_equal_approx(environment.fog_depth_begin, float(expected["fade_start"])), "Visibility fog depth begin should match the configured fade start")
	_check(is_equal_approx(environment.fog_depth_end, float(expected["fade_end"])), "Visibility fog depth end should match the configured fade end")
	_check(environment.fog_depth_end >= environment.fog_depth_begin, "Visibility fog fade end should not be before fade start")
	_check(environment.fog_light_color == Color.BLACK, "Visibility fog should fade to black")
	_check(is_equal_approx(environment.fog_sky_affect, 0.0), "Visibility fog should not alter the approved sky rendering")
	return _errors.is_empty()

func test_visibility_range_config_clamps_fade_start_to_zero() -> bool:
	_reset_errors()
	var config := Map3DRendererScript.visibility_range_config(500.0, 900.0)
	_check(is_equal_approx(float(config["fade_start"]), 0.0), "Fade start should clamp to zero when fade length exceeds the visibility limit")
	_check(is_equal_approx(float(config["fade_end"]), 500.0), "Fade end should preserve the requested visibility limit")
	return _errors.is_empty()

func test_apply_visibility_range_to_environment_handles_null_environment() -> bool:
	_reset_errors()
	var applied := Map3DRendererScript.apply_visibility_range_to_environment(null, true)
	_check(not applied, "Applying visibility range to a null Environment should fail safely")
	return _errors.is_empty()


func test_hidden_preview_defers_mesh_refresh_until_reactivated() -> bool:
	_reset_errors()
	var fixture := _create_renderer_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var terrain_mesh := fixture["terrain_mesh"] as MeshInstance3D
	var event_system := fixture["event_system"] as EventSystemStub
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub
	var editor_state := fixture["editor_state"] as EditorStateStub
	renderer._apply_pending_refresh()
	_check(terrain_mesh.mesh != null, "Expected visible preview startup to build an initial terrain mesh")
	editor_state.view_mode_3d = false
	event_system.map_view_updated.emit()
	current_map_data.horizontal_sectors = 0
	current_map_data.vertical_sectors = 0
	current_map_data.hgt_map = PackedByteArray()
	current_map_data.typ_map = PackedByteArray()
	current_map_data.blg_map = PackedByteArray()
	event_system.map_updated.emit()
	_check(renderer.has_pending_refresh(), "Expected hidden preview map updates to stay pending instead of rebuilding immediately")
	_check(terrain_mesh.mesh != null, "Expected hidden preview updates to preserve the previously built mesh until 3D view is shown again")
	editor_state.view_mode_3d = true
	event_system.map_view_updated.emit()
	renderer._apply_pending_refresh()
	_check(not renderer.has_pending_refresh(), "Expected pending hidden-preview refresh to clear after the preview is reactivated")
	_check(terrain_mesh.mesh == null, "Expected deferred refresh to apply the now-invalid map data once the preview becomes visible again")
	_dispose_renderer_fixture(fixture)
	return _errors.is_empty()

func run() -> int:
	var failures := 0
	var tests := [
		"test_apply_visibility_range_to_environment_enables_black_depth_fog",
		"test_visibility_range_config_clamps_fade_start_to_zero",
		"test_apply_visibility_range_to_environment_handles_null_environment",
		"test_hidden_preview_defers_mesh_refresh_until_reactivated",
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
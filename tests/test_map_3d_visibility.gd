extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")

var _errors: Array[String] = []


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated
	signal map_3d_overlay_animations_changed


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
	renderer.set_preloads_override(null)
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


func _create_textured_renderer_fixture(view_mode_3d: bool = true) -> Dictionary:
	var host := Node3D.new()
	host.name = "Map3DRendererTexturedVisibilityHost"
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
	renderer.set_preloads_override(Preloads)
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


func _configure_flat_map(current_map_data: CurrentMapDataStub, w: int, h: int, typ_value: int = 0) -> void:
	current_map_data.horizontal_sectors = w
	current_map_data.vertical_sectors = h
	current_map_data.hgt_map = PackedByteArray()
	current_map_data.hgt_map.resize((w + 2) * (h + 2))
	current_map_data.typ_map = PackedByteArray()
	current_map_data.typ_map.resize(w * h)
	current_map_data.blg_map = PackedByteArray()
	current_map_data.blg_map.resize(w * h)
	for i in current_map_data.typ_map.size():
		current_map_data.typ_map[i] = typ_value


func _count_overlay_children_with_instance_prefix(renderer: Map3DRenderer, prefix: String) -> int:
	var overlay := renderer.get_node_or_null("AuthoredOverlay") as Node3D
	if overlay == null:
		return 0
	var count := 0
	for child in overlay.get_children():
		if child == null or not child.has_meta("instance_key"):
			continue
		if String(child.get_meta("instance_key")).begins_with(prefix):
			count += 1
	return count


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


func _drain_renderer_work(renderer: Map3DRenderer, timeout_ms: int = 10000) -> bool:
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < timeout_ms:
		renderer._process(0.016)
		var state := renderer.get_build_state_snapshot()
		if not bool(state.get("is_building_3d", false)) and not renderer.has_pending_refresh():
			return true
	return false


func _drain_renderer_until_build_idle(renderer: Map3DRenderer, timeout_ms: int = 10000) -> bool:
	var start_msec := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < timeout_ms:
		renderer._process(0.016)
		var state := renderer.get_build_state_snapshot()
		if not bool(state.get("is_building_3d", false)):
			return true
	return false


func test_hidden_async_completion_queues_full_overlay_refresh_for_reactivation() -> bool:
	_reset_errors()
	var fixture := _create_textured_renderer_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system := fixture["event_system"] as EventSystemStub
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub
	var editor_state := fixture["editor_state"] as EditorStateStub
	_configure_flat_map(current_map_data, 24, 24)

	event_system.map_created.emit()
	renderer._apply_pending_refresh()
	_check(bool(renderer.get_build_state_snapshot().get("is_building_3d", false)), "Expected initial 3D map creation to start async chunk rendering")

	editor_state.view_mode_3d = false
	event_system.map_view_updated.emit()
	_check(_drain_renderer_until_build_idle(renderer), "Expected hidden initial async rendering to finish")
	var hidden_metrics := renderer.get_last_build_metrics()
	_check(bool(hidden_metrics.get("defer_full_overlay_refresh", false)), "Expected initial async overlay pass to defer a full overlay refresh")
	_check(renderer.has_pending_refresh(), "Expected hidden async completion to keep the deferred full overlay refresh queued")
	var hidden_slurp_count := _count_overlay_children_with_instance_prefix(renderer, "slurp:")

	editor_state.view_mode_3d = true
	event_system.map_view_updated.emit()
	renderer._apply_pending_refresh()
	_check(_drain_renderer_work(renderer), "Expected reactivated 3D preview to apply the deferred full overlay refresh")

	var reactivated_slurp_count := _count_overlay_children_with_instance_prefix(renderer, "slurp:")
	_check(not renderer.has_pending_refresh(), "Expected reactivated full overlay refresh to clear the pending state")
	_check(reactivated_slurp_count > hidden_slurp_count, "Expected reactivation to restore full slurp sector-border overlays")
	_dispose_renderer_fixture(fixture)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_apply_visibility_range_to_environment_enables_black_depth_fog",
		"test_visibility_range_config_clamps_fade_start_to_zero",
		"test_apply_visibility_range_to_environment_handles_null_environment",
		"test_hidden_preview_defers_mesh_refresh_until_reactivated",
		"test_hidden_async_completion_queues_full_overlay_refresh_for_reactivation",
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

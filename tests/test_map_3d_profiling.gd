extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const BenchmarkRunner = preload("res://tests/run_map_3d_benchmarks.gd")

var _errors: Array[String] = []


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated
	signal map_3d_overlay_animations_changed
	signal hgt_map_cells_edited(border_indices: Array)
	signal typ_map_cells_edited(typ_indices: Array)
	signal blg_map_cells_edited(blg_indices: Array)


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


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


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


static func _count_named_children(parent: Node, prefix: String) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child != null and String(child.name).begins_with(prefix):
			count += 1
	return count


func _make_zero_filled_packed_byte_array(size: int) -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(size)
	for i in range(size):
		arr[i] = 0
	return arr


func test_hgt_edit_triggers_incremental_chunk_rebuild() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system: EventSystemStub = fixture["event_system"]
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub

	var w := 8
	var h := 8
	current_map_data.horizontal_sectors = w
	current_map_data.vertical_sectors = h
	current_map_data.hgt_map = _make_zero_filled_packed_byte_array((w + 2) * (h + 2))
	current_map_data.typ_map = _make_zero_filled_packed_byte_array(w * h)
	current_map_data.blg_map = _make_zero_filled_packed_byte_array(w * h)

	# Seed chunk nodes via map_created so the initial state uses the chunked path.
	event_system.map_created.emit()
	renderer._apply_pending_refresh()

	var terrain_mesh := renderer.get_node_or_null("TerrainMesh")
	var edge_mesh := renderer.get_node_or_null("EdgeMesh")
	var before_terrain_chunks := _count_named_children(terrain_mesh, "TerrainChunk_")
	var before_edge_chunks := _count_named_children(edge_mesh, "EdgeChunk_")

	# Pick a deterministic border cell and edit its height.
	var border_idx := 0 # (0,0) corner of the border footprint
	current_map_data.hgt_map[border_idx] = 1
	event_system.hgt_map_cells_edited.emit([border_idx])

	# Build immediately to avoid relying on deferred refresh scheduling in headless tests.
	renderer.build_from_current_map()
	var metrics := renderer.get_last_build_metrics()
	_check(bool(metrics.get("incremental_rebuild", false)), "Expected hgt edit to use incremental chunk rebuild")
	_check(int(metrics.get("chunks_rebuilt", 0)) > 0, "Expected at least one chunk to be rebuilt")

	var after_terrain_chunks := _count_named_children(terrain_mesh, "TerrainChunk_")
	var after_edge_chunks := _count_named_children(edge_mesh, "EdgeChunk_")
	_check(after_terrain_chunks >= before_terrain_chunks, "Terrain chunk node count should not regress across hgt edit")
	_check(after_edge_chunks >= before_edge_chunks, "Edge chunk node count should not regress across hgt edit")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_typ_edit_triggers_incremental_chunk_rebuild() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system: EventSystemStub = fixture["event_system"]
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub

	var w := 8
	var h := 8
	current_map_data.horizontal_sectors = w
	current_map_data.vertical_sectors = h
	current_map_data.hgt_map = _make_zero_filled_packed_byte_array((w + 2) * (h + 2))
	current_map_data.typ_map = _make_zero_filled_packed_byte_array(w * h)
	current_map_data.blg_map = _make_zero_filled_packed_byte_array(w * h)

	event_system.map_created.emit()
	renderer._apply_pending_refresh()

	# Edit a single typ cell.
	var sx := 3
	var sy := 4
	var typ_idx := sy * w + sx
	current_map_data.typ_map[typ_idx] = 1
	event_system.typ_map_cells_edited.emit([typ_idx])

	renderer.build_from_current_map()
	var metrics := renderer.get_last_build_metrics()
	_check(bool(metrics.get("incremental_rebuild", false)), "Expected typ edit to use incremental chunk rebuild")
	_check(int(metrics.get("chunks_rebuilt", 0)) > 0, "Expected at least one chunk to be rebuilt")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_first_local_edit_after_full_build_stays_local() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system: EventSystemStub = fixture["event_system"]
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub

	var w := 6
	var h := 6
	current_map_data.horizontal_sectors = w
	current_map_data.vertical_sectors = h
	current_map_data.hgt_map = _make_zero_filled_packed_byte_array((w + 2) * (h + 2))
	current_map_data.typ_map = _make_zero_filled_packed_byte_array(w * h)
	current_map_data.blg_map = _make_zero_filled_packed_byte_array(w * h)

	renderer.build_from_current_map()
	renderer.build_from_current_map()

	var terrain_mesh := renderer.get_node_or_null("TerrainMesh")
	var expected_chunk_count := Map3DRendererScript.TerrainBuilder.all_chunks_for_map(w, h).size()
	_check_eq(_count_named_children(terrain_mesh, "TerrainChunk_"), expected_chunk_count, "Expected full build to seed terrain chunk nodes directly")

	var sx := 1
	var sy := 1
	var typ_idx := sy * w + sx
	current_map_data.typ_map[typ_idx] = 1
	event_system.typ_map_cells_edited.emit([typ_idx])
	renderer.build_from_current_map()

	var metrics := renderer.get_last_build_metrics()
	_check(bool(metrics.get("incremental_rebuild", false)), "Expected the first local edit after a full build to use incremental chunk rebuild")
	_check_eq(int(metrics.get("chunks_rebuilt", 0)), 1, "Expected the first local edit after a full build to stay localized to one chunk")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_typ_edit_uses_localized_overlay_refresh() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system: EventSystemStub = fixture["event_system"]
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub

	var w := 6
	var h := 6
	current_map_data.horizontal_sectors = w
	current_map_data.vertical_sectors = h
	current_map_data.hgt_map = _make_zero_filled_packed_byte_array((w + 2) * (h + 2))
	current_map_data.typ_map = _make_zero_filled_packed_byte_array(w * h)
	current_map_data.blg_map = _make_zero_filled_packed_byte_array(w * h)

	renderer.build_from_current_map()
	renderer.build_from_current_map()

	var typ_idx := 2 * w + 2
	current_map_data.typ_map[typ_idx] = 1
	event_system.typ_map_cells_edited.emit([typ_idx])
	renderer.build_from_current_map()

	var metrics := renderer.get_last_build_metrics()
	_check(bool(metrics.get("localized_overlay_refresh", false)), "Expected localized typ edit to use localized overlay refresh")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_visible_refresh_records_stage_timings_with_preloads() -> bool:
	_reset_errors()
	var fixture := _create_fixture(true)
	var renderer := fixture["renderer"] as Map3DRenderer
	renderer._apply_pending_refresh()
	_check(BenchmarkRunner.drain_renderer_work(renderer), "Expected visible refresh profiling fixture to finish async renderer work")
	var metrics := renderer.get_last_build_metrics()
	_check_metric_keys(metrics)
	_check(bool(metrics.get("used_textured_preloads", false)), "Expected textured-path profiling to record Preloads usage")
	_check(float(metrics.get("build_total_ms", 0.0)) > 0.0, "Expected async visible refresh profiling to record positive total build timing")
	_check(float(metrics.get("refresh_end_to_end_ms", 0.0)) > 0.0, "Expected async visible refresh profiling to record positive refresh end-to-end timing")
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
		"test_hgt_edit_triggers_incremental_chunk_rebuild",
		"test_typ_edit_triggers_incremental_chunk_rebuild",
		"test_first_local_edit_after_full_build_stays_local",
		"test_typ_edit_uses_localized_overlay_refresh",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

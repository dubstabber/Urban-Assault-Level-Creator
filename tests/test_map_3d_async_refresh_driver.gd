extends RefCounted

const DriverScript = preload("res://map/3d/runtime/map_3d_async_refresh_driver.gd")


class RendererStub extends Node3D:
	signal build_state_changed(is_building: bool, completed: int, total: int, status: String)
	signal build_finished(success: bool)
	const _MAX_INCREMENTAL_UNIT_BATCH := 2
	const _ASYNC_APPLY_RESULTS_PER_FRAME := 4
	const _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 8

	func _apply_pending_refresh() -> void:
		pass

	func emit_build_state_changed(is_building: bool, completed: int, total: int, status: String) -> void:
		build_state_changed.emit(is_building, completed, total, status)

	func emit_build_finished(success: bool) -> void:
		build_finished.emit(success)

	func defer_apply_pending_refresh() -> void:
		_apply_pending_refresh()

	func max_incremental_unit_batch() -> int:
		return _MAX_INCREMENTAL_UNIT_BATCH

	func async_chunk_apply_budget() -> int:
		return _ASYNC_APPLY_RESULTS_PER_FRAME

	func async_overlay_apply_budget(_descriptor_count: int = 0) -> int:
		return _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME

	func sector_size() -> float:
		return 1.0

	func height_scale() -> float:
		return 1.0

	func normal_geometry_cull_distance() -> float:
		return 5.5


class MapDataStub extends Node:
	var horizontal_sectors := 8
	var vertical_sectors := 8
	var level_set := 1
	var hgt_map := PackedByteArray()
	var typ_map := PackedByteArray()
	var blg_map := PackedByteArray()


class ChunkRuntimeStub extends RefCounted:
	var chunked_terrain_enabled := false
	var initial_build_in_progress := false
	var last_map_dimensions := Vector2i.ZERO
	var last_level_set := -1
	var _has_dirty_chunks := false
	var support_descriptors: Array = []

	func has_dirty_chunks() -> bool:
		return _has_dirty_chunks

	func get_support_descriptors() -> Array:
		return support_descriptors

	func erase_dirty_chunk(_chunk_coord: Vector2i) -> void:
		pass


class ContextPortStub extends RefCounted:
	var preview_active := true
	var current_map: Node = null

	func preview_refresh_active() -> bool:
		return preview_active

	func current_map_data() -> Node:
		return current_map

	func current_game_data_type() -> String:
		return "original"

	func preloads() -> Node:
		return null


class ScenePortStub extends RefCounted:
	var bump_calls := 0
	var terrain_chunks := {}
	var edge_chunks := {}
	var authored_overlay_root: Node3D = Node3D.new()
	var dynamic_overlay_root: Node3D = Node3D.new()

	func bump_3d_viewport_rendering() -> void:
		bump_calls += 1

	func is_inside_tree() -> bool:
		return true

	func terrain_chunk_nodes() -> Dictionary:
		return terrain_chunks

	func edge_chunk_nodes() -> Dictionary:
		return edge_chunks

	func ensure_overlay_nodes() -> void:
		pass

	func dynamic_overlay() -> Node3D:
		return dynamic_overlay_root

	func authored_overlay() -> Node3D:
		return authored_overlay_root

	func apply_geometry_distance_culling_to_overlay() -> void:
		pass


class BuildPortStub extends RefCounted:
	var pipeline_active := false
	var build_from_current_map_calls := 0
	var cancel_calls := 0
	var set_camera_framed_values: Array = []
	var frame_if_needed_calls := 0
	var worker_state := {}
	var overlay_descriptor_state := {}
	var overlay_stage := ""
	var chunk_runtime_ref := ChunkRuntimeStub.new()

	func is_async_pipeline_active(_overlay_apply_active: bool = false) -> bool:
		return pipeline_active

	func cancel_async_build(_overlay_apply_active: bool = false) -> void:
		cancel_calls += 1

	func cancel_async_initial_build() -> void:
		cancel_calls += 1

	func build_from_current_map() -> void:
		build_from_current_map_calls += 1

	func set_camera_framed(value: bool) -> void:
		set_camera_framed_values.append(value)

	func frame_if_needed() -> void:
		frame_if_needed_calls += 1

	func chunk_runtime():
		return chunk_runtime_ref

	func compute_effective_typ_for_map(_cmd: Node, _w: int, _h: int, typ: PackedByteArray, _blg: PackedByteArray, _game_data_type: String) -> PackedByteArray:
		return typ

	func edge_overlay_enabled() -> bool:
		return true

	func needs_full_rebuild(_w: int, _h: int, _level_set: int) -> bool:
		return false

	func invalidate_all_chunks(_w: int, _h: int) -> void:
		pass

	func dirty_chunks_sorted_by_priority(_w: int, _h: int) -> Array[Vector2i]:
		return []

	func coordinator():
		return self

	func reset_async_state() -> void:
		pass

	func is_async_build_active() -> bool:
		return false

	func is_async_overlay_descriptor_active() -> bool:
		return false

	func is_async_cancel_requested(_generation_id: int) -> bool:
		return false

	func set_async_worker_state(done: bool, failed: bool, message: String) -> void:
		worker_state = {"done": done, "failed": failed, "error": message}

	func get_async_worker_state() -> Dictionary:
		return worker_state

	func set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
		overlay_descriptor_state = {
			"done": done,
			"failed": failed,
			"result": result,
			"metrics": metrics,
		}

	func get_async_overlay_descriptor_state() -> Dictionary:
		return overlay_descriptor_state

	func set_async_overlay_descriptor_stage(stage: String) -> void:
		overlay_stage = stage

	func get_async_overlay_descriptor_stage() -> String:
		return overlay_stage

	func apply_dynamic_overlay(_descriptors: Array) -> void:
		pass

	func unit_runtime_index():
		return self

	func static_overlay_index():
		return self

	func replace_all(_descriptors: Array) -> void:
		pass

	func overlay_apply_manager():
		return self

	func localized_overlay_sector_list() -> Array[Vector2i]:
		return []

	func localized_dynamic_sector_list() -> Array[Vector2i]:
		return []

	func geometry_distance_culling_enabled() -> bool:
		return false

	func make_empty_build_metrics() -> Dictionary:
		return {}

	func elapsed_ms_since(_started_usec: int) -> float:
		return 0.0

	func finalize_build_metrics(_metrics: Dictionary, _build_started_usec: int) -> void:
		pass

	func apply_changes(_cmd: Node, _changes: Array) -> void:
		pass


var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _bind_driver(context: Variant = null, scene: Variant = null, build: Variant = null):
	var driver = DriverScript.new()
	var port = build if build != null else BuildPortStub.new()
	driver.bind(
		RendererStub.new(),
		context if context != null else ContextPortStub.new(),
		scene if scene != null else ScenePortStub.new(),
		port,
		port,
		port,
		port,
		port
	)
	return driver


func test_request_refresh_falls_back_to_sync_build_when_async_paths_are_unavailable() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var scene := ScenePortStub.new()
	var build := BuildPortStub.new()
	var driver = _bind_driver(context, scene, build)
	driver.request_refresh(true)
	driver.apply_pending_refresh()
	_check(build.build_from_current_map_calls == 1, "Expected fallback build path to invoke build_from_current_map once")
	_check(scene.bump_calls == 1, "Expected fallback build path to bump the 3D viewport")
	_check(build.set_camera_framed_values == [false], "Expected reframe request to clear the framed flag before framing")
	_check(build.frame_if_needed_calls == 1, "Expected reframe request to frame the camera after sync build")
	return _errors.is_empty()


func test_can_use_overlay_only_refresh_requires_scene_state_and_matching_map_signature() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var scene := ScenePortStub.new()
	var build := BuildPortStub.new()
	var map_data := MapDataStub.new()
	context.current_map = map_data
	build.chunk_runtime_ref.last_map_dimensions = Vector2i(8, 8)
	build.chunk_runtime_ref.last_level_set = 1
	scene.terrain_chunks[Vector2i(0, 0)] = MeshInstance3D.new()
	var driver = _bind_driver(context, scene, build)
	_check(driver.can_use_overlay_only_refresh(), "Expected overlay-only refresh to be allowed for matching dimensions, level set, and existing chunk nodes")
	scene.terrain_chunks.clear()
	_check(not driver.can_use_overlay_only_refresh(), "Expected overlay-only refresh to be rejected when no chunk nodes are present")
	return _errors.is_empty()


func test_normalize_unit_changes_deduplicates_by_kind_and_unit_id() -> bool:
	_reset_errors()
	var driver = _bind_driver()
	var normalized := driver.normalize_unit_changes([
		{"kind": "squad", "unit_id": 5, "action": "created"},
		{"kind": "squad", "unit_id": 5, "action": "visual"},
		{"kind": "host", "unit_id": 9, "action": "moved"},
		{"kind": "", "unit_id": 0, "action": "broken"},
	])
	_check(normalized.size() == 2, "Expected duplicate unit changes to collapse to one entry per kind/unit_id pair")
	var by_key := {}
	for change in normalized:
		by_key["%s:%d" % [change["kind"], change["unit_id"]]] = change["action"]
	_check(by_key.get("squad:5", "") == "visual", "Expected the later squad action to win during normalization")
	_check(by_key.get("host:9", "") == "moved", "Expected the host move action to be preserved")
	return _errors.is_empty()


func test_flush_pending_unit_changes_requests_dynamic_overlay_refresh_for_large_batches() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	var build := BuildPortStub.new()
	var driver = _bind_driver(context, ScenePortStub.new(), build)
	driver.enqueue_pending_unit_changes([
		{"kind": "squad", "unit_id": 1, "action": "visual"},
		{"kind": "squad", "unit_id": 2, "action": "visual"},
		{"kind": "squad", "unit_id": 3, "action": "visual"},
	])
	_check(driver.flush_pending_unit_changes(), "Expected pending unit changes to be consumed")
	_check(driver._dynamic_overlay_refresh_requested, "Expected oversized pending batches to request a dynamic overlay refresh")
	_check(driver.has_pending_refresh(), "Expected oversized pending batches to queue a refresh")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_request_refresh_falls_back_to_sync_build_when_async_paths_are_unavailable",
		"test_can_use_overlay_only_refresh_requires_scene_state_and_matching_map_signature",
		"test_normalize_unit_changes_deduplicates_by_kind_and_unit_id",
		"test_flush_pending_unit_changes_requests_dynamic_overlay_refresh_for_large_batches",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

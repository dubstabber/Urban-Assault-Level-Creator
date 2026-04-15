extends RefCounted

const ControllerScript = preload("res://map/3d/controllers/map_3d_renderer_event_controller.gd")


class RendererStub extends Node3D:
	var map_created_calls := 0
	var map_updated_calls := 0
	var map_view_updated_calls := 0
	var overlay_animation_calls := 0
	var hgt_edit_calls := 0
	var typ_edit_calls := 0
	var blg_edit_calls := 0
	var focus_calls := 0
	var units_changed_calls := 0
	var unit_position_calls := 0
	var unit_overlay_refresh_calls := 0

	func _on_map_created() -> void:
		map_created_calls += 1

	func _on_map_updated() -> void:
		map_updated_calls += 1

	func _on_map_view_updated() -> void:
		map_view_updated_calls += 1

	func _on_map_3d_overlay_animations_changed() -> void:
		overlay_animation_calls += 1

	func _on_hgt_map_cells_edited(_indices: Array) -> void:
		hgt_edit_calls += 1

	func _on_typ_map_cells_edited(_indices: Array) -> void:
		typ_edit_calls += 1

	func _on_blg_map_cells_edited(_indices: Array) -> void:
		blg_edit_calls += 1

	func _on_map_3d_focus_sector_requested(_sx: int, _sy: int) -> void:
		focus_calls += 1

	func _on_units_changed(_changes: Array) -> void:
		units_changed_calls += 1

	func _on_unit_position_committed(_unit_kind: String, _unit_id: int) -> void:
		unit_position_calls += 1

	func _on_unit_overlay_refresh_requested(_unit_kind: String, _unit_id: int) -> void:
		unit_overlay_refresh_calls += 1


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated
	signal map_3d_focus_sector_requested(sector_sx, sector_sy)
	signal map_3d_overlay_animations_changed
	signal units_changed(changes)
	signal unit_position_committed(unit_kind, unit_id)
	signal unit_overlay_refresh_requested(unit_kind, unit_id)
	signal hgt_map_cells_edited(indices)
	signal typ_map_cells_edited(indices)
	signal blg_map_cells_edited(indices)


class MapDataStub extends Node:
	var horizontal_sectors := 8
	var vertical_sectors := 8
	var level_set := 2
	var hgt_map := PackedByteArray([1])


class ChunkRuntimeStub extends RefCounted:
	var last_map_dimensions := Vector2i.ZERO
	var last_level_set := -1
	var clear_dirty_chunks_calls := 0
	var clear_authored_caches_calls := 0
	var invalidate_all_chunks_calls: Array = []
	var initial_build_in_progress := false
	var initial_build_accumulated_authored_descriptors: Array = []

	func take_localized_chunk_invalidation_pending() -> bool:
		return false

	func clear_dirty_chunks() -> void:
		clear_dirty_chunks_calls += 1

	func clear_authored_caches() -> void:
		clear_authored_caches_calls += 1

	func invalidate_all_chunks(w: int, h: int) -> void:
		invalidate_all_chunks_calls.append(Vector2i(w, h))


class EffectiveTypServiceStub extends RefCounted:
	var invalidate_cache_calls := 0
	var set_dirty_values: Array = []

	func invalidate_cache() -> void:
		invalidate_cache_calls += 1

	func set_dirty(value: bool) -> void:
		set_dirty_values.append(value)


class ContextPortStub extends RefCounted:
	var event_system_ref := EventSystemStub.new()
	var current_map_ref: Node = null
	var preview_active := true

	func event_system() -> Node:
		return event_system_ref

	func current_map_data() -> Node:
		return current_map_ref

	func preview_refresh_active() -> bool:
		return preview_active


class ScenePortStub extends RefCounted:
	var ensure_edge_node_calls := 0
	var set_camera_current_values: Array = []
	var clear_chunk_nodes_calls := 0
	var set_authored_overlay_values: Array = []

	func get_node_or_null(_path: NodePath) -> Node:
		return null

	func ensure_edge_node() -> void:
		ensure_edge_node_calls += 1

	func set_camera_current(current: bool) -> void:
		set_camera_current_values.append(current)

	func bump_3d_viewport_rendering() -> void:
		pass

	func clear_chunk_nodes() -> void:
		clear_chunk_nodes_calls += 1

	func set_authored_overlay(descriptors: Array) -> void:
		set_authored_overlay_values.append(descriptors.duplicate(true))


class OverlayScopeStub extends RefCounted:
	var recorded_dirty_sectors: Array = []
	var clear_calls := 0

	func record_sectors(sectors: Array) -> void:
		recorded_dirty_sectors.append(sectors.duplicate())

	func clear() -> void:
		clear_calls += 1


class RuntimeStateStub extends RefCounted:
	var sector_top_shader: Shader = null
	var edge_blend_shader: Shader = null
	var skip_next_map_changed_refresh := false


class AsyncRefreshDriverStub extends RefCounted:
	var request_refresh_values: Array = []
	var apply_pending_refresh_calls := 0
	var request_overlay_only_refresh_calls := 0
	var flush_pending_unit_changes_calls := 0
	var pending_refresh := false

	func request_refresh(reframe_camera: bool) -> void:
		request_refresh_values.append(reframe_camera)

	func apply_pending_refresh() -> void:
		apply_pending_refresh_calls += 1

	func request_overlay_only_refresh() -> void:
		request_overlay_only_refresh_calls += 1

	func flush_pending_unit_changes() -> bool:
		flush_pending_unit_changes_calls += 1
		return true

	func has_pending_refresh() -> bool:
		return pending_refresh


class RendererNodeStub extends RendererStub:
	var apply_preview_activity_state_calls := 0
	var apply_visibility_range_calls := 0
	var cancel_async_initial_build_calls := 0
	var is_map_signature_changed_value := false
	var recorded_signatures: Array = []
	var marked_chunks_dirty: Array = []

	func _apply_preview_activity_state() -> void:
		apply_preview_activity_state_calls += 1

	func _apply_visibility_range_from_editor_state() -> void:
		apply_visibility_range_calls += 1

	func _cancel_async_initial_build() -> void:
		cancel_async_initial_build_calls += 1

	func _is_map_signature_changed(_w: int, _h: int, _level_set: int, _hgt: PackedByteArray, _typ: PackedByteArray, _blg: PackedByteArray) -> bool:
		return is_map_signature_changed_value

	func _record_map_signature(w: int, h: int, level_set: int, _hgt: PackedByteArray, _typ: PackedByteArray, _blg: PackedByteArray) -> void:
		recorded_signatures.append({"w": w, "h": h, "level_set": level_set})

	func mark_chunks_dirty(chunk_coords: Array) -> void:
		marked_chunks_dirty.append(chunk_coords.duplicate())


var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _bind_controller(context: Variant = null, scene: Variant = null, renderer: Variant = null, async_driver: Variant = null, chunk_runtime: Variant = null, effective_typ_service: Variant = null, overlay_scope: Variant = null, runtime_state: Variant = null):
	var controller = ControllerScript.new()
	controller.bind(
		renderer if renderer != null else RendererNodeStub.new(),
		context if context != null else ContextPortStub.new(),
		scene if scene != null else ScenePortStub.new(),
		async_driver if async_driver != null else AsyncRefreshDriverStub.new(),
		chunk_runtime if chunk_runtime != null else ChunkRuntimeStub.new(),
		effective_typ_service if effective_typ_service != null else EffectiveTypServiceStub.new(),
		overlay_scope if overlay_scope != null else OverlayScopeStub.new(),
		runtime_state if runtime_state != null else RuntimeStateStub.new()
	)
	return controller


func test_ready_connects_event_system_signals_to_renderer_handlers() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	context.current_map_ref = MapDataStub.new()
	var renderer := RendererNodeStub.new()
	var scene := ScenePortStub.new()
	var async_driver := AsyncRefreshDriverStub.new()
	var chunk_runtime := ChunkRuntimeStub.new()
	var effective_typ_service := EffectiveTypServiceStub.new()
	var overlay_scope := OverlayScopeStub.new()
	var runtime_state := RuntimeStateStub.new()
	var controller = ControllerScript.new()
	controller.bind(renderer, context, scene, async_driver, chunk_runtime, effective_typ_service, overlay_scope, runtime_state)
	controller.ready()
	context.event_system_ref.map_created.emit()
	context.event_system_ref.map_updated.emit()
	context.event_system_ref.map_view_updated.emit()
	context.event_system_ref.map_3d_overlay_animations_changed.emit()
	context.event_system_ref.hgt_map_cells_edited.emit([0])
	context.event_system_ref.typ_map_cells_edited.emit([0])
	context.event_system_ref.blg_map_cells_edited.emit([0])
	context.event_system_ref.map_3d_focus_sector_requested.emit(1, 2)
	context.event_system_ref.units_changed.emit([])
	context.event_system_ref.unit_position_committed.emit("host", 1)
	context.event_system_ref.unit_overlay_refresh_requested.emit("host", 1)
	_check(renderer.map_created_calls == 1, "Expected map_created signal to reach the renderer handler")
	_check(renderer.map_updated_calls == 1, "Expected map_updated signal to reach the renderer handler")
	_check(renderer.map_view_updated_calls == 1, "Expected map_view_updated signal to reach the renderer handler")
	_check(renderer.overlay_animation_calls == 1, "Expected overlay animation signal to reach the renderer handler")
	_check(renderer.hgt_edit_calls == 1 and renderer.typ_edit_calls == 1 and renderer.blg_edit_calls == 1, "Expected map cell edit signals to reach the renderer handlers")
	_check(renderer.focus_calls == 1, "Expected focus-sector signal to reach the renderer handler")
	_check(renderer.units_changed_calls == 1, "Expected units_changed signal to reach the renderer handler")
	_check(renderer.unit_position_calls == 1, "Expected unit_position_committed signal to reach the renderer handler")
	_check(renderer.unit_overlay_refresh_calls == 1, "Expected unit_overlay_refresh_requested signal to reach the renderer handler")
	_check(renderer.apply_preview_activity_state_calls == 1, "Expected ready() to apply preview activity state once")
	_check(renderer.apply_visibility_range_calls == 1, "Expected ready() to apply visibility range once")
	_check(async_driver.request_refresh_values == [true], "Expected ready() to request an initial refresh when map data already exists")
	return _errors.is_empty()


func test_on_map_created_resets_runtime_and_requests_refresh() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	context.current_map_ref = MapDataStub.new()
	var scene := ScenePortStub.new()
	var renderer := RendererNodeStub.new()
	var async_driver := AsyncRefreshDriverStub.new()
	var chunk_runtime := ChunkRuntimeStub.new()
	var effective_typ_service := EffectiveTypServiceStub.new()
	var overlay_scope := OverlayScopeStub.new()
	var controller = _bind_controller(context, scene, renderer, async_driver, chunk_runtime, effective_typ_service, overlay_scope)
	controller.on_map_created()
	_check(renderer.cancel_async_initial_build_calls == 1, "Expected map creation to cancel any in-flight async build")
	_check(effective_typ_service.invalidate_cache_calls == 1, "Expected map creation to invalidate the effective typ cache")
	_check(effective_typ_service.set_dirty_values == [true], "Expected map creation to mark the effective typ cache dirty")
	_check(chunk_runtime.last_map_dimensions == Vector2i(8, 8), "Expected map creation to seed the last map dimensions")
	_check(chunk_runtime.last_level_set == 2, "Expected map creation to seed the last level set")
	_check(scene.clear_chunk_nodes_calls == 1, "Expected map creation to clear existing chunk nodes")
	_check(scene.set_authored_overlay_values.size() == 1 and scene.set_authored_overlay_values[0].is_empty(), "Expected map creation to clear the authored overlay")
	_check(overlay_scope.clear_calls == 1, "Expected map creation to clear localized overlay scope")
	_check(chunk_runtime.clear_dirty_chunks_calls == 1, "Expected map creation to clear dirty chunks")
	_check(chunk_runtime.clear_authored_caches_calls == 1, "Expected map creation to clear authored caches")
	_check(chunk_runtime.invalidate_all_chunks_calls == [Vector2i(8, 8)], "Expected map creation to invalidate every chunk for the new map")
	_check(chunk_runtime.initial_build_in_progress, "Expected map creation to mark initial chunk build as in progress")
	_check(async_driver.request_refresh_values == [true], "Expected map creation to request a reframing refresh")
	return _errors.is_empty()


func test_on_hgt_map_cells_edited_marks_chunks_and_sectors_without_dirtying_effective_typ() -> bool:
	_reset_errors()
	var context := ContextPortStub.new()
	context.current_map_ref = MapDataStub.new()
	var renderer := RendererNodeStub.new()
	var chunk_runtime := ChunkRuntimeStub.new()
	var effective_typ_service := EffectiveTypServiceStub.new()
	var overlay_scope := OverlayScopeStub.new()
	var controller = _bind_controller(context, ScenePortStub.new(), renderer, AsyncRefreshDriverStub.new(), chunk_runtime, effective_typ_service, overlay_scope)
	controller.on_hgt_map_cells_edited([0])
	_check(renderer.cancel_async_initial_build_calls == 1, "Expected HGT edits to cancel any active async build")
	_check(effective_typ_service.set_dirty_values == [false], "Expected HGT edits to keep the effective typ cache reusable")
	_check(renderer.marked_chunks_dirty.size() == 1 and renderer.marked_chunks_dirty[0].has(Vector2i(0, 0)), "Expected HGT edits to mark the affected chunk dirty")
	_check(overlay_scope.recorded_dirty_sectors.size() == 1 and overlay_scope.recorded_dirty_sectors[0].has(Vector2i(0, 0)), "Expected HGT edits to record the affected sector for localized overlay refresh")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_ready_connects_event_system_signals_to_renderer_handlers",
		"test_on_map_created_resets_runtime_and_requests_refresh",
		"test_on_hgt_map_cells_edited_marks_chunks_and_sectors_without_dirtying_effective_typ",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

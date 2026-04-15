extends RefCounted

const InvalidationRouter := preload("res://map/3d/services/map_3d_invalidation_router.gd")

var _renderer_node = null
var _build = null
var _context = null
var _scene = null
var _async_refresh_driver = null
var _rebuild_policy = null
var _chunk_runtime = null
var _effective_typ_service = null
var _overlay_refresh_scope = null
var _runtime_state = null


func bind(build_state_port, context_port, scene_port, async_refresh_driver, rebuild_policy, chunk_runtime, effective_typ_service, overlay_refresh_scope, runtime_state) -> void:
	_build = build_state_port
	_renderer_node = build_state_port.renderer_node()
	_context = context_port
	_scene = scene_port
	_async_refresh_driver = async_refresh_driver
	_rebuild_policy = rebuild_policy
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_overlay_refresh_scope = overlay_refresh_scope
	_runtime_state = runtime_state


func ready() -> void:
	var test_mesh = _scene.get_node_or_null("TestMesh")
	if test_mesh:
		_scene.ensure_edge_node()
		test_mesh.visible = false
	_scene.set_camera_current(true)

	var event_system = _context.event_system()
	if event_system:
		event_system.map_created.connect(Callable(_renderer_node, "_on_map_created"))
		event_system.map_updated.connect(Callable(_renderer_node, "_on_map_updated"))
		event_system.level_set_changed.connect(Callable(_renderer_node, "_on_level_set_changed"))
		event_system.map_view_updated.connect(Callable(_renderer_node, "_on_map_view_updated"))
		if event_system.has_signal("map_3d_focus_sector_requested"):
			event_system.map_3d_focus_sector_requested.connect(Callable(_renderer_node, "_on_map_3d_focus_sector_requested"))
		event_system.map_3d_overlay_animations_changed.connect(Callable(_renderer_node, "_on_map_3d_overlay_animations_changed"))
		if event_system.has_signal("units_changed"):
			event_system.units_changed.connect(Callable(_renderer_node, "_on_units_changed"))
		if event_system.has_signal("unit_position_committed"):
			event_system.unit_position_committed.connect(Callable(_renderer_node, "_on_unit_position_committed"))
		if event_system.has_signal("unit_overlay_refresh_requested"):
			event_system.unit_overlay_refresh_requested.connect(Callable(_renderer_node, "_on_unit_overlay_refresh_requested"))
		if event_system.has_signal("hgt_map_cells_edited"):
			event_system.hgt_map_cells_edited.connect(Callable(_renderer_node, "_on_hgt_map_cells_edited"))
		if event_system.has_signal("typ_map_cells_edited"):
			event_system.typ_map_cells_edited.connect(Callable(_renderer_node, "_on_typ_map_cells_edited"))
		if event_system.has_signal("blg_map_cells_edited"):
			event_system.blg_map_cells_edited.connect(Callable(_renderer_node, "_on_blg_map_cells_edited"))

	_renderer_node._apply_preview_activity_state()
	_renderer_node._apply_visibility_range_from_editor_state()
	var current_map_data = _context.current_map_data()
	if current_map_data and current_map_data.horizontal_sectors > 0 and current_map_data.vertical_sectors > 0 and not current_map_data.hgt_map.is_empty():
		_async_refresh_driver.request_refresh(true)


func request_refresh(reframe_camera: bool) -> void:
	_async_refresh_driver.request_refresh(reframe_camera)


func apply_pending_refresh() -> void:
	_async_refresh_driver.apply_pending_refresh()


func on_map_view_updated() -> void:
	_renderer_node._apply_preview_activity_state()
	_renderer_node._apply_visibility_range_from_editor_state()
	if _context.preview_refresh_active():
		_scene.bump_3d_viewport_rendering()
	if _async_refresh_driver.has_pending_refresh():
		_async_refresh_driver.request_refresh(false)
	elif _context.preview_refresh_active():
		_async_refresh_driver.flush_pending_unit_changes()


func on_map_overlay_animations_changed() -> void:
	if _context.preview_refresh_active():
		_async_refresh_driver.request_overlay_only_refresh()


func on_map_changed() -> void:
	if _runtime_state.skip_next_map_changed_refresh:
		_runtime_state.skip_next_map_changed_refresh = false
		return
	_renderer_node._cancel_async_initial_build()
	var has_localized_invalidation = _chunk_runtime.take_localized_chunk_invalidation_pending()
	var current_map_data = _context.current_map_data()
	if current_map_data:
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		if w > 0 and h > 0:
			var hgt: PackedByteArray = current_map_data.hgt_map
			var typ: PackedByteArray = current_map_data.typ_map
			var blg: PackedByteArray = current_map_data.blg_map
			var level_set = int(current_map_data.level_set)
			var signature_changed := false
			var skipped_signature_check: bool = _build.can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)
			if skipped_signature_check:
				_build.record_map_signature_metadata_only(w, h, level_set)
			else:
				signature_changed = _build.is_map_signature_changed(w, h, level_set, hgt, typ, blg)
				_build.record_map_signature(w, h, level_set, hgt, typ, blg)
			if signature_changed and not has_localized_invalidation:
				_chunk_runtime.invalidate_all_chunks(w, h)
				_effective_typ_service.set_dirty(true)
				_overlay_refresh_scope.clear()
		_async_refresh_driver.request_refresh(false)


func on_map_created() -> void:
	_renderer_node._cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data:
		_effective_typ_service.invalidate_cache()
		_effective_typ_service.set_dirty(true)
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		var level_set = int(current_map_data.level_set)
		_chunk_runtime.last_map_dimensions = Vector2i(w, h)
		_chunk_runtime.last_level_set = level_set
		_scene.clear_chunk_nodes()
		_scene.set_authored_overlay([])
		_overlay_refresh_scope.clear()
		_chunk_runtime.clear_dirty_chunks()
		_chunk_runtime.clear_authored_caches()
		_chunk_runtime.invalidate_all_chunks(w, h)
		_chunk_runtime.initial_build_in_progress = true
		_chunk_runtime.initial_build_accumulated_authored_descriptors.clear()
	_async_refresh_driver.request_refresh(true)


func on_hgt_map_cells_edited(border_indices: Array) -> void:
	_renderer_node._cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.mark_localized_signature_change(w, h, int(current_map_data.level_set))
	_effective_typ_service.set_dirty(false)
	var invalidation = InvalidationRouter.invalidation_for_hgt_border_indices(border_indices, w, h)
	_rebuild_policy.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_overlay_refresh_scope.record_sectors(invalidation.get("dirty_sectors", []))


func on_typ_map_cells_edited(typ_indices: Array) -> void:
	_renderer_node._cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.mark_localized_signature_change(w, h, int(current_map_data.level_set))
	_effective_typ_service.set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_typ_indices(typ_indices, w, h)
	_rebuild_policy.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_overlay_refresh_scope.record_sectors(invalidation.get("dirty_sectors", []))


func on_blg_map_cells_edited(blg_indices: Array) -> void:
	_renderer_node._cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.mark_localized_signature_change(w, h, int(current_map_data.level_set))
	_effective_typ_service.set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_blg_indices(blg_indices, w, h)
	_rebuild_policy.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_overlay_refresh_scope.record_sectors(invalidation.get("dirty_sectors", []))

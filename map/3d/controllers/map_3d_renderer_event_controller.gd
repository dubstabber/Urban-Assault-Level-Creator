extends RefCounted

const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"
const InvalidationRouter := preload("res://map/3d/services/map_3d_invalidation_router.gd")


func ready(renderer) -> void:
	renderer._sector_top_shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	renderer._edge_blend_shader = load(EDGE_BLEND_SHADER_PATH)

	var test_mesh = renderer.get_node_or_null("TestMesh")
	if test_mesh:
		renderer._ensure_edge_node()
		test_mesh.visible = false
	if renderer._camera:
		renderer._camera.current = true

	var event_system = renderer._event_system()
	if event_system:
		event_system.map_created.connect(renderer._on_map_created)
		event_system.map_updated.connect(renderer._on_map_updated)
		event_system.level_set_changed.connect(renderer._on_level_set_changed)
		event_system.map_view_updated.connect(renderer._on_map_view_updated)
		if event_system.has_signal("map_3d_focus_sector_requested"):
			event_system.map_3d_focus_sector_requested.connect(renderer._on_map_3d_focus_sector_requested)
		event_system.map_3d_overlay_animations_changed.connect(renderer._on_map_3d_overlay_animations_changed)
		if event_system.has_signal("units_changed"):
			event_system.units_changed.connect(renderer._on_units_changed)
		if event_system.has_signal("unit_position_committed"):
			event_system.unit_position_committed.connect(renderer._on_unit_position_committed)
		if event_system.has_signal("unit_overlay_refresh_requested"):
			event_system.unit_overlay_refresh_requested.connect(renderer._on_unit_overlay_refresh_requested)
		if event_system.has_signal("hgt_map_cells_edited"):
			event_system.hgt_map_cells_edited.connect(renderer._on_hgt_map_cells_edited)
		if event_system.has_signal("typ_map_cells_edited"):
			event_system.typ_map_cells_edited.connect(renderer._on_typ_map_cells_edited)
		if event_system.has_signal("blg_map_cells_edited"):
			event_system.blg_map_cells_edited.connect(renderer._on_blg_map_cells_edited)

	renderer._apply_preview_activity_state()
	renderer._apply_visibility_range_from_editor_state()
	var current_map_data = renderer._current_map_data()
	if current_map_data and current_map_data.horizontal_sectors > 0 and current_map_data.vertical_sectors > 0 and not current_map_data.hgt_map.is_empty():
		request_refresh(renderer, true)


func request_refresh(renderer, reframe_camera: bool) -> void:
	if not renderer._refresh_pending and renderer._refresh_requested_at_usec <= 0:
		renderer._refresh_requested_at_usec = Time.get_ticks_usec()
	renderer._refresh_pending = true
	renderer._refresh_reframe_pending = renderer._refresh_reframe_pending or reframe_camera
	if not renderer._preview_refresh_active():
		return
	if renderer._refresh_deferred:
		return
	renderer._refresh_deferred = true
	renderer.call_deferred("_apply_pending_refresh")


func apply_pending_refresh(renderer) -> void:
	renderer._refresh_deferred = false
	if not renderer._refresh_pending or not renderer._preview_refresh_active():
		return
	var reframe_camera = renderer._refresh_reframe_pending
	renderer._refresh_pending = false
	renderer._refresh_reframe_pending = false
	if renderer._is_async_pipeline_active():
		renderer._async_requested_restart = true
		renderer._async_requested_reframe = renderer._async_requested_reframe or reframe_camera
		renderer._cancel_async_initial_build()
		return
	if renderer._dynamic_overlay_refresh_requested:
		if renderer._start_async_dynamic_overlay_refresh(reframe_camera):
			return
	if renderer._overlay_only_refresh_requested or renderer._can_use_overlay_only_refresh():
		if renderer._start_async_overlay_only_refresh(reframe_camera):
			return
	if renderer._try_start_async_initial_build(reframe_camera):
		return
	renderer.build_from_current_map()
	renderer._bump_3d_viewport_rendering()
	if reframe_camera and renderer.is_inside_tree():
		renderer._framed = false
		renderer._frame_if_needed()


func on_map_view_updated(renderer) -> void:
	renderer._apply_preview_activity_state()
	renderer._apply_visibility_range_from_editor_state()
	if renderer._preview_refresh_active():
		renderer._bump_3d_viewport_rendering()
	if renderer._refresh_pending:
		request_refresh(renderer, renderer._refresh_reframe_pending)
	elif renderer._preview_refresh_active():
		renderer._flush_pending_unit_changes()


func on_map_overlay_animations_changed(renderer) -> void:
	if renderer._preview_refresh_active():
		renderer._request_overlay_only_refresh()


func on_map_changed(renderer) -> void:
	if renderer._skip_next_map_changed_refresh:
		renderer._skip_next_map_changed_refresh = false
		return
	renderer._cancel_async_initial_build()
	var has_localized_invalidation = renderer._chunk_rt.take_localized_chunk_invalidation_pending()
	var current_map_data = renderer._current_map_data()
	if current_map_data:
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		if w > 0 and h > 0:
			var hgt: PackedByteArray = current_map_data.hgt_map
			var typ: PackedByteArray = current_map_data.typ_map
			var blg: PackedByteArray = current_map_data.blg_map
			var level_set = int(current_map_data.level_set)
			var signature_changed = renderer._is_map_signature_changed(w, h, level_set, hgt, typ, blg)
			renderer._record_map_signature(w, h, level_set, hgt, typ, blg)
			if signature_changed and not has_localized_invalidation:
				renderer._invalidate_all_chunks(w, h)
				renderer._effective_typ_service.set_dirty(true)
				renderer._clear_localized_overlay_scope()
		request_refresh(renderer, false)


func on_map_created(renderer) -> void:
	renderer._cancel_async_initial_build()
	var current_map_data = renderer._current_map_data()
	if current_map_data:
		renderer._effective_typ_service.invalidate_cache()
		renderer._effective_typ_service.set_dirty(true)
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		var level_set = int(current_map_data.level_set)
		renderer._chunk_rt.last_map_dimensions = Vector2i(w, h)
		renderer._chunk_rt.last_level_set = level_set
		renderer._clear_chunk_nodes()
		renderer._set_authored_overlay([])
		renderer._clear_localized_overlay_scope()
		renderer._chunk_rt.clear_dirty_chunks()
		renderer._chunk_rt.clear_authored_caches()
		renderer._chunk_rt.invalidate_all_chunks(w, h)
		renderer._chunk_rt.initial_build_in_progress = true
		renderer._chunk_rt.initial_build_accumulated_authored_descriptors.clear()
	request_refresh(renderer, true)


func on_hgt_map_cells_edited(renderer, border_indices: Array) -> void:
	renderer._cancel_async_initial_build()
	var current_map_data = renderer._current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	renderer._effective_typ_service.set_dirty(false)
	var invalidation = InvalidationRouter.invalidation_for_hgt_border_indices(border_indices, w, h)
	renderer.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	renderer._record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))


func on_typ_map_cells_edited(renderer, typ_indices: Array) -> void:
	renderer._cancel_async_initial_build()
	var current_map_data = renderer._current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	renderer._effective_typ_service.set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_typ_indices(typ_indices, w, h)
	renderer.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	renderer._record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))


func on_blg_map_cells_edited(renderer, blg_indices: Array) -> void:
	renderer._cancel_async_initial_build()
	var current_map_data = renderer._current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	renderer._effective_typ_service.set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_blg_indices(blg_indices, w, h)
	renderer.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	renderer._record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))

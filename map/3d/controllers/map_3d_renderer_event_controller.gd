extends RefCounted

const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"
const InvalidationRouter := preload("res://map/3d/services/map_3d_invalidation_router.gd")

var _renderer_node = null
var _context = null
var _scene = null
var _build = null
var _async_refresh_driver = null


func bind(renderer, context_port, scene_port, build_state_port, async_refresh_driver) -> void:
	_renderer_node = renderer
	_context = context_port
	_scene = scene_port
	_build = build_state_port
	_async_refresh_driver = async_refresh_driver


func ready() -> void:
	_build.set_sector_top_shader(load("res://resources/terrain/shaders/sector_top.gdshader"))
	_build.set_edge_blend_shader(load(EDGE_BLEND_SHADER_PATH))

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

	_build.apply_preview_activity_state()
	_build.apply_visibility_range_from_editor_state()
	var current_map_data = _context.current_map_data()
	if current_map_data and current_map_data.horizontal_sectors > 0 and current_map_data.vertical_sectors > 0 and not current_map_data.hgt_map.is_empty():
		_build.request_refresh(true)


func request_refresh(reframe_camera: bool) -> void:
	_async_refresh_driver.request_refresh(reframe_camera)


func apply_pending_refresh() -> void:
	_async_refresh_driver.apply_pending_refresh()


func on_map_view_updated() -> void:
	_build.apply_preview_activity_state()
	_build.apply_visibility_range_from_editor_state()
	if _context.preview_refresh_active():
		_scene.bump_3d_viewport_rendering()
	if _build.has_pending_refresh():
		_build.request_refresh(false)
	elif _context.preview_refresh_active():
		_build.flush_pending_unit_changes()


func on_map_overlay_animations_changed() -> void:
	if _context.preview_refresh_active():
		_build.request_overlay_only_refresh()


func on_map_changed() -> void:
	if _build.skip_next_map_changed_refresh():
		_build.set_skip_next_map_changed_refresh(false)
		return
	_build.cancel_async_initial_build()
	var chunk_runtime = _build.chunk_runtime()
	var has_localized_invalidation = chunk_runtime.take_localized_chunk_invalidation_pending()
	var current_map_data = _context.current_map_data()
	if current_map_data:
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		if w > 0 and h > 0:
			var hgt: PackedByteArray = current_map_data.hgt_map
			var typ: PackedByteArray = current_map_data.typ_map
			var blg: PackedByteArray = current_map_data.blg_map
			var level_set = int(current_map_data.level_set)
			var signature_changed = _build.is_map_signature_changed(w, h, level_set, hgt, typ, blg)
			_build.record_map_signature(w, h, level_set, hgt, typ, blg)
			if signature_changed and not has_localized_invalidation:
				_build.invalidate_all_chunks(w, h)
				_build.effective_typ_service().set_dirty(true)
				_build.clear_localized_overlay_scope()
		_build.request_refresh(false)


func on_map_created() -> void:
	_build.cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data:
		var effective_typ_service = _build.effective_typ_service()
		effective_typ_service.invalidate_cache()
		effective_typ_service.set_dirty(true)
		var chunk_runtime = _build.chunk_runtime()
		var w := int(current_map_data.horizontal_sectors)
		var h := int(current_map_data.vertical_sectors)
		var level_set = int(current_map_data.level_set)
		chunk_runtime.last_map_dimensions = Vector2i(w, h)
		chunk_runtime.last_level_set = level_set
		_scene.clear_chunk_nodes()
		_build.set_authored_overlay([])
		_build.clear_localized_overlay_scope()
		chunk_runtime.clear_dirty_chunks()
		chunk_runtime.clear_authored_caches()
		chunk_runtime.invalidate_all_chunks(w, h)
		chunk_runtime.initial_build_in_progress = true
		chunk_runtime.initial_build_accumulated_authored_descriptors.clear()
	_build.request_refresh(true)


func on_hgt_map_cells_edited(border_indices: Array) -> void:
	_build.cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.effective_typ_service().set_dirty(false)
	var invalidation = InvalidationRouter.invalidation_for_hgt_border_indices(border_indices, w, h)
	_build.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_build.record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))


func on_typ_map_cells_edited(typ_indices: Array) -> void:
	_build.cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.effective_typ_service().set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_typ_indices(typ_indices, w, h)
	_build.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_build.record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))


func on_blg_map_cells_edited(blg_indices: Array) -> void:
	_build.cancel_async_initial_build()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		return
	var w := int(current_map_data.horizontal_sectors)
	var h := int(current_map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_build.effective_typ_service().set_dirty(true)
	var invalidation = InvalidationRouter.invalidation_for_blg_indices(blg_indices, w, h)
	_build.mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_build.record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))

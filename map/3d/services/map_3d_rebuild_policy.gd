extends RefCounted

const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")
const OverlayPositioning := preload("res://map/3d/overlays/map_3d_overlay_positioning.gd")

var _context = null
var _scene = null
var _runtime_state = null
var _chunk_runtime = null
var _effective_typ_service = null
var _overlay_refresh_scope = null


func bind(context_port, scene_port, runtime_state, chunk_runtime, effective_typ_service, overlay_refresh_scope) -> void:
	_context = context_port
	_scene = scene_port
	_runtime_state = runtime_state
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_overlay_refresh_scope = overlay_refresh_scope


func mark_chunks_dirty(chunk_coords: Array) -> void:
	if chunk_coords.is_empty():
		return
	_chunk_runtime.explicit_chunk_invalidation_pending = true
	_chunk_runtime.localized_chunk_invalidation_pending = true
	for chunk_value in chunk_coords:
		if chunk_value is Vector2i:
			_chunk_runtime.mark_chunk_dirty(Vector2i(chunk_value))


func mark_sector_dirty(sx: int, sy: int, edit_type: String = "hgt") -> void:
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_chunk_runtime.explicit_chunk_invalidation_pending = true
	_chunk_runtime.invalidate_chunks_for_sector_edit(sx, sy, w, h, edit_type)
	_overlay_refresh_scope.record_sectors([Vector2i(sx, sy)])


func mark_sectors_dirty(sectors: Array, edit_type: String = "hgt") -> void:
	var cmd: Node = _context.current_map_data()
	if cmd == null:
		return
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_chunk_runtime.explicit_chunk_invalidation_pending = true
	var localized: Array[Vector2i] = []
	for sector in sectors:
		var sector_coord := Vector2i.ZERO
		if sector is Vector2i:
			sector_coord = Vector2i(sector)
		elif sector is Vector2:
			sector_coord = Vector2i(int(sector.x), int(sector.y))
		else:
			continue
		_chunk_runtime.invalidate_chunks_for_sector_edit(sector_coord.x, sector_coord.y, w, h, edit_type)
		localized.append(sector_coord)
	if not localized.is_empty():
		_overlay_refresh_scope.record_sectors(localized)


func needs_full_rebuild(w: int, h: int, level_set: int = -1) -> bool:
	if level_set < 0:
		level_set = 0
		var cmd: Node = _context.current_map_data()
		if cmd != null:
			level_set = int(cmd.level_set)
	var has_chunk_nodes: bool = not _scene.terrain_chunk_nodes().is_empty()
	return _chunk_runtime.needs_full_rebuild(w, h, level_set, has_chunk_nodes)


func chunk_focus_coord(w: int, h: int) -> Vector2i:
	var camera: Camera3D = _scene.camera()
	if camera != null and is_instance_valid(camera):
		var world_pos := camera.global_position if camera.is_inside_tree() else camera.position
		var sx := clampi(OverlayPositioning.world_to_sector_index(world_pos.x), 0, maxi(w - 1, 0))
		var sy := clampi(OverlayPositioning.world_to_sector_index(world_pos.z), 0, maxi(h - 1, 0))
		return ChunkGrid.sector_to_chunk(sx, sy)
	var center_sx := maxi(w >> 1, 0)
	var center_sy := maxi(h >> 1, 0)
	return ChunkGrid.sector_to_chunk(center_sx, center_sy)


func dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	return _chunk_runtime.dirty_chunks_sorted_by_priority(chunk_focus_coord(w, h))


func handle_level_set_changed(cancel_async_build: Callable, request_refresh: Callable) -> void:
	_runtime_state.terrain_material_cache.clear()
	_runtime_state.edge_material_cache.clear()
	cancel_async_build.call()
	_effective_typ_service.invalidate_cache()
	_effective_typ_service.set_dirty(true)
	var cmd: Node = _context.current_map_data()
	if cmd != null:
		var w := int(cmd.horizontal_sectors)
		var h := int(cmd.vertical_sectors)
		if w > 0 and h > 0:
			_scene.clear_chunk_nodes()
			_scene.set_authored_overlay([])
			_chunk_runtime.clear_dirty_chunks()
			_chunk_runtime.clear_authored_caches()
			_chunk_runtime.last_map_dimensions = Vector2i(w, h)
			_chunk_runtime.last_level_set = int(cmd.level_set)
			_chunk_runtime.invalidate_all_chunks(w, h)
			_chunk_runtime.initial_build_in_progress = true
			_chunk_runtime.initial_build_accumulated_authored_descriptors.clear()
	request_refresh.call(false)

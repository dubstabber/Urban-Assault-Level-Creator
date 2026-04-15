extends RefCounted

const ChunkBuildExecutor := preload("res://map/3d/services/map_3d_chunk_build_executor.gd")
const OverlayPlanBuilder := preload("res://map/3d/services/map_3d_overlay_plan_builder.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")
const EffectiveTypService := preload("res://map/3d/services/map_3d_effective_typ_service.gd")
const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")

var _renderer = null
var _context = null
var _scene = null
var _async_map_snapshot = null
var _overlay_refresh_scope = null
var _chunk_runtime = null
var _effective_typ_service = null
var _unit_runtime_index = null
var _static_overlay_index = null
var _rebuild_policy = null


func bind(context_port, scene_port, async_map_snapshot, overlay_refresh_scope, chunk_runtime, effective_typ_service, unit_runtime_index, static_overlay_index, rebuild_policy, renderer = null) -> void:
	_renderer = renderer
	_context = context_port
	_scene = scene_port
	_async_map_snapshot = async_map_snapshot
	_overlay_refresh_scope = overlay_refresh_scope
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_unit_runtime_index = unit_runtime_index
	_static_overlay_index = static_overlay_index
	_rebuild_policy = rebuild_policy


func build_from_current_map() -> void:
	var build_started_usec = Time.get_ticks_usec()
	var metrics = BuildMetrics.empty_metrics()
	_renderer._sync_terrain_overlay_animation_mode_from_editor()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		_scene.clear()
		_renderer._finalize_build_metrics(metrics, build_started_usec)
		return

	var w: int = int(current_map_data.horizontal_sectors)
	var h: int = int(current_map_data.vertical_sectors)
	var hgt: PackedByteArray = current_map_data.hgt_map
	var typ: PackedByteArray = current_map_data.typ_map
	var blg: PackedByteArray = current_map_data.blg_map
	var expected = (w + 2) * (h + 2)
	if w <= 0 or h <= 0 or hgt.size() != expected or typ.size() != w * h:
		metrics["invalid_input"] = true
		var clear_started_usec = Time.get_ticks_usec()
		_scene.clear()
		metrics["overlay_node_creation_ms"] = BuildMetrics.elapsed_ms_since(clear_started_usec)
		_renderer._finalize_build_metrics(metrics, build_started_usec)
		return

	var game_data_type = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	_async_map_snapshot.blg = blg
	_async_map_snapshot.w = w
	_async_map_snapshot.h = h
	_async_map_snapshot.level_set = int(current_map_data.level_set)
	_async_map_snapshot.game_data_type = game_data_type

	var effective_typ: PackedByteArray
	var typ_checksum = EffectiveTypService.checksum_packed_byte_array(typ)
	var blg_checksum = EffectiveTypService.checksum_packed_byte_array(blg)
	var can_reuse_effective_typ = _effective_typ_service.is_valid_cache(w, h, game_data_type, typ_checksum, blg_checksum)
	if can_reuse_effective_typ:
		effective_typ = _effective_typ_service.get_effective_typ()
	else:
		effective_typ = _effective_typ_service.compute_effective_typ_for_map(current_map_data, w, h, typ, blg, game_data_type)
	_async_map_snapshot.effective_typ = effective_typ

	var pre = _context.preloads()
	if pre == null:
		var fallback_started_usec = Time.get_ticks_usec()
		var fallback_mesh = TerrainBuilder.build_mesh(hgt, w, h)
		metrics["terrain_build_ms"] = BuildMetrics.elapsed_ms_since(fallback_started_usec)
		if _scene.terrain_mesh() != null:
			_scene.terrain_mesh().mesh = fallback_mesh
			_scene.apply_untextured_materials(fallback_mesh)
		var fallback_overlay_started_usec = Time.get_ticks_usec()
		_scene.set_authored_overlay([])
		var fallback_counters: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
		metrics["piece_overlay_fast_path"] = int(fallback_counters.get("piece_overlay_fast_path", 0))
		metrics["piece_overlay_slow_path"] = int(fallback_counters.get("piece_overlay_slow_path", 0))
		metrics["overlay_node_creation_ms"] = BuildMetrics.elapsed_ms_since(fallback_overlay_started_usec)
		if _scene.edge_mesh() != null:
			_scene.edge_mesh().mesh = null
		_renderer._finalize_build_metrics(metrics, build_started_usec)
		return

	metrics["used_textured_preloads"] = true
	var level_set = int(current_map_data.level_set)
	var chunk_runtime = _chunk_runtime
	var has_chunk_nodes: bool = not _scene.terrain_chunk_nodes().is_empty()
	var requires_full_rebuild = _chunk_runtime.needs_full_rebuild(w, h, level_set, has_chunk_nodes)
	if chunk_runtime.chunked_terrain_enabled and requires_full_rebuild:
		_scene.clear_chunk_nodes()
		chunk_runtime.clear_authored_caches()
		chunk_runtime.prepare_chunked_full_rebuild(w, h, level_set)
		requires_full_rebuild = false
	var use_chunked = chunk_runtime.chunked_terrain_enabled and not requires_full_rebuild

	var terrain_started_usec = Time.get_ticks_usec()
	var authored_piece_descriptors: Array = []
	var support_descriptors: Array = []
	var overlay_descriptors: Array = []
	var processed_chunks: Array = []
	var localized_overlay_sectors = _overlay_refresh_scope.overlay_sector_list()
	var localized_dynamic_sectors = _overlay_refresh_scope.dynamic_sector_list()
	var rebuild_unit_index: bool = _unit_runtime_index.is_empty() or requires_full_rebuild or localized_dynamic_sectors.is_empty()
	if rebuild_unit_index:
		_unit_runtime_index.rebuild_from_map(current_map_data)
	metrics["dirty_sector_count"] = localized_overlay_sectors.size()
	metrics["dirty_chunk_count"] = chunk_runtime.get_dirty_chunk_count()
	metrics["unit_index_rebuilt"] = rebuild_unit_index

	if use_chunked:
		if chunk_runtime.has_dirty_chunks():
			var terrain_cache_snapshot_descriptors: Array = chunk_runtime.get_support_descriptors()
			if _scene.terrain_mesh() != null:
				_scene.terrain_mesh().mesh = null
			if _scene.edge_mesh() != null:
				_scene.edge_mesh().mesh = null
			var max_chunks = -1
			var is_initial_batch = chunk_runtime.initial_build_in_progress
			if is_initial_batch:
				max_chunks = chunk_runtime.initial_build_batch_size
			var rebuild_result = rebuild_dirty_chunks(hgt, effective_typ, w, h, pre, level_set, metrics, max_chunks)
			var batch_authored_descriptors: Array = rebuild_result.get("descriptors", [])
			processed_chunks = rebuild_result.get("processed_chunks", [])
			metrics["terrain_build_ms"] = BuildMetrics.elapsed_ms_since(terrain_started_usec)
			metrics["incremental_rebuild"] = true

			if is_initial_batch:
				chunk_runtime.initial_build_accumulated_authored_descriptors.append_array(batch_authored_descriptors)
				metrics["terrain_authored_descriptor_count"] = chunk_runtime.initial_build_accumulated_authored_descriptors.size()
				if chunk_runtime.has_dirty_chunks():
					_renderer._finalize_build_metrics(metrics, build_started_usec)
					_renderer._request_refresh(false)
					return
				authored_piece_descriptors = chunk_runtime.initial_build_accumulated_authored_descriptors
				chunk_runtime.initial_build_in_progress = false
				chunk_runtime.initial_build_accumulated_authored_descriptors.clear()
			else:
				authored_piece_descriptors = batch_authored_descriptors
				metrics["terrain_authored_descriptor_count"] = authored_piece_descriptors.size()

			var cached_terrain_descriptors: Array = chunk_runtime.get_support_descriptors()
			if cached_terrain_descriptors.is_empty():
				if not terrain_cache_snapshot_descriptors.is_empty():
					cached_terrain_descriptors = terrain_cache_snapshot_descriptors.duplicate()
				else:
					cached_terrain_descriptors = authored_piece_descriptors.duplicate()
			else:
				cached_terrain_descriptors = cached_terrain_descriptors.duplicate()
			support_descriptors = cached_terrain_descriptors
			overlay_descriptors = cached_terrain_descriptors.duplicate()
			metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
		else:
			support_descriptors = chunk_runtime.get_support_descriptors().duplicate()
			overlay_descriptors = support_descriptors.duplicate()
			metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
	else:
		_scene.clear_chunk_nodes()
		_chunk_runtime.invalidate_all_chunks(w, h)
		chunk_runtime.last_map_dimensions = Vector2i(w, h)
		chunk_runtime.last_level_set = level_set

		var result = TerrainBuilder.build_mesh_with_textures(
			hgt,
			effective_typ,
			w,
			h,
			pre.surface_type_map,
			pre.subsector_patterns,
			pre.tile_mapping,
			pre.tile_remap,
			pre.subsector_idx_remap,
			pre.lego_defs,
			level_set
		)
		metrics["terrain_build_ms"] = BuildMetrics.elapsed_ms_since(terrain_started_usec)
		var mesh: ArrayMesh = result["mesh"]
		var surface_to_surface_type: Dictionary = result["surface_to_surface_type"]
		authored_piece_descriptors = result.get("authored_piece_descriptors", [])
		metrics["terrain_authored_descriptor_count"] = authored_piece_descriptors.size()
		metrics["incremental_rebuild"] = false
		support_descriptors = authored_piece_descriptors.duplicate()
		overlay_descriptors = authored_piece_descriptors.duplicate()
		if _scene.terrain_mesh() != null:
			_scene.terrain_mesh().mesh = mesh
			_scene.apply_sector_top_materials(mesh, pre, surface_to_surface_type)

		var edge_started_usec = Time.get_ticks_usec()
		if _renderer._edge_overlay_enabled and effective_typ.size() == w * h:
			var edge_result = _scene.build_edge_overlay_result(hgt, w, h, effective_typ, pre.surface_type_map, level_set, pre)
			var edge_authored_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
			metrics["edge_authored_descriptor_count"] = edge_authored_descriptors.size()
			support_descriptors.append_array(edge_authored_descriptors)
			overlay_descriptors.append_array(edge_authored_descriptors)
			_scene.ensure_edge_node()
			_scene.edge_mesh().mesh = edge_result.get("mesh", null)
		else:
			if _scene.edge_mesh() != null:
				_scene.edge_mesh().mesh = null
		metrics["edge_slurp_build_ms"] = BuildMetrics.elapsed_ms_since(edge_started_usec)
		chunk_runtime.clear_dirty_chunks()
		_chunk_runtime.reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)

	var can_use_localized_overlay_refresh = use_chunked and not chunk_runtime.initial_build_in_progress and not processed_chunks.is_empty() and not localized_overlay_sectors.is_empty()
	var overlay_descriptor_started_usec = Time.get_ticks_usec()
	if can_use_localized_overlay_refresh:
		var localized_static_descriptors := OverlayPlanBuilder.build_localized_static_descriptors(
			blg,
			effective_typ,
			int(current_map_data.level_set),
			hgt,
			w,
			h,
			localized_overlay_sectors,
			authored_piece_descriptors,
			game_data_type
		)
		metrics["static_overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(overlay_descriptor_started_usec)
		metrics["overlay_descriptor_generation_ms"] = metrics["static_overlay_descriptor_generation_ms"]
		metrics["overlay_descriptor_count"] = localized_static_descriptors.size()
		var overlay_node_started_usec = Time.get_ticks_usec()
		apply_localized_static_overlay_refresh(localized_static_descriptors, processed_chunks, localized_overlay_sectors, int(current_map_data.level_set), w, h)
		metrics["static_overlay_apply_ms"] = BuildMetrics.elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]
		var dynamic_descriptor_started_usec = Time.get_ticks_usec()
		apply_localized_dynamic_overlay_refresh(current_map_data, int(current_map_data.level_set), hgt, w, h, support_descriptors, game_data_type, localized_dynamic_sectors, metrics)
		metrics["dynamic_overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(dynamic_descriptor_started_usec)
		metrics["dynamic_overlay_apply_ms"] = 0.0
		metrics["localized_overlay_refresh"] = true
	else:
		var overlay_plan := OverlayPlanBuilder.build_full_overlay_plan(
			current_map_data,
			blg,
			effective_typ,
			int(current_map_data.level_set),
			hgt,
			w,
			h,
			support_descriptors,
			game_data_type,
			metrics
		)
		var static_descriptors: Array = overlay_plan.get("static_descriptors", [])
		var dynamic_descriptors: Array = overlay_plan.get("dynamic_descriptors", [])
		overlay_descriptors = static_descriptors.duplicate()
		overlay_descriptors.append_array(dynamic_descriptors)
		var overlay_node_started_usec = Time.get_ticks_usec()
		_scene.set_authored_overlay(overlay_descriptors)
		metrics["static_overlay_apply_ms"] = BuildMetrics.elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]

	var piece_counters: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(piece_counters.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(piece_counters.get("piece_overlay_slow_path", 0))
	_overlay_refresh_scope.clear()
	_renderer._finalize_build_metrics(metrics, build_started_usec)


func rebuild_dirty_chunks(hgt: PackedByteArray, effective_typ: PackedByteArray, w: int, h: int, pre: Node, level_set: int, metrics: Dictionary, max_chunks: int = -1) -> Dictionary:
	var all_authored_descriptors: Array = []
	var chunks_rebuilt = 0
	var processed: Array[Vector2i] = []
	var apply_started_usec = Time.get_ticks_usec()
	var dirty_chunk_list = _rebuild_policy.dirty_chunks_sorted_by_priority(w, h)

	for chunk_coord in dirty_chunk_list:
		if max_chunks > 0 and chunks_rebuilt >= max_chunks:
			break
		var chunk_result := ChunkBuildExecutor.build_chunk_result(
			chunk_coord,
			hgt,
			effective_typ,
			w,
			h,
			pre.surface_type_map,
			pre.subsector_patterns,
			pre.tile_mapping,
			pre.tile_remap,
			pre.subsector_idx_remap,
			pre.lego_defs,
			level_set,
			_renderer._edge_overlay_enabled
		)
		var apply_result := ChunkBuildExecutor.apply_chunk_result(_scene, _chunk_runtime, chunk_result, pre)
		var chunk_authored_descriptors: Array = apply_result.get("descriptors", [])
		all_authored_descriptors.append_array(chunk_authored_descriptors)
		chunks_rebuilt += 1
		processed.append(chunk_coord)

	for chunk_coord in processed:
		_chunk_runtime.erase_dirty_chunk(chunk_coord)
	metrics["chunks_rebuilt"] = chunks_rebuilt
	metrics["chunk_apply_ms"] = BuildMetrics.elapsed_ms_since(apply_started_usec)
	return {
		"descriptors": all_authored_descriptors,
		"processed_chunks": processed,
	}


func apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	if _scene.authored_overlay() == null or not is_instance_valid(_scene.authored_overlay()):
		return
	var prefixes = StaticOverlayIndex.terrain_prefixes_for_chunks(set_id, affected_chunks, w, h)
	prefixes.append_array(StaticOverlayIndex.building_attachment_prefixes_for_sectors(set_id, affected_sectors))
	if prefixes.is_empty():
		return
	_static_overlay_index.replace_matching_prefixes(prefixes, replacement_descriptors)
	AuthoredOverlayManager.apply_overlay_for_prefixes(_scene.authored_overlay(), prefixes, replacement_descriptors)


func apply_localized_dynamic_overlay_refresh(current_map_data: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	if affected_sectors.is_empty():
		return
	_scene.ensure_overlay_nodes()
	var descriptors := OverlayPlanBuilder.build_localized_dynamic_descriptors(
		current_map_data,
		_unit_runtime_index,
		set_id,
		hgt,
		w,
		h,
		affected_sectors,
		support_descriptors,
		game_data_type,
		metrics
	)
	var prefixes = StaticOverlayIndex.exact_instance_key_prefixes(descriptors)
	if prefixes.is_empty():
		return
	AuthoredOverlayManager.apply_overlay_for_prefixes(_scene.dynamic_overlay(), prefixes, descriptors)
	_scene.apply_geometry_distance_culling_to_overlay()

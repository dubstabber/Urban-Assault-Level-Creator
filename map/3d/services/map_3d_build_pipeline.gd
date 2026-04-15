extends RefCounted

const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")

var _context = null
var _scene = null
var _build = null


func bind(context_port, scene_port, build_state_port) -> void:
	_context = context_port
	_scene = scene_port
	_build = build_state_port


func build_from_current_map() -> void:
	var build_started_usec = Time.get_ticks_usec()
	var metrics = _build.make_empty_build_metrics()
	_build.sync_terrain_overlay_animation_mode_from_editor()
	var current_map_data = _context.current_map_data()
	if current_map_data == null:
		_scene.clear()
		_build.finalize_build_metrics(metrics, build_started_usec)
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
		metrics["overlay_node_creation_ms"] = _build.elapsed_ms_since(clear_started_usec)
		_build.finalize_build_metrics(metrics, build_started_usec)
		return

	_build.unit_runtime_index().rebuild_from_map(current_map_data)
	var game_data_type = _context.current_game_data_type()
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	_build.set_async_blg(blg)
	_build.set_async_w(w)
	_build.set_async_h(h)
	_build.set_async_level_set(int(current_map_data.level_set))
	_build.set_async_game_data_type(game_data_type)

	var effective_typ: PackedByteArray
	var typ_checksum = _build.checksum_packed_byte_array(typ)
	var blg_checksum = _build.checksum_packed_byte_array(blg)
	var effective_typ_service = _build.effective_typ_service()
	var can_reuse_effective_typ = effective_typ_service.is_valid_cache(w, h, game_data_type, typ_checksum, blg_checksum)
	if can_reuse_effective_typ:
		effective_typ = effective_typ_service.get_effective_typ()
	else:
		effective_typ = _build.compute_effective_typ_for_map(current_map_data, w, h, typ, blg, game_data_type)
	_build.set_async_effective_typ(effective_typ)

	var pre = _context.preloads()
	if pre == null:
		var fallback_started_usec = Time.get_ticks_usec()
		var fallback_mesh = _build.build_mesh(hgt, w, h)
		metrics["terrain_build_ms"] = _build.elapsed_ms_since(fallback_started_usec)
		if _scene.terrain_mesh() != null:
			_scene.terrain_mesh().mesh = fallback_mesh
			_scene.apply_untextured_materials(fallback_mesh)
		var fallback_overlay_started_usec = Time.get_ticks_usec()
		_scene.set_authored_overlay([])
		var fallback_counters: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
		metrics["piece_overlay_fast_path"] = int(fallback_counters.get("piece_overlay_fast_path", 0))
		metrics["piece_overlay_slow_path"] = int(fallback_counters.get("piece_overlay_slow_path", 0))
		metrics["overlay_node_creation_ms"] = _build.elapsed_ms_since(fallback_overlay_started_usec)
		if _scene.edge_mesh() != null:
			_scene.edge_mesh().mesh = null
		_build.finalize_build_metrics(metrics, build_started_usec)
		return

	metrics["used_textured_preloads"] = true
	var level_set = int(current_map_data.level_set)
	var chunk_runtime = _build.chunk_runtime()
	var requires_full_rebuild = _build.needs_full_rebuild(w, h, level_set)
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
	var localized_overlay_sectors = _build.localized_overlay_sector_list()
	var localized_dynamic_sectors = _build.localized_dynamic_sector_list()
	metrics["dirty_sector_count"] = localized_overlay_sectors.size()
	metrics["dirty_chunk_count"] = chunk_runtime.get_dirty_chunk_count()

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
			metrics["terrain_build_ms"] = _build.elapsed_ms_since(terrain_started_usec)
			metrics["incremental_rebuild"] = true

			if is_initial_batch:
				chunk_runtime.initial_build_accumulated_authored_descriptors.append_array(batch_authored_descriptors)
				metrics["terrain_authored_descriptor_count"] = chunk_runtime.initial_build_accumulated_authored_descriptors.size()
				if chunk_runtime.has_dirty_chunks():
					_build.finalize_build_metrics(metrics, build_started_usec)
					_build.request_refresh(false)
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
		_build.invalidate_all_chunks(w, h)
		chunk_runtime.last_map_dimensions = Vector2i(w, h)
		chunk_runtime.last_level_set = level_set

		var result = _build.build_mesh_with_textures(
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
		metrics["terrain_build_ms"] = _build.elapsed_ms_since(terrain_started_usec)
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
		if _build.edge_overlay_enabled() and effective_typ.size() == w * h:
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
		metrics["edge_slurp_build_ms"] = _build.elapsed_ms_since(edge_started_usec)
		chunk_runtime.clear_dirty_chunks()
		_build.reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)

	var can_use_localized_overlay_refresh = use_chunked and not chunk_runtime.initial_build_in_progress and not processed_chunks.is_empty() and not localized_overlay_sectors.is_empty()
	var overlay_descriptor_started_usec = Time.get_ticks_usec()
	if can_use_localized_overlay_refresh:
		var localized_static_descriptors: Array = authored_piece_descriptors.duplicate()
		localized_static_descriptors.append_array(OverlayProducers.build_blg_attachment_descriptors_for_sectors(
			blg,
			effective_typ,
			int(current_map_data.level_set),
			hgt,
			w,
			h,
			localized_overlay_sectors,
			game_data_type
		))
		metrics["static_overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(overlay_descriptor_started_usec)
		metrics["overlay_descriptor_generation_ms"] = metrics["static_overlay_descriptor_generation_ms"]
		metrics["overlay_descriptor_count"] = localized_static_descriptors.size()
		var overlay_node_started_usec = Time.get_ticks_usec()
		apply_localized_static_overlay_refresh(localized_static_descriptors, processed_chunks, localized_overlay_sectors, int(current_map_data.level_set), w, h)
		metrics["static_overlay_apply_ms"] = _build.elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]
		var dynamic_descriptor_started_usec = Time.get_ticks_usec()
		apply_localized_dynamic_overlay_refresh(current_map_data, int(current_map_data.level_set), hgt, w, h, support_descriptors, game_data_type, localized_dynamic_sectors, metrics)
		metrics["dynamic_overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(dynamic_descriptor_started_usec)
		metrics["dynamic_overlay_apply_ms"] = 0.0
		metrics["localized_overlay_refresh"] = true
	else:
		overlay_descriptors.append_array(_build.build_blg_attachment_descriptors(blg, effective_typ, int(current_map_data.level_set), hgt, w, h, support_descriptors, game_data_type))
		if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
			overlay_descriptors.append_array(_build.build_host_station_descriptors(current_map_data.host_stations.get_children(), int(current_map_data.level_set), hgt, w, h, support_descriptors, metrics))
		if current_map_data.squads != null and is_instance_valid(current_map_data.squads):
			overlay_descriptors.append_array(_build.build_squad_descriptors(current_map_data.squads.get_children(), int(current_map_data.level_set), hgt, w, h, support_descriptors, game_data_type, metrics))
		metrics["overlay_descriptor_generation_ms"] = _build.elapsed_ms_since(overlay_descriptor_started_usec)
		metrics["static_overlay_descriptor_generation_ms"] = metrics["overlay_descriptor_generation_ms"]
		metrics["overlay_descriptor_count"] = overlay_descriptors.size()
		var overlay_node_started_usec = Time.get_ticks_usec()
		_scene.set_authored_overlay(overlay_descriptors)
		metrics["static_overlay_apply_ms"] = _build.elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]

	var piece_counters: Dictionary = UATerrainPieceLibrary.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(piece_counters.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(piece_counters.get("piece_overlay_slow_path", 0))
	_build.clear_localized_overlay_scope()
	_build.finalize_build_metrics(metrics, build_started_usec)


func rebuild_dirty_chunks(hgt: PackedByteArray, effective_typ: PackedByteArray, w: int, h: int, pre: Node, level_set: int, metrics: Dictionary, max_chunks: int = -1) -> Dictionary:
	var all_authored_descriptors: Array = []
	var chunks_rebuilt = 0
	var processed: Array[Vector2i] = []
	var apply_started_usec = Time.get_ticks_usec()
	var dirty_chunk_list = _build.dirty_chunks_sorted_by_priority(w, h)

	for chunk_coord in dirty_chunk_list:
		if max_chunks > 0 and chunks_rebuilt >= max_chunks:
			break
		var terrain_result = TerrainBuilder.build_chunk_mesh_with_textures(
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
			true
		)
		var chunk_node = _scene.get_or_create_terrain_chunk_node(chunk_coord)
		chunk_node.mesh = terrain_result["mesh"]
		_scene.apply_sector_top_materials(terrain_result["mesh"], pre, terrain_result["surface_to_surface_type"])

		var terrain_descriptors: Array = terrain_result.get("authored_piece_descriptors", [])
		var chunk_authored_descriptors: Array = terrain_descriptors.duplicate()

		if _build.edge_overlay_enabled():
			var edge_result = SlurpBuilder.build_chunk_edge_overlay_result(
				chunk_coord,
				hgt,
				w,
				h,
				effective_typ,
				pre.surface_type_map,
				level_set
			)
			var edge_chunk_node = _scene.get_or_create_edge_chunk_node(chunk_coord)
			edge_chunk_node.mesh = edge_result.get("mesh", null)
			_scene.apply_edge_surface_materials(
				edge_chunk_node.mesh,
				pre,
				edge_result.get("fallback_horiz_keys", []),
				edge_result.get("fallback_vert_keys", [])
			)
			var edge_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
			chunk_authored_descriptors.append_array(edge_descriptors)

		all_authored_descriptors.append_array(chunk_authored_descriptors)
		_build.update_terrain_authored_cache_for_chunk(chunk_coord, chunk_authored_descriptors)
		chunks_rebuilt += 1
		processed.append(chunk_coord)

	for chunk_coord in processed:
		_build.chunk_runtime().erase_dirty_chunk(chunk_coord)
	metrics["chunks_rebuilt"] = chunks_rebuilt
	metrics["chunk_apply_ms"] = _build.elapsed_ms_since(apply_started_usec)
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
	_build.static_overlay_index().replace_matching_prefixes(prefixes, replacement_descriptors)
	AuthoredOverlayManager.apply_overlay_for_prefixes(_scene.authored_overlay(), prefixes, replacement_descriptors)


func apply_localized_dynamic_overlay_refresh(current_map_data: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	if affected_sectors.is_empty():
		return
	_scene.ensure_overlay_nodes()
	var descriptors: Array = []
	if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
		var host_nodes = _build.unit_runtime_index().units_for_sectors(current_map_data, "host", affected_sectors)
		descriptors.append_array(OverlayProducers.build_host_station_descriptors_for_sectors(
			host_nodes,
			set_id,
			hgt,
			w,
			h,
			affected_sectors,
			support_descriptors,
			metrics
		))
	if current_map_data.squads != null and is_instance_valid(current_map_data.squads):
		var squad_nodes = _build.unit_runtime_index().units_for_sectors(current_map_data, "squad", affected_sectors)
		descriptors.append_array(OverlayProducers.build_squad_descriptors_for_sectors(
			squad_nodes,
			set_id,
			hgt,
			w,
			h,
			affected_sectors,
			support_descriptors,
			game_data_type,
			metrics
		))
	var prefixes = StaticOverlayIndex.exact_instance_key_prefixes(descriptors)
	if prefixes.is_empty():
		return
	AuthoredOverlayManager.apply_overlay_for_prefixes(_scene.dynamic_overlay(), prefixes, descriptors)
	_scene.apply_geometry_distance_culling_to_overlay()

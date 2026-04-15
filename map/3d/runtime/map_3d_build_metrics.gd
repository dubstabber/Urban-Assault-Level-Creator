extends RefCounted


static func empty_metrics() -> Dictionary:
	return {
		"used_textured_preloads": false,
		"invalid_input": false,
		"terrain_build_ms": 0.0,
		"chunk_apply_ms": 0.0,
		"edge_slurp_build_ms": 0.0,
		"overlay_descriptor_generation_ms": 0.0,
		"overlay_node_creation_ms": 0.0,
		"static_overlay_descriptor_generation_ms": 0.0,
		"static_overlay_apply_ms": 0.0,
		"dynamic_overlay_descriptor_generation_ms": 0.0,
		"dynamic_overlay_apply_ms": 0.0,
		"host_station_descriptor_generation_ms": 0.0,
		"squad_descriptor_generation_ms": 0.0,
		"building_attachment_descriptor_generation_ms": 0.0,
		"support_query_index_build_ms": 0.0,
		"support_query_candidate_count": 0,
		"support_query_cache_hits": 0,
		"support_height_query_ms": 0.0,
		"support_height_query_count": 0,
		"terrain_authored_descriptor_count": 0,
		"edge_authored_descriptor_count": 0,
		"overlay_descriptor_count": 0,
		"dirty_sector_count": 0,
		"dirty_chunk_count": 0,
		"localized_overlay_refresh": false,
		"piece_overlay_fast_path": 0,
		"piece_overlay_slow_path": 0,
		"build_total_ms": 0.0,
		"refresh_end_to_end_ms": 0.0,
	}


static func elapsed_ms_since(started_usec: int) -> float:
	if started_usec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)

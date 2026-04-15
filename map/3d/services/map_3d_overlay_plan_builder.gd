extends RefCounted

const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")


static func capture_dynamic_snapshots(current_map_data: Node) -> Dictionary:
	var host_station_snapshot: Array = []
	var squad_snapshot: Array = []
	if current_map_data == null:
		return {
			"host_station_snapshot": host_station_snapshot,
			"squad_snapshot": squad_snapshot,
		}
	if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
		host_station_snapshot = OverlayProducers.snapshot_host_station_nodes(current_map_data.host_stations.get_children())
	if current_map_data.squads != null and is_instance_valid(current_map_data.squads):
		squad_snapshot = OverlayProducers.snapshot_squad_nodes(current_map_data.squads.get_children())
	return {
		"host_station_snapshot": host_station_snapshot,
		"squad_snapshot": squad_snapshot,
	}


static func build_overlay_plan_from_snapshots(
		host_station_snapshot: Array,
		squad_snapshot: Array,
		blg: PackedByteArray,
		effective_typ: PackedByteArray,
		set_id: int,
		hgt: PackedByteArray,
		w: int,
		h: int,
		support_descriptors: Array,
		game_data_type: String,
		metrics: Dictionary,
		dynamic_only: bool = false
	) -> Dictionary:
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var started_usec := Time.get_ticks_usec()
	var static_descriptors: Array = support_descriptors.duplicate()
	var dynamic_descriptors: Array = []

	var static_started_usec := Time.get_ticks_usec()
	if not dynamic_only:
		static_descriptors.append_array(OverlayProducers.build_blg_attachment_descriptors(
			blg,
			effective_typ,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			game_data_type
		))
	metrics["static_overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(static_started_usec)

	var dynamic_started_usec := Time.get_ticks_usec()
	dynamic_descriptors.append_array(OverlayProducers.build_host_station_descriptors_from_snapshot(
		host_station_snapshot,
		set_id,
		hgt,
		w,
		h,
		support_descriptors,
		metrics
	))
	dynamic_descriptors.append_array(OverlayProducers.build_squad_descriptors_from_snapshot(
		squad_snapshot,
		set_id,
		hgt,
		w,
		h,
		support_descriptors,
		game_data_type,
		metrics
	))
	metrics["dynamic_overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(dynamic_started_usec)
	metrics["overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(started_usec)
	metrics["overlay_descriptor_count"] = static_descriptors.size() + dynamic_descriptors.size()
	return {
		"static_descriptors": static_descriptors,
		"dynamic_descriptors": dynamic_descriptors,
	}


static func build_full_overlay_plan(
		current_map_data: Node,
		blg: PackedByteArray,
		effective_typ: PackedByteArray,
		set_id: int,
		hgt: PackedByteArray,
		w: int,
		h: int,
		support_descriptors: Array,
		game_data_type: String,
		metrics: Dictionary
	) -> Dictionary:
	var snapshots := capture_dynamic_snapshots(current_map_data)
	return build_overlay_plan_from_snapshots(
		snapshots.get("host_station_snapshot", []),
		snapshots.get("squad_snapshot", []),
		blg,
		effective_typ,
		set_id,
		hgt,
		w,
		h,
		support_descriptors,
		game_data_type,
		metrics
	)


static func build_localized_static_descriptors(
		blg: PackedByteArray,
		effective_typ: PackedByteArray,
		set_id: int,
		hgt: PackedByteArray,
		w: int,
		h: int,
		affected_sectors: Array,
		chunk_support_descriptors: Array,
		game_data_type: String
	) -> Array:
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var descriptors: Array = chunk_support_descriptors.duplicate()
	descriptors.append_array(OverlayProducers.build_blg_attachment_descriptors_for_sectors(
		blg,
		effective_typ,
		set_id,
		hgt,
		w,
		h,
		affected_sectors,
		game_data_type
	))
	return descriptors


static func build_localized_dynamic_descriptors(
		current_map_data: Node,
		unit_runtime_index,
		set_id: int,
		hgt: PackedByteArray,
		w: int,
		h: int,
		affected_sectors: Array,
		support_descriptors: Array,
		game_data_type: String,
		metrics: Dictionary
	) -> Array:
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var descriptors: Array = []
	if current_map_data == null or affected_sectors.is_empty():
		return descriptors
	if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
		var host_nodes = unit_runtime_index.units_for_sectors(current_map_data, "host", affected_sectors)
		descriptors.append_array(OverlayProducers.build_host_station_descriptors(
			host_nodes,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			metrics
		))
	if current_map_data.squads != null and is_instance_valid(current_map_data.squads):
		var squad_nodes = unit_runtime_index.units_for_sectors(current_map_data, "squad", affected_sectors)
		descriptors.append_array(OverlayProducers.build_squad_descriptors(
			squad_nodes,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			game_data_type,
			metrics
		))
	return descriptors

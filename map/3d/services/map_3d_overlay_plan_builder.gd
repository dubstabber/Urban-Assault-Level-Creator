extends RefCounted

const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const SupportQueryContext := preload("res://map/3d/services/map_3d_support_query_context.gd")
const _DYNAMIC_SUPPORT_QUERY_SECTOR_RADIUS := 2


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
	var support_query_context = null
	var dynamic_support_descriptors := support_descriptors
	if not host_station_snapshot.is_empty() or not squad_snapshot.is_empty():
		dynamic_support_descriptors = _filtered_support_descriptors_for_dynamic_snapshots(host_station_snapshot, squad_snapshot, support_descriptors, w, h)
		support_query_context = SupportQueryContext.create_from_support_descriptors(dynamic_support_descriptors, metrics)

	var static_started_usec := Time.get_ticks_usec()
	if not dynamic_only:
		var building_started_usec := Time.get_ticks_usec()
		var building_descriptors := OverlayProducers.build_blg_attachment_descriptors(
			blg,
			effective_typ,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			game_data_type
		)
		metrics["building_attachment_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(building_started_usec)
		static_descriptors.append_array(building_descriptors)
	metrics["static_overlay_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(static_started_usec)

	var dynamic_started_usec := Time.get_ticks_usec()
	var host_started_usec := Time.get_ticks_usec()
	dynamic_descriptors.append_array(OverlayProducers.build_host_station_descriptors_from_snapshot(
		host_station_snapshot,
		set_id,
		hgt,
		w,
		h,
		support_descriptors,
		support_query_context,
		metrics
	))
	metrics["host_station_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(host_started_usec)
	var squad_started_usec := Time.get_ticks_usec()
	dynamic_descriptors.append_array(OverlayProducers.build_squad_descriptors_from_snapshot(
		squad_snapshot,
		set_id,
		hgt,
		w,
		h,
		support_descriptors,
		game_data_type,
		support_query_context,
		metrics
	))
	metrics["squad_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(squad_started_usec)
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
		game_data_type: String,
		metrics = null
	) -> Array:
	UATerrainPieceLibrary.set_piece_game_data_type(game_data_type)
	var descriptors: Array = chunk_support_descriptors.duplicate()
	var building_started_usec := Time.get_ticks_usec()
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
	if metrics != null and typeof(metrics) == TYPE_DICTIONARY:
		metrics["building_attachment_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(building_started_usec)
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
	var support_query_context = null
	var dynamic_support_descriptors := support_descriptors
	var has_dynamic_units := false
	if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
		has_dynamic_units = current_map_data.host_stations.get_child_count() > 0
	if not has_dynamic_units and current_map_data.squads != null and is_instance_valid(current_map_data.squads):
		has_dynamic_units = current_map_data.squads.get_child_count() > 0
	if has_dynamic_units:
		var dynamic_snapshots := capture_dynamic_snapshots(current_map_data)
		var localized_hosts := OverlayProducers.filter_snapshot_to_sectors(dynamic_snapshots.get("host_station_snapshot", []), affected_sectors)
		var localized_squads := OverlayProducers.filter_snapshot_to_sectors(dynamic_snapshots.get("squad_snapshot", []), affected_sectors)
		dynamic_support_descriptors = _filtered_support_descriptors_for_dynamic_snapshots(localized_hosts, localized_squads, support_descriptors, w, h)
		support_query_context = SupportQueryContext.create_from_support_descriptors(dynamic_support_descriptors, metrics)
	if current_map_data.host_stations != null and is_instance_valid(current_map_data.host_stations):
		var host_started_usec := Time.get_ticks_usec()
		var host_nodes = unit_runtime_index.units_for_sectors(current_map_data, "host", affected_sectors)
		descriptors.append_array(OverlayProducers.build_host_station_descriptors(
			host_nodes,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			support_query_context,
			metrics
		))
		metrics["host_station_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(host_started_usec)
	if current_map_data.squads != null and is_instance_valid(current_map_data.squads):
		var squad_started_usec := Time.get_ticks_usec()
		var squad_nodes = unit_runtime_index.units_for_sectors(current_map_data, "squad", affected_sectors)
		descriptors.append_array(OverlayProducers.build_squad_descriptors(
			squad_nodes,
			set_id,
			hgt,
			w,
			h,
			support_descriptors,
			game_data_type,
			support_query_context,
			metrics
		))
		metrics["squad_descriptor_generation_ms"] = BuildMetrics.elapsed_ms_since(squad_started_usec)
	return descriptors


static func filter_support_descriptors_to_sectors(support_descriptors: Array, sectors: Array, w: int, h: int) -> Array:
	if support_descriptors.is_empty() or sectors.is_empty():
		return support_descriptors
	var wanted := {}
	for sector_value in sectors:
		if not (sector_value is Vector2i):
			continue
		var sector := Vector2i(sector_value)
		wanted[_support_sector_key(sector.x, sector.y)] = true
	if wanted.is_empty():
		return support_descriptors
	var filtered: Array = []
	for desc_value in support_descriptors:
		if typeof(desc_value) != TYPE_DICTIONARY:
			filtered.append(desc_value)
			continue
		var desc := desc_value as Dictionary
		var support_sectors := _support_descriptor_sector_keys(desc, w, h)
		if support_sectors.is_empty():
			filtered.append(desc)
			continue
		for sector_key in support_sectors:
			if wanted.has(sector_key):
				filtered.append(desc)
				break
	return filtered if not filtered.is_empty() else support_descriptors


static func _filtered_support_descriptors_for_dynamic_snapshots(host_station_snapshot: Array, squad_snapshot: Array, support_descriptors: Array, w: int, h: int) -> Array:
	if support_descriptors.is_empty():
		return support_descriptors
	var wanted_sectors := _expanded_dynamic_support_sector_filter(host_station_snapshot, squad_snapshot, w, h)
	if wanted_sectors.is_empty():
		return support_descriptors
	var filtered: Array = []
	for desc_value in support_descriptors:
		if typeof(desc_value) != TYPE_DICTIONARY:
			filtered.append(desc_value)
			continue
		var desc := desc_value as Dictionary
		var support_sectors := _support_descriptor_sector_keys(desc, w, h)
		if support_sectors.is_empty():
			filtered.append(desc)
			continue
		for sector_key in support_sectors:
			if wanted_sectors.has(sector_key):
				filtered.append(desc)
				break
	return filtered if not filtered.is_empty() else support_descriptors


static func _expanded_dynamic_support_sector_filter(host_station_snapshot: Array, squad_snapshot: Array, w: int, h: int) -> Dictionary:
	var wanted := {}
	for snapshot in [host_station_snapshot, squad_snapshot]:
		for entry_value in snapshot:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry := entry_value as Dictionary
			var sector := OverlayProducers.playable_sector_at_world_position(float(entry.get("x", 0.0)), absf(float(entry.get("y", 0.0))))
			for dy in range(-_DYNAMIC_SUPPORT_QUERY_SECTOR_RADIUS, _DYNAMIC_SUPPORT_QUERY_SECTOR_RADIUS + 1):
				for dx in range(-_DYNAMIC_SUPPORT_QUERY_SECTOR_RADIUS, _DYNAMIC_SUPPORT_QUERY_SECTOR_RADIUS + 1):
					var sx := sector.x + dx
					var sy := sector.y + dy
					if sx < -1 or sy < -1 or sx > w or sy > h:
						continue
					wanted[_support_sector_key(sx, sy)] = true
	return wanted


static func _support_descriptor_sector_keys(desc: Dictionary, w: int, h: int) -> Array:
	var instance_key := String(desc.get("instance_key", ""))
	if instance_key.is_empty():
		return []
	var parts := instance_key.split(":")
	if parts.size() < 4:
		return []
	if parts[0] == "terrain":
		var sx := int(parts[2])
		var sy := int(parts[3])
		if sx < -1 or sy < -1 or sx > w or sy > h:
			return []
		return [_support_sector_key(sx, sy)]
	if parts[0] != "slurp" or parts.size() < 5:
		return []
	var seam_x := int(parts[3])
	var seam_y := int(parts[4])
	var keys: Array = []
	if parts[1] == "v":
		for sx in [seam_x, seam_x + 1]:
			if sx < -1 or sx > w or seam_y < -1 or seam_y > h:
				continue
			keys.append(_support_sector_key(sx, seam_y))
	elif parts[1] == "h":
		for sy in [seam_y, seam_y + 1]:
			if seam_x < -1 or seam_x > w or sy < -1 or sy > h:
				continue
			keys.append(_support_sector_key(seam_x, sy))
	return keys


static func _support_sector_key(sx: int, sy: int) -> String:
	return "%d:%d" % [sx, sy]

extends RefCounted

# Pure static overlay descriptor producers for the 3D map preview.
# Extracted from Map3DRenderer (Step 4 refactoring).
# All functions are static and produce plain descriptor dictionaries
# without touching the scene tree.

const VisualLookupService = preload("res://map/3d/services/map_3d_visual_lookup_service.gd")

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0

const HOST_STATION_BASE_NAMES := {
	56: "VP_ROBO",
	57: "VP_KROBO",
	58: "VP_BRGRO",
	59: "VP_GIGNT",
	60: "VP_TAERO",
	61: "VP_SULG1",
	62: "VP_BSECT",
	132: "VP_TRAIN",
	176: "VP_GIGNT",
	177: "VP_KROBO",
	178: "VP_TAERO",
}
const HOST_STATION_VISIBLE_GUN_BASE_NAMES := {
	90: "VP_MFLAK",
	91: "VP_MFLAK",
	92: "VP_MFLAK",
	93: "VP_FLAK2",
	94: "VP_FLAK2",
	95: "VP_FLAK2",
}
const HOST_STATION_GUN_ATTACHMENTS := {
	56: [
		{"gun_type": 90, "ua_offset": Vector3(0.0, -200.0, 55.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 91, "ua_offset": Vector3(0.0, -180.0, -80.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
		{"gun_type": 92, "ua_offset": Vector3(0.0, -390.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 93, "ua_offset": Vector3(0.0, 150.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
	],
	62: [
		{"gun_type": 95, "ua_offset": Vector3(0.0, -150.0, 375.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -120.0, -380.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
}

const SQUAD_FORMATION_SPACING := 100.0
const SQUAD_EXTRA_Y_OFFSET := 8.0


# ---------------------------------------------------------------------------
# Height query utilities (pure static, duplicated from renderer to avoid
# circular dependency).
# ---------------------------------------------------------------------------

static func _sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	var bh := h + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, bh - 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE

static func _world_to_sector_index(world_coord: float) -> int:
	return int(floor(world_coord / SECTOR_SIZE)) - 1

static func ground_height_at_world_position(hgt: PackedByteArray, w: int, h: int, world_x: float, world_z: float) -> float:
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2):
		return 0.0
	return _sample_hgt_height(hgt, w, h, _world_to_sector_index(world_x), _world_to_sector_index(world_z))

static func support_height_at_world_position(hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, world_x: float, world_z: float, profile = null) -> float:
	var started_usec := Time.get_ticks_usec()
	var terrain_height := ground_height_at_world_position(hgt, w, h, world_x, world_z)
	var authored_support: Variant = null
	if support_descriptors.size() > 0:
		authored_support = UATerrainPieceLibrary.support_height_at_world_position(support_descriptors, world_x, world_z)
	_profile_increment(profile, "support_height_query_count")
	_profile_add_duration(profile, "support_height_query_ms", _elapsed_ms_since(started_usec))
	if authored_support != null:
		return max(float(authored_support), terrain_height)
	return terrain_height


# ---------------------------------------------------------------------------
# Profiling helpers (duplicated from renderer for zero-coupling).
# ---------------------------------------------------------------------------

static func _elapsed_ms_since(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0

static func _profile_increment(profile, key: String) -> void:
	if profile == null or typeof(profile) != TYPE_DICTIONARY:
		return
	var dict := profile as Dictionary
	dict[key] = int(dict.get(key, 0)) + 1

static func _profile_add_duration(profile, key: String, ms: float) -> void:
	if profile == null or typeof(profile) != TYPE_DICTIONARY:
		return
	var dict := profile as Dictionary
	dict[key] = float(dict.get(key, 0.0)) + ms


# ---------------------------------------------------------------------------
# Coordinate / conversion helpers.
# ---------------------------------------------------------------------------

static func sector_center_origin(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE, sector_y, (float(sy) + 1.5) * SECTOR_SIZE)

static func vector3_from_variant(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return Vector3(value)
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var dict := Dictionary(value)
	return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))

static func godot_offset_from_ua(ua_offset: Vector3) -> Vector3:
	return Vector3(ua_offset.x, -ua_offset.y, -ua_offset.z)

static func godot_direction_from_ua(ua_direction: Vector3) -> Vector3:
	var godot_direction := Vector3(ua_direction.x, -ua_direction.y, -ua_direction.z)
	var horizontal_direction := Vector3(godot_direction.x, 0.0, godot_direction.z)
	if horizontal_direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return horizontal_direction.normalized()


# ---------------------------------------------------------------------------
# Name lookup helpers.
# ---------------------------------------------------------------------------

static func host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return String(HOST_STATION_BASE_NAMES.get(vehicle_id, ""))

static func host_station_gun_base_name_for_type(gun_type: int) -> String:
	return String(HOST_STATION_VISIBLE_GUN_BASE_NAMES.get(gun_type, ""))

static func building_attachment_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func squad_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func building_definition_for_id_and_sec_type(building_id: int, sec_type: int, set_id: int = 1, game_data_type: String = "original") -> Dictionary:
	return VisualLookupService._building_definition_for_id_and_sec_type(building_id, sec_type, set_id, game_data_type)


# ---------------------------------------------------------------------------
# Squad formation layout.
# ---------------------------------------------------------------------------

static func squad_formation_offsets(quantity: int) -> Array:
	var offsets: Array = []
	var columns := int(sqrt(float(quantity))) + 2
	for unit_index in range(quantity):
		var x_offset := SQUAD_FORMATION_SPACING * (float(unit_index % columns) - float(columns) / 2.0)
		var z_offset: float = - SQUAD_FORMATION_SPACING * floor(float(unit_index) / float(columns))
		offsets.append(Vector3(x_offset, 0.0, z_offset))
	return offsets


# ---------------------------------------------------------------------------
# Node snapshot methods (capture live Node2D data into plain Dictionaries).
# ---------------------------------------------------------------------------

static func snapshot_host_station_nodes(host_stations: Array) -> Array:
	var snapshot: Array = []
	for host_station in host_stations:
		if host_station == null or not is_instance_valid(host_station):
			continue
		if not (host_station is Node2D):
			continue
		var vehicle_value = host_station.get("vehicle")
		if vehicle_value == null:
			continue
		var station := host_station as Node2D
		var pos_y_value = host_station.get("pos_y")
		var editor_unit_id: Variant = host_station.get("editor_unit_id")
		var stable_id := int(editor_unit_id) if editor_unit_id != null and int(editor_unit_id) > 0 else int(host_station.get_instance_id())
		snapshot.append({
			"id": stable_id,
			"vehicle": int(vehicle_value),
			"x": float(station.position.x),
			"y": float(station.position.y),
			"pos_y": float(pos_y_value if pos_y_value != null else 0.0),
		})
	return snapshot

static func snapshot_squad_nodes(squads: Array) -> Array:
	var snapshot: Array = []
	for squad in squads:
		if squad == null or not is_instance_valid(squad):
			continue
		if not (squad is Node2D):
			continue
		var vehicle_value = squad.get("vehicle")
		if vehicle_value == null:
			continue
		var squad_node := squad as Node2D
		var editor_unit_id: Variant = squad.get("editor_unit_id")
		var stable_id := int(editor_unit_id) if editor_unit_id != null and int(editor_unit_id) > 0 else int(squad.get_instance_id())
		snapshot.append({
			"id": stable_id,
			"vehicle": int(vehicle_value),
			"x": float(squad_node.position.x),
			"y": float(squad_node.position.y),
			"quantity": max(1, int(squad.get("quantity") if squad.get("quantity") != null else 1)),
		})
	return snapshot


static func playable_sector_at_world_position(world_x: float, world_z: float) -> Vector2i:
	return Vector2i(_world_to_sector_index(world_x), _world_to_sector_index(world_z))


static func filter_snapshot_to_sectors(snapshot: Array, sectors: Array) -> Array:
	if sectors.is_empty():
		return []
	var wanted := {}
	for sector_value in sectors:
		if sector_value is Vector2i:
			wanted[Vector2i(sector_value)] = true
	var filtered: Array = []
	for entry_value in snapshot:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry := entry_value as Dictionary
		var sector := playable_sector_at_world_position(float(entry.get("x", 0.0)), absf(float(entry.get("y", 0.0))))
		if wanted.has(sector):
			filtered.append(entry)
	return filtered


# ---------------------------------------------------------------------------
# Descriptor producers.
# ---------------------------------------------------------------------------

static func build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	var descriptors: Array = []
	for host_station in host_stations:
		if typeof(host_station) != TYPE_DICTIONARY:
			continue
		var hs := host_station as Dictionary
		var vehicle := int(hs.get("vehicle", -1))
		if vehicle < 0:
			continue
		var base_name := host_station_base_name_for_vehicle(vehicle)
		if base_name.is_empty():
			continue
		if not UATerrainPieceLibrary.has_piece_source(set_id, base_name):
			continue
		var world_x := float(hs.get("x", 0.0))
		var world_z := absf(float(hs.get("y", 0.0)))
		var ua_y := float(hs.get("pos_y", 0.0))
		var support_y := support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile)
		var origin := Vector3(world_x, support_y - ua_y, world_z)
		var station_key_id := int(hs.get("id", 0))
		descriptors.append({
			"set_id": set_id,
			"raw_id": - 1,
			"base_name": base_name,
			"instance_key": "host:%d:%d:%s" % [set_id, station_key_id, base_name],
			"origin": origin,
		})
		var gun_attachments_value = HOST_STATION_GUN_ATTACHMENTS.get(vehicle, [])
		if gun_attachments_value is Array:
			for attachment in gun_attachments_value:
				if typeof(attachment) != TYPE_DICTIONARY:
					continue
				var gun_type := int(attachment.get("gun_type", -1))
				var gun_base_name := host_station_gun_base_name_for_type(gun_type)
				if gun_base_name.is_empty():
					continue
				if not UATerrainPieceLibrary.has_piece_source(set_id, gun_base_name):
					continue
				var ua_offset := vector3_from_variant(attachment.get("ua_offset", Vector3.ZERO))
				var gun_descriptor := {
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": gun_base_name,
					"instance_key": "host_gun:%d:%d:%d:%s" % [set_id, station_key_id, gun_type, gun_base_name],
					"origin": origin + godot_offset_from_ua(ua_offset),
				}
				var ua_direction := vector3_from_variant(attachment.get("ua_direction", Vector3.ZERO))
				var godot_direction := godot_direction_from_ua(ua_direction)
				if godot_direction.length_squared() > 0.000001:
					gun_descriptor["forward"] = godot_direction
				descriptors.append(gun_descriptor)
	return descriptors


static func build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return build_host_station_descriptors_from_snapshot(snapshot_host_station_nodes(host_stations), set_id, hgt, w, h, support_descriptors, profile)


static func build_host_station_descriptors_for_sectors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, support_descriptors: Array = [], profile = null) -> Array:
	return build_host_station_descriptors_from_snapshot(filter_snapshot_to_sectors(snapshot_host_station_nodes(host_stations), sectors), set_id, hgt, w, h, support_descriptors, profile)


static func build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	var descriptors: Array = []
	for squad in squads:
		if typeof(squad) != TYPE_DICTIONARY:
			continue
		var sq := squad as Dictionary
		var vehicle := int(sq.get("vehicle", -1))
		if vehicle < 0:
			continue
		var base_name := squad_base_name_for_vehicle(vehicle, set_id, game_data_type)
		if base_name.is_empty():
			continue
		var has_piece_source := UATerrainPieceLibrary.has_piece_source(set_id, base_name)
		if not has_piece_source:
			continue
		var world_x := float(sq.get("x", 0.0))
		var world_z := absf(float(sq.get("y", 0.0)))
		var anchor := Vector3(world_x, support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile), world_z)
		var squad_key_id := int(sq.get("id", 0))
		var quantity: int = max(1, int(sq.get("quantity", 1)))
		var offsets := squad_formation_offsets(quantity)
		for unit_index in offsets.size():
			var formation_offset: Vector3 = offsets[unit_index]
			descriptors.append({
				"set_id": set_id,
				"raw_id": - 1,
				"base_name": base_name,
				"origin": anchor + Vector3(formation_offset),
				"instance_key": "squad:%d:%d:%s:%d" % [set_id, squad_key_id, base_name, unit_index],
				"y_offset": SQUAD_EXTRA_Y_OFFSET,
			})
	return descriptors


static func build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return build_squad_descriptors_from_snapshot(snapshot_squad_nodes(squads), set_id, hgt, w, h, support_descriptors, game_data_type, profile)


static func build_squad_descriptors_for_sectors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return build_squad_descriptors_from_snapshot(filter_snapshot_to_sectors(snapshot_squad_nodes(squads), sectors), set_id, hgt, w, h, support_descriptors, game_data_type, profile)


static func build_blg_attachment_descriptors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, _support_descriptors: Array, game_data_type: String) -> Array:
	return build_blg_attachment_descriptors_for_sectors(blg, effective_typ, set_id, hgt, w, h, [], game_data_type)


static func build_blg_attachment_descriptors_for_sectors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, game_data_type: String) -> Array:
	var descriptors: Array = []
	if blg.size() != w * h or effective_typ.size() != w * h:
		return descriptors
	var sector_filter := {}
	if not sectors.is_empty():
		for sector_value in sectors:
			if sector_value is Vector2i:
				sector_filter[Vector2i(sector_value)] = true
	elif not _packed_byte_array_has_nonzero(blg):
		return descriptors
	# Source-backed building turret/radar sockets (`sbact_pos_*`) are defined relative to
	# the sector center, so their Y anchor should stay on the terrain sector height rather
	# than snapping up to the authored support mesh used by squads/host stations.
	for sy in h:
		for sx in w:
			if not sector_filter.is_empty() and not sector_filter.has(Vector2i(sx, sy)):
				continue
			var idx := sy * w + sx
			var building_id := int(blg[idx])
			if building_id <= 0:
				continue
			var definition := building_definition_for_id_and_sec_type(building_id, int(effective_typ[idx]), set_id, game_data_type)
			if definition.is_empty():
				continue
			var world_x := (float(sx) + 1.5) * SECTOR_SIZE
			var world_z := (float(sy) + 1.5) * SECTOR_SIZE
			var sector_origin := sector_center_origin(sx, sy, ground_height_at_world_position(hgt, w, h, world_x, world_z))
			var attachments: Array = definition.get("attachments", [])
			for attachment_idx in attachments.size():
				var attachment_value = attachments[attachment_idx]
				if typeof(attachment_value) != TYPE_DICTIONARY:
					continue
				var attachment := attachment_value as Dictionary
				var base_name := building_attachment_base_name_for_vehicle(int(attachment.get("vehicle_id", -1)), set_id, game_data_type)
				if base_name.is_empty():
					continue
				var has_piece_source := UATerrainPieceLibrary.has_piece_source(set_id, base_name)
				if not has_piece_source:
					continue
				var descriptor := {
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "blg_attach:%d:%d:%d:%d:%d:%s" % [
						set_id,
						sx,
						sy,
						building_id,
						int(attachment.get("vehicle_id", -1)),
						str(attachment_idx)
					],
					"origin": sector_origin + godot_offset_from_ua(vector3_from_variant(attachment.get("ua_offset", Vector3.ZERO))),
				}
				var godot_direction := godot_direction_from_ua(vector3_from_variant(attachment.get("ua_direction", Vector3.ZERO)))
				if godot_direction.length_squared() > 0.000001:
					descriptor["forward"] = godot_direction
				descriptors.append(descriptor)
	return descriptors


static func _packed_byte_array_has_nonzero(values: PackedByteArray) -> bool:
	for value in values:
		if int(value) != 0:
			return true
	return false

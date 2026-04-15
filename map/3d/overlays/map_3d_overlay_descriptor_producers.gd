extends RefCounted

# Pure static overlay descriptor producers for the 3D map preview.
# Extracted from Map3DRenderer (Step 4 refactoring).
# All functions are static and produce plain descriptor dictionaries
# without touching the scene tree.

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const VisualCatalog := preload("res://map/3d/config/map_3d_visual_catalog.gd")
const VisualLookupService = preload("res://map/3d/services/map_3d_visual_lookup_service.gd")
const SupportQueryContext := preload("res://map/3d/services/map_3d_support_query_context.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE

const HOST_STATION_BASE_NAMES := VisualCatalog.HOST_STATION_BASE_NAMES
const HOST_STATION_VISIBLE_GUN_BASE_NAMES := VisualCatalog.HOST_STATION_VISIBLE_GUN_BASE_NAMES
const HOST_STATION_GUN_ATTACHMENTS := VisualCatalog.HOST_STATION_GUN_ATTACHMENTS

const SQUAD_FORMATION_SPACING := SharedConstants.SQUAD_FORMATION_SPACING
const SQUAD_EXTRA_Y_OFFSET := SharedConstants.SQUAD_EXTRA_Y_OFFSET


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

static func support_height_at_world_position(hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, world_x: float, world_z: float, support_query_context = null, profile = null) -> float:
	var resolved := _resolve_support_query_context_and_profile(support_query_context, profile)
	var query_context = resolved.get("support_query_context", null)
	var resolved_profile = resolved.get("profile", null)
	var started_usec := Time.get_ticks_usec()
	var terrain_height := ground_height_at_world_position(hgt, w, h, world_x, world_z)
	if query_context != null:
		_profile_increment(resolved_profile, "support_height_query_count")
		var indexed_height := float(query_context.support_height_at_world_position(world_x, world_z, terrain_height, resolved_profile))
		_profile_add_duration(resolved_profile, "support_height_query_ms", _elapsed_ms_since(started_usec))
		return indexed_height
	var authored_support: Variant = null
	if support_descriptors.size() > 0:
		authored_support = UATerrainPieceLibrary.support_height_at_world_position(support_descriptors, world_x, world_z)
	_profile_increment(resolved_profile, "support_height_query_count")
	_profile_add_duration(resolved_profile, "support_height_query_ms", _elapsed_ms_since(started_usec))
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


static func _resolve_support_query_context_and_profile(maybe_context = null, maybe_profile = null) -> Dictionary:
	var support_query_context = null
	var profile = maybe_profile
	if typeof(maybe_context) == TYPE_OBJECT and maybe_context != null and maybe_context.has_method("support_height_at_world_position"):
		support_query_context = maybe_context
	elif profile == null:
		profile = maybe_context
	return {
		"support_query_context": support_query_context,
		"profile": profile,
	}


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

static func build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], support_query_context = null, profile = null) -> Array:
	var resolved := _resolve_support_query_context_and_profile(support_query_context, profile)
	var query_context = resolved.get("support_query_context", null)
	var resolved_profile = resolved.get("profile", null)
	var descriptors: Array = []
	var base_name_cache := {}
	var piece_source_cache := {}
	for host_station in host_stations:
		if typeof(host_station) != TYPE_DICTIONARY:
			continue
		var hs := host_station as Dictionary
		var vehicle := int(hs.get("vehicle", -1))
		if vehicle < 0:
			continue
		var base_name := String(base_name_cache.get(vehicle, ""))
		if base_name.is_empty():
			base_name = host_station_base_name_for_vehicle(vehicle)
			base_name_cache[vehicle] = base_name
		if base_name.is_empty():
			continue
		var piece_source_key := "%d:%s" % [set_id, base_name]
		var has_piece_source := bool(piece_source_cache.get(piece_source_key, false))
		if not piece_source_cache.has(piece_source_key):
			has_piece_source = UATerrainPieceLibrary.has_piece_source(set_id, base_name)
			piece_source_cache[piece_source_key] = has_piece_source
		if not has_piece_source:
			continue
		var world_x := float(hs.get("x", 0.0))
		var world_z := absf(float(hs.get("y", 0.0)))
		var ua_y := float(hs.get("pos_y", 0.0))
		var support_y := support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, query_context, resolved_profile)
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
				var gun_piece_source_key := "%d:%s" % [set_id, gun_base_name]
				var has_gun_piece_source := bool(piece_source_cache.get(gun_piece_source_key, false))
				if not piece_source_cache.has(gun_piece_source_key):
					has_gun_piece_source = UATerrainPieceLibrary.has_piece_source(set_id, gun_base_name)
					piece_source_cache[gun_piece_source_key] = has_gun_piece_source
				if not has_gun_piece_source:
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


static func build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], support_query_context = null, profile = null) -> Array:
	return build_host_station_descriptors_from_snapshot(snapshot_host_station_nodes(host_stations), set_id, hgt, w, h, support_descriptors, support_query_context, profile)


static func build_host_station_descriptors_for_sectors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, support_descriptors: Array = [], support_query_context = null, profile = null) -> Array:
	return build_host_station_descriptors_from_snapshot(filter_snapshot_to_sectors(snapshot_host_station_nodes(host_stations), sectors), set_id, hgt, w, h, support_descriptors, support_query_context, profile)


static func build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, support_query_context = null, profile = null) -> Array:
	var resolved := _resolve_support_query_context_and_profile(support_query_context, profile)
	var query_context = resolved.get("support_query_context", null)
	var resolved_profile = resolved.get("profile", null)
	var descriptors: Array = []
	var base_name_cache := {}
	var piece_source_cache := {}
	var formation_offsets_cache := {}
	for squad in squads:
		if typeof(squad) != TYPE_DICTIONARY:
			continue
		var sq := squad as Dictionary
		var vehicle := int(sq.get("vehicle", -1))
		if vehicle < 0:
			continue
		var vehicle_key := "%d:%d:%s" % [vehicle, set_id, game_data_type]
		var base_name := String(base_name_cache.get(vehicle_key, ""))
		if base_name.is_empty():
			base_name = squad_base_name_for_vehicle(vehicle, set_id, game_data_type)
			base_name_cache[vehicle_key] = base_name
		if base_name.is_empty():
			continue
		var piece_source_key := "%d:%s" % [set_id, base_name]
		var has_piece_source := bool(piece_source_cache.get(piece_source_key, false))
		if not piece_source_cache.has(piece_source_key):
			has_piece_source = UATerrainPieceLibrary.has_piece_source(set_id, base_name)
			piece_source_cache[piece_source_key] = has_piece_source
		if not has_piece_source:
			continue
		var world_x := float(sq.get("x", 0.0))
		var world_z := absf(float(sq.get("y", 0.0)))
		var anchor := Vector3(world_x, support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, query_context, resolved_profile), world_z)
		var squad_key_id := int(sq.get("id", 0))
		var quantity: int = max(1, int(sq.get("quantity", 1)))
		var offsets: Array = formation_offsets_cache.get(quantity, [])
		if offsets.is_empty():
			offsets = squad_formation_offsets(quantity)
			formation_offsets_cache[quantity] = offsets
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


static func build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, support_query_context = null, profile = null) -> Array:
	return build_squad_descriptors_from_snapshot(snapshot_squad_nodes(squads), set_id, hgt, w, h, support_descriptors, game_data_type, support_query_context, profile)


static func build_squad_descriptors_for_sectors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, support_descriptors: Array, game_data_type: String, support_query_context = null, profile = null) -> Array:
	return build_squad_descriptors_from_snapshot(filter_snapshot_to_sectors(snapshot_squad_nodes(squads), sectors), set_id, hgt, w, h, support_descriptors, game_data_type, support_query_context, profile)


static func build_blg_attachment_descriptors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, _support_descriptors: Array, game_data_type: String) -> Array:
	return build_blg_attachment_descriptors_for_sectors(blg, effective_typ, set_id, hgt, w, h, [], game_data_type)


static func build_blg_attachment_descriptors_for_sectors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, sectors: Array, game_data_type: String) -> Array:
	var descriptors: Array = []
	if blg.size() != w * h or effective_typ.size() != w * h:
		return descriptors
	var sector_filter := {}
	var sector_list: Array[Vector2i] = []
	if not sectors.is_empty():
		for sector_value in sectors:
			if not (sector_value is Vector2i):
				continue
			var sector := Vector2i(sector_value)
			if sector.x < 0 or sector.y < 0 or sector.x >= w or sector.y >= h or sector_filter.has(sector):
				continue
			sector_filter[sector] = true
			sector_list.append(sector)
	else:
		sector_list = _occupied_blg_sectors(blg, w, h)
	if sector_list.is_empty():
		return descriptors
	# Source-backed building turret/radar sockets (`sbact_pos_*`) are defined relative to
	# the sector center, so their Y anchor should stay on the terrain sector height rather
	# than snapping up to the authored support mesh used by squads/host stations.
	var attachment_template_cache := {}
	var piece_source_cache := {}
	for sector in sector_list:
		_append_building_attachment_descriptors_for_sector(
			descriptors,
			blg,
			effective_typ,
			set_id,
			hgt,
			w,
			h,
			sector.x,
			sector.y,
			game_data_type,
			attachment_template_cache,
			piece_source_cache
		)
	return descriptors


static func _append_building_attachment_descriptors_for_sector(descriptors: Array, blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, sx: int, sy: int, game_data_type: String, attachment_template_cache: Dictionary, piece_source_cache: Dictionary) -> void:
	if sx < 0 or sy < 0 or sx >= w or sy >= h:
		return
	var idx := sy * w + sx
	var building_id := int(blg[idx])
	if building_id <= 0:
		return
	var sec_type := int(effective_typ[idx])
	var attachment_templates := _building_attachment_templates_for_sector(building_id, sec_type, set_id, game_data_type, attachment_template_cache, piece_source_cache)
	if attachment_templates.is_empty():
		return
	var world_x := (float(sx) + 1.5) * SECTOR_SIZE
	var world_z := (float(sy) + 1.5) * SECTOR_SIZE
	var sector_origin := sector_center_origin(sx, sy, ground_height_at_world_position(hgt, w, h, world_x, world_z))
	for template_value in attachment_templates:
		if typeof(template_value) != TYPE_DICTIONARY:
			continue
		var template := template_value as Dictionary
		var descriptor := {
			"set_id": set_id,
			"raw_id": - 1,
			"base_name": String(template.get("base_name", "")),
			"instance_key": "blg_attach:%d:%d:%d:%d:%d:%s" % [
				set_id,
				sx,
				sy,
				building_id,
				int(template.get("vehicle_id", -1)),
				String(template.get("attachment_index", "0"))
			],
			"origin": sector_origin + Vector3(template.get("offset", Vector3.ZERO)),
		}
		var godot_direction := Vector3(template.get("forward", Vector3.ZERO))
		if godot_direction.length_squared() > 0.000001:
			descriptor["forward"] = godot_direction
		descriptors.append(descriptor)


static func _building_attachment_templates_for_sector(building_id: int, sec_type: int, set_id: int, game_data_type: String, attachment_template_cache: Dictionary, piece_source_cache: Dictionary) -> Array:
	var cache_key := "%d:%d:%d:%s" % [building_id, sec_type, set_id, game_data_type]
	if attachment_template_cache.has(cache_key):
		return attachment_template_cache[cache_key]
	var definition := VisualLookupService._building_definition_for_id_and_sec_type_ref(building_id, sec_type, set_id, game_data_type)
	if definition.is_empty():
		attachment_template_cache[cache_key] = []
		return []
	var templates: Array = []
	var attachments: Array = definition.get("attachments", [])
	for attachment_idx in attachments.size():
		var attachment_value = attachments[attachment_idx]
		if typeof(attachment_value) != TYPE_DICTIONARY:
			continue
		var attachment := attachment_value as Dictionary
		var vehicle_id := int(attachment.get("vehicle_id", -1))
		var base_name := building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type)
		if base_name.is_empty():
			continue
		var piece_source_key := "%d:%s" % [set_id, base_name]
		var has_piece_source := bool(piece_source_cache.get(piece_source_key, false))
		if not piece_source_cache.has(piece_source_key):
			has_piece_source = UATerrainPieceLibrary.has_piece_source(set_id, base_name)
			piece_source_cache[piece_source_key] = has_piece_source
		if not has_piece_source:
			continue
		var template := {
			"vehicle_id": vehicle_id,
			"attachment_index": str(attachment_idx),
			"base_name": base_name,
			"offset": godot_offset_from_ua(vector3_from_variant(attachment.get("ua_offset", Vector3.ZERO))),
		}
		var godot_direction := godot_direction_from_ua(vector3_from_variant(attachment.get("ua_direction", Vector3.ZERO)))
		if godot_direction.length_squared() > 0.000001:
			template["forward"] = godot_direction
		templates.append(template)
	attachment_template_cache[cache_key] = templates
	return templates


static func _packed_byte_array_has_nonzero(values: PackedByteArray) -> bool:
	for value in values:
		if int(value) != 0:
			return true
	return false


static func _occupied_blg_sectors(blg: PackedByteArray, w: int, h: int) -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	if blg.size() != w * h:
		return sectors
	for sy in h:
		for sx in w:
			if int(blg[sy * w + sx]) <= 0:
				continue
			sectors.append(Vector2i(sx, sy))
	return sectors

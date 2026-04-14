extends RefCounted

const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const VisualCatalog := preload("res://map/3d/config/map_3d_visual_catalog.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE
const WORLD_SCALE := SharedConstants.WORLD_SCALE


static func sector_center_origin(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE, sector_y, (float(sy) + 1.5) * SECTOR_SIZE)


static func sector_center_origin_scaled(sx: int, sy: int, sector_y: float) -> Vector3:
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE * WORLD_SCALE, sector_y * WORLD_SCALE, (float(sy) + 1.5) * SECTOR_SIZE * WORLD_SCALE)


static func host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return String(VisualCatalog.HOST_STATION_BASE_NAMES.get(vehicle_id, ""))


static func host_station_gun_base_name_for_type(gun_type: int) -> String:
	return String(VisualCatalog.HOST_STATION_VISIBLE_GUN_BASE_NAMES.get(gun_type, ""))


static func vector3_from_variant(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return Vector3(value)
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var dict := Dictionary(value)
	return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))


static func host_station_godot_offset_from_ua(ua_offset: Vector3) -> Vector3:
	return Vector3(ua_offset.x, -ua_offset.y, -ua_offset.z)


static func host_station_godot_direction_from_ua(ua_direction: Vector3) -> Vector3:
	var godot_direction := Vector3(ua_direction.x, -ua_direction.y, -ua_direction.z)
	var horizontal_direction := Vector3(godot_direction.x, 0.0, godot_direction.z)
	if horizontal_direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return horizontal_direction.normalized()


static func world_to_sector_index(world_coord: float) -> int:
	return int(floor(world_coord / SECTOR_SIZE)) - 1


static func _sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, h + 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE


static func ground_height_at_world_position(hgt: PackedByteArray, w: int, h: int, world_x: float, world_z: float) -> float:
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2):
		return 0.0
	return _sample_hgt_height(hgt, w, h, world_to_sector_index(world_x), world_to_sector_index(world_z))


static func _elapsed_ms_since(started_usec: int) -> float:
	return maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)


static func _profile_increment(profile, key: String, amount: int = 1) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = int(profile.get(key, 0)) + amount


static func _profile_add_duration(profile, key: String, duration_ms: float) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = float(profile.get(key, 0.0)) + maxf(duration_ms, 0.0)


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


static func host_station_origin(host_station: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	var pos_y_value = host_station.get("pos_y")
	var ua_x := float(host_station.position.x)
	var world_z := absf(float(host_station.position.y))
	var ua_y := float(pos_y_value if pos_y_value != null else 0.0)
	var support_y := support_height_at_world_position(hgt, w, h, support_descriptors, ua_x, world_z, profile)
	return Vector3(ua_x, support_y - ua_y, world_z)


static func snapshot_host_station_nodes(host_stations: Array) -> Array:
	return OverlayProducers.snapshot_host_station_nodes(host_stations)


static func build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return OverlayProducers.build_host_station_descriptors_from_snapshot(host_stations, set_id, hgt, w, h, support_descriptors, profile)


static func build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return OverlayProducers.build_host_station_descriptors(host_stations, set_id, hgt, w, h, support_descriptors, profile)


static func squad_quantity(squad: Object) -> int:
	var quantity_value = squad.get("quantity")
	if quantity_value == null:
		return 1
	return max(1, int(quantity_value))


static func squad_anchor_origin(squad: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	var world_x := float(squad.position.x)
	var world_z := absf(float(squad.position.y))
	return Vector3(world_x, support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile), world_z)


static func squad_formation_offsets(quantity: int) -> Array:
	return OverlayProducers.squad_formation_offsets(quantity)


static func snapshot_squad_nodes(squads: Array) -> Array:
	return OverlayProducers.snapshot_squad_nodes(squads)


static func build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors_from_snapshot(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)


static func build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)

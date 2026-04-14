extends RefCounted
const VisualLookupService := preload("res://map/3d/services/map_3d_visual_lookup_service.gd")

var cache_valid := false
var cache_game_data_type := ""
var cache_dims: Vector2i = Vector2i(-1, -1)
var cache: PackedByteArray = PackedByteArray()
var dirty := true
var cache_typ_checksum: int = 0
var cache_blg_checksum: int = 0


func invalidate_cache() -> void:
	cache_valid = false


func is_valid_cache(w: int, h: int, game_data_type: String, typ_checksum: int, blg_checksum: int) -> bool:
	return cache_valid and (not dirty) and cache_dims == Vector2i(w, h) and cache_game_data_type == game_data_type and cache_typ_checksum == typ_checksum and cache_blg_checksum == blg_checksum


func get_effective_typ() -> PackedByteArray:
	return cache


func set_dirty(value: bool) -> void:
	dirty = value


func compute_effective_typ_for_map(
	cmd: Node,
	w: int,
	h: int,
	typ: PackedByteArray,
	blg: PackedByteArray,
	game_data_type: String
) -> PackedByteArray:
	var typ_checksum := checksum_packed_byte_array(typ)
	var blg_checksum := checksum_packed_byte_array(blg)
	var can_reuse_effective_typ := cache_valid and (not dirty) and cache_dims == Vector2i(w, h) and cache_game_data_type == game_data_type and cache_typ_checksum == typ_checksum and cache_blg_checksum == blg_checksum
	if can_reuse_effective_typ:
		return cache
	var effective_typ := effective_typ_map_for_3d(
		typ,
		blg,
		game_data_type,
		w,
		h,
		cmd.beam_gates,
		cmd.tech_upgrades,
		cmd.stoudson_bombs
	)
	cache = effective_typ
	cache_valid = true
	cache_game_data_type = game_data_type
	cache_dims = Vector2i(w, h)
	cache_typ_checksum = typ_checksum
	cache_blg_checksum = blg_checksum
	dirty = false
	return effective_typ


static func clear_runtime_lookup_caches_for_tests() -> void:
	VisualLookupService._clear_runtime_lookup_caches_for_tests()


static func checksum_packed_byte_array(data: PackedByteArray) -> int:
	var h: int = 2166136261
	for b in data:
		h = int((h ^ int(b)) * 16777619)
		h = h & 0xFFFFFFFF
	return h


static func blg_typ_overrides_for_game_data_type(game_data_type: String) -> Dictionary:
	return VisualLookupService._blg_typ_overrides_for_game_data_type(game_data_type)


static func building_sec_type_overrides_for_script_names(set_id: int, game_data_type: String, script_names: Array[String]) -> Dictionary:
	return VisualLookupService._building_sec_type_overrides_for_script_names(set_id, game_data_type, script_names)


static func tech_upgrade_typ_overrides_for_3d(set_id: int, game_data_type: String) -> Dictionary:
	return VisualLookupService._tech_upgrade_typ_overrides_for_3d(set_id, game_data_type)


static func entity_property(entity: Variant, property_names: Array[String], default_value: Variant = null) -> Variant:
	if typeof(entity) == TYPE_DICTIONARY:
		var dict := entity as Dictionary
		for property_name in property_names:
			if dict.has(property_name):
				return dict[property_name]
		return default_value
	if typeof(entity) != TYPE_OBJECT or entity == null:
		return default_value
	var object := entity as Object
	var available_properties := {}
	for property_value in object.get_property_list():
		if typeof(property_value) != TYPE_DICTIONARY:
			continue
		var property_name := String(Dictionary(property_value).get("name", ""))
		if property_name.is_empty():
			continue
		available_properties[property_name] = true
	for property_name in property_names:
		if available_properties.has(property_name):
			return object.get(property_name)
	return default_value


static func entity_int_property(entity: Variant, property_names: Array[String], default_value := -1) -> int:
	var value = entity_property(entity, property_names, null)
	if value == null:
		return default_value
	return int(value)


static func apply_sector_building_overrides_from_entities(
	effective: PackedByteArray,
	w: int,
	h: int,
	entities: Array,
	building_property_names: Array[String],
	building_sec_type_overrides: Dictionary
) -> void:
	if w <= 0 or h <= 0 or effective.size() != w * h:
		return
	for entity in entities:
		var sector_x := entity_int_property(entity, ["sec_x"], -1)
		var sector_y := entity_int_property(entity, ["sec_y"], -1)
		if sector_x <= 0 or sector_y <= 0 or sector_x > w or sector_y > h:
			continue
		var sec_x := sector_x - 1
		var sec_y := sector_y - 1
		var building_id := entity_int_property(entity, building_property_names, -1)
		if building_id < 0 or not building_sec_type_overrides.has(building_id):
			continue
		effective[sec_y * w + sec_x] = clampi(int(building_sec_type_overrides[building_id]), 0, 255)


static func effective_typ_map_for_3d(
	typ: PackedByteArray,
	blg: PackedByteArray,
	game_data_type: String,
	w: int = -1,
	h: int = -1,
	beam_gates: Array = [],
	tech_upgrades: Array = [],
	stoudson_bombs: Array = [],
	set_id: int = 1
) -> PackedByteArray:
	var effective: PackedByteArray = typ.duplicate()
	var blg_overrides := blg_typ_overrides_for_game_data_type(game_data_type)
	if blg.size() == typ.size():
		for i in min(typ.size(), blg.size()):
			var building_id := int(blg[i])
			if not blg_overrides.has(building_id):
				continue
			effective[i] = clampi(int(blg_overrides[building_id]), 0, 255)
	if w <= 0 or h <= 0 or typ.size() != w * h:
		return effective
	var build_script_overrides := building_sec_type_overrides_for_script_names(set_id, game_data_type, ["BUILD.SCR"])
	var tech_upgrade_overrides := tech_upgrade_typ_overrides_for_3d(set_id, game_data_type)
	apply_sector_building_overrides_from_entities(effective, w, h, beam_gates, ["closed_bp"], build_script_overrides)
	apply_sector_building_overrides_from_entities(effective, w, h, tech_upgrades, ["building_id", "building"], tech_upgrade_overrides)
	apply_sector_building_overrides_from_entities(effective, w, h, stoudson_bombs, ["inactive_bp"], build_script_overrides)
	return effective

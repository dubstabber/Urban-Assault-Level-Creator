extends RefCounted
class_name Map3DStaticOverlayIndex

const TerrainBuilder := preload("res://map/map_3d_terrain_builder.gd")

var _descriptors_by_key: Dictionary = {}


func clear() -> void:
	_descriptors_by_key.clear()


func replace_all(descriptors: Array) -> void:
	_descriptors_by_key.clear()
	for desc_any in descriptors:
		if typeof(desc_any) != TYPE_DICTIONARY:
			continue
		var desc := desc_any as Dictionary
		var key := String(desc.get("instance_key", ""))
		if key.is_empty():
			continue
		_descriptors_by_key[key] = desc


func replace_matching_prefixes(prefixes: Array, descriptors: Array) -> void:
	for key_value in _descriptors_by_key.keys():
		var key := String(key_value)
		if _matches_prefixes(key, prefixes):
			_descriptors_by_key.erase(key)
	for desc_any in descriptors:
		if typeof(desc_any) != TYPE_DICTIONARY:
			continue
		var desc := desc_any as Dictionary
		var key := String(desc.get("instance_key", ""))
		if key.is_empty():
			continue
		_descriptors_by_key[key] = desc


func descriptors() -> Array:
	return _descriptors_by_key.values().duplicate(true)


static func terrain_prefixes_for_chunks(set_id: int, chunks: Array, w: int, h: int) -> Array[String]:
	var prefixes: Array[String] = []
	var seen := {}
	for chunk_value in chunks:
		if not (chunk_value is Vector2i):
			continue
		var chunk_coord := Vector2i(chunk_value)
		var chunk_range := TerrainBuilder.chunk_sector_range(chunk_coord.x, chunk_coord.y)
		var sx_min := maxi(chunk_range.position.x - 1, -1)
		var sy_min := maxi(chunk_range.position.y - 1, -1)
		var sx_max := mini(chunk_range.position.x + TerrainBuilder.CHUNK_SIZE + 1, w + 1)
		var sy_max := mini(chunk_range.position.y + TerrainBuilder.CHUNK_SIZE + 1, h + 1)
		for y in range(sy_min, sy_max):
			for x in range(sx_min, sx_max):
				_add_prefix(prefixes, seen, "terrain:%d:%d:%d:" % [set_id, x, y])
		for y in range(sy_min, sy_max):
			for x in range(sx_min, mini(chunk_range.position.x + TerrainBuilder.CHUNK_SIZE, w)):
				_add_prefix(prefixes, seen, "slurp:v:%d:%d:%d:" % [set_id, x, y])
		for y in range(sy_min, mini(chunk_range.position.y + TerrainBuilder.CHUNK_SIZE, h)):
			for x in range(sx_min, sx_max):
				_add_prefix(prefixes, seen, "slurp:h:%d:%d:%d:" % [set_id, x, y])
	return prefixes


static func building_attachment_prefixes_for_sectors(set_id: int, sectors: Array) -> Array[String]:
	var prefixes: Array[String] = []
	var seen := {}
	for sector_value in sectors:
		if not (sector_value is Vector2i):
			continue
		var sector := Vector2i(sector_value)
		_add_prefix(prefixes, seen, "blg_attach:%d:%d:%d:" % [set_id, sector.x, sector.y])
	return prefixes


static func exact_instance_key_prefixes(descriptors: Array) -> Array[String]:
	var prefixes: Array[String] = []
	var seen := {}
	for desc_any in descriptors:
		if typeof(desc_any) != TYPE_DICTIONARY:
			continue
		var key := String((desc_any as Dictionary).get("instance_key", ""))
		if key.is_empty():
			continue
		_add_prefix(prefixes, seen, key)
	return prefixes


static func _matches_prefixes(key: String, prefixes: Array) -> bool:
	for prefix_value in prefixes:
		var prefix := String(prefix_value)
		if not prefix.is_empty() and key.begins_with(prefix):
			return true
	return false


static func _add_prefix(target: Array[String], seen: Dictionary, prefix: String) -> void:
	if prefix.is_empty() or seen.has(prefix):
		return
	seen[prefix] = true
	target.append(prefix)

extends RefCounted
class_name Map3DSupportQueryContext

const SupportSampler := preload("res://map/terrain/ua_authored_support_sampler.gd")
const UATerrainPieceLibrary := preload("res://map/terrain/ua_authored_piece_library.gd")

const BUCKET_CELL_SIZE := SupportSampler.SUPPORT_BUCKET_CELL_SIZE

var _entries: Array = []
var _buckets := {}
var _memoized_heights := {}


static func create_from_support_descriptors(support_descriptors: Array, profile = null):
	var context = load("res://map/3d/services/map_3d_support_query_context.gd").new()
	context._build_from_support_descriptors(support_descriptors, profile)
	return context


static func create_from_entries(entries: Array, profile = null):
	var context = load("res://map/3d/services/map_3d_support_query_context.gd").new()
	context._build_from_entries(entries, profile)
	return context


func is_empty() -> bool:
	return _entries.is_empty()


func support_height_at_world_position(world_x: float, world_z: float, terrain_height: float, profile = null) -> float:
	var cache_key := _memoize_key(world_x, world_z)
	if _memoized_heights.has(cache_key):
		_profile_increment(profile, "support_query_cache_hits")
		return float(_memoized_heights[cache_key])
	var candidate_indices := _candidate_indices_for_world_position(world_x, world_z)
	_profile_add_count(profile, "support_query_candidate_count", candidate_indices.size())
	var best_y := terrain_height
	for entry_index in candidate_indices:
		var idx := int(entry_index)
		if idx < 0 or idx >= _entries.size():
			continue
		var entry := _entries[idx] as Dictionary
		if not _entry_contains_world_position(entry, world_x, world_z):
			continue
		var sampled_height = SupportSampler.support_sampler_height_at_world_position(
			entry.get("sampler", {}),
			entry.get("basis", Basis.IDENTITY),
			entry.get("origin", Vector3.ZERO),
			world_x,
			world_z
		)
		if sampled_height == null:
			continue
		best_y = maxf(best_y, float(sampled_height))
	_memoized_heights[cache_key] = best_y
	return best_y


func _build_from_support_descriptors(support_descriptors: Array, profile = null) -> void:
	var started_usec := Time.get_ticks_usec()
	var entries: Array = []
	for desc_value in support_descriptors:
		var entry := _entry_from_support_descriptor(desc_value)
		if entry.is_empty():
			continue
		entries.append(entry)
	_build_from_entries(entries, null)
	_profile_add_duration(profile, "support_query_index_build_ms", _elapsed_ms_since(started_usec))


func _build_from_entries(entries: Array, _profile = null) -> void:
	_entries.clear()
	_buckets.clear()
	_memoized_heights.clear()
	for entry_value in entries:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var normalized := _normalized_entry(entry_value as Dictionary)
		if normalized.is_empty():
			continue
		var entry_index := _entries.size()
		_entries.append(normalized)
		var min_cell_x := _bucket_coord(float(normalized.get("min_x", 0.0)))
		var max_cell_x := _bucket_coord(float(normalized.get("max_x", 0.0)))
		var min_cell_z := _bucket_coord(float(normalized.get("min_z", 0.0)))
		var max_cell_z := _bucket_coord(float(normalized.get("max_z", 0.0)))
		for cell_x in range(min_cell_x, max_cell_x + 1):
			for cell_z in range(min_cell_z, max_cell_z + 1):
				var bucket_key := _bucket_key(cell_x, cell_z)
				var bucket: Array = _buckets.get(bucket_key, [])
				bucket.append(entry_index)
				_buckets[bucket_key] = bucket


static func _entry_from_support_descriptor(desc_value) -> Dictionary:
	if typeof(desc_value) != TYPE_DICTIONARY:
		return {}
	var desc := desc_value as Dictionary
	var base_name := String(desc.get("base_name", "")).strip_edges()
	if base_name.is_empty():
		return {}
	var set_id := maxi(int(desc.get("set_id", 1)), 1)
	var warp_sig := UATerrainPieceLibrary._warp_signature(desc)
	var sampler := UATerrainPieceLibrary._piece_support_sampler(set_id, base_name, warp_sig, desc)
	if typeof(sampler) != TYPE_DICTIONARY or (sampler as Dictionary).is_empty():
		return {}
	var bounds_min := Vector3((sampler as Dictionary).get("bounds_min", Vector3.ZERO))
	var bounds_max := Vector3((sampler as Dictionary).get("bounds_max", Vector3.ZERO))
	var basis := UATerrainPieceLibrary._piece_basis_from_desc(desc)
	var origin := UATerrainPieceLibrary._piece_position_from_desc(desc)
	var world_bounds := _world_bounds_from_local_bounds(bounds_min, bounds_max, basis, origin)
	return {
		"sampler": sampler,
		"basis": basis,
		"origin": origin,
		"min_x": float(world_bounds.get("min_x", 0.0)),
		"max_x": float(world_bounds.get("max_x", 0.0)),
		"min_z": float(world_bounds.get("min_z", 0.0)),
		"max_z": float(world_bounds.get("max_z", 0.0)),
	}


static func _normalized_entry(entry: Dictionary) -> Dictionary:
	if entry.is_empty():
		return {}
	var sampler_value = entry.get("sampler", {})
	if typeof(sampler_value) != TYPE_DICTIONARY or (sampler_value as Dictionary).is_empty():
		return {}
	return {
		"sampler": sampler_value,
		"basis": entry.get("basis", Basis.IDENTITY),
		"origin": entry.get("origin", Vector3.ZERO),
		"min_x": float(entry.get("min_x", 0.0)),
		"max_x": float(entry.get("max_x", 0.0)),
		"min_z": float(entry.get("min_z", 0.0)),
		"max_z": float(entry.get("max_z", 0.0)),
	}


func _candidate_indices_for_world_position(world_x: float, world_z: float) -> Array:
	var cell_x := _bucket_coord(world_x)
	var cell_z := _bucket_coord(world_z)
	var seen := {}
	var indices: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket: Array = _buckets.get(_bucket_key(cell_x + dx, cell_z + dz), [])
			for entry_index in bucket:
				var idx := int(entry_index)
				if seen.has(idx):
					continue
				seen[idx] = true
				indices.append(idx)
	return indices


static func _entry_contains_world_position(entry: Dictionary, world_x: float, world_z: float) -> bool:
	return (
		world_x >= float(entry.get("min_x", 0.0)) - 0.001
		and world_x <= float(entry.get("max_x", 0.0)) + 0.001
		and world_z >= float(entry.get("min_z", 0.0)) - 0.001
		and world_z <= float(entry.get("max_z", 0.0)) + 0.001
	)


static func _world_bounds_from_local_bounds(bounds_min: Vector3, bounds_max: Vector3, basis: Basis, origin: Vector3) -> Dictionary:
	var corners := [
		Vector3(bounds_min.x, 0.0, bounds_min.z),
		Vector3(bounds_min.x, 0.0, bounds_max.z),
		Vector3(bounds_max.x, 0.0, bounds_min.z),
		Vector3(bounds_max.x, 0.0, bounds_max.z),
	]
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for corner in corners:
		var world_corner: Vector3 = origin + (basis * corner)
		min_x = minf(min_x, world_corner.x)
		max_x = maxf(max_x, world_corner.x)
		min_z = minf(min_z, world_corner.z)
		max_z = maxf(max_z, world_corner.z)
	if min_x == INF or min_z == INF:
		return {}
	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_z": min_z,
		"max_z": max_z,
	}


static func _elapsed_ms_since(started_usec: int) -> float:
	if started_usec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)


static func _memoize_key(world_x: float, world_z: float) -> String:
	return "%.3f:%.3f" % [world_x, world_z]


static func _bucket_coord(value: float) -> int:
	return int(floor(value / BUCKET_CELL_SIZE))


static func _bucket_key(cell_x: int, cell_z: int) -> String:
	return "%d:%d" % [cell_x, cell_z]


static func _profile_increment(profile, key: String) -> void:
	if profile == null or typeof(profile) != TYPE_DICTIONARY:
		return
	var dict := profile as Dictionary
	dict[key] = int(dict.get(key, 0)) + 1


static func _profile_add_count(profile, key: String, amount: int) -> void:
	if profile == null or typeof(profile) != TYPE_DICTIONARY:
		return
	var dict := profile as Dictionary
	dict[key] = int(dict.get(key, 0)) + amount


static func _profile_add_duration(profile, key: String, ms: float) -> void:
	if profile == null or typeof(profile) != TYPE_DICTIONARY:
		return
	var dict := profile as Dictionary
	dict[key] = float(dict.get(key, 0.0)) + ms

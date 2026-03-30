extends RefCounted
class_name UAAuthoredSupportSampler

const SUPPORT_BUCKET_CELL_SIZE := 300.0

static var _piece_sampler_cache := {}

static func clear_runtime_caches() -> void:
	_piece_sampler_cache.clear()

static func clear_runtime_caches_for_tests() -> void:
	clear_runtime_caches()

static func has_piece_sampler_cache(cache_key: String) -> bool:
	return _piece_sampler_cache.has(cache_key)

static func get_cached_piece_sampler(cache_key: String) -> Dictionary:
	var cached = _piece_sampler_cache.get(cache_key, {})
	return cached if typeof(cached) == TYPE_DICTIONARY else {}

static func store_piece_sampler(cache_key: String, sampler: Dictionary) -> Dictionary:
	_piece_sampler_cache[cache_key] = sampler
	return sampler

static func piece_position_from_desc(desc: Dictionary, overlay_y_bias: float = 8.0) -> Vector3:
	return Vector3(desc.get("origin", Vector3.ZERO)) + Vector3(0.0, overlay_y_bias + float(desc.get("y_offset", 0.0)), 0.0)

static func piece_basis_from_desc(desc: Dictionary) -> Basis:
	var forward_value = desc.get("forward", null)
	if typeof(forward_value) != TYPE_VECTOR3:
		return Basis.IDENTITY
	var forward := Vector3(forward_value)
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() <= 0.000001:
		return Basis.IDENTITY
	return Basis(Vector3.UP, atan2(-horizontal_forward.x, -horizontal_forward.z))

static func support_height_at_world_position(descriptors: Array, world_x: float, world_z: float, sampler_provider: Callable, overlay_y_bias: float = 8.0):
	if not sampler_provider.is_valid():
		return null
	var seeded := false
	var best_y := 0.0
	for desc_value in descriptors:
		if typeof(desc_value) != TYPE_DICTIONARY:
			continue
		var desc := desc_value as Dictionary
		var sampler_value = sampler_provider.call(desc)
		if typeof(sampler_value) != TYPE_DICTIONARY:
			continue
		var sampler := sampler_value as Dictionary
		if sampler.is_empty():
			continue
		var basis := piece_basis_from_desc(desc)
		var origin := piece_position_from_desc(desc, overlay_y_bias)
		var sampled_height = support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)
		if sampled_height == null:
			continue
		var sampled_height_float := float(sampled_height)
		if not seeded or sampled_height_float > best_y:
			best_y = sampled_height_float
			seeded = true
	if not seeded:
		return null
	return best_y

static func mesh_support_height_at_world_position(mesh: Mesh, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	var sampler := support_sampler_from_mesh(mesh)
	return support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)

static func support_sampler_from_mesh(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}
	var triangles: Array = []
	for surface_idx in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in range(0, verts.size(), 3):
				if i + 2 >= verts.size():
					break
				append_support_triangle_record(triangles, verts[i], verts[i + 1], verts[i + 2])
			continue
		for i in range(0, indices.size(), 3):
			if i + 2 >= indices.size():
				break
			append_support_triangle_record(triangles, verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]])
	return support_sampler_from_triangle_records(triangles)

static func append_support_triangle_record(out: Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return
	if absf(normal.normalized().y) <= 0.0001:
		return
	var denominator := ((b.z - c.z) * (a.x - c.x)) + ((c.x - b.x) * (a.z - c.z))
	if absf(denominator) <= 0.000001:
		return
	out.append({
		"a": a,
		"b": b,
		"c": c,
		"denominator": denominator,
		"min_x": minf(a.x, minf(b.x, c.x)),
		"max_x": maxf(a.x, maxf(b.x, c.x)),
		"min_z": minf(a.z, minf(b.z, c.z)),
		"max_z": maxf(a.z, maxf(b.z, c.z)),
	})

static func support_sampler_from_triangle_records(triangles: Array) -> Dictionary:
	if triangles.is_empty():
		return {}
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	var buckets := {}
	for tri_index in triangles.size():
		var tri_value = triangles[tri_index]
		if typeof(tri_value) != TYPE_DICTIONARY:
			continue
		var tri := tri_value as Dictionary
		var a := Vector3(tri.get("a", Vector3.ZERO))
		var b := Vector3(tri.get("b", Vector3.ZERO))
		var c := Vector3(tri.get("c", Vector3.ZERO))
		min_v = min_v.min(a).min(b).min(c)
		max_v = max_v.max(a).max(b).max(c)
		var min_cell_x := _support_bucket_coord(float(tri.get("min_x", 0.0)))
		var max_cell_x := _support_bucket_coord(float(tri.get("max_x", 0.0)))
		var min_cell_z := _support_bucket_coord(float(tri.get("min_z", 0.0)))
		var max_cell_z := _support_bucket_coord(float(tri.get("max_z", 0.0)))
		for cell_x in range(min_cell_x, max_cell_x + 1):
			for cell_z in range(min_cell_z, max_cell_z + 1):
				var bucket_key := _support_bucket_key(cell_x, cell_z)
				var bucket: Array = buckets.get(bucket_key, [])
				bucket.append(tri_index)
				buckets[bucket_key] = bucket
	if min_v == Vector3(INF, INF, INF) or max_v == Vector3(-INF, -INF, -INF):
		return {}
	return {
		"bounds_min": min_v,
		"bounds_max": max_v,
		"buckets": buckets,
		"triangles": triangles,
	}

static func support_sampler_height_at_world_position(sampler: Dictionary, basis: Basis, origin: Vector3, world_x: float, world_z: float):
	if sampler.is_empty():
		return null
	var local := basis.inverse() * Vector3(world_x - origin.x, 0.0, world_z - origin.z)
	var local_y = support_sampler_height_at_local_position(sampler, local.x, local.z)
	if local_y == null:
		return null
	return origin.y + float(local_y)

static func support_sampler_height_at_local_position(sampler: Dictionary, local_x: float, local_z: float):
	var bounds_min := Vector3(sampler.get("bounds_min", Vector3.ZERO))
	var bounds_max := Vector3(sampler.get("bounds_max", Vector3.ZERO))
	if local_x < bounds_min.x - 0.001 or local_x > bounds_max.x + 0.001 or local_z < bounds_min.z - 0.001 or local_z > bounds_max.z + 0.001:
		return null
	var bucket_key := _support_bucket_key(_support_bucket_coord(local_x), _support_bucket_coord(local_z))
	var candidate_indices_value = sampler.get("buckets", {}).get(bucket_key, [])
	if typeof(candidate_indices_value) != TYPE_ARRAY:
		return null
	var triangles_value = sampler.get("triangles", [])
	if typeof(triangles_value) != TYPE_ARRAY:
		return null
	var triangles := Array(triangles_value)
	var seeded := false
	var best_y := 0.0
	for index_value in Array(candidate_indices_value):
		var tri_index := int(index_value)
		if tri_index < 0 or tri_index >= triangles.size():
			continue
		var tri_value = triangles[tri_index]
		if typeof(tri_value) != TYPE_DICTIONARY:
			continue
		var tri := tri_value as Dictionary
		if local_x < float(tri.get("min_x", 0.0)) - 0.001 or local_x > float(tri.get("max_x", 0.0)) + 0.001 or local_z < float(tri.get("min_z", 0.0)) - 0.001 or local_z > float(tri.get("max_z", 0.0)) + 0.001:
			continue
		var sampled = _triangle_support_height_at_local_position(tri, local_x, local_z)
		if sampled == null:
			continue
		var sampled_f := float(sampled)
		if not seeded or sampled_f > best_y:
			best_y = sampled_f
			seeded = true
	if not seeded:
		return null
	return best_y

static func triangle_support_height_at_world_position(a: Vector3, b: Vector3, c: Vector3, world_x: float, world_z: float):
	var normal := (b - a).cross(c - a)
	if normal.length_squared() <= 0.000001:
		return null
	if absf(normal.normalized().y) <= 0.0001:
		return null
	var denominator := ((b.z - c.z) * (a.x - c.x)) + ((c.x - b.x) * (a.z - c.z))
	if absf(denominator) <= 0.000001:
		return null
	var alpha := (((b.z - c.z) * (world_x - c.x)) + ((c.x - b.x) * (world_z - c.z))) / denominator
	var beta := (((c.z - a.z) * (world_x - c.x)) + ((a.x - c.x) * (world_z - c.z))) / denominator
	var gamma := 1.0 - alpha - beta
	if alpha < -0.001 or beta < -0.001 or gamma < -0.001:
		return null
	return (alpha * a.y) + (beta * b.y) + (gamma * c.y)

static func _support_bucket_coord(value: float) -> int:
	return int(floor(value / SUPPORT_BUCKET_CELL_SIZE))

static func _support_bucket_key(cell_x: int, cell_z: int) -> String:
	return "%d:%d" % [cell_x, cell_z]

static func _triangle_support_height_at_local_position(tri: Dictionary, local_x: float, local_z: float):
	var a := Vector3(tri.get("a", Vector3.ZERO))
	var b := Vector3(tri.get("b", Vector3.ZERO))
	var c := Vector3(tri.get("c", Vector3.ZERO))
	var denominator := float(tri.get("denominator", 0.0))
	if absf(denominator) <= 0.000001:
		return null
	var alpha := (((b.z - c.z) * (local_x - c.x)) + ((c.x - b.x) * (local_z - c.z))) / denominator
	var beta := (((c.z - a.z) * (local_x - c.x)) + ((a.x - c.x) * (local_z - c.z))) / denominator
	var gamma := 1.0 - alpha - beta
	if alpha < -0.001 or beta < -0.001 or gamma < -0.001:
		return null
	return (alpha * a.y) + (beta * b.y) + (gamma * c.y)

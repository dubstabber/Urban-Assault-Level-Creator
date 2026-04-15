extends RefCounted

const SupportQueryContext := preload("res://map/3d/services/map_3d_support_query_context.gd")
const SupportSampler := preload("res://map/terrain/ua_authored_support_sampler.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(actual, expected, msg: String) -> void:
	if actual != expected:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(actual), str(expected)]
		push_error(full_msg)
		_errors.append(full_msg)


func _make_sampler(height: float, width: float = 300.0, depth: float = 300.0) -> Dictionary:
	var triangles: Array = []
	SupportSampler.append_support_triangle_record(
		triangles,
		Vector3(0.0, height, 0.0),
		Vector3(width, height, 0.0),
		Vector3(0.0, height, depth)
	)
	SupportSampler.append_support_triangle_record(
		triangles,
		Vector3(width, height, 0.0),
		Vector3(width, height, depth),
		Vector3(0.0, height, depth)
	)
	return SupportSampler.support_sampler_from_triangle_records(triangles)


func _entry_from_sampler(sampler: Dictionary, basis: Basis, origin: Vector3) -> Dictionary:
	var bounds := SupportQueryContext._world_bounds_from_local_bounds(
		Vector3(sampler.get("bounds_min", Vector3.ZERO)),
		Vector3(sampler.get("bounds_max", Vector3.ZERO)),
		basis,
		origin
	)
	return {
		"sampler": sampler,
		"basis": basis,
		"origin": origin,
		"min_x": float(bounds.get("min_x", 0.0)),
		"max_x": float(bounds.get("max_x", 0.0)),
		"min_z": float(bounds.get("min_z", 0.0)),
		"max_z": float(bounds.get("max_z", 0.0)),
	}


func test_empty_context_returns_terrain_height() -> bool:
	_reset_errors()
	var context = SupportQueryContext.create_from_entries([])
	_check_eq(context.support_height_at_world_position(100.0, 100.0, 42.0), 42.0, "Empty support query context should fall back to terrain height")
	return _errors.is_empty()


func test_indexed_lookup_matches_linear_support_sampler_result() -> bool:
	_reset_errors()
	var low_sampler = _make_sampler(5.0)
	var high_sampler = _make_sampler(12.0)
	var entry_low = _entry_from_sampler(low_sampler, Basis.IDENTITY, Vector3(0.0, 8.0, 0.0))
	var entry_high = _entry_from_sampler(high_sampler, Basis.IDENTITY, Vector3(0.0, 28.0, 0.0))
	var context = SupportQueryContext.create_from_entries([entry_low, entry_high])
	var descriptors := [
		{"id": "low", "origin": Vector3.ZERO},
		{"id": "high", "origin": Vector3(0.0, 20.0, 0.0)},
	]
	var provider := func(desc: Dictionary) -> Dictionary:
		return low_sampler if String(desc.get("id", "")) == "low" else high_sampler
	var indexed = context.support_height_at_world_position(50.0, 50.0, 0.0)
	var linear = SupportSampler.support_height_at_world_position(descriptors, 50.0, 50.0, provider, 8.0)
	_check(linear != null, "Linear support sampler reference should resolve a height")
	_check(is_equal_approx(indexed, float(linear)), "Indexed support lookup should match the linear support sampler result")
	return _errors.is_empty()


func test_rotated_entry_matches_direct_sampler_query() -> bool:
	_reset_errors()
	var sampler = _make_sampler(9.0, 600.0, 300.0)
	var basis = SupportSampler.piece_basis_from_desc({"forward": Vector3(1.0, 0.0, 0.0)})
	var origin = Vector3(2000.0, 30.0, 3000.0)
	var context = SupportQueryContext.create_from_entries([_entry_from_sampler(sampler, basis, origin)])
	var world_x = 1850.0
	var world_z = 3250.0
	var indexed = context.support_height_at_world_position(world_x, world_z, 0.0)
	var direct = SupportSampler.support_sampler_height_at_world_position(sampler, basis, origin, world_x, world_z)
	_check(direct != null, "Direct rotated sampler query should resolve a height")
	_check(is_equal_approx(indexed, float(direct)), "Indexed rotated support lookup should match the direct sampler query")
	return _errors.is_empty()


func test_memoized_repeat_queries_record_cache_hits() -> bool:
	_reset_errors()
	var sampler = _make_sampler(7.0)
	var context = SupportQueryContext.create_from_entries([_entry_from_sampler(sampler, Basis.IDENTITY, Vector3.ZERO)])
	var profile = {}
	var first = context.support_height_at_world_position(50.0, 50.0, 0.0, profile)
	var second = context.support_height_at_world_position(50.0, 50.0, 0.0, profile)
	_check(is_equal_approx(first, second), "Memoized support queries should preserve the sampled height")
	_check_eq(int(profile.get("support_query_cache_hits", 0)), 1, "Second identical query should be served from the memoized support-query cache")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_empty_context_returns_terrain_height",
		"test_indexed_lookup_matches_linear_support_sampler_result",
		"test_rotated_entry_matches_direct_sampler_query",
		"test_memoized_repeat_queries_record_cache_hits",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

extends RefCounted

const SupportSamplerScript = preload("res://map/terrain/ua_authored_support_sampler.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var detail := "%s  (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(detail)
		_errors.append(detail)


func test_piece_position_from_desc_applies_overlay_bias_and_y_offset() -> bool:
	_reset_errors()
	var pos := SupportSamplerScript.piece_position_from_desc({
		"origin": Vector3(10.0, 20.0, 30.0),
		"y_offset": 5.0,
	}, 8.0)
	_check_eq(pos, Vector3(10.0, 33.0, 30.0), "Descriptor piece position should apply overlay bias and y_offset above the origin")
	return _errors.is_empty()


func test_piece_basis_from_desc_uses_horizontal_forward() -> bool:
	_reset_errors()
	var basis := SupportSamplerScript.piece_basis_from_desc({"forward": Vector3(1.0, 99.0, 0.0)})
	var rotated_forward := basis * Vector3(0.0, 0.0, -1.0)
	_check(rotated_forward.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.001, "Piece basis should derive yaw from the horizontal forward vector only")
	return _errors.is_empty()


func test_support_sampler_from_triangle_records_queries_height() -> bool:
	_reset_errors()
	var triangles: Array = []
	SupportSamplerScript.append_support_triangle_record(
		triangles,
		Vector3(0.0, 10.0, 0.0),
		Vector3(300.0, 10.0, 0.0),
		Vector3(0.0, 10.0, 300.0)
	)
	var sampler := SupportSamplerScript.support_sampler_from_triangle_records(triangles)
	_check(not sampler.is_empty(), "Triangle records should build a non-empty support sampler")
	var sampled = SupportSamplerScript.support_sampler_height_at_local_position(sampler, 50.0, 50.0)
	_check(sampled != null and is_equal_approx(float(sampled), 10.0), "Sampler should return the expected local-space support height inside the triangle")
	var outside = SupportSamplerScript.support_sampler_height_at_local_position(sampler, 500.0, 500.0)
	_check(outside == null, "Sampler should return null outside its bounds")
	return _errors.is_empty()


func test_support_height_at_world_position_uses_provider_and_highest_piece() -> bool:
	_reset_errors()
	var low_triangles: Array = []
	SupportSamplerScript.append_support_triangle_record(
		low_triangles,
		Vector3(0.0, 5.0, 0.0),
		Vector3(300.0, 5.0, 0.0),
		Vector3(0.0, 5.0, 300.0)
	)
	var high_triangles: Array = []
	SupportSamplerScript.append_support_triangle_record(
		high_triangles,
		Vector3(0.0, 12.0, 0.0),
		Vector3(300.0, 12.0, 0.0),
		Vector3(0.0, 12.0, 300.0)
	)
	var sampler_map := {
		"low": SupportSamplerScript.support_sampler_from_triangle_records(low_triangles),
		"high": SupportSamplerScript.support_sampler_from_triangle_records(high_triangles),
	}
	var provider := func(desc: Dictionary) -> Dictionary:
		return Dictionary(sampler_map.get(String(desc.get("id", "")), {}))
	var result = SupportSamplerScript.support_height_at_world_position(
		[
			{"id": "low", "origin": Vector3.ZERO},
			{"id": "high", "origin": Vector3(0.0, 20.0, 0.0)}
		],
		50.0,
		50.0,
		provider,
		8.0
	)
	_check(result != null and is_equal_approx(float(result), 40.0), "Support height query should use the provider and select the highest matching authored piece")
	return _errors.is_empty()


func run() -> int:
	var tests: Array[String] = [
		"test_piece_position_from_desc_applies_overlay_bias_and_y_offset",
		"test_piece_basis_from_desc_uses_horizontal_forward",
		"test_support_sampler_from_triangle_records_queries_height",
		"test_support_height_at_world_position_uses_provider_and_highest_piece",
	]
	var total_failures := 0
	for test_name in tests:
		if not has_method(test_name):
			push_error("Missing test method: %s" % test_name)
			total_failures += 1
			continue
		var passed: bool = call(test_name)
		if passed:
			print("  PASS  %s" % test_name)
		else:
			print("  FAIL  %s" % test_name)
			total_failures += 1
	if total_failures == 0:
		print("All %d authored support sampler tests passed" % tests.size())
	else:
		push_error("%d / %d authored support sampler tests failed" % [total_failures, tests.size()])
	return total_failures

extends RefCounted

# Unit tests for Map3DRefreshCoordinator
# Run via: godot4 --headless -s res://tests/test_runner.gd

const CoordinatorScript = preload("res://map/map_3d_refresh_coordinator.gd")

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


# ---- Tests ----

func test_chunk_payload_queue_fifo() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	_check_eq(c.async_chunk_payload_count(), 0, "Queue should start empty")
	c.push_async_chunk_payload({"id": 1})
	c.push_async_chunk_payload({"id": 2})
	_check_eq(c.async_chunk_payload_count(), 2, "Queue should have 2 items")
	var first := c.pop_async_chunk_payload()
	_check_eq(int(first.get("id", -1)), 1, "First popped should be id=1")
	var second := c.pop_async_chunk_payload()
	_check_eq(int(second.get("id", -1)), 2, "Second popped should be id=2")
	var empty := c.pop_async_chunk_payload()
	_check(empty.is_empty(), "Pop from empty queue should return empty dict")
	_check_eq(c.async_chunk_payload_count(), 0, "Queue should be empty after pops")
	return _errors.is_empty()


func test_chunk_payload_clear() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	c.push_async_chunk_payload({"a": 1})
	c.push_async_chunk_payload({"b": 2})
	c.clear_async_chunk_payloads()
	_check_eq(c.async_chunk_payload_count(), 0, "Queue should be empty after clear")
	return _errors.is_empty()


func test_worker_state_roundtrip() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var initial := c.get_async_worker_state()
	_check_eq(bool(initial.get("done", true)), false, "Worker should not be done initially")
	_check_eq(bool(initial.get("failed", true)), false, "Worker should not have failed initially")
	_check_eq(String(initial.get("error", "x")), "", "Worker error should be empty initially")
	c.set_async_worker_state(true, true, "boom")
	var updated := c.get_async_worker_state()
	_check_eq(bool(updated.get("done", false)), true, "Worker should be done after set")
	_check_eq(bool(updated.get("failed", false)), true, "Worker should have failed after set")
	_check_eq(String(updated.get("error", "")), "boom", "Worker error should be 'boom'")
	return _errors.is_empty()


func test_overlay_descriptor_state_roundtrip() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	c.set_async_overlay_descriptor_state(true, false, {"key": "val"}, {"m": 1})
	var state := c.get_async_overlay_descriptor_state()
	_check_eq(bool(state.get("done", false)), true, "Overlay done should be true")
	_check_eq(bool(state.get("failed", true)), false, "Overlay failed should be false")
	var result: Dictionary = state.get("result", {})
	_check_eq(String(result.get("key", "")), "val", "Overlay result should carry payload")
	var metrics: Dictionary = state.get("metrics", {})
	_check_eq(int(metrics.get("m", 0)), 1, "Overlay metrics should carry payload")
	return _errors.is_empty()


func test_overlay_descriptor_stage_roundtrip() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	_check_eq(c.get_async_overlay_descriptor_stage(), "", "Stage should start empty")
	c.set_async_overlay_descriptor_stage("building")
	_check_eq(c.get_async_overlay_descriptor_stage(), "building", "Stage should be 'building'")
	return _errors.is_empty()


func test_cancel_requested_default_false() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	_check_eq(c.is_async_cancel_requested(0), false, "Cancel should not be requested by default")
	return _errors.is_empty()


func test_cancel_async_build_sets_flag_via_overlay_apply() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	c.active_build_generation_id = 5
	# Without a real thread, is_async_build_active() is false, so we use the
	# overlay_apply_active=true path which unconditionally sets the cancel flag.
	c.cancel_async_build(true)
	_check_eq(c._async_cancel_requested, true, "Cancel flag should be set after cancel_async_build")
	return _errors.is_empty()


func test_is_async_cancel_requested_checks_generation() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	c.active_build_generation_id = 3
	c._async_cancel_requested = true
	_check_eq(c.is_async_cancel_requested(3), true, "Should be cancelled for matching gen")
	_check_eq(c.is_async_cancel_requested(2), false, "Should not be cancelled for non-matching gen")
	return _errors.is_empty()


func test_map_signature_initially_changed() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var hgt := PackedByteArray([0])
	var typ := PackedByteArray([0])
	var blg := PackedByteArray([0])
	_check(c.is_map_signature_changed(1, 1, 1, hgt, typ, blg), "Signature should be changed when not yet recorded")
	return _errors.is_empty()


func test_map_signature_unchanged_after_record() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var hgt := PackedByteArray([10, 20, 30])
	var typ := PackedByteArray([1, 2])
	var blg := PackedByteArray([5])
	c.record_map_signature(2, 3, 1, hgt, typ, blg)
	_check(not c.is_map_signature_changed(2, 3, 1, hgt, typ, blg), "Signature should match after recording same data")
	return _errors.is_empty()


func test_map_signature_changed_on_dims() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var hgt := PackedByteArray([0])
	var typ := PackedByteArray([0])
	var blg := PackedByteArray([0])
	c.record_map_signature(1, 1, 1, hgt, typ, blg)
	_check(c.is_map_signature_changed(2, 1, 1, hgt, typ, blg), "Signature should change when w differs")
	_check(c.is_map_signature_changed(1, 2, 1, hgt, typ, blg), "Signature should change when h differs")
	return _errors.is_empty()


func test_map_signature_changed_on_level_set() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var hgt := PackedByteArray([0])
	var typ := PackedByteArray([0])
	var blg := PackedByteArray([0])
	c.record_map_signature(1, 1, 1, hgt, typ, blg)
	_check(c.is_map_signature_changed(1, 1, 2, hgt, typ, blg), "Signature should change when level_set differs")
	return _errors.is_empty()


func test_map_signature_changed_on_data() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	var hgt := PackedByteArray([0])
	var typ := PackedByteArray([0])
	var blg := PackedByteArray([0])
	c.record_map_signature(1, 1, 1, hgt, typ, blg)
	_check(c.is_map_signature_changed(1, 1, 1, PackedByteArray([1]), typ, blg), "Signature should change when hgt differs")
	_check(c.is_map_signature_changed(1, 1, 1, hgt, PackedByteArray([1]), blg), "Signature should change when typ differs")
	_check(c.is_map_signature_changed(1, 1, 1, hgt, typ, PackedByteArray([1])), "Signature should change when blg differs")
	return _errors.is_empty()


func test_reset_async_state_clears_all() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	c.push_async_chunk_payload({"x": 1})
	c.set_async_worker_state(true, true, "fail")
	c.set_async_overlay_descriptor_state(true, true, {"r": 1}, {"m": 1})
	c.set_async_overlay_descriptor_stage("building")
	c._async_cancel_requested = true
	c.reset_async_state()
	_check_eq(c.async_chunk_payload_count(), 0, "Queue should be empty after reset")
	var ws := c.get_async_worker_state()
	_check_eq(bool(ws.get("done", true)), false, "Worker done should be false after reset")
	_check_eq(bool(ws.get("failed", true)), false, "Worker failed should be false after reset")
	var os := c.get_async_overlay_descriptor_state()
	_check_eq(bool(os.get("done", true)), false, "Overlay done should be false after reset")
	_check_eq(c.get_async_overlay_descriptor_stage(), "", "Overlay stage should be empty after reset")
	_check_eq(c._async_cancel_requested, false, "Cancel flag should be false after reset")
	return _errors.is_empty()


func test_is_async_build_active_without_thread() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	_check_eq(c.is_async_build_active(), false, "Should not be active without a thread")
	return _errors.is_empty()


func test_is_async_pipeline_active_with_overlay_apply() -> bool:
	_reset_errors()
	var c := CoordinatorScript.new()
	_check_eq(c.is_async_pipeline_active(false), false, "Pipeline should be inactive with nothing running")
	_check_eq(c.is_async_pipeline_active(true), true, "Pipeline should be active when overlay apply is active")
	return _errors.is_empty()


# ---- Runner ----

func run() -> int:
	var tests: Array[String] = [
		"test_chunk_payload_queue_fifo",
		"test_chunk_payload_clear",
		"test_worker_state_roundtrip",
		"test_overlay_descriptor_state_roundtrip",
		"test_overlay_descriptor_stage_roundtrip",
		"test_cancel_requested_default_false",
		"test_cancel_async_build_sets_flag_via_overlay_apply",
		"test_is_async_cancel_requested_checks_generation",
		"test_map_signature_initially_changed",
		"test_map_signature_unchanged_after_record",
		"test_map_signature_changed_on_dims",
		"test_map_signature_changed_on_level_set",
		"test_map_signature_changed_on_data",
		"test_reset_async_state_clears_all",
		"test_is_async_build_active_without_thread",
		"test_is_async_pipeline_active_with_overlay_apply",
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
		print("All %d coordinator tests passed" % tests.size())
	else:
		push_error("%d / %d coordinator tests failed" % [total_failures, tests.size()])
	return total_failures

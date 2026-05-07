extends RefCounted

const ChunkBuildPort := preload("res://map/3d/runtime/map_3d_chunk_build_port.gd")
const OverlayRuntimePort := preload("res://map/3d/runtime/map_3d_overlay_runtime_port.gd")
const BuildMetricsPort := preload("res://map/3d/runtime/map_3d_build_metrics_port.gd")

var _errors: Array[String] = []


class RuntimeStateStub extends RefCounted:
	var edge_overlay_enabled := true
	var geometry_distance_culling_enabled := false
	var overlay_apply_manager = RefCounted.new()
	var last_build_metrics: Dictionary = {}


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func test_ports_expose_segregated_capabilities() -> bool:
	_reset_errors()
	var chunk_port := ChunkBuildPort.new()
	var overlay_port := OverlayRuntimePort.new()
	var metrics_port := BuildMetricsPort.new()

	for method_name in [
		"chunk_runtime",
		"compute_effective_typ_for_map",
		"needs_full_rebuild",
		"dirty_chunks_sorted_by_priority",
		"edge_overlay_enabled",
	]:
		_check(chunk_port.has_method(method_name), "Chunk build port should expose %s" % method_name)
	for forbidden_name in [
		"static_overlay_index",
		"overlay_apply_manager",
		"apply_localized_dynamic_overlay_refresh",
		"finalize_build_metrics",
	]:
		_check(not chunk_port.has_method(forbidden_name), "Chunk build port should not expose %s" % forbidden_name)

	for method_name in [
		"unit_runtime_index",
		"static_overlay_index",
		"overlay_apply_manager",
		"localized_overlay_sector_list",
		"apply_localized_dynamic_overlay_refresh",
		"geometry_distance_culling_enabled",
	]:
		_check(overlay_port.has_method(method_name), "Overlay runtime port should expose %s" % method_name)
	for forbidden_name in [
		"compute_effective_typ_for_map",
		"dirty_chunks_sorted_by_priority",
		"make_empty_build_metrics",
		"finalize_build_metrics",
	]:
		_check(not overlay_port.has_method(forbidden_name), "Overlay runtime port should not expose %s" % forbidden_name)

	for method_name in [
		"make_empty_build_metrics",
		"elapsed_ms_since",
		"finalize_build_metrics",
	]:
		_check(metrics_port.has_method(method_name), "Build metrics port should expose %s" % method_name)
	for forbidden_name in [
		"chunk_runtime",
		"unit_runtime_index",
		"static_overlay_index",
		"compute_effective_typ_for_map",
	]:
		_check(not metrics_port.has_method(forbidden_name), "Build metrics port should not expose %s" % forbidden_name)
	return _errors.is_empty()


func test_metrics_port_owns_last_build_metrics_storage() -> bool:
	_reset_errors()
	var state := RuntimeStateStub.new()
	var metrics_port := BuildMetricsPort.new()
	metrics_port.bind(state)
	var metrics := metrics_port.make_empty_build_metrics()
	metrics["terrain_build_ms"] = 2.5
	metrics_port.finalize_build_metrics(metrics, Time.get_ticks_usec())
	_check(state.last_build_metrics.has("build_total_ms"), "Metrics port should stamp total build time")
	_check(is_equal_approx(float(state.last_build_metrics.get("terrain_build_ms", 0.0)), 2.5), "Metrics port should preserve existing metric values")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_ports_expose_segregated_capabilities",
		"test_metrics_port_owns_last_build_metrics_storage",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

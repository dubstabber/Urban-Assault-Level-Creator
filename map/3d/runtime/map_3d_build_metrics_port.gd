extends RefCounted

const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")


var _runtime_state = null
var _async_refresh_driver = null


func bind(runtime_state, async_refresh_driver = null) -> void:
	_runtime_state = runtime_state
	_async_refresh_driver = async_refresh_driver


func make_empty_build_metrics() -> Dictionary:
	return BuildMetrics.empty_metrics()


func elapsed_ms_since(started_usec: int) -> float:
	return BuildMetrics.elapsed_ms_since(started_usec)


func finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	metrics["build_total_ms"] = BuildMetrics.elapsed_ms_since(build_started_usec)
	if _async_refresh_driver != null and _async_refresh_driver.get_refresh_requested_at_usec() > 0:
		metrics["refresh_end_to_end_ms"] = BuildMetrics.elapsed_ms_since(_async_refresh_driver.get_refresh_requested_at_usec())
		_async_refresh_driver.clear_refresh_requested_at_usec()
	_runtime_state.last_build_metrics = metrics.duplicate(true)

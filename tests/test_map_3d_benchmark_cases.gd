extends RefCounted

const BenchmarkCases = preload("res://tests/helpers/map_3d_benchmark_cases.gd")
const BenchmarkRunner = preload("res://tests/run_map_3d_benchmarks.gd")

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func test_catalog_exposes_required_named_cases() -> bool:
	_reset_errors()
	var names := BenchmarkCases.all_case_names()
	for required_name in ["small_visible_flat", "medium_visible_varied", "large_visible_varied", "set6_ptcl_visible", "large_hidden_refresh_workflow"]:
		_check(names.has(required_name), "Benchmark catalog should include '%s'" % required_name)
	_check(names.size() == 5, "Benchmark catalog should stay intentionally small and reviewable in this phase")
	return _errors.is_empty()


func test_particle_case_uses_set6_ptcl_typ_values() -> bool:
	_reset_errors()
	var case_data := BenchmarkCases.get_case("set6_ptcl_visible")
	var map_data: Dictionary = case_data.get("map_data", {})
	var typ_map := PackedByteArray(map_data.get("typ_map", PackedByteArray()))
	_check(int(map_data.get("level_set", 0)) == 6, "Particle-heavy benchmark should target set 6")
	_check(not typ_map.is_empty(), "Particle-heavy benchmark should define typ data")
	for value in typ_map:
		_check(int(value) == 234 or int(value) == 235, "Particle-heavy benchmark should only use PTCL-authored typ 234/235 sectors")
	return _errors.is_empty()


func test_hidden_workflow_case_starts_inactive_and_has_burst_updates() -> bool:
	_reset_errors()
	var case_data := BenchmarkCases.get_case("large_hidden_refresh_workflow")
	var workflow: Dictionary = case_data.get("workflow", {})
	var map_data: Dictionary = case_data.get("map_data", {})
	_check(not bool(workflow.get("start_visible", true)), "Hidden workflow benchmark should start with the 3D preview inactive")
	_check(bool(workflow.get("reactivate_after_burst", false)), "Hidden workflow benchmark should reactivate the preview after the update burst")
	_check(int(workflow.get("map_update_burst", 0)) >= 2, "Hidden workflow benchmark should model multiple coalescable updates")
	_check(int(map_data.get("horizontal_sectors", 0)) >= 64, "Hidden workflow benchmark should use a large representative map width")
	_check(int(map_data.get("vertical_sectors", 0)) >= 64, "Hidden workflow benchmark should use a large representative map height")
	return _errors.is_empty()


func test_cases_define_smoke_budgets() -> bool:
	_reset_errors()
	for case_name in BenchmarkCases.all_case_names():
		var case_data := BenchmarkCases.get_case(case_name)
		var budgets_value = case_data.get("smoke_budgets", {})
		_check(typeof(budgets_value) == TYPE_DICTIONARY and not Dictionary(budgets_value).is_empty(), "Benchmark case '%s' should define smoke budgets" % case_name)
	return _errors.is_empty()


func test_runtime_count_helpers_report_expected_structure() -> bool:
	_reset_errors()
	var renderer := Node3D.new()
	renderer.name = "Map3D"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	var edge_mesh := MeshInstance3D.new()
	edge_mesh.name = "EdgeMesh"
	var overlay := Node3D.new()
	overlay.name = "AuthoredOverlay"
	renderer.add_child(terrain_mesh)
	renderer.add_child(edge_mesh)
	renderer.add_child(overlay)
	var terrain_chunk := MeshInstance3D.new()
	terrain_chunk.name = "TerrainChunk_0_0"
	terrain_chunk.mesh = ArrayMesh.new()
	terrain_mesh.add_child(terrain_chunk)
	var edge_chunk := MeshInstance3D.new()
	edge_chunk.name = "EdgeChunk_0_0"
	edge_chunk.mesh = ArrayMesh.new()
	edge_mesh.add_child(edge_chunk)
	var overlay_piece := Node3D.new()
	overlay.add_child(overlay_piece)
	var animated := Node3D.new()
	animated.set_meta("ua_authored_animated", true)
	overlay_piece.add_child(animated)
	var emitter := Node3D.new()
	emitter.set_meta("ua_authored_particle_emitter", true)
	overlay_piece.add_child(emitter)
	var node_counts := BenchmarkRunner.collect_runtime_node_counts(renderer)
	var resource_counts := BenchmarkRunner.collect_runtime_resource_counts(renderer)
	_check(int(node_counts.get("terrain_chunk_node_count", -1)) == 1, "Runtime node counts should include terrain chunk children")
	_check(int(node_counts.get("edge_chunk_node_count", -1)) == 1, "Runtime node counts should include edge chunk children")
	_check(int(node_counts.get("overlay_top_level_child_count", -1)) == 1, "Runtime node counts should include top-level overlay children")
	_check(int(node_counts.get("authored_animated_node_count", -1)) == 1, "Runtime node counts should include authored animated children")
	_check(int(node_counts.get("authored_particle_emitter_node_count", -1)) == 1, "Runtime node counts should include authored particle emitter children")
	_check(int(resource_counts.get("mesh_resource_count", -1)) == 2, "Runtime resource counts should include unique mesh resources")
	renderer.free()
	return _errors.is_empty()


func test_hidden_smoke_budget_accepts_expected_summary_shape() -> bool:
	_reset_errors()
	var case_data := BenchmarkCases.get_case("large_hidden_refresh_workflow")
	var smoke := BenchmarkRunner.evaluate_smoke_budgets(case_data, {
		"case_elapsed_ms": 4000.0,
		"hidden_burst_elapsed_ms": 10.0,
		"pending_refresh_before_reactivate": true,
		"hidden_build_started_before_reactivate": false,
		"pending_refresh_after_run": false,
		"metrics": {
			"build_total_ms": 6000.0,
		},
	})
	_check(bool(smoke.get("within_budget", false)), "Hidden workflow smoke evaluation should accept summaries that satisfy the declared budgets")
	return _errors.is_empty()


func test_unknown_case_returns_empty_dictionary() -> bool:
	_reset_errors()
	_check(BenchmarkCases.get_case("does_not_exist").is_empty(), "Unknown benchmark case lookups should fail safely")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for name in [
		"test_catalog_exposes_required_named_cases",
		"test_particle_case_uses_set6_ptcl_typ_values",
		"test_hidden_workflow_case_starts_inactive_and_has_burst_updates",
		"test_cases_define_smoke_budgets",
		"test_runtime_count_helpers_report_expected_structure",
		"test_hidden_smoke_budget_accepts_expected_summary_shape",
		"test_unknown_case_returns_empty_dictionary",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures
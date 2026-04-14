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


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


func _snapshot_map_edit_state() -> Dictionary:
	return {
		"horizontal_sectors": CurrentMapData.horizontal_sectors,
		"vertical_sectors": CurrentMapData.vertical_sectors,
		"typ_map": CurrentMapData.typ_map.duplicate(),
		"own_map": CurrentMapData.own_map.duplicate(),
		"blg_map": CurrentMapData.blg_map.duplicate(),
		"beam_gates": CurrentMapData.beam_gates.duplicate(),
		"stoudson_bombs": CurrentMapData.stoudson_bombs.duplicate(),
		"tech_upgrades": CurrentMapData.tech_upgrades.duplicate(),
		"selected_sector_idx": EditorState.selected_sector_idx,
		"selected_sector": EditorState.selected_sector,
		"selected_sectors": EditorState.selected_sectors.duplicate(true),
		"selected_beam_gate": EditorState.selected_beam_gate,
		"selected_bomb": EditorState.selected_bomb,
		"selected_tech_upgrade": EditorState.selected_tech_upgrade,
		"selected_bg_key_sector": EditorState.selected_bg_key_sector,
		"selected_bomb_key_sector": EditorState.selected_bomb_key_sector,
		"sector_clipboard": EditorState.sector_clipboard.duplicate(true),
	}


func _restore_map_edit_state(snapshot: Dictionary) -> void:
	var typ_map_snapshot: PackedByteArray = snapshot.get("typ_map", PackedByteArray())
	var own_map_snapshot: PackedByteArray = snapshot.get("own_map", PackedByteArray())
	var blg_map_snapshot: PackedByteArray = snapshot.get("blg_map", PackedByteArray())
	CurrentMapData.horizontal_sectors = int(snapshot.get("horizontal_sectors", 0))
	CurrentMapData.vertical_sectors = int(snapshot.get("vertical_sectors", 0))
	CurrentMapData.typ_map = typ_map_snapshot.duplicate()
	CurrentMapData.own_map = own_map_snapshot.duplicate()
	CurrentMapData.blg_map = blg_map_snapshot.duplicate()
	CurrentMapData.beam_gates = snapshot.get("beam_gates", []).duplicate()
	CurrentMapData.stoudson_bombs = snapshot.get("stoudson_bombs", []).duplicate()
	CurrentMapData.tech_upgrades = snapshot.get("tech_upgrades", []).duplicate()
	EditorState.selected_sector_idx = int(snapshot.get("selected_sector_idx", -1))
	EditorState.selected_sector = snapshot.get("selected_sector", Vector2i(-1, -1))
	EditorState.selected_sectors = snapshot.get("selected_sectors", []).duplicate(true)
	EditorState.selected_beam_gate = snapshot.get("selected_beam_gate", null)
	EditorState.selected_bomb = snapshot.get("selected_bomb", null)
	EditorState.selected_tech_upgrade = snapshot.get("selected_tech_upgrade", null)
	EditorState.selected_bg_key_sector = snapshot.get("selected_bg_key_sector", Vector2i(-1, -1))
	EditorState.selected_bomb_key_sector = snapshot.get("selected_bomb_key_sector", Vector2i(-1, -1))
	EditorState.sector_clipboard = snapshot.get("sector_clipboard", {}).duplicate(true)


func _capture_map_edit_event_sequence(callback: Callable) -> Array:
	var events: Array = []
	var hgt_cb := func(indices: Array) -> void:
		events.append({"name": "hgt", "payload": indices.duplicate()})
	var typ_cb := func(indices: Array) -> void:
		events.append({"name": "typ", "payload": indices.duplicate()})
	var blg_cb := func(indices: Array) -> void:
		events.append({"name": "blg", "payload": indices.duplicate()})
	var updated_cb := func() -> void:
		events.append({"name": "updated"})
	EventSystem.hgt_map_cells_edited.connect(hgt_cb)
	EventSystem.typ_map_cells_edited.connect(typ_cb)
	EventSystem.blg_map_cells_edited.connect(blg_cb)
	EventSystem.map_updated.connect(updated_cb)
	callback.call()
	EventSystem.hgt_map_cells_edited.disconnect(hgt_cb)
	EventSystem.typ_map_cells_edited.disconnect(typ_cb)
	EventSystem.blg_map_cells_edited.disconnect(blg_cb)
	EventSystem.map_updated.disconnect(updated_cb)
	return events


func test_catalog_exposes_required_named_cases() -> bool:
	_reset_errors()
	var names := BenchmarkCases.all_case_names()
	for required_name in ["small_visible_flat", "medium_visible_varied", "target_visible_varied_34x32", "large_visible_varied", "set6_ptcl_visible", "large_hidden_refresh_workflow"]:
		_check(names.has(required_name), "Benchmark catalog should include '%s'" % required_name)
	_check(names.size() == 6, "Benchmark catalog should stay intentionally small and reviewable in this phase")
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


func test_runner_event_system_stub_exposes_renderer_signals() -> bool:
	_reset_errors()
	var event_system := BenchmarkRunner.EventSystemStub.new()
	_check(event_system.has_signal("map_3d_overlay_animations_changed"), "Benchmark EventSystemStub should expose map_3d_overlay_animations_changed")
	_check(event_system.has_signal("blg_map_cells_edited"), "Benchmark EventSystemStub should expose blg_map_cells_edited")
	event_system.free()
	return _errors.is_empty()


func test_zero_build_metrics_are_rejected() -> bool:
	_reset_errors()
	_check(not BenchmarkRunner.summary_has_non_zero_build_metrics({"metrics": {}}), "Empty benchmark metrics should be rejected")
	_check(not BenchmarkRunner.summary_has_non_zero_build_metrics({
		"metrics": {
			"terrain_build_ms": 0.0,
			"edge_slurp_build_ms": 0.0,
			"overlay_descriptor_generation_ms": 0.0,
			"overlay_node_creation_ms": 0.0,
			"build_total_ms": 0.0,
			"refresh_end_to_end_ms": 0.0,
			"overlay_descriptor_count": 0,
			"terrain_authored_descriptor_count": 0,
			"edge_authored_descriptor_count": 0,
			"chunks_rebuilt": 0,
		},
	}), "All-zero benchmark metrics should be rejected")
	_check(BenchmarkRunner.summary_has_non_zero_build_metrics({
		"metrics": {
			"build_total_ms": 1.0,
		},
	}), "Positive build metrics should be accepted")
	return _errors.is_empty()


func test_emit_map_edit_update_orders_fine_grained_signals_before_map_updated() -> bool:
	_reset_errors()
	var events := _capture_map_edit_event_sequence(func() -> void:
		CurrentMapData.emit_map_edit_update([7], [3], [5])
	)
	_check_eq(events.size(), 4, "emit_map_edit_update should emit three fine-grained signals plus map_updated")
	if events.size() >= 4:
		_check_eq(String(events[0].get("name", "")), "hgt", "emit_map_edit_update should emit hgt edits first")
		_check_eq(String(events[1].get("name", "")), "typ", "emit_map_edit_update should emit typ edits second")
		_check_eq(String(events[2].get("name", "")), "blg", "emit_map_edit_update should emit blg edits third")
		_check_eq(String(events[3].get("name", "")), "updated", "emit_map_edit_update should emit map_updated last")
	return _errors.is_empty()


func test_clear_sector_emits_typ_and_blg_before_map_updated() -> bool:
	_reset_errors()
	var snapshot := _snapshot_map_edit_state()
	CurrentMapData.horizontal_sectors = 1
	CurrentMapData.vertical_sectors = 1
	CurrentMapData.typ_map = PackedByteArray([12])
	CurrentMapData.own_map = PackedByteArray([3])
	CurrentMapData.blg_map = PackedByteArray([44])
	CurrentMapData.beam_gates.clear()
	CurrentMapData.stoudson_bombs.clear()
	CurrentMapData.tech_upgrades.clear()
	EditorState.selected_beam_gate = null
	EditorState.selected_bomb = null
	EditorState.selected_tech_upgrade = null
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	var events := _capture_map_edit_event_sequence(func() -> void:
		CurrentMapData.clear_sector(0, true)
	)
	_check_eq(CurrentMapData.typ_map[0], 0, "clear_sector should clear typ_map")
	_check_eq(CurrentMapData.blg_map[0], 0, "clear_sector should clear blg_map")
	_check_eq(events.size(), 3, "clear_sector should emit typ, blg, then map_updated")
	if events.size() >= 3:
		_check_eq(String(events[0].get("name", "")), "typ", "clear_sector should emit typ edits before map_updated")
		_check_eq(String(events[1].get("name", "")), "blg", "clear_sector should emit blg edits before map_updated")
		_check_eq(String(events[2].get("name", "")), "updated", "clear_sector should emit map_updated last")
		_check_eq(events[0].get("payload", []), [0], "clear_sector should report the edited typ sector")
		_check_eq(events[1].get("payload", []), [0], "clear_sector should report the edited blg sector")
	_restore_map_edit_state(snapshot)
	return _errors.is_empty()


func test_paste_sector_emits_typ_and_blg_before_map_updated() -> bool:
	_reset_errors()
	var snapshot := _snapshot_map_edit_state()
	CurrentMapData.horizontal_sectors = 1
	CurrentMapData.vertical_sectors = 1
	CurrentMapData.typ_map = PackedByteArray([2])
	CurrentMapData.own_map = PackedByteArray([1])
	CurrentMapData.blg_map = PackedByteArray([8])
	CurrentMapData.beam_gates.clear()
	CurrentMapData.stoudson_bombs.clear()
	CurrentMapData.tech_upgrades.clear()
	EditorState.selected_sector_idx = 0
	EditorState.selected_sector = Vector2i(1, 1)
	EditorState.selected_sectors.clear()
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	EditorState.sector_clipboard = {
		"typ_map": 23,
		"own_map": 6,
		"blg_map": 51,
		"beam_gate": null,
		"stoudson_bomb": null,
		"tech_upgrade": null,
		"bg_key_sector_parent": null,
		"bomb_key_sector_parent": null
	}
	UndoRedoManager.clear_history()
	var events := _capture_map_edit_event_sequence(func() -> void:
		Utils.paste_sector()
	)
	_check_eq(CurrentMapData.typ_map[0], 23, "paste_sector should update typ_map")
	_check_eq(CurrentMapData.own_map[0], 6, "paste_sector should update own_map")
	_check_eq(CurrentMapData.blg_map[0], 51, "paste_sector should update blg_map")
	_check_eq(events.size(), 3, "paste_sector should emit typ, blg, then map_updated")
	if events.size() >= 3:
		_check_eq(String(events[0].get("name", "")), "typ", "paste_sector should emit typ edits before map_updated")
		_check_eq(String(events[1].get("name", "")), "blg", "paste_sector should emit blg edits before map_updated")
		_check_eq(String(events[2].get("name", "")), "updated", "paste_sector should emit map_updated last")
		_check_eq(events[0].get("payload", []), [0], "paste_sector should report the edited typ sector")
		_check_eq(events[1].get("payload", []), [0], "paste_sector should report the edited blg sector")
	_restore_map_edit_state(snapshot)
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
		"test_runner_event_system_stub_exposes_renderer_signals",
		"test_zero_build_metrics_are_rejected",
		"test_emit_map_edit_update_orders_fine_grained_signals_before_map_updated",
		"test_clear_sector_emits_typ_and_blg_before_map_updated",
		"test_paste_sector_emits_typ_and_blg_before_map_updated",
		"test_unknown_case_returns_empty_dictionary",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

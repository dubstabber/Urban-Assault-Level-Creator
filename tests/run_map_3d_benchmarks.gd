extends SceneTree

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const BenchmarkCases = preload("res://tests/helpers/map_3d_benchmark_cases.gd")
const SetSdfParserScript = preload("res://map/terrain/set_sdf_parser.gd")


class EventSystemStub extends Node:
	signal map_created
	signal map_updated
	signal level_set_changed
	signal map_view_updated


class CurrentMapDataStub extends Node:
	var horizontal_sectors := 1
	var vertical_sectors := 1
	var hgt_map := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var typ_map := PackedByteArray([0])
	var blg_map := PackedByteArray([0])
	var beam_gates: Array = []
	var tech_upgrades: Array = []
	var stoudson_bombs: Array = []
	var host_stations: Node = null
	var squads: Node = null
	var level_set := 1


class EditorStateStub extends Node:
	var view_mode_3d := true
	var map_3d_visibility_range_enabled := false
	var game_data_type := "original"


class BenchmarkPreloads extends Node:
	var surface_type_map := {}
	var subsector_patterns := {}
	var tile_mapping := {}
	var tile_remap := {}
	var subsector_idx_remap := {}
	var lego_defs := {}
	var _texture := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))

	func configure_for_set(set_id: int) -> void:
		var full_data: Dictionary = SetSdfParserScript.parse_full_typ_data(set_id)
		surface_type_map = full_data.get("surface_types", {})
		subsector_patterns = full_data.get("subsector_patterns", {})
		tile_mapping = full_data.get("tile_mapping", {})
		lego_defs = full_data.get("lego_defs", {})

	func get_ground_texture(_surface_type: int) -> Texture2D:
		return _texture


static func collect_runtime_node_counts(renderer: Node) -> Dictionary:
	if renderer == null:
		return {}
	var overlay := renderer.get_node_or_null("AuthoredOverlay")
	var node_count := 0
	var mesh_instance_node_count := 0
	var overlay_descendant_count := 0
	var authored_animated_node_count := 0
	var authored_particle_emitter_node_count := 0
	var stack: Array = [renderer]
	while not stack.is_empty():
		var current = stack.pop_back() as Node
		if current == null:
			continue
		if current != renderer:
			node_count += 1
		if current is MeshInstance3D:
			mesh_instance_node_count += 1
		if current.has_meta("ua_authored_animated"):
			authored_animated_node_count += 1
		if current.has_meta("ua_authored_particle_emitter"):
			authored_particle_emitter_node_count += 1
		if overlay != null and current != overlay and overlay.is_ancestor_of(current):
			overlay_descendant_count += 1
		for child in current.get_children():
			stack.append(child)
	var terrain_mesh := renderer.get_node_or_null("TerrainMesh")
	var edge_mesh := renderer.get_node_or_null("EdgeMesh")
	return {
		"descendant_node_count": node_count,
		"mesh_instance_node_count": mesh_instance_node_count,
		"overlay_top_level_child_count": overlay.get_child_count() if overlay != null else 0,
		"overlay_descendant_count": overlay_descendant_count,
		"terrain_chunk_node_count": _count_named_children(terrain_mesh, "TerrainChunk_"),
		"edge_chunk_node_count": _count_named_children(edge_mesh, "EdgeChunk_"),
		"authored_animated_node_count": authored_animated_node_count,
		"authored_particle_emitter_node_count": authored_particle_emitter_node_count,
	}


static func collect_runtime_resource_counts(renderer: Node) -> Dictionary:
	if renderer == null:
		return {}
	var mesh_ids := {}
	var material_ids := {}
	var texture_ids := {}
	var mesh_surface_count := 0
	var stack: Array = [renderer]
	while not stack.is_empty():
		var current = stack.pop_back() as Node
		if current == null:
			continue
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			_track_resource(mesh_ids, mesh_instance.mesh)
			_track_resource(material_ids, mesh_instance.material_override)
			if mesh_instance.mesh != null:
				mesh_surface_count += mesh_instance.mesh.get_surface_count()
				for surface_idx in range(mesh_instance.mesh.get_surface_count()):
					var material := mesh_instance.mesh.surface_get_material(surface_idx)
					_track_resource(material_ids, material)
					_track_material_textures(texture_ids, material)
		for child in current.get_children():
			stack.append(child)
	return {
		"mesh_resource_count": mesh_ids.size(),
		"material_resource_count": material_ids.size(),
		"texture_resource_count": texture_ids.size(),
		"mesh_surface_count": mesh_surface_count,
	}


static func evaluate_smoke_budgets(case_data: Dictionary, summary: Dictionary) -> Dictionary:
	var budgets_value = case_data.get("smoke_budgets", {})
	if typeof(budgets_value) != TYPE_DICTIONARY:
		return {"budgets": {}, "violations": [], "within_budget": true}
	var budgets := budgets_value as Dictionary
	var violations: Array[String] = []
	var metrics_value = summary.get("metrics", {})
	var metrics := metrics_value as Dictionary if typeof(metrics_value) == TYPE_DICTIONARY else {}
	if budgets.has("case_elapsed_ms_max") and float(summary.get("case_elapsed_ms", 0.0)) > float(budgets.get("case_elapsed_ms_max", 0.0)):
		violations.append("case_elapsed_ms exceeded budget")
	if budgets.has("build_total_ms_max") and float(metrics.get("build_total_ms", 0.0)) > float(budgets.get("build_total_ms_max", 0.0)):
		violations.append("build_total_ms exceeded budget")
	if budgets.has("hidden_burst_elapsed_ms_max") and float(summary.get("hidden_burst_elapsed_ms", 0.0)) > float(budgets.get("hidden_burst_elapsed_ms_max", 0.0)):
		violations.append("hidden_burst_elapsed_ms exceeded budget")
	if bool(budgets.get("expect_pending_refresh_before_reactivate", false)) and not bool(summary.get("pending_refresh_before_reactivate", false)):
		violations.append("pending_refresh_before_reactivate did not match expectation")
	if bool(budgets.get("expect_no_build_before_reactivate", false)) and bool(summary.get("hidden_build_started_before_reactivate", false)):
		violations.append("hidden build started before reactivation")
	if budgets.has("expect_pending_refresh_after_run") and bool(summary.get("pending_refresh_after_run", false)) != bool(budgets.get("expect_pending_refresh_after_run", false)):
		violations.append("pending_refresh_after_run did not match expectation")
	return {
		"budgets": budgets.duplicate(true),
		"violations": violations,
		"within_budget": violations.is_empty(),
	}


static func build_case_summary(case_name: String, case_data: Dictionary, workflow: Dictionary, renderer: Map3DRenderer, current_map_data: Node, case_elapsed_ms: float, hidden_burst_elapsed_ms: float, pending_refresh_before_reactivate: bool, hidden_build_started_before_reactivate: bool) -> Dictionary:
	var summary := {
		"case": case_name,
		"description": case_data.get("description", ""),
		"dimensions": "%dx%d" % [int(current_map_data.get("horizontal_sectors")), int(current_map_data.get("vertical_sectors"))],
		"workflow": workflow.duplicate(true),
		"case_elapsed_ms": case_elapsed_ms,
		"hidden_burst_elapsed_ms": hidden_burst_elapsed_ms,
		"pending_refresh_before_reactivate": pending_refresh_before_reactivate,
		"hidden_build_started_before_reactivate": hidden_build_started_before_reactivate,
		"pending_refresh_after_run": renderer.has_pending_refresh(),
		"metrics": renderer.get_last_build_metrics(),
		"node_counts": collect_runtime_node_counts(renderer),
		"resource_counts": collect_runtime_resource_counts(renderer),
	}
	summary["smoke"] = evaluate_smoke_budgets(case_data, summary)
	return summary


static func _count_named_children(parent: Node, prefix: String) -> int:
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child != null and String(child.name).begins_with(prefix):
			count += 1
	return count


static func _track_resource(target: Dictionary, resource: Resource) -> void:
	if resource == null:
		return
	target[resource.get_instance_id()] = true


static func _track_material_textures(target: Dictionary, material: Material) -> void:
	if material == null:
		return
	for property_info in material.get_property_list():
		var property_name := String(property_info.get("name", ""))
		if not property_name.ends_with("_texture"):
			continue
		var value = material.get(property_name)
		if value is Texture2D:
			target[(value as Texture2D).get_instance_id()] = true


func _should_assert_budgets() -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--assert-budget":
			return true
	return false


func _init() -> void:
	call_deferred("_run_benchmarks")


func _run_benchmarks() -> void:
	var failures := 0
	for case_name in _selected_case_names():
		if not _run_case(case_name):
			failures += 1
	quit(failures)


func _selected_case_names() -> Array:
	var selected: Array = []
	var args := OS.get_cmdline_user_args()
	for idx in range(args.size()):
		if args[idx] != "--case" or idx + 1 >= args.size():
			continue
		for name in String(args[idx + 1]).split(",", false):
			selected.append(name)
	return selected if not selected.is_empty() else BenchmarkCases.all_case_names()


func _run_case(case_name: String) -> bool:
	var case_data := BenchmarkCases.get_case(case_name)
	if case_data.is_empty():
		push_error("Unknown map 3D benchmark case: %s" % case_name)
		return false
	var workflow: Dictionary = case_data.get("workflow", {})
	var fixture := _create_fixture(case_data, bool(workflow.get("start_visible", true)))
	var renderer := fixture["renderer"] as Map3DRenderer
	var event_system := fixture["event_system"] as EventSystemStub
	var current_map_data := fixture["current_map_data"] as CurrentMapDataStub
	var editor_state := fixture["editor_state"] as EditorStateStub
	var started_usec := Time.get_ticks_usec()
	var hidden_burst_elapsed_ms := 0.0
	var pending_refresh_before_reactivate := false
	var hidden_build_started_before_reactivate := false
	if bool(workflow.get("start_visible", true)):
		renderer._apply_pending_refresh()
	else:
		var hidden_burst_started_usec := Time.get_ticks_usec()
		for update_step in range(int(workflow.get("map_update_burst", 1))):
			_touch_hidden_map(current_map_data, update_step)
			event_system.map_updated.emit()
		hidden_burst_elapsed_ms = float(Time.get_ticks_usec() - hidden_burst_started_usec) / 1000.0
		pending_refresh_before_reactivate = renderer.has_pending_refresh()
		var hidden_metrics := renderer.get_last_build_metrics()
		hidden_build_started_before_reactivate = float(hidden_metrics.get("build_total_ms", 0.0)) > 0.0 or int(hidden_metrics.get("overlay_descriptor_count", 0)) > 0
		if bool(workflow.get("reactivate_after_burst", false)):
			editor_state.view_mode_3d = true
			event_system.map_view_updated.emit()
			renderer._apply_pending_refresh()
	var summary := build_case_summary(
		case_name,
		case_data,
		workflow,
		renderer,
		current_map_data,
		float(Time.get_ticks_usec() - started_usec) / 1000.0,
		hidden_burst_elapsed_ms,
		pending_refresh_before_reactivate,
		hidden_build_started_before_reactivate
	)
	print("BENCH ", JSON.stringify(summary))
	if _should_assert_budgets() and not bool(Dictionary(summary.get("smoke", {})).get("within_budget", false)):
		push_error("Benchmark smoke budget failed for %s: %s" % [case_name, JSON.stringify(Dictionary(summary.get("smoke", {})).get("violations", []))])
		_dispose_fixture(fixture)
		return false
	_dispose_fixture(fixture)
	return true


func _create_fixture(case_data: Dictionary, start_visible: bool) -> Dictionary:
	var host := Node3D.new()
	host.name = "Map3DBenchmarkHost"
	var renderer := Map3DRendererScript.new()
	renderer.name = "Map3D"
	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "TerrainMesh"
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = Environment.new()
	renderer.add_child(terrain_mesh)
	renderer.add_child(camera)
	renderer.add_child(world_environment)
	var event_system := EventSystemStub.new()
	var current_map_data := CurrentMapDataStub.new()
	BenchmarkCases.apply_map_data(current_map_data, case_data.get("map_data", {}))
	var editor_state := EditorStateStub.new()
	editor_state.view_mode_3d = start_visible
	var preloads := BenchmarkPreloads.new()
	preloads.name = "BenchmarkPreloads"
	preloads.configure_for_set(int(current_map_data.level_set))
	renderer.set_event_system_override(event_system)
	renderer.set_current_map_data_override(current_map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)
	host.add_child(preloads)
	host.add_child(renderer)
	root.add_child(host)
	if not renderer.is_node_ready():
		renderer._ready()
	return {
		"host": host,
		"renderer": renderer,
		"event_system": event_system,
		"current_map_data": current_map_data,
		"editor_state": editor_state,
		"preloads": preloads,
	}


func _dispose_fixture(fixture: Dictionary) -> void:
	var host: Node = fixture.get("host")
	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()
	for key in ["event_system", "current_map_data", "editor_state"]:
		var node: Node = fixture.get(key)
		if node != null and is_instance_valid(node):
			node.free()


func _touch_hidden_map(current_map_data: CurrentMapDataStub, update_step: int) -> void:
	if current_map_data.hgt_map.is_empty():
		return
	var hgt := current_map_data.hgt_map
	var index := mini(1 + update_step, hgt.size() - 1)
	hgt[index] = (int(hgt[index]) + update_step + 1) % 32
	current_map_data.hgt_map = hgt
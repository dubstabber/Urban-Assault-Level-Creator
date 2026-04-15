extends SceneTree

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const BenchmarkRunner = preload("res://tests/run_map_3d_benchmarks.gd")

var _created_autoload_names: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_paths := _selected_level_paths()
	if level_paths.is_empty():
		push_error("No level paths selected")
		quit(1)
		return

	var failures := 0
	for level_path in level_paths:
		if not await _run_level(level_path):
			failures += 1
	_cleanup_autoloads()
	quit(failures)


func _selected_level_paths() -> Array[String]:
	var selected: Array[String] = []
	var args := OS.get_cmdline_user_args()
	for idx in range(args.size()):
		if String(args[idx]) != "--level" or idx + 1 >= args.size():
			continue
		for raw_name in String(args[idx + 1]).split(",", false):
			var trimmed := raw_name.strip_edges()
			if trimmed.is_empty():
				continue
			selected.append(_normalize_level_path(trimmed))
	if not selected.is_empty():
		return selected
	return ["res://test-levels/L7171.ldf"]


func _stop_at_first_ready() -> bool:
	for arg in OS.get_cmdline_user_args():
		if String(arg) == "--stop-at-first-ready":
			return true
	return false


func _normalize_level_path(value: String) -> String:
	if value.begins_with("res://"):
		return value
	if value.begins_with("test-levels/"):
		return "res://%s" % value
	return "res://test-levels/%s" % value


func _run_level(level_path: String) -> bool:
	var event_system := _autoload("EventSystem")
	var current_map_data := _autoload("CurrentMapData")
	var preloads := _autoload("Preloads")
	var editor_state := _autoload("EditorState")
	_autoload("UndoRedoManager")
	if event_system == null or current_map_data == null or preloads == null or editor_state == null:
		push_error("Missing required autoloads for real-level profiling")
		return false

	var map_host := Node2D.new()
	map_host.name = "RealMapProfileHost"
	var host_stations := Node2D.new()
	host_stations.name = "HostStations"
	var squads := Node2D.new()
	squads.name = "Squads"
	map_host.add_child(host_stations)
	map_host.add_child(squads)
	root.add_child(map_host)
	current_map_data.host_stations = host_stations
	current_map_data.squads = squads

	var renderer_host := Node3D.new()
	renderer_host.name = "RealMap3DProfileRendererHost"
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
	renderer.set_event_system_override(event_system)
	renderer.set_current_map_data_override(current_map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)
	renderer_host.add_child(renderer)
	root.add_child(renderer_host)
	if not renderer.is_node_ready():
		renderer._ready()

	editor_state.view_mode_3d = true
	var started_usec := Time.get_ticks_usec()
	current_map_data.close_map()
	current_map_data.map_path = level_path
	var opener_script = load("res://main/parsers/singleplayer_opener.gd")
	if opener_script == null:
		push_error("Failed to load SingleplayerOpener")
		_dispose_hosts(renderer_host, map_host, current_map_data)
		return false
	var opener = opener_script.new()
	await opener.load_level_async(renderer_host)
	var parsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0

	renderer._apply_pending_refresh()
	var stop_at_first_ready := _stop_at_first_ready()
	var first_ready_ok := _drain_renderer_until_first_ready(renderer, 120000)
	var first_ready_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var first_ready_summary := {
		"level": level_path,
		"dimensions": "%dx%d" % [int(current_map_data.horizontal_sectors), int(current_map_data.vertical_sectors)],
		"host_station_count": current_map_data.host_stations.get_child_count() if current_map_data.host_stations != null else 0,
		"squad_count": current_map_data.squads.get_child_count() if current_map_data.squads != null else 0,
		"parse_elapsed_ms": parsed_ms,
		"first_ready_elapsed_ms": first_ready_ms,
		"metrics": renderer.get_last_build_metrics().duplicate(true),
		"node_counts": BenchmarkRunner.collect_runtime_node_counts(renderer),
		"resource_counts": BenchmarkRunner.collect_runtime_resource_counts(renderer),
	}
	print("REAL3D_FIRST_READY ", JSON.stringify(first_ready_summary))
	if not first_ready_ok:
		push_error("Timed out waiting for first 3D ready state on %s" % level_path)
		_dispose_hosts(renderer_host, map_host, current_map_data)
		return false
	if stop_at_first_ready:
		_dispose_hosts(renderer_host, map_host, current_map_data)
		return true
	if not BenchmarkRunner.drain_renderer_work(renderer, 120000):
		var timeout_summary := {
			"level": level_path,
			"dimensions": "%dx%d" % [int(current_map_data.horizontal_sectors), int(current_map_data.vertical_sectors)],
			"host_station_count": current_map_data.host_stations.get_child_count() if current_map_data.host_stations != null else 0,
			"squad_count": current_map_data.squads.get_child_count() if current_map_data.squads != null else 0,
			"parse_elapsed_ms": parsed_ms,
			"build_state": renderer.get_build_state_snapshot(),
			"metrics": renderer.get_last_build_metrics(),
			"node_counts": BenchmarkRunner.collect_runtime_node_counts(renderer),
			"resource_counts": BenchmarkRunner.collect_runtime_resource_counts(renderer),
		}
		print("REAL3D_TIMEOUT ", JSON.stringify(timeout_summary))
		push_error("Timed out waiting for 3D renderer on %s" % level_path)
		_dispose_hosts(renderer_host, map_host, current_map_data)
		return false

	var total_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	var summary := {
		"level": level_path,
		"dimensions": "%dx%d" % [int(current_map_data.horizontal_sectors), int(current_map_data.vertical_sectors)],
		"host_station_count": current_map_data.host_stations.get_child_count() if current_map_data.host_stations != null else 0,
		"squad_count": current_map_data.squads.get_child_count() if current_map_data.squads != null else 0,
		"parse_elapsed_ms": parsed_ms,
		"total_elapsed_ms": total_ms,
		"metrics": renderer.get_last_build_metrics(),
		"node_counts": BenchmarkRunner.collect_runtime_node_counts(renderer),
		"resource_counts": BenchmarkRunner.collect_runtime_resource_counts(renderer),
	}
	print("REAL3D ", JSON.stringify(summary))

	_dispose_hosts(renderer_host, map_host, current_map_data)
	return true


func _drain_renderer_until_first_ready(renderer: Map3DRenderer, timeout_ms: int = 20000) -> bool:
	if renderer == null:
		return false
	var deadline_usec = Time.get_ticks_usec() + (timeout_ms * 1000)
	var observed_building := false
	while Time.get_ticks_usec() <= deadline_usec:
		if renderer.has_pending_refresh() and not bool(renderer.get_build_state_snapshot().get("is_building_3d", false)):
			renderer._apply_pending_refresh()
		renderer._process(0.0)
		var snapshot = renderer.get_build_state_snapshot()
		var building = bool(snapshot.get("is_building_3d", false))
		observed_building = observed_building or building
		if observed_building and not building and _renderer_has_meaningful_ready_state(renderer):
			return true
		OS.delay_msec(1)
	return false


func _renderer_has_meaningful_ready_state(renderer: Map3DRenderer) -> bool:
	if renderer == null:
		return false
	var metrics := renderer.get_last_build_metrics()
	if bool(metrics.get("invalid_input", false)):
		return false
	if float(metrics.get("build_total_ms", 0.0)) > 0.0:
		return true
	var node_counts := BenchmarkRunner.collect_runtime_node_counts(renderer)
	if int(node_counts.get("terrain_chunk_node_count", 0)) > 0:
		return true
	if int(node_counts.get("overlay_top_level_child_count", 0)) > 0:
		return true
	return false


func _dispose_hosts(renderer_host: Node, map_host: Node, current_map_data: Node) -> void:
	if current_map_data != null:
		current_map_data.player_host_station = null
		current_map_data.host_stations = null
		current_map_data.squads = null
	for node in [renderer_host, map_host]:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()


func _autoload(name: String) -> Node:
	var existing := root.get_node_or_null(name)
	if existing != null:
		return existing
	var autoload_paths := {
		"EventSystem": "res://globals/EventSystem.gd",
		"CurrentMapData": "res://globals/CurrentMapData.gd",
		"Preloads": "res://globals/Preloads.gd",
		"EditorState": "res://globals/EditorState.gd",
		"UndoRedoManager": "res://globals/UndoRedoManager.gd",
	}
	var script_path := String(autoload_paths.get(name, ""))
	if script_path.is_empty():
		return null
	var script = load(script_path)
	if script == null or not script.can_instantiate():
		return null
	var node := script.new() as Node
	if node == null:
		return null
	node.name = name
	root.add_child(node)
	_created_autoload_names.append(name)
	return node


func _cleanup_autoloads() -> void:
	for idx in range(_created_autoload_names.size() - 1, -1, -1):
		var autoload_name := _created_autoload_names[idx]
		var autoload_node := root.get_node_or_null(autoload_name)
		if autoload_node == null or not is_instance_valid(autoload_node):
			continue
		root.remove_child(autoload_node)
		autoload_node.free()
	_created_autoload_names.clear()

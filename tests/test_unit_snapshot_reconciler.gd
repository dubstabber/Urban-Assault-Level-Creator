extends RefCounted

const ReconcilerScript := preload("res://globals/unit_snapshot_reconciler.gd")

var _errors: Array[String] = []
var _created_autoload_names: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _scene_root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


func _autoload(name: String) -> Node:
	var root := _scene_root()
	if root == null:
		return null
	var existing := root.get_node_or_null(name)
	if existing != null:
		return existing
	return _create_autoload(name, root)


func _create_autoload(name: String, root: Node) -> Node:
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
	var script := load(script_path)
	if script == null or not script.can_instantiate():
		return null
	var node := script.new() as Node
	if node == null:
		return null
	node.name = name
	root.add_child(node)
	_created_autoload_names.append(name)
	return node


func _current_map_data() -> Node:
	return _autoload("CurrentMapData")


func _editor_state() -> Node:
	return _autoload("EditorState")


func _undo_redo_manager() -> Node:
	return _autoload("UndoRedoManager")


func _preloads() -> Node:
	return _autoload("Preloads")


func _make_fixture() -> Dictionary:
	_current_map_data()
	_preloads()
	_editor_state()
	_undo_redo_manager()
	var host := Node2D.new()
	host.name = "UnitSnapshotReconcilerTestHost"
	var host_stations := Node2D.new()
	host_stations.name = "HostStations"
	var squads := Node2D.new()
	squads.name = "Squads"
	host.add_child(host_stations)
	host.add_child(squads)
	var root := _scene_root()
	if root != null:
		root.add_child(host)
	var current_map_data := _current_map_data()
	current_map_data.host_stations = host_stations
	current_map_data.squads = squads
	current_map_data.horizontal_sectors = 4
	current_map_data.vertical_sectors = 4
	current_map_data.reset_editor_unit_ids()
	return {
		"host": host,
		"host_stations": host_stations,
		"squads": squads,
	}


func _dispose_fixture(fixture: Dictionary) -> void:
	var current_map_data := _current_map_data()
	current_map_data.host_stations = null
	current_map_data.squads = null
	current_map_data.player_host_station = null
	current_map_data.reset_editor_unit_ids()
	var host: Node = fixture.get("host", null)
	if host != null and is_instance_valid(host):
		if host.get_parent() != null:
			host.get_parent().remove_child(host)
		host.free()
	var root := _scene_root()
	if root != null:
		for idx in range(_created_autoload_names.size() - 1, -1, -1):
			var autoload_name := _created_autoload_names[idx]
			var autoload_node := root.get_node_or_null(autoload_name)
			if autoload_node != null and is_instance_valid(autoload_node):
				root.remove_child(autoload_node)
				autoload_node.free()
	_created_autoload_names.clear()


func _create_host_station(owner_id: int, vehicle_id: int, position: Vector2, pos_y: int = -500) -> HostStation:
	var preloads := _preloads()
	var current_map_data := _current_map_data()
	var hoststation = preloads.HOSTSTATION.instantiate() as HostStation
	current_map_data.host_stations.add_child(hoststation)
	hoststation.create(owner_id, vehicle_id)
	hoststation.position = position
	hoststation.pos_y = pos_y
	return hoststation


func _create_squad(owner_id: int, vehicle_id: int, position: Vector2, quantity: int = 1) -> Squad:
	var preloads := _preloads()
	var current_map_data := _current_map_data()
	var squad = preloads.SQUAD.instantiate() as Squad
	current_map_data.squads.add_child(squad)
	squad.create(owner_id, vehicle_id)
	squad.position = position
	squad.quantity = quantity
	return squad


func _find_squad_by_editor_unit_id(editor_unit_id: int) -> Squad:
	var current_map_data := _current_map_data()
	for squad_any in current_map_data.squads.get_children():
		if squad_any is Squad and int(squad_any.editor_unit_id) == editor_unit_id:
			return squad_any as Squad
	return null


func test_apply_unit_snapshot_reconciles_in_place() -> bool:
	_reset_errors()
	var fixture := _make_fixture()

	var removed_host := _create_host_station(1, 56, Vector2(1200.0, 1200.0))
	var kept_host := _create_host_station(1, 57, Vector2(1800.0, 1200.0))
	var moved_squad := _create_squad(1, 1, Vector2(1200.0, 1800.0), 1)
	var unchanged_squad := _create_squad(1, 1, Vector2(1800.0, 1800.0), 1)
	var current_map_data := _current_map_data()
	var editor_state := _editor_state()
	var undo_redo_manager := _undo_redo_manager()
	current_map_data.player_host_station = kept_host
	editor_state.selected_unit = moved_squad

	var snapshot: Dictionary = undo_redo_manager.create_unit_snapshot()
	var host_entries_source: Array = snapshot.get("host_stations", []).duplicate(true)
	var host_entries: Array = []
	var squad_entries: Array = snapshot.get("squads", []).duplicate(true)

	for entry_any in host_entries_source:
		if typeof(entry_any) != TYPE_DICTIONARY:
			continue
		var entry := entry_any as Dictionary
		if int(entry.get("editor_unit_id", 0)) == int(removed_host.editor_unit_id):
			continue
		host_entries.append(entry)

	for idx in squad_entries.size():
		var entry := squad_entries[idx] as Dictionary
		if int(entry.get("editor_unit_id", 0)) == int(moved_squad.editor_unit_id):
			entry["position"] = Vector2(2400.0, 2400.0)
			squad_entries[idx] = entry

	var new_squad_id: int = int(current_map_data.allocate_editor_unit_id())
	squad_entries.append({
		"editor_unit_id": new_squad_id,
		"owner_id": 1,
		"vehicle": 1,
		"position": Vector2(3000.0, 3000.0),
		"quantity": 3,
		"useable": false,
		"mb_status": false,
	})

	snapshot["host_stations"] = host_entries
	snapshot["squads"] = squad_entries
	snapshot["player_host_station_index"] = 0

	var result := ReconcilerScript.apply_unit_snapshot(snapshot)
	var changes: Array = result.get("changes", [])

	_check(current_map_data.host_stations.get_child_count() == 1, "Expected reconciler to remove only the deleted host station")
	_check(current_map_data.squads.get_child_count() == 3, "Expected reconciler to preserve existing squads and add one new squad")
	_check(removed_host.get_parent() == null, "Removed host station should be detached instead of left in the container")
	_check(is_instance_valid(kept_host), "Unchanged host station should stay valid")
	_check(kept_host.get_parent() == current_map_data.host_stations, "Unchanged host station should be preserved in place")
	_check(is_instance_valid(moved_squad), "Moved squad should stay valid")
	_check(moved_squad.position == Vector2(2400.0, 2400.0), "Moved squad should be updated in place")
	_check(unchanged_squad.get_parent() == current_map_data.squads, "Unchanged squad should be preserved in place")
	_check(_find_squad_by_editor_unit_id(new_squad_id) != null, "Reconciler should create the new squad from the snapshot")
	_check(editor_state.selected_unit == moved_squad, "Selected unit should be remapped back to the preserved moved squad")

	var change_keys := {}
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		change_keys["%s:%d:%s" % [String(change.get("kind", "")), int(change.get("unit_id", 0)), String(change.get("action", ""))]] = true
	_check(change_keys.has("host:%d:removed" % int(removed_host.editor_unit_id)), "Expected removed host station change entry")
	_check(change_keys.has("squad:%d:moved" % int(moved_squad.editor_unit_id)), "Expected moved squad change entry")
	_check(change_keys.has("squad:%d:created" % new_squad_id), "Expected created squad change entry")
	_check(not change_keys.has("host:%d:visual" % int(kept_host.editor_unit_id)), "Unchanged host station should not be reported as changed")
	_check(not change_keys.has("squad:%d:visual" % int(unchanged_squad.editor_unit_id)), "Unchanged squad should not be reported as changed")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func test_squad_ready_initializes_editor_unit_id_and_limits() -> bool:
	_reset_errors()
	var fixture := _make_fixture()
	var current_map_data := _current_map_data()
	var squad := _create_squad(1, 1, Vector2(1200.0, 1200.0), 1)

	_check(int(squad.editor_unit_id) > 0, "Squad _ready should assign a stable editor_unit_id through Unit._ready()")
	_check(int(squad.right_limit) == int(current_map_data.horizontal_sectors) * 1200 + 1200, "Squad _ready should initialize right drag limit from the current map dimensions")
	_check(int(squad.bottom_limit) == int(current_map_data.vertical_sectors) * 1200 + 1200, "Squad _ready should initialize bottom drag limit from the current map dimensions")

	_dispose_fixture(fixture)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_apply_unit_snapshot_reconciles_in_place",
		"test_squad_ready_initializes_editor_unit_id_and_limits",
	]:
		print("RUN ", test_name)
		var ok: bool = bool(call(test_name))
		if ok:
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

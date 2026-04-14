extends RefCounted
class_name UnitSnapshotReconciler

const UnitChangeDispatcherScript := preload("res://globals/unit_change_dispatcher.gd")


static func _autoload(name: String) -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null(name)
	return null


static func _current_map_data() -> Node:
	return _autoload("CurrentMapData")


static func _editor_state() -> Node:
	return _autoload("EditorState")


static func _preloads() -> Node:
	return _autoload("Preloads")


static func apply_unit_snapshot(snapshot: Dictionary) -> Dictionary:
	var editor_state := _editor_state()
	var current_map_data := _current_map_data()
	if editor_state == null or current_map_data == null:
		return {
			"changes": [],
			"selected_unit": null,
		}
	var previous_selected_id := UnitChangeDispatcherScript.unit_id_for(editor_state.selected_unit)
	var changes: Array = []
	changes.append_array(_reconcile_host_stations(snapshot.get("host_stations", [])))
	changes.append_array(_reconcile_squads(snapshot.get("squads", [])))

	var hs_index := int(snapshot.get("player_host_station_index", -1))
	if hs_index >= 0 and hs_index < current_map_data.host_stations.get_child_count():
		current_map_data.player_host_station = current_map_data.host_stations.get_child(hs_index)
	else:
		current_map_data.player_host_station = null

	var selected_unit := _find_unit_by_editor_id(previous_selected_id)
	editor_state.selected_unit = selected_unit
	return {
		"changes": changes,
		"selected_unit": selected_unit,
	}


static func _reconcile_host_stations(snapshot_entries: Array) -> Array:
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return []
	return _reconcile_units(current_map_data.host_stations, snapshot_entries, "host")


static func _reconcile_squads(snapshot_entries: Array) -> Array:
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return []
	return _reconcile_units(current_map_data.squads, snapshot_entries, "squad")


static func _reconcile_units(container: Node, snapshot_entries: Array, unit_kind: String) -> Array:
	var changes: Array = []
	if container == null or not is_instance_valid(container):
		return changes

	var existing_by_id := {}
	for child_any in container.get_children():
		if child_any == null or not is_instance_valid(child_any):
			continue
		var child := child_any as Node
		var editor_unit_id := UnitChangeDispatcherScript.unit_id_for(child)
		if editor_unit_id > 0:
			existing_by_id[editor_unit_id] = child

	var seen_ids := {}
	for idx in snapshot_entries.size():
		if typeof(snapshot_entries[idx]) != TYPE_DICTIONARY:
			continue
		var entry := snapshot_entries[idx] as Dictionary
		var editor_unit_id := _entry_editor_unit_id(entry)
		if editor_unit_id <= 0:
			continue
		seen_ids[editor_unit_id] = true

		var unit_node: Node = existing_by_id.get(editor_unit_id, null)
		var before_state: Dictionary = {}
		var created := false
		if unit_node == null or not is_instance_valid(unit_node):
			unit_node = _instantiate_unit(unit_kind)
			if unit_node == null:
				continue
			container.add_child(unit_node)
			_set_unit_editor_id(unit_node, editor_unit_id)
			created = true
		else:
			before_state = _serialize_live_unit(unit_node, unit_kind)

		_apply_snapshot_entry_to_unit(unit_node, entry, unit_kind, editor_unit_id)
		if idx < container.get_child_count() and container.get_child(idx) != unit_node:
			container.move_child(unit_node, idx)

		if created:
			changes.append(UnitChangeDispatcherScript.change_for_unit(unit_node, "created", unit_kind))
			continue

		var after_state := _serialize_live_unit(unit_node, unit_kind)
		if before_state == after_state:
			continue
		var action := "visual"
		if Vector2(before_state.get("position", Vector2.ZERO)) != Vector2(after_state.get("position", Vector2.ZERO)) or int(before_state.get("pos_y", 0)) != int(after_state.get("pos_y", 0)):
			action = "moved"
		changes.append(UnitChangeDispatcherScript.change_for_unit(unit_node, action, unit_kind))

	for existing_id_any in existing_by_id.keys():
		var existing_id := int(existing_id_any)
		if seen_ids.has(existing_id):
			continue
		var unit_node: Node = existing_by_id[existing_id]
		if unit_node == null or not is_instance_valid(unit_node):
			continue
		changes.append(UnitChangeDispatcherScript.change_for_unit(unit_node, "removed", unit_kind))
		if unit_node.get_parent() == container:
			container.remove_child(unit_node)
		unit_node.queue_free()

	return changes


static func _instantiate_unit(unit_kind: String) -> Node:
	var preloads := _preloads()
	if preloads == null:
		return null
	if unit_kind == "host":
		return preloads.HOSTSTATION.instantiate()
	if unit_kind == "squad":
		return preloads.SQUAD.instantiate()
	return null


static func _apply_snapshot_entry_to_unit(unit_node: Node, entry: Dictionary, unit_kind: String, editor_unit_id: int) -> void:
	if editor_unit_id > 0:
		_set_unit_editor_id(unit_node, editor_unit_id)

	if unit_kind == "host" and unit_node is HostStation:
		var hoststation := unit_node as HostStation
		hoststation.create(int(entry.get("owner_id", 1)), int(entry.get("vehicle", 0)))
		hoststation.position = entry.get("position", Vector2.ZERO)
		hoststation.pos_y = int(entry.get("pos_y", -500))
		hoststation.energy = int(entry.get("energy", 300000))
		hoststation.view_angle = int(entry.get("view_angle", 0))
		hoststation.view_angle_enabled = bool(entry.get("view_angle_enabled", false))
		hoststation.reload_const = int(entry.get("reload_const", 0))
		hoststation.reload_const_enabled = bool(entry.get("reload_const_enabled", false))
		hoststation.con_budget = int(entry.get("con_budget", 100))
		hoststation.con_delay = int(entry.get("con_delay", 0))
		hoststation.def_budget = int(entry.get("def_budget", 99))
		hoststation.def_delay = int(entry.get("def_delay", 0))
		hoststation.rec_budget = int(entry.get("rec_budget", 99))
		hoststation.rec_delay = int(entry.get("rec_delay", 0))
		hoststation.rob_budget = int(entry.get("rob_budget", 80))
		hoststation.rob_delay = int(entry.get("rob_delay", 0))
		hoststation.pow_budget = int(entry.get("pow_budget", 80))
		hoststation.pow_delay = int(entry.get("pow_delay", 0))
		hoststation.rad_budget = int(entry.get("rad_budget", 0))
		hoststation.rad_delay = int(entry.get("rad_delay", 0))
		hoststation.saf_budget = int(entry.get("saf_budget", 50))
		hoststation.saf_delay = int(entry.get("saf_delay", 0))
		hoststation.cpl_budget = int(entry.get("cpl_budget", 99))
		hoststation.cpl_delay = int(entry.get("cpl_delay", 0))
		hoststation.mb_status = bool(entry.get("mb_status", false))
		hoststation.recalculate_limits()
		return

	if unit_kind == "squad" and unit_node is Squad:
		var squad := unit_node as Squad
		squad.create(int(entry.get("owner_id", 1)), int(entry.get("vehicle", 0)))
		squad.position = entry.get("position", Vector2.ZERO)
		squad.quantity = int(entry.get("quantity", 1))
		squad.useable = bool(entry.get("useable", false))
		squad.mb_status = bool(entry.get("mb_status", false))
		squad.recalculate_limits()


static func _serialize_live_unit(unit_node: Node, unit_kind: String) -> Dictionary:
	if unit_kind == "host" and unit_node is HostStation:
		var hs := unit_node as HostStation
		return {
			"editor_unit_id": UnitChangeDispatcherScript.unit_id_for(hs),
			"owner_id": hs.owner_id,
			"vehicle": hs.vehicle,
			"position": hs.position,
			"pos_y": hs.pos_y,
			"energy": hs.energy,
			"view_angle": hs.view_angle,
			"view_angle_enabled": hs.view_angle_enabled,
			"reload_const": hs.reload_const,
			"reload_const_enabled": hs.reload_const_enabled,
			"con_budget": hs.con_budget,
			"con_delay": hs.con_delay,
			"def_budget": hs.def_budget,
			"def_delay": hs.def_delay,
			"rec_budget": hs.rec_budget,
			"rec_delay": hs.rec_delay,
			"rob_budget": hs.rob_budget,
			"rob_delay": hs.rob_delay,
			"pow_budget": hs.pow_budget,
			"pow_delay": hs.pow_delay,
			"rad_budget": hs.rad_budget,
			"rad_delay": hs.rad_delay,
			"saf_budget": hs.saf_budget,
			"saf_delay": hs.saf_delay,
			"cpl_budget": hs.cpl_budget,
			"cpl_delay": hs.cpl_delay,
			"mb_status": hs.mb_status,
		}
	if unit_kind == "squad" and unit_node is Squad:
		var squad := unit_node as Squad
		return {
			"editor_unit_id": UnitChangeDispatcherScript.unit_id_for(squad),
			"owner_id": squad.owner_id,
			"vehicle": squad.vehicle,
			"position": squad.position,
			"quantity": squad.quantity,
			"useable": squad.useable,
			"mb_status": squad.mb_status,
		}
	return {}


static func _entry_editor_unit_id(entry: Dictionary) -> int:
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return 0
	var editor_unit_id := int(entry.get("editor_unit_id", 0))
	if editor_unit_id > 0:
		current_map_data.reserve_editor_unit_id(editor_unit_id)
		return editor_unit_id
	return current_map_data.allocate_editor_unit_id()


static func _set_unit_editor_id(unit_node: Node, editor_unit_id: int) -> void:
	if unit_node == null or not is_instance_valid(unit_node) or editor_unit_id <= 0:
		return
	unit_node.set("editor_unit_id", editor_unit_id)
	var current_map_data := _current_map_data()
	if current_map_data != null:
		current_map_data.reserve_editor_unit_id(editor_unit_id)


static func _find_unit_by_editor_id(editor_unit_id: int) -> Unit:
	if editor_unit_id <= 0:
		return null
	var current_map_data := _current_map_data()
	if current_map_data == null:
		return null
	for container in [current_map_data.host_stations, current_map_data.squads]:
		if container == null or not is_instance_valid(container):
			continue
		for child_any in container.get_children():
			if child_any == null or not is_instance_valid(child_any):
				continue
			var child_editor_unit_id: Variant = child_any.get("editor_unit_id")
			if child_editor_unit_id != null and int(child_editor_unit_id) == editor_unit_id:
				return child_any as Unit
	return null

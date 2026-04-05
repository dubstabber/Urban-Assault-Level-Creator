extends Node
class_name UndoRedoHistory

const MAX_HISTORY := 100

var undo_stack: Array[Dictionary] = []
var redo_stack: Array[Dictionary] = []
var max_history := MAX_HISTORY

var _active_group: Dictionary = {}
var _is_replaying := false


func _ready() -> void:
	EventSystem.map_created.connect(clear_history)
	EventSystem.map_load_finished.connect(clear_history)
	EventSystem.new_map_requested.connect(clear_history)
	EventSystem.open_map_requested.connect(clear_history)
	EventSystem.close_map_requested.connect(clear_history)


func begin_group(label: String, coalesce_key := "") -> void:
	if _is_replaying:
		return
	if _has_active_group():
		commit_group()
	_active_group = {
		"label": label,
		"changes": [],
		"coalesce_key": coalesce_key
	}


func record_change(change: Dictionary) -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if not _is_valid_change(change):
		return
	if change.before == change.after:
		return

	var changes: Array = _active_group.changes
	for existing: Dictionary in changes:
		if existing.map == change.map and existing.index == change.index:
			existing.after = change.after
			return
	changes.append(change.duplicate())


func record_item_snapshot(before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if before_snapshot == after_snapshot:
		return
	_active_group.changes.append({
		"kind": "item_snapshot",
		"before": before_snapshot.duplicate(true),
		"after": after_snapshot.duplicate(true)
	})


func record_resize_snapshot(before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if before_snapshot == after_snapshot:
		return
	_active_group.changes.append({
		"kind": "resize_snapshot",
		"before": before_snapshot.duplicate(true),
		"after": after_snapshot.duplicate(true)
	})


func record_unit_snapshot(before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if before_snapshot == after_snapshot:
		return
	_active_group.changes.append({
		"kind": "unit_snapshot",
		"before": before_snapshot.duplicate(true),
		"after": after_snapshot.duplicate(true)
	})


func create_item_snapshot() -> Dictionary:
	return {
		"beam_gates": _serialize_beam_gates(CurrentMapData.beam_gates),
		"stoudson_bombs": _serialize_stoudson_bombs(CurrentMapData.stoudson_bombs),
		"tech_upgrades": _serialize_tech_upgrades(CurrentMapData.tech_upgrades)
	}


func create_unit_snapshot() -> Dictionary:
	return {
		"host_stations": _serialize_host_stations(),
		"squads": _serialize_squads(),
		"player_host_station_index": _get_player_host_station_index()
	}


func create_resize_snapshot() -> Dictionary:
	return {
		"horizontal_sectors": CurrentMapData.horizontal_sectors,
		"vertical_sectors": CurrentMapData.vertical_sectors,
		"typ_map": CurrentMapData.typ_map.duplicate(),
		"own_map": CurrentMapData.own_map.duplicate(),
		"hgt_map": CurrentMapData.hgt_map.duplicate(),
		"blg_map": CurrentMapData.blg_map.duplicate(),
		"host_stations": _serialize_host_stations(),
		"squads": _serialize_squads()
	}


func commit_group() -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if _active_group.changes.is_empty():
		_active_group.clear()
		return

	if _try_coalesce_with_previous_group():
		_emit_fine_grained_map_edit_signals(_active_group)
		_active_group.clear()
		redo_stack.clear()
		return

	_emit_fine_grained_map_edit_signals(_active_group)
	undo_stack.append(_active_group.duplicate(true))
	_active_group.clear()
	redo_stack.clear()
	while undo_stack.size() > max_history:
		undo_stack.remove_at(0)


func _emit_fine_grained_map_edit_signals(group: Dictionary) -> void:
	var edited_typ_indices: Array = []
	var edited_hgt_indices: Array = []
	var edited_blg_indices: Array = []
	for change_value in group.get("changes", []):
		if typeof(change_value) != TYPE_DICTIONARY:
			continue
		var change := change_value as Dictionary
		if not _is_valid_change(change):
			continue
		var idx := int(change.get("index", -1))
		match String(change.get("map", "")):
			"typ_map":
				if not edited_typ_indices.has(idx):
					edited_typ_indices.append(idx)
			"hgt_map":
				if not edited_hgt_indices.has(idx):
					edited_hgt_indices.append(idx)
			"blg_map":
				if not edited_blg_indices.has(idx):
					edited_blg_indices.append(idx)
	if not edited_typ_indices.is_empty():
		EventSystem.typ_map_cells_edited.emit(edited_typ_indices)
	if not edited_hgt_indices.is_empty():
		EventSystem.hgt_map_cells_edited.emit(edited_hgt_indices)
	if not edited_blg_indices.is_empty():
		EventSystem.blg_map_cells_edited.emit(edited_blg_indices)


func clear_history() -> void:
	undo_stack.clear()
	redo_stack.clear()
	_active_group.clear()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func undo() -> void:
	if undo_stack.is_empty():
		return
	var group: Dictionary = undo_stack.pop_back()
	_apply_group(group, true)
	redo_stack.append(group)


func redo() -> void:
	if redo_stack.is_empty():
		return
	var group: Dictionary = redo_stack.pop_back()
	_apply_group(group, false)
	undo_stack.append(group)


func _apply_group(group: Dictionary, use_before: bool) -> void:
	_is_replaying = true
	var edited_typ_indices: Array = []
	var edited_hgt_indices: Array = []
	var edited_blg_indices: Array = []
	var edited_item_data := false

	for change: Dictionary in group.changes:
		if change.has("kind") and change.kind == "item_snapshot":
			var snapshot_key := "before" if use_before else "after"
			_apply_item_snapshot(change[snapshot_key])
			edited_item_data = true
			continue
		if change.has("kind") and change.kind == "resize_snapshot":
			var resize_snapshot_key := "before" if use_before else "after"
			_apply_resize_snapshot(change[resize_snapshot_key])
			edited_item_data = true
			continue
		if change.has("kind") and change.kind == "unit_snapshot":
			var unit_snapshot_key := "before" if use_before else "after"
			_apply_unit_snapshot(change[unit_snapshot_key])
			edited_item_data = true
			continue
		if not _is_valid_change(change):
			continue
		var value_key := "before" if use_before else "after"
		var edited_value: int = int(change[value_key])
		match change.map:
			"typ_map":
				if change.index >= 0 and change.index < CurrentMapData.typ_map.size():
					CurrentMapData.typ_map[change.index] = edited_value
					if not edited_typ_indices.has(change.index):
						edited_typ_indices.append(change.index)
			"own_map":
				if change.index >= 0 and change.index < CurrentMapData.own_map.size():
					CurrentMapData.own_map[change.index] = edited_value
			"hgt_map":
				if change.index >= 0 and change.index < CurrentMapData.hgt_map.size():
					CurrentMapData.hgt_map[change.index] = edited_value
					if not edited_hgt_indices.has(change.index):
						edited_hgt_indices.append(change.index)
			"blg_map":
				if change.index >= 0 and change.index < CurrentMapData.blg_map.size():
					CurrentMapData.blg_map[change.index] = edited_value
					if not edited_blg_indices.has(change.index):
						edited_blg_indices.append(change.index)

	_is_replaying = false

	if not edited_typ_indices.is_empty():
		EventSystem.typ_map_cells_edited.emit(edited_typ_indices)
	if not edited_hgt_indices.is_empty():
		EventSystem.hgt_map_cells_edited.emit(edited_hgt_indices)
	if not edited_blg_indices.is_empty():
		EventSystem.blg_map_cells_edited.emit(edited_blg_indices)
	if edited_item_data:
		EventSystem.item_updated.emit()
	EventSystem.map_updated.emit()


func _has_active_group() -> bool:
	return _active_group.has("changes")


func _try_coalesce_with_previous_group() -> bool:
	var coalesce_key: String = str(_active_group.get("coalesce_key", ""))
	if coalesce_key.is_empty() or undo_stack.is_empty():
		return false
	var previous_group: Dictionary = undo_stack[-1]
	if str(previous_group.get("coalesce_key", "")) != coalesce_key:
		return false
	if previous_group.get("changes", []).size() != 1 or _active_group.changes.size() != 1:
		return false
	var previous_change: Dictionary = previous_group.changes[0]
	var active_change: Dictionary = _active_group.changes[0]
	if previous_change.get("kind", "") != "unit_snapshot" or active_change.get("kind", "") != "unit_snapshot":
		return false
	previous_change.after = active_change.after.duplicate(true)
	previous_group.label = _active_group.label
	undo_stack[-1] = previous_group
	return true


func _is_valid_change(change: Dictionary) -> bool:
	return change.has("map") and change.has("index") and change.has("before") and change.has("after")


func _serialize_beam_gates(source: Array[BeamGate]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for bg in source:
		serialized.append({
			"sec_x": bg.sec_x,
			"sec_y": bg.sec_y,
			"closed_bp": bg.closed_bp,
			"opened_bp": bg.opened_bp,
			"key_sectors": bg.key_sectors.duplicate(),
			"target_levels": bg.target_levels.duplicate(),
			"mb_status": bg.mb_status
		})
	return serialized


func _serialize_stoudson_bombs(source: Array[StoudsonBomb]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for bomb in source:
		serialized.append({
			"sec_x": bomb.sec_x,
			"sec_y": bomb.sec_y,
			"inactive_bp": bomb.inactive_bp,
			"active_bp": bomb.active_bp,
			"trigger_bp": bomb.trigger_bp,
			"type": bomb.type,
			"countdown": bomb.countdown,
			"key_sectors": bomb.key_sectors.duplicate()
		})
	return serialized


func _serialize_tech_upgrades(source: Array[TechUpgrade]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for tu in source:
		serialized.append({
			"sec_x": tu.sec_x,
			"sec_y": tu.sec_y,
			"building_id": tu.building_id,
			"type": tu.type,
			"mb_status": tu.mb_status,
			"vehicles": _serialize_tech_modifiers(tu.vehicles),
			"weapons": _serialize_tech_modifiers(tu.weapons),
			"buildings": _serialize_tech_modifiers(tu.buildings)
		})
	return serialized


func _serialize_tech_modifiers(source: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for modifier in source:
		var modifier_dict: Dictionary = {}
		var members = modifier.get_script().get_script_property_list()
		for member in members:
			if member.name in modifier:
				modifier_dict[member.name] = modifier[member.name]
		serialized.append(modifier_dict)
	return serialized


func _apply_item_snapshot(snapshot: Dictionary) -> void:
	CurrentMapData.beam_gates = _deserialize_beam_gates(snapshot.get("beam_gates", []))
	CurrentMapData.stoudson_bombs = _deserialize_stoudson_bombs(snapshot.get("stoudson_bombs", []))
	CurrentMapData.tech_upgrades = _deserialize_tech_upgrades(snapshot.get("tech_upgrades", []))
	EditorState.selected_beam_gate = null
	EditorState.selected_bomb = null
	EditorState.selected_tech_upgrade = null
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)


func _deserialize_beam_gates(source: Array) -> Array[BeamGate]:
	var result: Array[BeamGate] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var bg := BeamGate.new(int(entry.get("sec_x", 0)), int(entry.get("sec_y", 0)))
		bg.closed_bp = int(entry.get("closed_bp", 25))
		bg.opened_bp = int(entry.get("opened_bp", 26))
		bg.key_sectors = entry.get("key_sectors", []).duplicate()
		bg.target_levels = entry.get("target_levels", []).duplicate()
		bg.mb_status = bool(entry.get("mb_status", false))
		result.append(bg)
	return result


func _deserialize_stoudson_bombs(source: Array) -> Array[StoudsonBomb]:
	var result: Array[StoudsonBomb] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var bomb := StoudsonBomb.new(int(entry.get("sec_x", 0)), int(entry.get("sec_y", 0)))
		bomb.inactive_bp = int(entry.get("inactive_bp", 35))
		bomb.active_bp = int(entry.get("active_bp", 36))
		bomb.trigger_bp = int(entry.get("trigger_bp", 37))
		bomb.type = int(entry.get("type", 1))
		bomb.countdown = int(entry.get("countdown", 614400))
		bomb.key_sectors = entry.get("key_sectors", []).duplicate()
		result.append(bomb)
	return result


func _deserialize_tech_upgrades(source: Array) -> Array[TechUpgrade]:
	var result: Array[TechUpgrade] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var tu := TechUpgrade.new(int(entry.get("sec_x", 0)), int(entry.get("sec_y", 0)))
		tu.building_id = int(entry.get("building_id", 4))
		tu.type = int(entry.get("type", 99))
		tu.mb_status = bool(entry.get("mb_status", false))
		tu.vehicles = _deserialize_vehicle_modifiers(entry.get("vehicles", []))
		tu.weapons = _deserialize_weapon_modifiers(entry.get("weapons", []))
		tu.buildings = _deserialize_building_modifiers(entry.get("buildings", []))
		result.append(tu)
	return result


func _deserialize_vehicle_modifiers(source: Array) -> Array[TechUpgrade.ModifyVehicle]:
	var result: Array[TechUpgrade.ModifyVehicle] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var modifier := TechUpgrade.ModifyVehicle.new()
		for key in entry.keys():
			modifier[key] = entry[key]
		result.append(modifier)
	return result


func _deserialize_weapon_modifiers(source: Array) -> Array[TechUpgrade.ModifyWeapon]:
	var result: Array[TechUpgrade.ModifyWeapon] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var modifier := TechUpgrade.ModifyWeapon.new()
		for key in entry.keys():
			modifier[key] = entry[key]
		result.append(modifier)
	return result


func _deserialize_building_modifiers(source: Array) -> Array[TechUpgrade.ModifyBuilding]:
	var result: Array[TechUpgrade.ModifyBuilding] = []
	for entry_any in source:
		var entry: Dictionary = entry_any
		var modifier := TechUpgrade.ModifyBuilding.new()
		for key in entry.keys():
			modifier[key] = entry[key]
		result.append(modifier)
	return result


func _serialize_host_stations() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	if not CurrentMapData.host_stations:
		return serialized
	for hs: HostStation in CurrentMapData.host_stations.get_children():
		serialized.append({
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
			"mb_status": hs.mb_status
		})
	return serialized


func _serialize_squads() -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	if not CurrentMapData.squads:
		return serialized
	for squad: Squad in CurrentMapData.squads.get_children():
		serialized.append({
			"owner_id": squad.owner_id,
			"vehicle": squad.vehicle,
			"position": squad.position,
			"quantity": squad.quantity,
			"useable": squad.useable,
			"mb_status": squad.mb_status
		})
	return serialized


func _apply_resize_snapshot(snapshot: Dictionary) -> void:
	CurrentMapData.horizontal_sectors = int(snapshot.get("horizontal_sectors", 0))
	CurrentMapData.vertical_sectors = int(snapshot.get("vertical_sectors", 0))
	CurrentMapData.typ_map = snapshot.get("typ_map", PackedByteArray()).duplicate()
	CurrentMapData.own_map = snapshot.get("own_map", PackedByteArray()).duplicate()
	CurrentMapData.hgt_map = snapshot.get("hgt_map", PackedByteArray()).duplicate()
	CurrentMapData.blg_map = snapshot.get("blg_map", PackedByteArray()).duplicate()
	_restore_host_stations(snapshot.get("host_stations", []))
	_restore_squads(snapshot.get("squads", []))
	EditorState.selected_unit = null
	EditorState.unselect_all()
	get_tree().root.size_changed.emit()


func _apply_unit_snapshot(snapshot: Dictionary) -> void:
	_restore_host_stations(snapshot.get("host_stations", []))
	_restore_squads(snapshot.get("squads", []))
	var hs_index := int(snapshot.get("player_host_station_index", -1))
	if hs_index >= 0 and hs_index < CurrentMapData.host_stations.get_child_count():
		CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(hs_index)
	else:
		CurrentMapData.player_host_station = null
	EditorState.selected_unit = null
	EventSystem.unit_selected.emit()


func _restore_host_stations(host_stations_snapshot: Array) -> void:
	if not CurrentMapData.host_stations:
		return
	for hs in CurrentMapData.host_stations.get_children():
		hs.queue_free()
	for entry_any in host_stations_snapshot:
		var entry: Dictionary = entry_any
		var hoststation = Preloads.HOSTSTATION.instantiate()
		CurrentMapData.host_stations.add_child(hoststation)
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
	if CurrentMapData.host_stations.get_child_count() > 0:
		CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
	else:
		CurrentMapData.player_host_station = null


func _restore_squads(squads_snapshot: Array) -> void:
	if not CurrentMapData.squads:
		return
	for squad in CurrentMapData.squads.get_children():
		squad.queue_free()
	for entry_any in squads_snapshot:
		var entry: Dictionary = entry_any
		var squad = Preloads.SQUAD.instantiate()
		CurrentMapData.squads.add_child(squad)
		squad.create(int(entry.get("owner_id", 1)), int(entry.get("vehicle", 0)))
		squad.position = entry.get("position", Vector2.ZERO)
		squad.quantity = int(entry.get("quantity", 1))
		squad.useable = bool(entry.get("useable", false))
		squad.mb_status = bool(entry.get("mb_status", false))
		squad.recalculate_limits()


func _get_player_host_station_index() -> int:
	if not CurrentMapData.host_stations or not is_instance_valid(CurrentMapData.player_host_station):
		return -1
	for i in CurrentMapData.host_stations.get_child_count():
		if CurrentMapData.host_stations.get_child(i) == CurrentMapData.player_host_station:
			return i
	return -1

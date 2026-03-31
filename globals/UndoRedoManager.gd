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


func begin_group(label: String) -> void:
	if _is_replaying:
		return
	if _has_active_group():
		commit_group()
	_active_group = {
		"label": label,
		"changes": []
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


func create_item_snapshot() -> Dictionary:
	return {
		"beam_gates": _serialize_beam_gates(CurrentMapData.beam_gates),
		"stoudson_bombs": _serialize_stoudson_bombs(CurrentMapData.stoudson_bombs),
		"tech_upgrades": _serialize_tech_upgrades(CurrentMapData.tech_upgrades)
	}


func commit_group() -> void:
	if _is_replaying:
		return
	if not _has_active_group():
		return
	if _active_group.changes.is_empty():
		_active_group.clear()
		return

	undo_stack.append(_active_group.duplicate(true))
	_active_group.clear()
	redo_stack.clear()
	while undo_stack.size() > max_history:
		undo_stack.remove_at(0)


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
	var edited_item_data := false

	for change: Dictionary in group.changes:
		if change.has("kind") and change.kind == "item_snapshot":
			var snapshot_key := "before" if use_before else "after"
			_apply_item_snapshot(change[snapshot_key])
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

	_is_replaying = false

	if not edited_typ_indices.is_empty():
		EventSystem.typ_map_cells_edited.emit(edited_typ_indices)
	if not edited_hgt_indices.is_empty():
		EventSystem.hgt_map_cells_edited.emit(edited_hgt_indices)
	if edited_item_data:
		EventSystem.item_updated.emit()
	EventSystem.map_updated.emit()


func _has_active_group() -> bool:
	return _active_group.has("changes")


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

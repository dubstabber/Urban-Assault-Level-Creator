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

	for change: Dictionary in group.changes:
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
	EventSystem.map_updated.emit()


func _has_active_group() -> bool:
	return _active_group.has("changes")


func _is_valid_change(change: Dictionary) -> bool:
	return change.has("map") and change.has("index") and change.has("before") and change.has("after")

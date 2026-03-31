extends HBoxContainer

var level_index: int


func create(_level_index: int) -> void:
	if _level_index > 0:
		level_index = _level_index
		$Label.text = 'This beam gate unlocks: L%02d%02d' % [level_index, level_index]


func _on_button_pressed() -> void:
	if not EditorState.selected_beam_gate: return
	var undo_redo_manager = get_node("/root/UndoRedoManager")
	undo_redo_manager.begin_group("Beam gate remove level")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	EditorState.selected_beam_gate.target_levels.erase(level_index)
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()
	if EditorState.selected_beam_gate.target_levels.is_empty():
		EventSystem.map_updated.emit()
	CurrentMapData.is_saved = false
	queue_free()

extends HBoxContainer

var level_index: int


func create(_level_index: int) -> void:
	if _level_index > 0:
		level_index = _level_index
		if level_index < 10:
			$Label.text = 'This beam gate unlocks: L0%s0%s' % [level_index, level_index]
		else:
			$Label.text = 'This beam gate unlocks: L%s%s' % [level_index, level_index]


func _on_button_pressed() -> void:
	if not CurrentMapData.selected_beam_gate: return
	CurrentMapData.selected_beam_gate.target_levels.erase(level_index)
	if CurrentMapData.selected_beam_gate.target_levels.is_empty():
		EventSystem.map_updated.emit()
	queue_free()

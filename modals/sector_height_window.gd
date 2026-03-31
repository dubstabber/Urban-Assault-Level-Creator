extends Window

@onready var height_value_spin_box: SpinBox = $PanelContainer/MarginContainer2/HeightSpinBox
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	EventSystem.sector_height_window_requested.connect(popup)


func _on_ok_button_pressed() -> void:
	hide()
	
	if height_value_spin_box.value >= 0 and height_value_spin_box.value < 256:
		var edited_border_indices: Array = []
		undo_redo_manager.begin_group("Set sector height")
		if EditorState.selected_sectors.size() > 1 and CurrentMapData.hgt_map.size() > 0:
			for sector_dict in EditorState.selected_sectors:
				var border_idx := int(sector_dict.border_idx)
				var before := int(CurrentMapData.hgt_map[border_idx])
				CurrentMapData.hgt_map[border_idx] = int(height_value_spin_box.value)
				edited_border_indices.append(border_idx)
				undo_redo_manager.record_change({
					"map": "hgt_map",
					"index": border_idx,
					"before": before,
					"after": int(CurrentMapData.hgt_map[border_idx])
				})
			EventSystem.hgt_map_cells_edited.emit(edited_border_indices)
			EventSystem.map_updated.emit()
		elif EditorState.border_selected_sector_idx >= 0 and CurrentMapData.hgt_map.size() > 0:
			var before := int(CurrentMapData.hgt_map[EditorState.border_selected_sector_idx])
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] = int(height_value_spin_box.value)
			edited_border_indices.append(EditorState.border_selected_sector_idx)
			undo_redo_manager.record_change({
				"map": "hgt_map",
				"index": EditorState.border_selected_sector_idx,
				"before": before,
				"after": int(CurrentMapData.hgt_map[EditorState.border_selected_sector_idx])
			})
			EventSystem.hgt_map_cells_edited.emit(edited_border_indices)
			EventSystem.map_updated.emit()
		undo_redo_manager.commit_group()
	else:
		printerr("Wrong height value: ", height_value_spin_box.value)
	

func close() -> void:
	hide()


func _on_about_to_popup() -> void:
	height_value_spin_box.value = CurrentMapData.hgt_map[EditorState.border_selected_sector_idx]

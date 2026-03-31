extends Window

@onready var typ_map_spin_box: SpinBox = %TypMapSpinBox
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	EventSystem.sector_building_windows_requested.connect(popup)


func _on_ok_button_pressed() -> void:
	hide()
	
	if typ_map_spin_box.value >= 0 and typ_map_spin_box.value < 256:
		var edited_typ_indices: Array = []
		undo_redo_manager.begin_group("Set typ value")
		if EditorState.selected_sectors.size() > 1 and CurrentMapData.hgt_map.size() > 0:
			for sector_dict in EditorState.selected_sectors:
				if sector_dict.has("idx"):
					var idx := int(sector_dict.idx)
					var before := int(CurrentMapData.typ_map[idx])
					CurrentMapData.typ_map[idx] = int(typ_map_spin_box.value)
					edited_typ_indices.append(idx)
					undo_redo_manager.record_change({
						"map": "typ_map",
						"index": idx,
						"before": before,
						"after": int(CurrentMapData.typ_map[idx])
					})
			if not edited_typ_indices.is_empty():
				EventSystem.typ_map_cells_edited.emit(edited_typ_indices)
			EventSystem.map_updated.emit()
		elif EditorState.selected_sector_idx >= 0 and CurrentMapData.typ_map.size() > 0:
			var before := int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = int(typ_map_spin_box.value)
			edited_typ_indices.append(EditorState.selected_sector_idx)
			undo_redo_manager.record_change({
				"map": "typ_map",
				"index": EditorState.selected_sector_idx,
				"before": before,
				"after": int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
			})
			EventSystem.typ_map_cells_edited.emit(edited_typ_indices)
			EventSystem.map_updated.emit()
		undo_redo_manager.commit_group()
	else:
		printerr("Wrong typ_map value: ", typ_map_spin_box.value)


func close() -> void:
	hide()


func _on_about_to_popup() -> void:
	typ_map_spin_box.value = CurrentMapData.typ_map[EditorState.selected_sector_idx]


func _on_typ_map_picker_button_pressed() -> void:
	%TypMapPickerWindow.popup.call_deferred()


func _on_typ_map_picker_window_building_selected(index: int) -> void:
	typ_map_spin_box.value = index

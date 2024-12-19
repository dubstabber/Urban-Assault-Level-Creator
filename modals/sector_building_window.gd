extends Window

@onready var typ_map_spin_box: SpinBox = $PanelContainer/VBoxContainer/MarginContainer2/SpinBox


func _ready() -> void:
	EventSystem.sector_building_windows_requested.connect(popup)


func _on_ok_button_pressed() -> void:
	hide()
	
	if typ_map_spin_box.value >= 0 and typ_map_spin_box.value < 256:
		if EditorState.selected_sectors.size() > 1 and CurrentMapData.hgt_map.size() > 0:
			for sector_dict in EditorState.selected_sectors:
				CurrentMapData.typ_map[sector_dict.idx] = int(typ_map_spin_box.value)
			EventSystem.map_updated.emit()
		elif EditorState.selected_sector_idx >= 0 and CurrentMapData.typ_map.size() > 0:
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = int(typ_map_spin_box.value)
			EventSystem.map_updated.emit()
	else:
		printerr("Wrong typ_map value: ", typ_map_spin_box.value)


func close() -> void:
	hide()


func _on_about_to_popup() -> void:
	typ_map_spin_box.value = CurrentMapData.typ_map[EditorState.selected_sector_idx]

extends Window

@onready var typ_map_spin_box: SpinBox = $PanelContainer/VBoxContainer/MarginContainer2/SpinBox


func _on_ok_button_pressed() -> void:
	hide()
	
	if typ_map_spin_box.value >= 0 and typ_map_spin_box.value < 256:
		if CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.typ_map.size() > 0:
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = typ_map_spin_box.value
			EventSystem.map_updated.emit()
	else:
		printerr("Wrong typ_map value: ", typ_map_spin_box.value)


func close() -> void:
	hide()

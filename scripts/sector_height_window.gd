extends Window

@onready var height_value_spin_box: SpinBox = $PanelContainer/MarginContainer2/HeightSpinBox


func _on_ok_button_pressed() -> void:
	hide()
	
	if height_value_spin_box.value >= 0 and height_value_spin_box.value < 256:
		if CurrentMapData.border_selected_sector_idx >= 0 and CurrentMapData.hgt_map.size() > 0:
			CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx] = int(height_value_spin_box.value)
			EventSystem.map_updated.emit()
	else:
		printerr("Wrong height value: ", height_value_spin_box.value)
	

func close() -> void:
	hide()


func _on_about_to_popup() -> void:
	height_value_spin_box.value = CurrentMapData.hgt_map[CurrentMapData.border_selected_sector_idx]

extends Window

@onready var typ_map_spin_box: SpinBox = $PanelContainer/VBoxContainer/MarginContainer2/SpinBox


func _on_ok_button_pressed() -> void:
	hide()
	
	if typ_map_spin_box.value >= 0 and typ_map_spin_box.value < 256:
		EventSystem.building_added.emit(typ_map_spin_box.value)
	else:
		printerr("Wrong typ_map value: ", typ_map_spin_box.value)
		


func close() -> void:
	hide()

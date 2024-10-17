extends Window

@onready var height_value_spin_box: SpinBox = $PanelContainer/MarginContainer2/SpinBox


func _on_ok_button_pressed() -> void:
	hide()
	
	if height_value_spin_box.value >= 0 and height_value_spin_box.value < 256:
		Signals.sector_height_changed.emit(height_value_spin_box.value)
	else:
		printerr("Wrong height value: ", height_value_spin_box.value)
	

func close() -> void:
	hide()
	

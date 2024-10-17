extends Window

@onready var horizontal_sectors_spinbox = $PanelContainer/MarginContainer2/GridContainer/SpinBox
@onready var vertical_sectors_spinbox = $PanelContainer/MarginContainer2/GridContainer/SpinBox2


func _on_create_button_pressed() -> void:
	CurrentMapData.horizontal_sectors = horizontal_sectors_spinbox.value
	CurrentMapData.vertical_sectors = vertical_sectors_spinbox.value
	hide()
	var sectors = CurrentMapData.horizontal_sectors * CurrentMapData.vertical_sectors
	for sector in sectors:
		CurrentMapData.typ_map.append(0)
		CurrentMapData.own_map.append(0)
		CurrentMapData.blg_map.append(0)
		
	var sectors_with_borders = (CurrentMapData.horizontal_sectors+2) * (CurrentMapData.vertical_sectors+2)
	for sector in sectors_with_borders:
		CurrentMapData.hgt_map.append(127)
	Signals.map_created.emit()

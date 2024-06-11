extends CanvasLayer

signal map_created

@onready var new_map_window = $NewMapWindow
@onready var horizontal_sectors = $NewMapWindow/PanelContainer/MarginContainer2/GridContainer/SpinBox
@onready var vertical_sectors = $NewMapWindow/PanelContainer/MarginContainer2/GridContainer/SpinBox2


func _on_create_button_pressed():
	CurrentMapData.horizontal_sectors = horizontal_sectors.value
	CurrentMapData.vertical_sectors = vertical_sectors.value
	new_map_window.hide()
	map_created.emit()
	var sectors = CurrentMapData.horizontal_sectors * CurrentMapData.vertical_sectors
	for sector in sectors:
		CurrentMapData.typ_map.append(0)
		CurrentMapData.own_map.append(0)
		CurrentMapData.blg_map.append(0)
		
	var sectors_with_borders = (CurrentMapData.horizontal_sectors+2) * (CurrentMapData.vertical_sectors+2)
	for sector in sectors_with_borders:
		CurrentMapData.hgt_map.append(0)

extends CanvasLayer

signal map_created

@onready var new_map_window = $NewMapWindow
@onready var horizontal_sectors = $NewMapWindow/PanelContainer/MarginContainer2/GridContainer/SpinBox
@onready var vertical_sectors = $NewMapWindow/PanelContainer/MarginContainer2/GridContainer/SpinBox2

func _ready():
	
	pass


func _on_create_button_pressed():
	CurrentMapData.horizontal_sectors = horizontal_sectors.value
	CurrentMapData.vertical_sectors = vertical_sectors.value
	new_map_window.hide()
	map_created.emit()

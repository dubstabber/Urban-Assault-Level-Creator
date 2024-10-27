extends TabBar


func _ready() -> void:
	CurrentMapData.selected.connect(_update_properties)


func _update_properties() -> void:
	if CurrentMapData.border_selected_sector_idx >= 0:
		%NoSectorLabel.hide()
		
	else:
		%NoSectorLabel.show()
	

extends ConfirmationDialog


func  _ready() -> void:
	confirmed.connect(func():
		if CurrentMapData.horizontal_sectors == 0 or CurrentMapData.vertical_sectors == 0:
			return
		if CurrentMapData.map_path.is_empty():
			%SaveLevelFileDialog.popup()
			await %SaveLevelFileDialog.visibility_changed
			close_requested.emit()
		else:
			SingleplayerSaver.save()
	)
	canceled.connect(func(): 
		hide()
		close_requested.emit()
	)
	

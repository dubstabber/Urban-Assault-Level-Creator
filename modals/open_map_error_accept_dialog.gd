extends AcceptDialog


func _ready() -> void:
	EventSystem.open_map_failed.connect(func():
		dialog_text = "Error: Map from file '%s' could not be loaded" % CurrentMapData.map_path
		popup()
		CurrentMapData.close_map()
		EventSystem.map_updated.emit()
		get_tree().root.size_changed.emit()
		CurrentMapData.is_saved = true
		)

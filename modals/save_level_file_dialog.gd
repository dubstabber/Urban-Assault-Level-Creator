extends FileDialog


func _ready() -> void:
	file_selected.connect(func(path: String):
		CurrentMapData.map_path = path
		SingleplayerSaver.save()
		)

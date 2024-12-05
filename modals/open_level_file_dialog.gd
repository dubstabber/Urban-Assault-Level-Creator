extends FileDialog


func _ready() -> void:
	file_selected.connect(func(path: String):
		CurrentMapData.close_map()
		CurrentMapData.map_path = path
		SingleplayerOpener.load_level()
		)

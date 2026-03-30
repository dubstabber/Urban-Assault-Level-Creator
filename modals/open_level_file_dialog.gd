extends FileDialog


func _ready() -> void:
	file_selected.connect(func(path: String):
		hide()
		MapLoadService.request_open_map(path)
		)

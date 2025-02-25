extends AcceptDialog


func _ready() -> void:
	EventSystem.load_enemy_settings_failed.connect(func(path: String):
		dialog_text = "File '%s' could not be loaded" % path
		popup()
		)
	EventSystem.save_enemy_settings_failed.connect(func(path: String):
		dialog_text = "File '%s' could not be saved" % path
		popup()
		)

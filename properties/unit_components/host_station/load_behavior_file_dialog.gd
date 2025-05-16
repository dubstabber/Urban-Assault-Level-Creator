extends FileDialog


@onready var load_behavior_file_dialog: FileDialog = %LoadBehaviorFileDialog

func _ready() -> void:
	EventSystem.load_hs_behavior_dialog_requested.connect(popup)
	load_behavior_file_dialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			printerr("File '%s' could not be loaded" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return
		var behavior_json = file.get_line()
		var behavior_data = JSON.parse_string(behavior_json)
		if behavior_data and typeof(behavior_data) == TYPE_DICTIONARY:
			EventSystem.behavior_loaded.emit(behavior_data)
)

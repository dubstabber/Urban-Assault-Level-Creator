extends FileDialog

const _UALegacyText = preload("res://map/ua_legacy_text.gd")

@onready var load_behavior_file_dialog: FileDialog = %LoadBehaviorFileDialog

func _ready() -> void:
	EventSystem.load_hs_behavior_dialog_requested.connect(popup)
	load_behavior_file_dialog.file_selected.connect(func(path: String):
		var behavior_json := _UALegacyText.read_file(path)
		if behavior_json.is_empty():
			printerr("File '%s' could not be loaded" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return

		var trimmed := behavior_json.strip_edges()
		if not trimmed.begins_with("{") and not trimmed.begins_with("["):
			printerr("File '%s' does not appear to be valid JSON" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return

		var behavior_data = JSON.parse_string(behavior_json)
		if behavior_data == null:
			printerr("Invalid JSON syntax in file '%s'" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return
		if typeof(behavior_data) != TYPE_DICTIONARY:
			printerr("JSON in file '%s' is not a dictionary/object" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return
		EventSystem.behavior_loaded.emit(behavior_data)
	)

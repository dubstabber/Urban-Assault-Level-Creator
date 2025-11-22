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
		
		# Quick validation: check if file starts with JSON-like content
		# to avoid reading entire large binary files
		if not _is_likely_json_file(file):
			printerr("File '%s' does not appear to be valid JSON" % path)
			EventSystem.load_enemy_settings_failed.emit(path)
			return
		
		file.seek(0)
		var behavior_json = file.get_as_text()
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

func _is_likely_json_file(file: FileAccess) -> bool:
	# Read first 512 bytes to check if file looks like JSON
	# This avoids reading entire large binary files
	var max_check_size := 512
	var file_size = file.get_length()
	var check_size = mini(max_check_size, file_size)
	
	if check_size == 0:
		return false
	
	var buffer = file.get_buffer(check_size)
	var text = buffer.get_string_from_utf8()
	
	# JSON should start with { or [ after stripping whitespace
	var trimmed = text.strip_edges()
	return trimmed.begins_with("{") or trimmed.begins_with("[")

extends AcceptDialog


func _ready() -> void:
	EventSystem.editor_fatal_error_occured.connect(func(error_type: String):
		dialog_text = 'There was an error opening the editor:\n'
		match error_type:
			"invalid_json": dialog_text += 'data.json is not a valid file'
			"no_hoststations": dialog_text += 'there is no hoststations entry in the data.json for "%s" data set' % EditorState.game_data_type
			_: dialog_text += 'unknown fatal error'
		
		popup()
		await visibility_changed
		get_tree().quit()
		)

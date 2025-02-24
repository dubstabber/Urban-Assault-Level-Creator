extends AcceptDialog


func _ready() -> void:
	EventSystem.editor_fatal_error_occured.connect(func(error_type: String):
		match error_type:
			"invalid_json": dialog_text = "There was an error opening the editor:
data.json is not a valid file"
		popup()
		await confirmed
		get_tree().quit()
		)

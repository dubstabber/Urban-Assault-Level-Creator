extends HBoxContainer


func _ready() -> void:
	EventSystem.editor_mode_changed.connect(_change_state_labels)
	_change_state_labels()


func _change_state_labels() -> void:
	match EditorState.mode:
		EditorState.States.Select:
			%EditorModeLabel.text = "Mode: %s" % "Select"
		EditorState.States.TypMapDesign:
			%EditorModeLabel.text = "Mode: %s" % "Building design"

extends TextureButton


func _ready() -> void:
	pressed.connect(func():
		$"../../..".hide()
		EditorState.mode = EditorState.States.Select
	)

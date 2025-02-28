extends HBoxContainer

@export var warning_icon: CompressedTexture2D
@export var no_warning_icon: CompressedTexture2D
@onready var logs_button: Button = %LogsButton


func _ready() -> void:
	EventSystem.warning_logs_updated.connect(func():
		logs_button.text = "0" if EditorState.warning_messages.is_empty() and EditorState.error_messages.is_empty() else str(EditorState.warning_messages.size() + EditorState.error_messages.size())
		logs_button.icon = no_warning_icon if EditorState.warning_messages.is_empty() and EditorState.error_messages.is_empty() else warning_icon
		)
	logs_button.pressed.connect(func(): 
		EventSystem.warning_logs_window_requested.emit()
		)

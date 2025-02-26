extends Window

@export var warning_icon: CompressedTexture2D
@onready var logs_list: ItemList = %LogsList


func _ready() -> void:
	EventSystem.warning_logs_window_requested.connect(display_messages)
	logs_list.clear()


func display_messages() -> void:
	for message in EditorState.warning_messages:
		logs_list.add_item(message, warning_icon)
	popup()


func close() -> void:
	logs_list.clear()
	hide()


func _on_refresh_button_pressed() -> void:
	EditorState.refresh_warnings()
	logs_list.clear()
	display_messages()


func _on_clear_button_pressed() -> void:
	EditorState.warning_messages.clear()
	logs_list.clear()
	EventSystem.warning_logs_updated.emit()

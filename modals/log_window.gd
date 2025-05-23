extends Window

@export var warning_icon: CompressedTexture2D

@onready var logs_list: ItemList = %LogsList


func _ready() -> void:
	EventSystem.warning_logs_window_requested.connect(display_messages)
	logs_list.clear()


func _on_refresh_button_pressed() -> void:
	EventSystem.warning_logs_updated.emit(true)
	logs_list.clear()
	display_messages()
	

func _on_clear_button_pressed() -> void:
	EditorState.error_messages.clear()
	EditorState.warning_messages.clear()
	logs_list.clear()
	EventSystem.warning_logs_updated.emit(false)


func _on_copy_text_button_pressed() -> void:
	var item = logs_list.get_selected_items()
	if item:
		var item_text = logs_list.get_item_text(item[0])
		DisplayServer.clipboard_set(item_text)


func display_messages() -> void:
	for message in EditorState.error_messages:
		logs_list.add_item(message, Preloads.error_icon)
	
	for message in EditorState.warning_messages:
		logs_list.add_item(message, warning_icon)
	popup()


func close() -> void:
	logs_list.clear()
	hide()
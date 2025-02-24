extends Window

@onready var logs_container: VBoxContainer = %LogsContainer


func _ready() -> void:
	EventSystem.warning_logs_window_requested.connect(display_messages)


func display_messages() -> void:
	for message in EditorState.warning_messages:
		var new_label = Label.new()
		new_label.text = message
		new_label["theme_override_colors/font_color"] = "b67b00"
		new_label["theme_override_font_sizes/font_size"] = 14
		logs_container.add_child(new_label)
	popup()


func close() -> void:
	for child in logs_container.get_children():
		logs_container.remove_child(child)
		child.queue_free()
	hide()

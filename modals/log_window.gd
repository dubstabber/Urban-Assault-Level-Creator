extends Window


func _ready() -> void:
	EventSystem.warning_logs_window_requested.connect(popup)


func close() -> void:
	hide()

extends Window

@onready var level_description_text_edit = %LevelDescriptionTextEdit


func _ready() -> void:
	level_description_text_edit.text_changed.connect(func():
		CurrentMapData.level_description = level_description_text_edit.text
		CurrentMapData.is_saved = false
		)


func _on_about_to_popup() -> void:
	level_description_text_edit.text = CurrentMapData.level_description


func close() -> void:
	hide()

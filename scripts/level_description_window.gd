extends Window


func _ready() -> void:
	%LevelDescriptionTextEdit.text_changed.connect(func():
		CurrentMapData.level_description = %LevelDescriptionTextEdit.text
		)


func _on_about_to_popup() -> void:
	%LevelDescriptionTextEdit.text = CurrentMapData.level_description


func close() -> void:
	hide()

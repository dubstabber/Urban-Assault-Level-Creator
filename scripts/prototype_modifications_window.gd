extends Window


func _ready() -> void:
	%PrototypeModificationsTextEdit.text_changed.connect(func():
		CurrentMapData.prototype_modifications = %PrototypeModificationsTextEdit.text
		)


func _on_about_to_popup() -> void:
	%PrototypeModificationsTextEdit.text = CurrentMapData.prototype_modifications


func close() -> void:
	hide()


func _on_original_reset_button_pressed() -> void:
	%PrototypeModificationsTextEdit.text = "include data:scripts/startup2.scr"
	CurrentMapData.prototype_modifications = %PrototypeModificationsTextEdit.text


func _on_md_ghorkov_reset_button_pressed() -> void:
	%PrototypeModificationsTextEdit.text = "include script:startupG.scr"
	CurrentMapData.prototype_modifications = %PrototypeModificationsTextEdit.text


func _on_md_taerkasten_teset_button_pressed() -> void:
	%PrototypeModificationsTextEdit.text = "include script:startupT.scr"
	CurrentMapData.prototype_modifications = %PrototypeModificationsTextEdit.text

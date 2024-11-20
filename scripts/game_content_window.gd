extends Window


@export var button_group: ButtonGroup


func _on_about_to_popup() -> void:
	for child in %ContentContainer.get_children():
		child.queue_free()
	
	for game_mode in Preloads.ua_data.data.keys():
		var check_box = CheckBox.new()
		check_box.text = game_mode
		check_box.button_group = button_group
		check_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		check_box["theme_override_font_sizes/font_size"] = 12
		%ContentContainer.add_child(check_box)
		if CurrentMapData.game_data_type == game_mode:
			check_box.button_pressed = true


func close() -> void:
	hide()


func _on_save_button_pressed() -> void:
	CurrentMapData.game_data_type = button_group.get_pressed_button().text
	hide()

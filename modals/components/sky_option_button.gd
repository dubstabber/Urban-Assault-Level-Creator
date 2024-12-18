extends OptionButton


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			select((get_selected_id() - 1 + get_item_count()) % get_item_count())
			var sky_text = %SkyOptionButton.get_item_text(get_selected_id())
			%SkyTexture.texture = Preloads.skies[sky_text]
		elif event.keycode == KEY_DOWN:
			select((get_selected_id() + 1) % get_item_count())
			var sky_text = %SkyOptionButton.get_item_text(get_selected_id())
			%SkyTexture.texture = Preloads.skies[sky_text]

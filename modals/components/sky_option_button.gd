extends OptionButton

@onready var sky_texture: TextureRect = %SkyTexture


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP:
			select((get_selected_id() - 1 + get_item_count()) % get_item_count())
			var sky_text = get_item_text(get_selected_id())
			sky_texture.texture = Preloads.skies[sky_text]
		elif event.keycode == KEY_DOWN:
			select((get_selected_id() + 1) % get_item_count())
			var sky_text = get_item_text(get_selected_id())
			sky_texture.texture = Preloads.skies[sky_text]

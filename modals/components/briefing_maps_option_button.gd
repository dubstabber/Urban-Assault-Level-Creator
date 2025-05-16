extends OptionButton

@onready var briefing_map_texture: TextureRect = %BriefingMapTexture


func _gui_input(event: InputEvent) -> void:
	if has_focus():
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_UP:
				select((get_selected_id() - 1 + get_item_count()) % get_item_count())
				var item_text = get_item_text(get_selected_id())
				CurrentMapData.briefing_map = item_text
				var mb_map_name = item_text.replace(".%s"%item_text.get_extension(), "")
				briefing_map_texture.texture = Preloads.mbmaps[mb_map_name]
				CurrentMapData.is_saved = false
			elif event.keycode == KEY_DOWN:
				select((get_selected_id() + 1) % get_item_count())
				var item_text = get_item_text(get_selected_id())
				CurrentMapData.briefing_map = item_text
				var mb_map_name = item_text.replace(".%s"%item_text.get_extension(), "")
				briefing_map_texture.texture = Preloads.mbmaps[mb_map_name]
				CurrentMapData.is_saved = false

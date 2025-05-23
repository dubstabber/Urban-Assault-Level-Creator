extends Window

signal debriefing_map_selected(full_map_name: String)

@onready var debriefing_map_grid: GridContainer = %DebriefingMapGrid


func _on_about_to_popup() -> void:
	for child in debriefing_map_grid.get_children():
		child.queue_free()
		debriefing_map_grid.remove_child(child)
	
	setup_map_buttons(Preloads.ua_data.data[EditorState.game_data_type].missionDebriefingMaps)
	setup_map_buttons(Preloads.ua_data.data[EditorState.game_data_type].missionBriefingMaps)


func setup_map_buttons(full_map_names: Array) -> void:
	for full_map_name in full_map_names:
		var map_button = Button.new()
		var map_name = full_map_name.replace(".%s" %full_map_name.get_extension(), "")
		map_button.icon = Preloads.mbmaps[map_name]
		map_button.custom_minimum_size = Vector2(350, 350)
		map_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_button.expand_icon = true
		map_button.tooltip_text = full_map_name
		map_button.set_meta("full_map_name", full_map_name)
		map_button.pressed.connect(func():
			debriefing_map_selected.emit(map_button.get_meta("full_map_name"))
			hide()
			)
		debriefing_map_grid.add_child(map_button)


func close() -> void:
	hide()

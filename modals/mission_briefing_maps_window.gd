extends Window

@onready var briefing_map_picker_window: Window = %BriefingMapPickerWindow
@onready var debriefing_map_picker_window: Window = %DebriefingMapPickerWindow


func _on_about_to_popup() -> void:
	refresh()


func refresh() -> void:
	%BriefingMapsOptionButton.clear()
	for mb_map in Preloads.ua_data.data[EditorState.game_data_type].missionBriefingMaps:
		%BriefingMapsOptionButton.add_item(mb_map)
	for mb_map in Preloads.ua_data.data[EditorState.game_data_type].missionDebriefingMaps:
		%BriefingMapsOptionButton.add_item(mb_map)
	var mb_index = get_option_index_by_text(%BriefingMapsOptionButton, CurrentMapData.briefing_map)
	%BriefingMapsOptionButton.selected = mb_index
	var mb_map_name := CurrentMapData.briefing_map.replace(".%s" % CurrentMapData.briefing_map.get_extension(), "")
	%BriefingMapTexture.texture = Preloads.mbmaps[mb_map_name]
	%MBsizeXSpinBox.value = CurrentMapData.briefing_size_x
	%MBsizeYSpinBox.value = CurrentMapData.briefing_size_y
	
	%DebriefingMapsOptionButton.clear()
	for db_map in Preloads.ua_data.data[EditorState.game_data_type].missionDebriefingMaps:
		%DebriefingMapsOptionButton.add_item(db_map)
	for db_map in Preloads.ua_data.data[EditorState.game_data_type].missionBriefingMaps:
		%DebriefingMapsOptionButton.add_item(db_map)
	var db_index = get_option_index_by_text(%DebriefingMapsOptionButton, CurrentMapData.debriefing_map)
	%DebriefingMapsOptionButton.selected = db_index
	var db_map_name := CurrentMapData.debriefing_map.replace(".%s" %CurrentMapData.debriefing_map.get_extension(), "")
	%DebriefingMapTexture.texture = Preloads.mbmaps[db_map_name]
	%DBsizeXSpinBox.value = CurrentMapData.debriefing_size_x
	%DBsizeYSpinBox.value = CurrentMapData.debriefing_size_y


func get_option_index_by_text(option_button: OptionButton, text: String) -> int:
	for i in range(option_button.item_count):
		if option_button.get_item_text(i) == text:
			return i
	return -1


func _on_briefing_maps_option_button_item_selected(index: int) -> void:
	var item_text = %BriefingMapsOptionButton.get_item_text(index)
	if CurrentMapData.briefing_map != item_text: CurrentMapData.is_saved = false
	CurrentMapData.briefing_map = item_text
	var mb_map_name = item_text.replace(".%s" %item_text.get_extension(), "")
	%BriefingMapTexture.texture = Preloads.mbmaps[mb_map_name]


func _on_debriefing_maps_option_button_item_selected(index: int) -> void:
	var item_text = %DebriefingMapsOptionButton.get_item_text(index)
	if CurrentMapData.debriefing_map != item_text: CurrentMapData.is_saved = false
	CurrentMapData.debriefing_map = item_text
	var db_map_name = item_text.replace(".%s" %item_text.get_extension(), "")
	%DebriefingMapTexture.texture = Preloads.mbmaps[db_map_name]
	CurrentMapData.is_saved = false


func close() -> void:
	hide()


func _on_m_bsize_x_spin_box_value_changed(value: float) -> void:
	if CurrentMapData.briefing_size_x != int(value):
		CurrentMapData.is_saved = false
	CurrentMapData.briefing_size_x = int(value)


func _on_m_bsize_y_spin_box_value_changed(value: float) -> void:
	if CurrentMapData.briefing_size_y != int(value):
		CurrentMapData.is_saved = false
	CurrentMapData.briefing_size_y = int(value)


func _on_d_bsize_x_spin_box_value_changed(value: float) -> void:
	if CurrentMapData.debriefing_size_x != int(value):
		CurrentMapData.is_saved = false
	CurrentMapData.debriefing_size_x = int(value)


func _on_d_bsize_y_spin_box_value_changed(value: float) -> void:
	if CurrentMapData.debriefing_size_y != int(value):
		CurrentMapData.is_saved = false
	CurrentMapData.debriefing_size_y = int(value)


func _on_briefing_map_picker_button_pressed() -> void:
	briefing_map_picker_window.popup()


func _on_debriefing_map_picker_button_pressed() -> void:
	debriefing_map_picker_window.popup()


func _on_briefing_map_picker_window_briefing_map_selected(full_map_name: String) -> void:
	var index = get_option_index_by_text(%BriefingMapsOptionButton, full_map_name)
	%BriefingMapsOptionButton.select(index)
	_on_briefing_maps_option_button_item_selected(index)


func _on_debriefing_map_picker_window_debriefing_map_selected(full_map_name: String) -> void:
	var index = get_option_index_by_text(%DebriefingMapsOptionButton, full_map_name)
	%DebriefingMapsOptionButton.select(index)
	_on_debriefing_maps_option_button_item_selected(index)

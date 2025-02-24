extends VBoxContainer


func _ready() -> void:
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	EventSystem.unit_selected.connect(_update_properties)
	
	%QuantitySpinBox.value_changed.connect(func(value: float):
		if EditorState.selected_unit is Squad:
			if EditorState.selected_unit.quantity != value: CurrentMapData.is_saved = false
			EditorState.selected_unit.quantity = value
	)
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations.keys():
		%FactionOptionButton.add_item(hs, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
	%FactionOptionButton.item_selected.connect(func(index: int):
		EditorState.selected_unit.change_faction(%FactionOptionButton.get_item_id(index))
		CurrentMapData.is_saved = false
	)
	%XposSquadLineEdit.text_submitted.connect(func(text_value: String):
		var pos_x = clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors+1) * 1200)-5)
		if EditorState.selected_unit.position.x != pos_x: 
			CurrentMapData.is_saved = false
			%XposSquadLineEdit.text = str(pos_x)
		EditorState.selected_unit.position.x = pos_x
	)
	%ZposSquadLineEdit.text_submitted.connect(func(text_value: String):
		var pos_z = clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors+1) * 1200)-5)
		if EditorState.selected_unit.position.y != pos_z: 
			CurrentMapData.is_saved = false
			%ZposSquadLineEdit.text = "-%s" % str(pos_z)
		EditorState.selected_unit.position.y = pos_z
	)
	%UseableCheckBox.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.useable != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.useable = toggled
	)
	%MBstatusSquadCheckBox.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.mb_status = toggled
	)


func _update_properties() -> void:
	if EditorState.selected_unit is Squad:
		if Preloads.squad_images.has(str(EditorState.selected_unit.vehicle)):
			%SquadIcon.texture = Preloads.squad_images[str(EditorState.selected_unit.vehicle)]
			%SquadNameLabel.text = EditorState.selected_unit.unit_name
		else:
			%SquadIcon.texture = null
			%SquadNameLabel.text = "Unknown unit"
		
		%QuantitySpinBox.value = EditorState.selected_unit.quantity
		%FactionOptionButton.select(%FactionOptionButton.get_item_index(EditorState.selected_unit.owner_id))
		
		%XposSquadLineEdit.text = str(round(EditorState.selected_unit.position.x))
		%ZposSquadLineEdit.text = str(round(-EditorState.selected_unit.position.y))
		if not EditorState.selected_unit.position_changed.is_connected(_update_coordinates):
			EditorState.selected_unit.position_changed.connect(_update_coordinates)
		
		%UseableCheckBox.button_pressed = EditorState.selected_unit.useable
		%MBstatusSquadCheckBox.button_pressed = EditorState.selected_unit.mb_status
		
		show()


func _update_coordinates():
	if EditorState.selected_unit is Squad:
		%XposSquadLineEdit.text = str(round(EditorState.selected_unit.position.x))
		%ZposSquadLineEdit.text = str(round(-EditorState.selected_unit.position.y))

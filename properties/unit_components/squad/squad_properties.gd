extends VBoxContainer


func _ready() -> void:
	EventSystem.unit_selected.connect(_update_properties)
	
	%QuantitySpinBox.value_changed.connect(func(value: float):
		if CurrentMapData.selected_unit is Squad:
			if CurrentMapData.selected_unit.quantity != value: CurrentMapData.is_saved = false
			CurrentMapData.selected_unit.quantity = value
	)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations.keys():
		%FactionOptionButton.add_item(hs, Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)
	%FactionOptionButton.item_selected.connect(func(index: int):
		CurrentMapData.selected_unit.change_faction(%FactionOptionButton.get_item_id(index))
		CurrentMapData.is_saved = false
	)
	%XposSquadLineEdit.text_submitted.connect(func(text_value: String):
		var pos_x = clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors+1) * 1200)-5)
		if CurrentMapData.selected_unit.position.x != pos_x: 
			CurrentMapData.is_saved = false
			%XposSquadLineEdit.text = str(pos_x)
		CurrentMapData.selected_unit.position.x = pos_x
	)
	%ZposSquadLineEdit.text_submitted.connect(func(text_value: String):
		var pos_z = clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors+1) * 1200)-5)
		if CurrentMapData.selected_unit.position.y != pos_z: 
			CurrentMapData.is_saved = false
			%ZposSquadLineEdit.text = "-%s" % str(pos_z)
		CurrentMapData.selected_unit.position.y = pos_z
	)
	%UseableCheckBox.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.useable != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.useable = toggled
	)
	%MBstatusSquadCheckBox.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.mb_status = toggled
	)


func _update_properties() -> void:
	if CurrentMapData.selected_unit is Squad:
		if Preloads.squad_images.has(str(CurrentMapData.selected_unit.vehicle)):
			%SquadIcon.texture = Preloads.squad_images[str(CurrentMapData.selected_unit.vehicle)]
			%SquadNameLabel.text = CurrentMapData.selected_unit.unit_name
		else:
			%SquadIcon.texture = null
			%SquadNameLabel.text = "Unknown unit"
		
		%QuantitySpinBox.value = CurrentMapData.selected_unit.quantity
		%FactionOptionButton.select(%FactionOptionButton.get_item_index(CurrentMapData.selected_unit.owner_id))
		
		%XposSquadLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%ZposSquadLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))
		if not CurrentMapData.selected_unit.position_changed.is_connected(_update_coordinates):
			CurrentMapData.selected_unit.position_changed.connect(_update_coordinates)
		
		%UseableCheckBox.button_pressed = CurrentMapData.selected_unit.useable
		%MBstatusSquadCheckBox.button_pressed = CurrentMapData.selected_unit.mb_status
		
		show()


func _update_coordinates():
	if CurrentMapData.selected_unit is Squad:
		%XposSquadLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%ZposSquadLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))

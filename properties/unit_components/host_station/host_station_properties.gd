extends VBoxContainer


func _ready() -> void:
	EventSystem.unit_selected.connect(_update_properties)
	%EnergyLineEdit.text_changed.connect(func(new_value: String):
		var validated_value = int(new_value)
		if validated_value == 0: validated_value = 1
		if EditorState.selected_unit.energy != abs(validated_value * 400): CurrentMapData.is_saved = false
		EditorState.selected_unit.energy = abs(validated_value * 400)
	)
	%ViewAngleLineEdit.text_changed.connect(func(new_value: String):
		if EditorState.selected_unit.view_angle != abs(int(new_value)):
			CurrentMapData.is_saved = false
			EditorState.selected_unit.view_angle = abs(int(new_value))
	)
	%ViewAngleCheckButton.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.view_angle_enabled != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.view_angle_enabled = toggled
		%ViewAngleLineEdit.editable = toggled
	)
	%ReloadConstLineEdit.text_changed.connect(func(new_value: String):
		if CurrentMapData.player_host_station == EditorState.selected_unit:
			var converted_value = abs(int(ceil(float(new_value) * (60000.0 / 255.0))))
			if EditorState.selected_unit.reload_const != converted_value:
				CurrentMapData.is_saved = false
				EditorState.selected_unit.reload_const = converted_value
		else:
			var converted_value = abs(int(ceil(float(new_value) * (70000.0 / 255.0))))
			if EditorState.selected_unit.reload_const != converted_value:
				CurrentMapData.is_saved = false
				EditorState.selected_unit.reload_const = converted_value
	)
	%ReloadConstCheckButton.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.reload_const_enabled != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.reload_const_enabled = toggled
		%ReloadConstLineEdit.editable = toggled
	)
	%XposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_x := clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.x != pos_x:
			CurrentMapData.is_saved = false
			%XposHostStationLineEdit.text = str(pos_x)
			print(pos_x)
		EditorState.selected_unit.position.x = pos_x
		)
	%YposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_y := int(text_value) if int(text_value) <= 0 else -int(text_value)
		if EditorState.selected_unit.pos_y != pos_y:
			CurrentMapData.is_saved = false
			%YposHostStationLineEdit.text = str(pos_y)
		EditorState.selected_unit.pos_y = pos_y
		)
	%ZposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_z := clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.y != pos_z:
			CurrentMapData.is_saved = false
			%ZposHostStationLineEdit.text = "-%s" % str(pos_z)
		EditorState.selected_unit.position.y = pos_z
		)
	%ConqueringHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.con_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.con_budget = value_changed
		%ConqueringValueLabel.text = str(value_changed)
	)
	%ConqueringDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.con_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.con_delay = converted_value
	)
	%DefenseHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.def_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.def_budget = value_changed
		%DefenseValueLabel.text = str(value_changed)
	)
	%DefenseDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.def_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.def_delay = converted_value
	)
	%ReconnaissanceHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rec_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rec_budget = value_changed
		%ReconnaissanceValueLabel.text = str(value_changed)
	)
	%ReconnaissanceDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.rec_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rec_delay = converted_value
	)
	%AttackingHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rob_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rob_budget = value_changed
		%AttackingValueLabel.text = str(value_changed)
	)
	%AttackingDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.rob_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rob_delay = converted_value
	)
	%PowerBuildingHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.pow_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_budget = value_changed
		%PowerBuildingValueLabel.text = str(value_changed)
	)
	%PowerBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.pow_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_delay = converted_value
	)
	%RadarBuildingHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rad_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rad_budget = value_changed
		%RadarBuildingValueLabel.text = str(value_changed)
	)
	%RadarBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.rad_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rad_delay = converted_value
	)
	%FlakBuildingHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.saf_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.saf_budget = value_changed
		%FlakBuildingValueLabel.text = str(value_changed)
	)
	%FlakBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.saf_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.saf_delay = converted_value
	)
	%MovingStationHSlider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.cpl_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.cpl_budget = value_changed
		%MovingStationValueLabel.text = str(value_changed)
	)
	%MovingStationDelayLineEdit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1000
		if EditorState.selected_unit.cpl_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.cpl_delay = converted_value
	)
	%MBstatusHostStationCheckBox.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.mb_status != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.mb_status = toggled
	)
	for hs_robo in Preloads.hs_robo_images:
		%HostStationRoboOptionButton.add_item(Preloads.hs_robo_images[hs_robo].name, hs_robo)
	%HostStationRoboOptionButton.item_selected.connect(func(index: int):
		EditorState.selected_unit.vehicle = %HostStationRoboOptionButton.get_item_id(index)
		%HostStationRoboTextureRect.texture = Preloads.hs_robo_images[%HostStationRoboOptionButton.get_item_id(index)].image
		CurrentMapData.is_saved = false
	)
	%LoadBehaviorFileButton.pressed.connect(func():
		EventSystem.load_hs_behavior_dialog_requested.emit()
	)
	%SaveBehaviorFileButton.pressed.connect(func():
		EventSystem.save_hs_behavior_dialog_requested.emit()
	)
	
	EventSystem.behavior_loaded.connect(func(behavior_data: Dictionary):
		if behavior_data.has("con_budget"):
			EditorState.selected_unit.con_budget = behavior_data.con_budget
			%ConqueringHSlider.value = int(behavior_data.con_budget)
		if behavior_data.has("con_delay"):
			EditorState.selected_unit.con_delay = behavior_data.con_delay
			%ConqueringDelayLineEdit.text = str(behavior_data.con_delay)
		if behavior_data.has("def_budget"):
			EditorState.selected_unit.def_budget = behavior_data.def_budget
			%DefenseHSlider.value = int(behavior_data.def_budget)
		if behavior_data.has("def_delay"):
			EditorState.selected_unit.def_delay = behavior_data.def_delay
			%DefenseDelayLineEdit.text = str(behavior_data.def_delay)
		if behavior_data.has("rec_budget"):
			EditorState.selected_unit.rec_budget = behavior_data.rec_budget
			%ReconnaissanceHSlider.value = int(behavior_data.rec_budget)
		if behavior_data.has("rec_delay"):
			EditorState.selected_unit.rec_delay = behavior_data.rec_delay
			%ReconnaissanceDelayLineEdit.text = str(behavior_data.rec_delay)
		if behavior_data.has("rob_budget"):
			EditorState.selected_unit.rob_budget = behavior_data.rob_budget
			%AttackingHSlider.value = int(behavior_data.rob_budget)
		if behavior_data.has("rob_delay"):
			EditorState.selected_unit.rob_delay = behavior_data.rob_delay
			%AttackingDelayLineEdit.text = str(behavior_data.rob_delay)
		if behavior_data.has("pow_budget"):
			EditorState.selected_unit.pow_budget = behavior_data.pow_budget
			%PowerBuildingHSlider.value = int(behavior_data.pow_budget)
		if behavior_data.has("pow_delay"):
			EditorState.selected_unit.pow_delay = behavior_data.pow_delay
			%PowerBuildingDelayLineEdit.text = str(behavior_data.pow_delay)
		if behavior_data.has("rad_budget"):
			EditorState.selected_unit.rad_budget = behavior_data.rad_budget
			%RadarBuildingHSlider.value = int(behavior_data.rad_budget)
		if behavior_data.has("rad_delay"):
			EditorState.selected_unit.rad_delay = behavior_data.rad_delay
			%RadarBuildingDelayLineEdit.text = str(behavior_data.rad_delay)
		if behavior_data.has("saf_budget"):
			EditorState.selected_unit.saf_budget = behavior_data.saf_budget
			%FlakBuildingHSlider.value = int(behavior_data.saf_budget)
		if behavior_data.has("saf_delay"):
			EditorState.selected_unit.saf_delay = behavior_data.saf_delay
			%FlakBuildingDelayLineEdit.text = str(behavior_data.saf_delay)
		if behavior_data.has("cpl_budget"):
			EditorState.selected_unit.cpl_budget = behavior_data.cpl_budget
			%MovingStationHSlider.value = int(behavior_data.cpl_budget)
		if behavior_data.has("cpl_delay"):
			EditorState.selected_unit.cpl_delay = behavior_data.cpl_delay
			%MovingStationDelayLineEdit.text = str(behavior_data.cpl_delay)
		CurrentMapData.is_saved = false
	)


func _update_properties() -> void:
	if EditorState.selected_unit is HostStation:
		var i = 1
		for hs in CurrentMapData.host_stations.get_children():
			if EditorState.selected_unit == hs: break
			else: i += 1
		
		%HSnumberLabel.text = "Host station " + str(i) + ": "
		%HSnameLabel.text = EditorState.selected_unit.unit_name
		if EditorState.selected_unit.owner_id < 1 or EditorState.selected_unit.owner_id > 7:
			%OwnerErrorLabel.show()
		else: %OwnerErrorLabel.hide()
		
		%EnergyLineEdit.text = str(EditorState.selected_unit.energy / 400)
		
		%ViewAngleLineEdit.text = str(EditorState.selected_unit.view_angle)
		%ViewAngleCheckButton.button_pressed = EditorState.selected_unit.view_angle_enabled
		%ViewAngleLineEdit.editable = %ViewAngleCheckButton.button_pressed
		
		if CurrentMapData.player_host_station == EditorState.selected_unit:
			%ReloadConstLineEdit.text = str(int(float(EditorState.selected_unit.reload_const) / (60000.0 / 255.0)))
		else:
			%ReloadConstLineEdit.text = str(int(float(EditorState.selected_unit.reload_const) / (70000.0 / 255.0)))
		%ReloadConstCheckButton.button_pressed = EditorState.selected_unit.reload_const_enabled
		%ReloadConstLineEdit.editable = %ReloadConstCheckButton.button_pressed
		
		%XposHostStationLineEdit.text = str(roundi(EditorState.selected_unit.position.x))
		%YposHostStationLineEdit.text = str(EditorState.selected_unit.pos_y)
		%ZposHostStationLineEdit.text = str(roundi(-EditorState.selected_unit.position.y))
		if not EditorState.selected_unit.position_changed.is_connected(_update_coordinates):
			EditorState.selected_unit.position_changed.connect(_update_coordinates)
		
		%ConqueringHSlider.value = EditorState.selected_unit.con_budget
		%ConqueringValueLabel.text = str(EditorState.selected_unit.con_budget)
		%ConqueringDelayLineEdit.text = str(EditorState.selected_unit.con_delay / 1000)
		%DefenseHSlider.value = EditorState.selected_unit.def_budget
		%DefenseValueLabel.text = str(EditorState.selected_unit.def_budget)
		%DefenseDelayLineEdit.text = str(EditorState.selected_unit.def_delay / 1000)
		%ReconnaissanceHSlider.value = EditorState.selected_unit.rec_budget
		%ReconnaissanceValueLabel.text = str(EditorState.selected_unit.rec_budget)
		%ReconnaissanceDelayLineEdit.text = str(EditorState.selected_unit.rec_delay / 1000)
		%AttackingHSlider.value = EditorState.selected_unit.rob_budget
		%AttackingValueLabel.text = str(EditorState.selected_unit.rob_budget)
		%AttackingDelayLineEdit.text = str(EditorState.selected_unit.rob_delay / 1000)
		%PowerBuildingHSlider.value = EditorState.selected_unit.pow_budget
		%PowerBuildingValueLabel.text = str(EditorState.selected_unit.pow_budget)
		%PowerBuildingDelayLineEdit.text = str(EditorState.selected_unit.pow_delay / 1000)
		%RadarBuildingHSlider.value = EditorState.selected_unit.rad_budget
		%RadarBuildingValueLabel.text = str(EditorState.selected_unit.rad_budget)
		%RadarBuildingDelayLineEdit.text = str(EditorState.selected_unit.rad_delay / 1000)
		%FlakBuildingHSlider.value = EditorState.selected_unit.saf_budget
		%FlakBuildingValueLabel.text = str(EditorState.selected_unit.saf_budget)
		%FlakBuildingDelayLineEdit.text = str(EditorState.selected_unit.saf_delay / 1000)
		%MovingStationHSlider.value = EditorState.selected_unit.cpl_budget
		%MovingStationValueLabel.text = str(EditorState.selected_unit.cpl_budget)
		%MovingStationDelayLineEdit.text = str(EditorState.selected_unit.cpl_delay / 1000)
		
		%MBstatusHostStationCheckBox.button_pressed = EditorState.selected_unit.mb_status
		
		%HostStationRoboTextureRect.texture = Preloads.hs_robo_images[EditorState.selected_unit.vehicle].image
		%HostStationRoboOptionButton.select(%HostStationRoboOptionButton.get_item_index(EditorState.selected_unit.vehicle))
		
		show()


func _update_coordinates():
	if EditorState.selected_unit is HostStation:
		%XposHostStationLineEdit.text = str(roundi(EditorState.selected_unit.position.x))
		%ZposHostStationLineEdit.text = str(roundi(-EditorState.selected_unit.position.y))

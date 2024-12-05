extends VBoxContainer


func _ready() -> void:
	EventSystem.unit_selected.connect(_update_properties)
	%EnergyLineEdit.text_changed.connect(func(new_value: String):
		var validated_value = int(new_value)
		if validated_value == 0: validated_value = 1
		if CurrentMapData.selected_unit.energy != abs(validated_value * 400): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.energy = abs(validated_value * 400)
	)
	%ViewAngleLineEdit.text_changed.connect(func(new_value: String):
		if CurrentMapData.selected_unit.view_angle != abs(int(new_value)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.view_angle = abs(int(new_value))
		CurrentMapData.is_saved = false
	)
	%ViewAngleCheckButton.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.view_angle_enabled != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.view_angle_enabled = toggled
		%ViewAngleLineEdit.editable = toggled
	)
	%ReloadConstLineEdit.text_changed.connect(func(new_value: String):
		if CurrentMapData.player_host_station == CurrentMapData.selected_unit:
			var converted_value = abs(int(ceil(float(new_value) * (60000.0/255.0))))
			if CurrentMapData.selected_unit.reload_const != converted_value: CurrentMapData.is_saved = false
			CurrentMapData.selected_unit.reload_const = converted_value
		else:
			var converted_value = abs(int(ceil(float(new_value) * (70000.0/255.0))))
			if CurrentMapData.selected_unit.reload_const != converted_value: CurrentMapData.is_saved = false
			CurrentMapData.selected_unit.reload_const = converted_value
	)
	%ReloadConstCheckButton.toggled.connect(func(toggled:bool):
		if CurrentMapData.selected_unit.reload_const_enabled != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.reload_const_enabled = toggled
		%ReloadConstLineEdit.editable = toggled
	)
	%XposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_x = clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors+1) * 1200)-5)
		if CurrentMapData.selected_unit.position.x != pos_x: 
			CurrentMapData.is_saved = false
			%XposHostStationLineEdit.text = str(pos_x)
		CurrentMapData.selected_unit.position.x = pos_x
		)
	%YposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_y = int(text_value) if int(text_value) <= 0 else -int(text_value)
		if CurrentMapData.selected_unit.pos_y != pos_y: 
			CurrentMapData.is_saved = false
			%YposHostStationLineEdit.text = str(pos_y)
		CurrentMapData.selected_unit.pos_y = pos_y
		)
	%ZposHostStationLineEdit.text_submitted.connect(func(text_value: String):
		var pos_z = clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors+1) * 1200)-5)
		if CurrentMapData.selected_unit.position.y != pos_z: 
			CurrentMapData.is_saved = false
			%ZposHostStationLineEdit.text = "-%s" % str(pos_z)
		CurrentMapData.selected_unit.position.y = pos_z
		)
	%ConqueringHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.con_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.con_budget = value_changed
		%ConqueringValueLabel.text = str(value_changed)
	)
	%ConqueringDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.con_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.con_delay = abs(int(value_changed))
	)
	%DefenseHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.def_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.def_budget = value_changed
		%DefenseValueLabel.text = str(value_changed)
	)
	%DefenseDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.def_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.def_delay = abs(int(value_changed))
	)
	%ReconnaissanceHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.rec_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rec_budget = value_changed
		%ReconnaissanceValueLabel.text = str(value_changed)
	)
	%ReconnaissanceDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.rec_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rec_delay = abs(int(value_changed))
	)
	%AttackingHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.rob_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rob_budget = value_changed
		%AttackingValueLabel.text = str(value_changed)
	)
	%AttackingDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.rob_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rob_delay = abs(int(value_changed))
	)
	%PowerBuildingHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.pow_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.pow_budget = value_changed
		%PowerBuildingValueLabel.text = str(value_changed)
	)
	%PowerBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.pow_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.pow_delay = abs(int(value_changed))
	)
	%RadarBuildingHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.rad_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rad_budget = value_changed
		%RadarBuildingValueLabel.text = str(value_changed)
	)
	%RadarBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.rad_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.rad_delay = abs(int(value_changed))
	)
	%FlakBuildingHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.saf_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.saf_budget = value_changed
		%FlakBuildingValueLabel.text = str(value_changed)
	)
	%FlakBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.saf_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.saf_delay = abs(int(value_changed))
	)
	%MovingStationHSlider.value_changed.connect(func(value_changed: int):
		if CurrentMapData.selected_unit.cpl_budget != value_changed: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.cpl_budget = value_changed
		%MovingStationValueLabel.text = str(value_changed)
	)
	%MovingStationDelayLineEdit.text_changed.connect(func(value_changed: String):
		if CurrentMapData.selected_unit.cpl_delay != abs(int(value_changed)): CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.cpl_delay = abs(int(value_changed))
	)
	%MBstatusHostStationCheckBox.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.mb_status = toggled
	)
	for hs_robo in Preloads.hs_robo_images:
		%HostStationRoboOptionButton.add_item(Preloads.hs_robo_images[hs_robo].name,hs_robo)
	%HostStationRoboOptionButton.item_selected.connect(func(index: int):
		CurrentMapData.selected_unit.vehicle = %HostStationRoboOptionButton.get_item_id(index)
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
		CurrentMapData.selected_unit.con_budget = behavior_data.con_budget
		%ConqueringHSlider.value = int(behavior_data.con_budget)
		CurrentMapData.selected_unit.con_delay = behavior_data.con_delay
		%ConqueringDelayLineEdit.text = str(behavior_data.con_delay)
		CurrentMapData.selected_unit.def_budget = behavior_data.def_budget
		%DefenseHSlider.value = int(behavior_data.def_budget)
		CurrentMapData.selected_unit.def_delay = behavior_data.def_delay
		%DefenseDelayLineEdit.text = str(behavior_data.def_delay)
		CurrentMapData.selected_unit.rec_budget = behavior_data.rec_budget
		%ReconnaissanceHSlider.value = int(behavior_data.rec_budget)
		CurrentMapData.selected_unit.rec_delay = behavior_data.rec_delay
		%ReconnaissanceDelayLineEdit.text = str(behavior_data.rec_delay)
		CurrentMapData.selected_unit.rob_budget = behavior_data.rob_budget
		%AttackingHSlider.value = int(behavior_data.rob_budget)
		CurrentMapData.selected_unit.rob_delay = behavior_data.rob_delay
		%AttackingDelayLineEdit.text = str(behavior_data.rob_delay)
		CurrentMapData.selected_unit.pow_budget = behavior_data.pow_budget
		%PowerBuildingHSlider.value = int(behavior_data.pow_budget)
		CurrentMapData.selected_unit.pow_delay = behavior_data.pow_delay
		%PowerBuildingDelayLineEdit.text = str(behavior_data.pow_delay)
		CurrentMapData.selected_unit.rad_budget = behavior_data.rad_budget
		%RadarBuildingHSlider.value = int(behavior_data.rad_budget)
		CurrentMapData.selected_unit.rad_delay = behavior_data.rad_delay
		%RadarBuildingDelayLineEdit.text = str(behavior_data.rad_delay)
		CurrentMapData.selected_unit.saf_budget = behavior_data.saf_budget
		%FlakBuildingHSlider.value = int(behavior_data.saf_budget)
		CurrentMapData.selected_unit.saf_delay = behavior_data.saf_delay
		%FlakBuildingDelayLineEdit.text = str(behavior_data.saf_delay)
		CurrentMapData.selected_unit.cpl_budget = behavior_data.cpl_budget
		%MovingStationHSlider.value = int(behavior_data.cpl_budget)
		CurrentMapData.selected_unit.cpl_delay = behavior_data.cpl_delay
		%MovingStationDelayLineEdit.text = str(behavior_data.cpl_delay)
		CurrentMapData.is_saved = false
	)


func _update_properties() -> void:
	if CurrentMapData.selected_unit is HostStation:
		var i = 1
		for hs in CurrentMapData.host_stations.get_children():
			if CurrentMapData.selected_unit == hs: break
			else: i += 1
		
		%HSnumberLabel.text = "Host station " + str(i) + ": "
		%HSnameLabel.text = CurrentMapData.selected_unit.unit_name
		%EnergyLineEdit.text = str(CurrentMapData.selected_unit.energy/400)
		
		%ViewAngleLineEdit.text = str(CurrentMapData.selected_unit.view_angle)
		%ViewAngleCheckButton.button_pressed = CurrentMapData.selected_unit.view_angle_enabled
		%ViewAngleLineEdit.editable = %ViewAngleCheckButton.button_pressed
		
		if CurrentMapData.player_host_station == CurrentMapData.selected_unit:
			%ReloadConstLineEdit.text = str(int(float(CurrentMapData.selected_unit.reload_const) / (60000.0/255.0)))
		else:
			%ReloadConstLineEdit.text = str(int(float(CurrentMapData.selected_unit.reload_const) / (70000.0/255.0)))
		%ReloadConstCheckButton.button_pressed = CurrentMapData.selected_unit.reload_const_enabled
		%ReloadConstLineEdit.editable = %ReloadConstCheckButton.button_pressed
		
		%XposHostStationLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%YposHostStationLineEdit.text = str(CurrentMapData.selected_unit.pos_y)
		%ZposHostStationLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))
		if not CurrentMapData.selected_unit.position_changed.is_connected(_update_coordinates):
			CurrentMapData.selected_unit.position_changed.connect(_update_coordinates)
		
		%ConqueringHSlider.value = CurrentMapData.selected_unit.con_budget
		%ConqueringValueLabel.text = str(CurrentMapData.selected_unit.con_budget)
		%ConqueringDelayLineEdit.text = str(CurrentMapData.selected_unit.con_delay)
		%DefenseHSlider.value = CurrentMapData.selected_unit.def_budget
		%DefenseValueLabel.text = str(CurrentMapData.selected_unit.def_budget)
		%DefenseDelayLineEdit.text = str(CurrentMapData.selected_unit.def_delay)
		%ReconnaissanceHSlider.value = CurrentMapData.selected_unit.rec_budget
		%ReconnaissanceValueLabel.text = str(CurrentMapData.selected_unit.rec_budget)
		%ReconnaissanceDelayLineEdit.text = str(CurrentMapData.selected_unit.rec_delay)
		%AttackingHSlider.value = CurrentMapData.selected_unit.rob_budget
		%AttackingValueLabel.text = str(CurrentMapData.selected_unit.rob_budget)
		%AttackingDelayLineEdit.text = str(CurrentMapData.selected_unit.rob_delay)
		%PowerBuildingHSlider.value = CurrentMapData.selected_unit.pow_budget
		%PowerBuildingValueLabel.text = str(CurrentMapData.selected_unit.pow_budget)
		%PowerBuildingDelayLineEdit.text = str(CurrentMapData.selected_unit.pow_delay)
		%RadarBuildingHSlider.value = CurrentMapData.selected_unit.rad_budget
		%RadarBuildingValueLabel.text = str(CurrentMapData.selected_unit.rad_budget)
		%RadarBuildingDelayLineEdit.text = str(CurrentMapData.selected_unit.rad_delay)
		%FlakBuildingHSlider.value = CurrentMapData.selected_unit.saf_budget
		%FlakBuildingValueLabel.text = str(CurrentMapData.selected_unit.saf_budget)
		%FlakBuildingDelayLineEdit.text = str(CurrentMapData.selected_unit.saf_delay)
		%MovingStationHSlider.value = CurrentMapData.selected_unit.cpl_budget
		%MovingStationValueLabel.text = str(CurrentMapData.selected_unit.cpl_budget)
		%MovingStationDelayLineEdit.text = str(CurrentMapData.selected_unit.cpl_delay)
		
		%MBstatusHostStationCheckBox.button_pressed = CurrentMapData.selected_unit.mb_status
		
		%HostStationRoboTextureRect.texture = Preloads.hs_robo_images[CurrentMapData.selected_unit.vehicle].image
		%HostStationRoboOptionButton.select(%HostStationRoboOptionButton.get_item_index(CurrentMapData.selected_unit.vehicle))
		
		show()


func _update_coordinates():
	if CurrentMapData.selected_unit is HostStation:
		%XposHostStationLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%ZposHostStationLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))
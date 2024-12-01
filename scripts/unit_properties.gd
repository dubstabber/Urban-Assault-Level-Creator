extends TabBar


func _ready():
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
		%LoadBehaviorFileDialog.show()
	)
	%SaveBehaviorFileButton.pressed.connect(func():
		%SaveBehaviorFileDialog.show()
	)
	%LoadBehaviorFileDialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.READ)
		var behavior_json = file.get_line()
		var behavior_data = JSON.parse_string(behavior_json)
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
	%SaveBehaviorFileDialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		var behavior_data := {
			con_budget = CurrentMapData.selected_unit.con_budget,
			con_delay = CurrentMapData.selected_unit.con_delay,
			def_budget = CurrentMapData.selected_unit.def_budget,
			def_delay = CurrentMapData.selected_unit.def_delay,
			rec_budget = CurrentMapData.selected_unit.rec_budget,
			rec_delay = CurrentMapData.selected_unit.rec_delay,
			rob_budget = CurrentMapData.selected_unit.rob_budget,
			rob_delay = CurrentMapData.selected_unit.rob_delay,
			pow_budget = CurrentMapData.selected_unit.pow_budget,
			pow_delay = CurrentMapData.selected_unit.pow_delay,
			rad_budget = CurrentMapData.selected_unit.rad_budget,
			rad_delay = CurrentMapData.selected_unit.rad_delay,
			saf_budget = CurrentMapData.selected_unit.saf_budget,
			saf_delay = CurrentMapData.selected_unit.saf_delay,
			cpl_budget = CurrentMapData.selected_unit.cpl_budget,
			cpl_delay = CurrentMapData.selected_unit.cpl_delay
		}
		var behavior_data_json = JSON.stringify(behavior_data)
		file.store_line(behavior_data_json)
	)
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
	%UseableCheckBox.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.useable != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.useable = toggled
	)
	%MBstatusSquadCheckBox.toggled.connect(func(toggled: bool):
		if CurrentMapData.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		CurrentMapData.selected_unit.mb_status = toggled
	)


func _update_properties():
	if CurrentMapData.selected_unit:
		%NoUnitLabel.hide()
		var i = 1
		if CurrentMapData.selected_unit is HostStation:
			for hs in CurrentMapData.host_stations.get_children():
				if CurrentMapData.selected_unit == hs: break
				else: i += 1
			%SquadProperties.hide()
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
			
			%HostStationProperties.show()
		elif CurrentMapData.selected_unit is Squad:
			%HostStationProperties.hide()
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
			
			%SquadProperties.show()
	else:
		%NoUnitLabel.show()
		%HostStationProperties.hide()
		%SquadProperties.hide()


func _update_coordinates():
	if CurrentMapData.selected_unit is HostStation:
		%XposHostStationLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%ZposHostStationLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))
	elif CurrentMapData.selected_unit is Squad:
		%XposSquadLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
		%ZposSquadLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))

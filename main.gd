extends Control


@onready var map_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer
@onready var sub_viewport_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer
@onready var map = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map

@onready var context_menu = $ContextMenu

@onready var properties_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer

@onready var host_stations = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/HostStations
@onready var squads = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/Squads


func _ready():
	get_tree().get_root().connect("size_changed",_on_resize)
	CurrentMapData.connect("selected", _update_properties)
	
	%EnergyLineEdit.text_changed.connect(func(new_value: String):
		var validated_value = int(new_value)
		if validated_value == 0: validated_value = 1
		CurrentMapData.selected_unit.energy = abs(validated_value * 400)
	)
	%ViewAngleLineEdit.text_changed.connect(func(new_value: String):
		CurrentMapData.selected_unit.view_angle = abs(int(new_value))
	)
	%ViewAngleCheckButton.toggled.connect(func(toggled: bool):
		CurrentMapData.selected_unit.view_angle_enabled = toggled
		%ViewAngleLineEdit.editable = toggled
	)
	%ReloadConstLineEdit.text_changed.connect(func(new_value: String):
		CurrentMapData.selected_unit.reload_const = abs(int(ceil(float(new_value) * (60000.0/255.0))))
	)
	%ReloadConstCheckButton.toggled.connect(func(toggled:bool):
		CurrentMapData.selected_unit.reload_const_enabled = toggled
		%ReloadConstLineEdit.editable = toggled
	)
	%ConqueringHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.con_budget = value_changed
		%ConqueringValueLabel.text = str(value_changed)
	)
	%ConqueringDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.con_delay = abs(int(value_changed))
	)
	%DefenseHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.def_budget = value_changed
		%DefenseValueLabel.text = str(value_changed)
	)
	%DefenseDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.def_delay = abs(int(value_changed))
	)
	%ReconnaissanceHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.rec_budget = value_changed
		%ReconnaissanceValueLabel.text = str(value_changed)
	)
	%ReconnaissanceDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.rec_delay = abs(int(value_changed))
	)
	%AttackingHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.rob_budget = value_changed
		%AttackingValueLabel.text = str(value_changed)
	)
	%AttackingDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.rob_delay = abs(int(value_changed))
	)
	%PowerBuildingHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.pow_budget = value_changed
		%PowerBuildingValueLabel.text = str(value_changed)
	)
	%PowerBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.pow_delay = abs(int(value_changed))
	)
	%RadarBuildingHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.rad_budget = value_changed
		%RadarBuildingValueLabel.text = str(value_changed)
	)
	%RadarBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.rad_delay = abs(int(value_changed))
	)
	%FlakBuildingHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.saf_budget = value_changed
		%FlakBuildingValueLabel.text = str(value_changed)
	)
	%FlakBuildingDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.saf_delay = abs(int(value_changed))
	)
	%MovingStationHSlider.value_changed.connect(func(value_changed: int):
		CurrentMapData.selected_unit.cpl_budget = value_changed
		%MovingStationValueLabel.text = str(value_changed)
	)
	%MovingStationDelayLineEdit.text_changed.connect(func(value_changed: String):
		CurrentMapData.selected_unit.cpl_delay = abs(int(value_changed))
	)
	%MBstatusCheckBox.toggled.connect(func(toggled: bool):
		CurrentMapData.selected_unit.mb_status = toggled
	)


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_local_mouse_position().x)
		var mouse_y = round(get_local_mouse_position().y)
		context_menu.position = Vector2(mouse_x, mouse_y - context_menu.size.y)
		context_menu.show_popup()
		#prints('main: right click, x:', mouse_x, " ,y:",mouse_y)


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	properties_container.size.x = DisplayServer.window_get_size().x/3.0
	map_container.custom_minimum_size.x = DisplayServer.window_get_size().x - properties_container.size.x
	map_container.custom_minimum_size.y = DisplayServer.window_get_size().y - 70
	
	map.recalculate_size()
	sub_viewport_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_container.custom_minimum_size.y = map.map_visible_height


func _update_properties():
	if CurrentMapData.selected_unit:
		%NoUnitLabel.hide()
		var i = 1
		if CurrentMapData.selected_unit is HostStation:
			for hs in host_stations.get_children():
				if CurrentMapData.selected_unit == hs: break
				else: i += 1
			%SquadProperties.hide()
			%HSnumberLabel.text = "Host station " + str(i) + ": "
			%HSnameLabel.text = CurrentMapData.selected_unit.unit_name
			%EnergyLineEdit.text = str(CurrentMapData.selected_unit.energy/400)
			
			%ViewAngleLineEdit.text = str(CurrentMapData.selected_unit.view_angle)
			%ViewAngleCheckButton.button_pressed = CurrentMapData.selected_unit.view_angle_enabled
			%ViewAngleLineEdit.editable = %ViewAngleCheckButton.button_pressed
			
			#TODO: convert reload const based on if player or ai is selected
			%ReloadConstLineEdit.text = str(int(float(CurrentMapData.selected_unit.reload_const) / (60000.0/255.0)))
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
			
			%MBstatusCheckBox.button_pressed = CurrentMapData.selected_unit.mb_status
			
			%HostStationProperties.show()
		elif CurrentMapData.selected_unit is Squad:
			%HostStationProperties.hide()
			%SquadIcon.texture = Preloads.squad_images[str(CurrentMapData.selected_unit.vehicle)]
			%SquadNumberLabel.text = "Squad: "
			%SquadNameLabel.text = CurrentMapData.selected_unit.unit_name
			%SquadProperties.show()
	else:
		%NoUnitLabel.show()
		%HostStationProperties.hide()
		%SquadProperties.hide()


func _update_coordinates():
	if CurrentMapData.selected_unit:
		if CurrentMapData.selected_unit is HostStation:
			%XposHostStationLineEdit.text = str(round(CurrentMapData.selected_unit.position.x))
			%ZposHostStationLineEdit.text = str(round(-CurrentMapData.selected_unit.position.y))


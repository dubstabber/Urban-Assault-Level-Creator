extends VBoxContainer


@onready var hs_number_label: Label = %HSnumberLabel
@onready var hs_name_label: Label = %HSnameLabel
@onready var owner_error_label: Label = %OwnerErrorLabel

@onready var energy_line_edit: LineEdit = %EnergyLineEdit
@onready var view_angle_line_edit: LineEdit = %ViewAngleLineEdit
@onready var view_angle_check_button: Button = %ViewAngleCheckButton
@onready var reload_const_line_edit: LineEdit = %ReloadConstLineEdit
@onready var reload_const_check_button: Button = %ReloadConstCheckButton

@onready var xpos_host_station_line_edit: LineEdit = %XposHostStationLineEdit
@onready var ypos_host_station_line_edit: LineEdit = %YposHostStationLineEdit
@onready var zpos_host_station_line_edit: LineEdit = %ZposHostStationLineEdit

@onready var conquering_h_slider: HSlider = %ConqueringHSlider
@onready var conquering_value_label: Label = %ConqueringValueLabel
@onready var conquering_delay_line_edit: LineEdit = %ConqueringDelayLineEdit
@onready var defense_h_slider: HSlider = %DefenseHSlider
@onready var defense_value_label: Label = %DefenseValueLabel
@onready var defense_delay_line_edit: LineEdit = %DefenseDelayLineEdit
@onready var reconnaissance_h_slider: HSlider = %ReconnaissanceHSlider
@onready var reconnaissance_value_label: Label = %ReconnaissanceValueLabel
@onready var reconnaissance_delay_line_edit: LineEdit = %ReconnaissanceDelayLineEdit
@onready var attacking_h_slider: HSlider = %AttackingHSlider
@onready var attacking_value_label: Label = %AttackingValueLabel
@onready var attacking_delay_line_edit: LineEdit = %AttackingDelayLineEdit
@onready var power_building_h_slider: HSlider = %PowerBuildingHSlider
@onready var power_building_value_label: Label = %PowerBuildingValueLabel
@onready var power_building_delay_line_edit: LineEdit = %PowerBuildingDelayLineEdit
@onready var radar_building_h_slider: HSlider = %RadarBuildingHSlider
@onready var radar_building_value_label: Label = %RadarBuildingValueLabel
@onready var radar_building_delay_line_edit: LineEdit = %RadarBuildingDelayLineEdit
@onready var flak_building_h_slider: HSlider = %FlakBuildingHSlider
@onready var flak_building_value_label: Label = %FlakBuildingValueLabel
@onready var flak_building_delay_line_edit: LineEdit = %FlakBuildingDelayLineEdit
@onready var moving_station_h_slider: HSlider = %MovingStationHSlider
@onready var moving_station_value_label: Label = %MovingStationValueLabel
@onready var moving_station_delay_line_edit: LineEdit = %MovingStationDelayLineEdit

@onready var mb_status_host_station_check_box: CheckBox = %MBstatusHostStationCheckBox

@onready var host_station_robo_option_button: OptionButton = %HostStationRoboOptionButton
@onready var host_station_robo_texture_rect: TextureRect = %HostStationRoboTextureRect

@onready var load_behavior_file_button: Button = %LoadBehaviorFileButton
@onready var save_behavior_file_button: Button = %SaveBehaviorFileButton


func _ready() -> void:
	EventSystem.unit_selected.connect(_update_properties)
	energy_line_edit.text_changed.connect(func(new_value: String):
		var validated_value = int(new_value)
		if validated_value == 0: validated_value = 1
		if EditorState.selected_unit.energy != abs(validated_value * 400): CurrentMapData.is_saved = false
		EditorState.selected_unit.energy = abs(validated_value * 400)
	)
	view_angle_line_edit.text_changed.connect(func(new_value: String):
		if EditorState.selected_unit.view_angle != abs(int(new_value)):
			CurrentMapData.is_saved = false
			EditorState.selected_unit.view_angle = abs(int(new_value))
	)
	view_angle_check_button.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.view_angle_enabled != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.view_angle_enabled = toggled
		view_angle_line_edit.editable = toggled
	)
	reload_const_line_edit.text_changed.connect(func(new_value: String):
		var converted_value: int
		if CurrentMapData.player_host_station == EditorState.selected_unit:
			converted_value = abs(int(ceil(float(new_value) * (60000.0 / 255.0))))
		else:
			converted_value = abs(int(ceil(float(new_value) * (70000.0 / 255.0))))
		if EditorState.selected_unit.reload_const != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.reload_const = converted_value
	)
	reload_const_check_button.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.reload_const_enabled != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.reload_const_enabled = toggled
		reload_const_line_edit.editable = toggled
	)
	xpos_host_station_line_edit.text_submitted.connect(func(text_value: String):
		var pos_x := clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.x != pos_x:
			CurrentMapData.is_saved = false
			xpos_host_station_line_edit.text = str(pos_x)
			print(pos_x)
		EditorState.selected_unit.position.x = pos_x
		)
	ypos_host_station_line_edit.text_submitted.connect(func(text_value: String):
		var pos_y := int(text_value) if int(text_value) <= 0 else -int(text_value)
		if EditorState.selected_unit.pos_y != pos_y:
			CurrentMapData.is_saved = false
			ypos_host_station_line_edit.text = str(pos_y)
		EditorState.selected_unit.pos_y = pos_y
		)
	zpos_host_station_line_edit.text_submitted.connect(func(text_value: String):
		var pos_z := clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.y != pos_z:
			CurrentMapData.is_saved = false
			zpos_host_station_line_edit.text = "-%s" % str(pos_z)
		EditorState.selected_unit.position.y = pos_z
		)
	conquering_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.con_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.con_budget = value_changed
		conquering_value_label.text = str(value_changed)
	)
	conquering_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.con_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.con_delay = converted_value
	)
	defense_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.def_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.def_budget = value_changed
		defense_value_label.text = str(value_changed)
	)
	defense_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.def_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.def_delay = converted_value
	)
	reconnaissance_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rec_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rec_budget = value_changed
		reconnaissance_value_label.text = str(value_changed)
	)
	reconnaissance_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.rec_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rec_delay = converted_value
	)
	attacking_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rob_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rob_budget = value_changed
		attacking_value_label.text = str(value_changed)
	)
	attacking_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.rob_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rob_delay = converted_value
	)
	power_building_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.pow_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_budget = value_changed
		power_building_value_label.text = str(value_changed)
	)
	power_building_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.pow_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_delay = converted_value
	)
	radar_building_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rad_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rad_budget = value_changed
		radar_building_value_label.text = str(value_changed)
	)
	radar_building_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.rad_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rob_delay = converted_value
	)
	power_building_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.pow_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_budget = value_changed
		power_building_value_label.text = str(value_changed)
	)
	power_building_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.pow_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.pow_delay = converted_value
	)
	radar_building_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.rad_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rad_budget = value_changed
		radar_building_value_label.text = str(value_changed)
	)
	radar_building_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.rad_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.rad_delay = converted_value
	)
	flak_building_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.saf_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.saf_budget = value_changed
		flak_building_value_label.text = str(value_changed)
	)
	flak_building_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.saf_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.saf_delay = converted_value
	)
	moving_station_h_slider.value_changed.connect(func(value_changed: int):
		if EditorState.selected_unit.cpl_budget != value_changed:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.cpl_budget = value_changed
		moving_station_value_label.text = str(value_changed)
	)
	moving_station_delay_line_edit.text_changed.connect(func(value_changed: String):
		var converted_value = abs(int(value_changed)) * 1024
		if EditorState.selected_unit.cpl_delay != converted_value:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.cpl_delay = converted_value
	)
	mb_status_host_station_check_box.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.mb_status != toggled:
			CurrentMapData.is_saved = false
			EditorState.selected_unit.mb_status = toggled
	)
	for hs_robo in Preloads.hs_robo_images:
		host_station_robo_option_button.add_item(Preloads.hs_robo_images[hs_robo].name, hs_robo)
	host_station_robo_option_button.item_selected.connect(func(index: int):
		EditorState.selected_unit.vehicle = host_station_robo_option_button.get_item_id(index)
		host_station_robo_texture_rect.texture = Preloads.hs_robo_images[host_station_robo_option_button.get_item_id(index)].image
		CurrentMapData.is_saved = false
	)
	load_behavior_file_button.pressed.connect(func():
		EventSystem.load_hs_behavior_dialog_requested.emit()
	)
	save_behavior_file_button.pressed.connect(func():
		EventSystem.save_hs_behavior_dialog_requested.emit()
	)
	
	EventSystem.behavior_loaded.connect(_on_behavior_loaded)


func _update_properties() -> void:
	if EditorState.selected_unit is HostStation:
		var i = 1
		for hs in CurrentMapData.host_stations.get_children():
			if EditorState.selected_unit == hs: break
			else: i += 1
		
		hs_number_label.text = "Host station " + str(i) + ": "
		hs_name_label.text = EditorState.selected_unit.unit_name
		if EditorState.selected_unit.owner_id < 1 or EditorState.selected_unit.owner_id > 7:
			owner_error_label.show()
		else: owner_error_label.hide()
		
		energy_line_edit.text = str(EditorState.selected_unit.energy / 400)
		
		view_angle_line_edit.text = str(EditorState.selected_unit.view_angle)
		view_angle_line_edit.editable = view_angle_check_button.button_pressed
		view_angle_check_button.button_pressed = EditorState.selected_unit.view_angle_enabled
		
		if CurrentMapData.player_host_station == EditorState.selected_unit:
			reload_const_line_edit.text = str(int(float(EditorState.selected_unit.reload_const) / (60000.0 / 255.0)))
		else:
			reload_const_line_edit.text = str(int(float(EditorState.selected_unit.reload_const) / (70000.0 / 255.0)))
		reload_const_check_button.button_pressed = EditorState.selected_unit.reload_const_enabled
		reload_const_line_edit.editable = reload_const_check_button.button_pressed
		
		xpos_host_station_line_edit.text = str(roundi(EditorState.selected_unit.position.x))
		ypos_host_station_line_edit.text = str(EditorState.selected_unit.pos_y)
		zpos_host_station_line_edit.text = str(roundi(-EditorState.selected_unit.position.y))
		if not EditorState.selected_unit.position_changed.is_connected(_update_coordinates):
			EditorState.selected_unit.position_changed.connect(_update_coordinates)
		
		conquering_h_slider.value = EditorState.selected_unit.con_budget
		conquering_value_label.text = str(EditorState.selected_unit.con_budget)
		conquering_delay_line_edit.text = str(EditorState.selected_unit.con_delay / 1024)
		defense_h_slider.value = EditorState.selected_unit.def_budget
		defense_value_label.text = str(EditorState.selected_unit.def_budget)
		defense_delay_line_edit.text = str(EditorState.selected_unit.def_delay / 1024)
		reconnaissance_h_slider.value = EditorState.selected_unit.rec_budget
		reconnaissance_value_label.text = str(EditorState.selected_unit.rec_budget)
		reconnaissance_delay_line_edit.text = str(EditorState.selected_unit.rec_delay / 1024)
		attacking_h_slider.value = EditorState.selected_unit.rob_budget
		attacking_value_label.text = str(EditorState.selected_unit.rob_budget)
		attacking_delay_line_edit.text = str(EditorState.selected_unit.rob_delay / 1024)
		power_building_h_slider.value = EditorState.selected_unit.pow_budget
		power_building_value_label.text = str(EditorState.selected_unit.pow_budget)
		power_building_delay_line_edit.text = str(EditorState.selected_unit.pow_delay / 1024)
		radar_building_h_slider.value = EditorState.selected_unit.rad_budget
		radar_building_value_label.text = str(EditorState.selected_unit.rad_budget)
		radar_building_delay_line_edit.text = str(EditorState.selected_unit.rad_delay / 1024)
		flak_building_h_slider.value = EditorState.selected_unit.saf_budget
		flak_building_value_label.text = str(EditorState.selected_unit.saf_budget)
		flak_building_delay_line_edit.text = str(EditorState.selected_unit.saf_delay / 1024)
		moving_station_h_slider.value = EditorState.selected_unit.cpl_budget
		moving_station_value_label.text = str(EditorState.selected_unit.cpl_budget)
		moving_station_delay_line_edit.text = str(EditorState.selected_unit.cpl_delay / 1024)
		
		mb_status_host_station_check_box.button_pressed = EditorState.selected_unit.mb_status
		
		host_station_robo_texture_rect.texture = Preloads.hs_robo_images[EditorState.selected_unit.vehicle].image
		host_station_robo_option_button.select(host_station_robo_option_button.get_item_index(EditorState.selected_unit.vehicle))
		
		show()


func _update_coordinates():
	if EditorState.selected_unit is HostStation:
		xpos_host_station_line_edit.text = str(roundi(EditorState.selected_unit.position.x))
		zpos_host_station_line_edit.text = str(roundi(-EditorState.selected_unit.position.y))


func _on_behavior_loaded(behavior_data: Dictionary) -> void:
	var behavior_mappings = [
		{"key": "con_budget", "unit_attr": "con_budget", "slider": conquering_h_slider, "line_edit": null},
		{"key": "con_delay", "unit_attr": "con_delay", "slider": null, "line_edit": conquering_delay_line_edit, "divide": 1024.0},
		{"key": "def_budget", "unit_attr": "def_budget", "slider": defense_h_slider, "line_edit": null},
		{"key": "def_delay", "unit_attr": "def_delay", "slider": null, "line_edit": defense_delay_line_edit, "divide": 1024.0},
		{"key": "rec_budget", "unit_attr": "rec_budget", "slider": reconnaissance_h_slider, "line_edit": null},
		{"key": "rec_delay", "unit_attr": "rec_delay", "slider": null, "line_edit": reconnaissance_delay_line_edit, "divide": 1024.0},
		{"key": "rob_budget", "unit_attr": "rob_budget", "slider": attacking_h_slider, "line_edit": null},
		{"key": "rob_delay", "unit_attr": "rob_delay", "slider": null, "line_edit": attacking_delay_line_edit, "divide": 1024.0},
		{"key": "pow_budget", "unit_attr": "pow_budget", "slider": power_building_h_slider, "line_edit": null},
		{"key": "pow_delay", "unit_attr": "pow_delay", "slider": null, "line_edit": power_building_delay_line_edit, "divide": 1024.0},
		{"key": "rad_budget", "unit_attr": "rad_budget", "slider": radar_building_h_slider, "line_edit": null},
		{"key": "rad_delay", "unit_attr": "rad_delay", "slider": null, "line_edit": radar_building_delay_line_edit, "divide": 1024.0},
		{"key": "saf_budget", "unit_attr": "saf_budget", "slider": flak_building_h_slider, "line_edit": null},
		{"key": "saf_delay", "unit_attr": "saf_delay", "slider": null, "line_edit": flak_building_delay_line_edit, "divide": 1024.0},
		{"key": "cpl_budget", "unit_attr": "cpl_budget", "slider": moving_station_h_slider, "line_edit": null},
		{"key": "cpl_delay", "unit_attr": "cpl_delay", "slider": null, "line_edit": moving_station_delay_line_edit, "divide": 1024.0},
	]
	
	for mapping in behavior_mappings:
		if behavior_data.has(mapping.key):
			var value = behavior_data[mapping.key]
			EditorState.selected_unit.set(mapping.unit_attr, value)
			
			if mapping.slider:
				mapping.slider.value = int(value)
			if mapping.line_edit:
				var display_value = int(int(value) / mapping.get("divide", 1.0))
				mapping.line_edit.text = str(display_value)
	
	CurrentMapData.is_saved = false

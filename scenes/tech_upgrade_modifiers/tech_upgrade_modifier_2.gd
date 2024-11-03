extends VBoxContainer

var building_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name


func _ready() -> void:
	%EnableResistanceCheckBox.toggled.connect(enable_building.bind("res_enabled"))
	%EnableGhorkovCheckBox.toggled.connect(enable_building.bind("ghor_enabled"))
	%EnableTaerkastenCheckBox.toggled.connect(enable_building.bind("taer_enabled"))
	%EnableMykonianCheckBox.toggled.connect(enable_building.bind("myko_enabled"))
	%EnableSulgogarCheckBox.toggled.connect(enable_building.bind("sulg_enabled"))
	%EnableBlackSectCheckBox.toggled.connect(enable_building.bind("blacksect_enabled"))
	%EnableTrainingCheckBox.toggled.connect(enable_building.bind("training_enabled"))
	
	%RemoveButton.pressed.connect(func():
		if building_modifier:
			CurrentMapData.selected_tech_upgrade.buildings.erase(building_modifier)
		queue_free()
		)


func enable_building(toggled: bool, property: String) -> void:
	if not building_modifier: building_modifier = CurrentMapData.selected_tech_upgrade.new_building_modifier(int(CurrentMapData.blg_names.find_key(item_name)))
	building_modifier[property] = toggled
	CurrentMapData.selected_tech_upgrade.synchronize(building_modifier, "enable")


func update_ui() -> void:
	if building_modifier:
		%EnableResistanceCheckBox.button_pressed = building_modifier.res_enabled
		%EnableGhorkovCheckBox.button_pressed = building_modifier.ghor_enabled
		%EnableTaerkastenCheckBox.button_pressed = building_modifier.taer_enabled
		%EnableMykonianCheckBox.button_pressed = building_modifier.myko_enabled
		%EnableSulgogarCheckBox.button_pressed = building_modifier.sulg_enabled
		%EnableBlackSectCheckBox.button_pressed = building_modifier.blacksect_enabled
		%EnableTrainingCheckBox.button_pressed = building_modifier.training_enabled

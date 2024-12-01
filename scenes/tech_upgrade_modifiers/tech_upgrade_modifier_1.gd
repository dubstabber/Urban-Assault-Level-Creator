extends VBoxContainer

var vehicle_modifier
var weapon_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name


func _ready() -> void:
	%EnableResistanceCheckBox.toggled.connect(enable_vehicle.bind("res_enabled"))
	%EnableGhorkovCheckBox.toggled.connect(enable_vehicle.bind("ghor_enabled"))
	%EnableTaerkastenCheckBox.toggled.connect(enable_vehicle.bind("taer_enabled"))
	%EnableMykonianCheckBox.toggled.connect(enable_vehicle.bind("myko_enabled"))
	%EnableSulgogarCheckBox.toggled.connect(enable_vehicle.bind("sulg_enabled"))
	%EnableBlackSectCheckBox.toggled.connect(enable_vehicle.bind("blacksect_enabled"))
	%EnableTrainingCheckBox.toggled.connect(enable_vehicle.bind("training_enabled"))
	
	%AddEnergyLineEdit.text_changed.connect(modify_vehicle.bind("energy"))
	%AddShieldLineEdit.text_changed.connect(modify_vehicle.bind("shield"))
	%AddWeaponLineEdit.text_changed.connect(modify_vehicle.bind("num_weapons"))
	%AddRadarLineEdit.text_changed.connect(modify_vehicle.bind("radar"))
	
	%AddDamageLineEdit.text_changed.connect(modify_weapon.bind("energy"))
	%AddShotTimeLineEdit.text_changed.connect(modify_weapon.bind("shot_time"))
	%AddShotTimeUserLineEdit.text_changed.connect(modify_weapon.bind("shot_time_user"))
	
	%RemoveButton.pressed.connect(func():
		if vehicle_modifier:
			CurrentMapData.selected_tech_upgrade.vehicles.erase(vehicle_modifier)
		if weapon_modifier:
			CurrentMapData.selected_tech_upgrade.weapons.erase(weapon_modifier)
		CurrentMapData.is_saved = false
		queue_free()
		)


func enable_vehicle(toggled: bool, property: String) -> void:
	if not vehicle_modifier: vehicle_modifier = CurrentMapData.selected_tech_upgrade.new_vehicle_modifier(CurrentMapData.units_db[item_name])
	vehicle_modifier[property] = toggled
	CurrentMapData.selected_tech_upgrade.synchronize(vehicle_modifier, "enable")
	CurrentMapData.is_saved = false


func modify_vehicle(new_text: String, property: String) -> void:
	if not vehicle_modifier: vehicle_modifier = CurrentMapData.selected_tech_upgrade.new_vehicle_modifier(CurrentMapData.units_db[item_name])
	if property == "energy":
		vehicle_modifier[property] = int(new_text) * 100
	else:
		vehicle_modifier[property] = int(new_text)
	CurrentMapData.selected_tech_upgrade.synchronize(vehicle_modifier, property)
	CurrentMapData.is_saved = false


func modify_weapon(new_text: String, property: String) -> void:
	if not weapon_modifier: weapon_modifier = CurrentMapData.selected_tech_upgrade.new_weapon_modifier(CurrentMapData.units_db[item_name])
	if property == "energy":
		weapon_modifier[property] = int(new_text) * 100
	else:
		weapon_modifier[property] = int(new_text)
	CurrentMapData.selected_tech_upgrade.synchronize(weapon_modifier, property)
	CurrentMapData.is_saved = false


func update_ui() -> void:
	if vehicle_modifier:
		%EnableResistanceCheckBox.button_pressed = vehicle_modifier.res_enabled
		%EnableGhorkovCheckBox.button_pressed = vehicle_modifier.ghor_enabled
		%EnableTaerkastenCheckBox.button_pressed = vehicle_modifier.taer_enabled
		%EnableMykonianCheckBox.button_pressed = vehicle_modifier.myko_enabled
		%EnableSulgogarCheckBox.button_pressed = vehicle_modifier.sulg_enabled
		%EnableBlackSectCheckBox.button_pressed = vehicle_modifier.blacksect_enabled
		%EnableTrainingCheckBox.button_pressed = vehicle_modifier.training_enabled
		
		%AddEnergyLineEdit.text = str(vehicle_modifier.energy / 100)
		%AddShieldLineEdit.text = str(vehicle_modifier.shield)
		%AddWeaponLineEdit.text = str(vehicle_modifier.num_weapons)
		%AddRadarLineEdit.text = str(vehicle_modifier.radar)
	if weapon_modifier:
		%AddDamageLineEdit.text = str(weapon_modifier.energy / 100)
		%AddShotTimeLineEdit.text = str(weapon_modifier.shot_time)
		%AddShotTimeUserLineEdit.text = str(weapon_modifier.shot_time_user)

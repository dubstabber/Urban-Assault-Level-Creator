extends VBoxContainer

var vehicle_modifier
var weapon_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name

@onready var enable_resistance_checkbox: CheckBox = %EnableResistanceCheckBox
@onready var enable_ghorkov_checkbox: CheckBox = %EnableGhorkovCheckBox
@onready var enable_taerkasten_checkbox: CheckBox = %EnableTaerkastenCheckBox
@onready var enable_mykonian_checkbox: CheckBox = %EnableMykonianCheckBox
@onready var enable_sulgogar_checkbox: CheckBox = %EnableSulgogarCheckBox
@onready var enable_blacksect_checkbox: CheckBox = %EnableBlackSectCheckBox
@onready var enable_training_checkbox: CheckBox = %EnableTrainingCheckBox

@onready var add_energy_line_edit: LineEdit = %AddEnergyLineEdit
@onready var add_shield_line_edit: LineEdit = %AddShieldLineEdit
@onready var add_weapon_line_edit: LineEdit = %AddWeaponLineEdit
@onready var add_radar_line_edit: LineEdit = %AddRadarLineEdit

@onready var add_damage_line_edit: LineEdit = %AddDamageLineEdit
@onready var add_shot_time_line_edit: LineEdit = %AddShotTimeLineEdit
@onready var add_shot_time_user_line_edit: LineEdit = %AddShotTimeUserLineEdit

@onready var remove_button: Button = %RemoveButton
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	enable_resistance_checkbox.toggled.connect(enable_vehicle.bind("res_enabled"))
	enable_ghorkov_checkbox.toggled.connect(enable_vehicle.bind("ghor_enabled"))
	enable_taerkasten_checkbox.toggled.connect(enable_vehicle.bind("taer_enabled"))
	enable_mykonian_checkbox.toggled.connect(enable_vehicle.bind("myko_enabled"))
	enable_sulgogar_checkbox.toggled.connect(enable_vehicle.bind("sulg_enabled"))
	enable_blacksect_checkbox.toggled.connect(enable_vehicle.bind("blacksect_enabled"))
	enable_training_checkbox.toggled.connect(enable_vehicle.bind("training_enabled"))
	
	add_energy_line_edit.text_changed.connect(modify_vehicle.bind("energy"))
	add_shield_line_edit.text_changed.connect(modify_vehicle.bind("shield"))
	add_weapon_line_edit.text_changed.connect(modify_vehicle.bind("num_weapons"))
	add_radar_line_edit.text_changed.connect(modify_vehicle.bind("radar"))
	
	add_damage_line_edit.text_changed.connect(modify_weapon.bind("energy"))
	add_shot_time_line_edit.text_changed.connect(modify_weapon.bind("shot_time"))
	add_shot_time_user_line_edit.text_changed.connect(modify_weapon.bind("shot_time_user"))
	
	remove_button.pressed.connect(func():
		undo_redo_manager.begin_group("Tech modifier remove")
		var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
		if vehicle_modifier:
			EditorState.selected_tech_upgrade.vehicles.erase(vehicle_modifier)
		if weapon_modifier:
			EditorState.selected_tech_upgrade.weapons.erase(weapon_modifier)
		CurrentMapData.is_saved = false
		undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
		undo_redo_manager.commit_group()
		queue_free()
		)


func enable_vehicle(toggled: bool, property: String) -> void:
	undo_redo_manager.begin_group("Tech vehicle modifier")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	if not vehicle_modifier:
		vehicle_modifier = EditorState.selected_tech_upgrade.new_vehicle_modifier(find_id_by_name(item_name))
		if not vehicle_modifier:
			undo_redo_manager.commit_group()
			return
	if vehicle_modifier[property] == toggled:
		undo_redo_manager.commit_group()
		return
	vehicle_modifier[property] = toggled
	EditorState.selected_tech_upgrade.synchronize(vehicle_modifier, "enable")
	CurrentMapData.is_saved = false
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()


func modify_vehicle(new_text: String, property: String) -> void:
	undo_redo_manager.begin_group("Tech vehicle modifier")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	if not vehicle_modifier:
		vehicle_modifier = EditorState.selected_tech_upgrade.new_vehicle_modifier(find_id_by_name(item_name))
		if not vehicle_modifier:
			undo_redo_manager.commit_group()
			return
	if property == "energy":
		vehicle_modifier[property] = int(new_text) * 100
	else:
		vehicle_modifier[property] = int(new_text)
	EditorState.selected_tech_upgrade.synchronize(vehicle_modifier, property)
	CurrentMapData.is_saved = false
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()


func modify_weapon(new_text: String, property: String) -> void:
	undo_redo_manager.begin_group("Tech weapon modifier")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	if not weapon_modifier:
		weapon_modifier = EditorState.selected_tech_upgrade.new_weapon_modifier(find_id_by_name(item_name))
		if not weapon_modifier:
			undo_redo_manager.commit_group()
			return
	if property == "energy":
		weapon_modifier[property] = int(new_text) * 100
	else:
		weapon_modifier[property] = int(new_text)
	EditorState.selected_tech_upgrade.synchronize(weapon_modifier, property)
	CurrentMapData.is_saved = false
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()


func update_ui() -> void:
	if vehicle_modifier:
		enable_resistance_checkbox.button_pressed = vehicle_modifier.res_enabled
		enable_ghorkov_checkbox.button_pressed = vehicle_modifier.ghor_enabled
		enable_taerkasten_checkbox.button_pressed = vehicle_modifier.taer_enabled
		enable_mykonian_checkbox.button_pressed = vehicle_modifier.myko_enabled
		enable_sulgogar_checkbox.button_pressed = vehicle_modifier.sulg_enabled
		enable_blacksect_checkbox.button_pressed = vehicle_modifier.blacksect_enabled
		enable_training_checkbox.button_pressed = vehicle_modifier.training_enabled
		
		add_energy_line_edit.text = str(vehicle_modifier.energy / 100)
		add_shield_line_edit.text = str(vehicle_modifier.shield)
		add_weapon_line_edit.text = str(vehicle_modifier.num_weapons)
		add_radar_line_edit.text = str(vehicle_modifier.radar)
	if weapon_modifier:
		add_damage_line_edit.text = str(weapon_modifier.energy / 100)
		add_shot_time_line_edit.text = str(weapon_modifier.shot_time)
		add_shot_time_user_line_edit.text = str(weapon_modifier.shot_time_user)


func find_id_by_name(unit_name: String) -> int:
	for id in EditorState.units_db:
		if EditorState.units_db[id] == unit_name:
			return id
	return -1

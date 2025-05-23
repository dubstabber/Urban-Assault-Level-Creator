extends VBoxContainer

@export var TECH_UPGRADE_MODIFIER_1: PackedScene
@export var TECH_UPGRADE_MODIFIER_2: PackedScene
@export var TECH_UPGRADE_MODIFIER_3: PackedScene

@onready var tu_option_button: Button = %TUOptionButton
@onready var sound_type_option_button: Button = %SoundTypeOptionButton
@onready var tech_upgrade_mbstatus_checkbox: CheckBox = %TechUpgradeMBstatusCheckBox
@onready var tu_modify_option_button: OptionButton = %TUmodifyOptionButton
@onready var tech_upgrade_modifiers_container: Container = %TechUpgradeModifiersContainer
@onready var tu_add_item_button: Button = %TUAddItemButton
@onready var invalid_building_label: Label = %InvalidBuildingLabel


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	tu_option_button.item_selected.connect(func(index: int):
		if EditorState.selected_tech_upgrade:
			var building_id = tu_option_button.get_item_id(index)
			EditorState.selected_tech_upgrade.building_id = building_id
			match building_id:
				60: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 106
				61: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 113
				4: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 100
				7: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 73
				15: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 104
				51: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 101
				50: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 102
				16: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 103
				65: CurrentMapData.typ_map[EditorState.selected_sector_idx] = 110
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = building_id
			EventSystem.map_updated.emit()
		)
	sound_type_option_button.item_selected.connect(func(index: int):
		if EditorState.selected_tech_upgrade:
			EditorState.selected_tech_upgrade.type = sound_type_option_button.get_item_id(index)
			CurrentMapData.is_saved = false
		)
	tech_upgrade_mbstatus_checkbox.toggled.connect(func(toggled_on: bool):
		if EditorState.selected_tech_upgrade:
			if EditorState.selected_tech_upgrade.mb_status != toggled_on:
				CurrentMapData.is_saved = false
			EditorState.selected_tech_upgrade.mb_status = toggled_on
		)
	tu_add_item_button.pressed.connect(func():
		if not EditorState.selected_tech_upgrade: return
		var item_name = tu_modify_option_button.get_item_text(tu_modify_option_button.selected)
		for modifier in tech_upgrade_modifiers_container.get_children():
			if modifier.item_name == item_name: return
		
		# Check if the item is a weapon
		var weapon_id = find_weapon_id_by_name(item_name)
		if weapon_id != -1:
			if TECH_UPGRADE_MODIFIER_3:
				var tu_modifier3 = TECH_UPGRADE_MODIFIER_3.instantiate()
				tu_modifier3.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier3)
			else:
				printerr("TECH_UPGRADE_MODIFIER_3 scene could not be found")
			return

		# Check if the item is a unit
		var unit_id = find_unit_id_by_name(item_name)
		if unit_id != -1:
			if TECH_UPGRADE_MODIFIER_1:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tu_modifier1.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier1)
			else:
				printerr("TECH_UPGRADE_MODIFIER_1 scene could not be found")
			return
		
		
		# Check if the item is a building
		var building_id = find_building_id_by_name(item_name)
		if building_id != -1:
			if TECH_UPGRADE_MODIFIER_2:
				var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
				tu_modifier2.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier2)
			else:
				printerr("TECH_UPGRADE_MODIFIER_2 scene could not be found")
			return
		)


func _update_properties() -> void:
	if EditorState.selected_tech_upgrade:
		show()
		if EditorState.selected_tech_upgrade.building_id == 60 and CurrentMapData.level_set != 5:
			invalid_building_label.show()
		else:
			invalid_building_label.hide()
		
		tu_option_button.select(tu_option_button.get_item_index(EditorState.selected_tech_upgrade.building_id))
		sound_type_option_button.select(sound_type_option_button.get_item_index(EditorState.selected_tech_upgrade.type))
		tech_upgrade_mbstatus_checkbox.button_pressed = EditorState.selected_tech_upgrade.mb_status
		
		tu_modify_option_button.clear()
		for unit_id in EditorState.units_db:
			tu_modify_option_button.add_item(EditorState.units_db[unit_id])
		for building_id in EditorState.buildings_db:
			tu_modify_option_button.add_item(EditorState.buildings_db[building_id])
		for modifier in tech_upgrade_modifiers_container.get_children():
			modifier.queue_free()
		if TECH_UPGRADE_MODIFIER_1:
			for vehicle_modifier in EditorState.selected_tech_upgrade.vehicles:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tech_upgrade_modifiers_container.add_child(tu_modifier1)
				tu_modifier1.vehicle_modifier = vehicle_modifier
				var vehicle_name := ""
				if vehicle_modifier.vehicle_id in EditorState.units_db:
					vehicle_name = EditorState.units_db[vehicle_modifier.vehicle_id]
				tu_modifier1.item_name = "Unknown unit" if vehicle_name.is_empty() else vehicle_name
				
				for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
					if weapon_modifier.weapon_id == vehicle_modifier.vehicle_id:
						tu_modifier1.weapon_modifier = weapon_modifier
				tu_modifier1.update_ui()
		else:
			printerr("TECH_UPGRADE_MODIFIER_1 scene could not be found")
		
		if TECH_UPGRADE_MODIFIER_3:
			for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
				if EditorState.selected_tech_upgrade.vehicles.any(func(vehicle):
					return vehicle.vehicle_id == weapon_modifier.weapon_id):
					continue
				
				# If weapon_modifier is just a weapon then use "TECH_UPGRADE_MODIFIER_3" container
				# else if weapon_modifier is a squad then use "TECH_UPGRADE_MODIFIER_1" container
				var tu_modifier: VBoxContainer = null
				if weapon_modifier.weapon_id in EditorState.weapons_db:
					tu_modifier = TECH_UPGRADE_MODIFIER_3.instantiate()
				else:
					tu_modifier = TECH_UPGRADE_MODIFIER_1.instantiate()

				tech_upgrade_modifiers_container.add_child(tu_modifier)
				tu_modifier.weapon_modifier = weapon_modifier
				var vehicle_name := ""
				if weapon_modifier.weapon_id in EditorState.units_db:
					vehicle_name = EditorState.units_db[weapon_modifier.weapon_id]
				tu_modifier.item_name = "Unknown unit/weapon" if vehicle_name.is_empty() else vehicle_name
				tu_modifier.update_ui()
		else:
			printerr("TECH_UPGRADE_MODIFIER_3 scene could not be found")
		
		if TECH_UPGRADE_MODIFIER_2:
			for building_modifier in EditorState.selected_tech_upgrade.buildings:
				var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
				tech_upgrade_modifiers_container.add_child(tu_modifier2)
				tu_modifier2.building_modifier = building_modifier
				tu_modifier2.item_name = "Unknown building" if not EditorState.buildings_db.has(building_modifier.building_id) else EditorState.buildings_db[building_modifier.building_id]
				tu_modifier2.update_ui()
		else:
			printerr("TECH_UPGRADE_MODIFIER_2 scene could not be found")
	else:
		hide()


# Helper functions for finding IDs by name
func find_unit_id_by_name(unit_name: String) -> int:
	for id in EditorState.units_db:
		if EditorState.units_db[id] == unit_name:
			return id
	return -1


func find_weapon_id_by_name(weapon_name: String) -> int:
	for id in EditorState.weapons_db:
		if EditorState.weapons_db[id] == weapon_name:
			return id
	return -1


func find_building_id_by_name(building_name: String) -> int:
	for id in EditorState.buildings_db:
		if EditorState.buildings_db[id] == building_name:
			return id
	return -1
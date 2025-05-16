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
		
		if item_name in EditorState.weapons_db:
			if TECH_UPGRADE_MODIFIER_3:
				var tu_modifier3 = TECH_UPGRADE_MODIFIER_3.instantiate()
				tu_modifier3.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier3)
			else:
				printerr("TECH_UPGRADE_MODIFIER_3 scene could not be found")
		elif item_name in EditorState.units_db:
			if TECH_UPGRADE_MODIFIER_1:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tu_modifier1.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier1)
			else:
				printerr("TECH_UPGRADE_MODIFIER_1 scene could not be find")
		elif item_name in EditorState.blg_names.values():
			if TECH_UPGRADE_MODIFIER_2:
				var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
				tu_modifier2.item_name = item_name
				tech_upgrade_modifiers_container.add_child(tu_modifier2)
			else:
				printerr("TECH_UPGRADE_MODIFIER_2 scene could not be found")
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
		for unit in EditorState.units_db:
			tu_modify_option_button.add_item(unit)
		for building in EditorState.blg_names:
			tu_modify_option_button.add_item(EditorState.blg_names[building])
		for modifier in tech_upgrade_modifiers_container.get_children():
			modifier.queue_free()
		for vehicle_modifier in EditorState.selected_tech_upgrade.vehicles:
			if TECH_UPGRADE_MODIFIER_1:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tech_upgrade_modifiers_container.add_child(tu_modifier1)
				tu_modifier1.vehicle_modifier = vehicle_modifier
				var vehicle_name := ""
				for unit in EditorState.units_db:
					if EditorState.units_db[unit] == vehicle_modifier.vehicle_id:
						vehicle_name = unit
						break
				
				if vehicle_name.is_empty(): tu_modifier1.item_name = "Unknown unit"
				else: tu_modifier1.item_name = vehicle_name
				
				for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
					if weapon_modifier.weapon_id == vehicle_modifier.vehicle_id:
						tu_modifier1.weapon_modifier = weapon_modifier
				tu_modifier1.update_ui()
			else:
				printerr("TECH_UPGRADE_MODIFIER_1 scene could not be found")
				return
		
		for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
			if EditorState.selected_tech_upgrade.vehicles.any(func(vehicle):
				return vehicle.vehicle_id == weapon_modifier.weapon_id):
					continue
			
			# If weapon_modifier is just a weapon then use "TECH_UPGRADE_MODIFIER_3" container
			# else if weapon_modifier is a squad then use "TECH_UPGRADE_MODIFIER_1" container
			var tu_modifier: VBoxContainer = null
			for weapon_id in EditorState.weapons_db.values():
				if weapon_id == weapon_modifier.weapon_id:
					if TECH_UPGRADE_MODIFIER_3:
						tu_modifier = TECH_UPGRADE_MODIFIER_3.instantiate()
						break
					else:
						printerr("TECH_UPGRADE_MODIFIER_3 scene could not be found")
						return
			if tu_modifier == null:
				if TECH_UPGRADE_MODIFIER_1:
					tu_modifier = TECH_UPGRADE_MODIFIER_1.instantiate()
				else:
					printerr("TECH_UPGRADE_MODIFIER_1 scene could not be found")
					return
			tech_upgrade_modifiers_container.add_child(tu_modifier)
			tu_modifier.weapon_modifier = weapon_modifier
			var vehicle_name := ""
			for unit in EditorState.units_db:
				if EditorState.units_db[unit] == weapon_modifier.weapon_id:
					vehicle_name = unit
					break
			
			if vehicle_name.is_empty(): tu_modifier.item_name = "Unknown unit/weapon"
			else: tu_modifier.item_name = vehicle_name
			tu_modifier.update_ui()
		
		for building_modifier in EditorState.selected_tech_upgrade.buildings:
			if TECH_UPGRADE_MODIFIER_2:
				var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
				tech_upgrade_modifiers_container.add_child(tu_modifier2)
				tu_modifier2.building_modifier = building_modifier
				if EditorState.blg_names.has(building_modifier.building_id):
					tu_modifier2.item_name = EditorState.blg_names[building_modifier.building_id]
				else: tu_modifier2.item_name = "Unknown building"
				tu_modifier2.update_ui()
			else:
				printerr("TECH_UPGRADE_MODIFIER_2 scene could not be found")
				return
	else:
		hide()

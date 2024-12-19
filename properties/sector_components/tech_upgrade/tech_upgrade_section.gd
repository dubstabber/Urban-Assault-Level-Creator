extends VBoxContainer

@export var TECH_UPGRADE_MODIFIER_1: PackedScene
@export var TECH_UPGRADE_MODIFIER_2: PackedScene
@export var TECH_UPGRADE_MODIFIER_3: PackedScene


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	%TUOptionButton.item_selected.connect(func(index: int):
		if EditorState.selected_tech_upgrade:
			var building_id = %TUOptionButton.get_item_id(index)
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
	%SoundTypeOptionButton.item_selected.connect(func(index: int):
		if EditorState.selected_tech_upgrade:
			EditorState.selected_tech_upgrade.type = %SoundTypeOptionButton.get_item_id(index)
			CurrentMapData.is_saved = false
		)
	%TechUpgradeMBstatusCheckBox.toggled.connect(func(toggled_on: bool):
		if EditorState.selected_tech_upgrade:
			EditorState.selected_tech_upgrade.mb_status = toggled_on
			CurrentMapData.is_saved = false
		)
	%TUAddItemButton.pressed.connect(func():
		if not EditorState.selected_tech_upgrade: return
		var item_name = %TUmodifyOptionButton.get_item_text(%TUmodifyOptionButton.selected)
		for modifier in %TechUpgradeModifiersContainer.get_children():
			if modifier.item_name == item_name: return
		
		if item_name in EditorState.weapons_db:
			var tu_modifier3 = TECH_UPGRADE_MODIFIER_3.instantiate()
			tu_modifier3.item_name = item_name
			%TechUpgradeModifiersContainer.add_child(tu_modifier3)
		elif item_name in EditorState.units_db:
			if TECH_UPGRADE_MODIFIER_1:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tu_modifier1.item_name = item_name
				%TechUpgradeModifiersContainer.add_child(tu_modifier1)
			else:
				printerr("TECH_UPGRADE_MODIFIER_1 scene could not be find")
		elif item_name in EditorState.blg_names.values():
			var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
			tu_modifier2.item_name = item_name
			%TechUpgradeModifiersContainer.add_child(tu_modifier2)
		)


func _update_properties() -> void:
	if EditorState.selected_tech_upgrade:
		show()
		if EditorState.selected_tech_upgrade.building_id == 60 and CurrentMapData.level_set != 5:
			%InvalidBuildingLabel.show()
		else:
			%InvalidBuildingLabel.hide()
		
		%TUOptionButton.select(%TUOptionButton.get_item_index(EditorState.selected_tech_upgrade.building_id))
		%SoundTypeOptionButton.select(%SoundTypeOptionButton.get_item_index(EditorState.selected_tech_upgrade.type))
		%TechUpgradeMBstatusCheckBox.button_pressed = EditorState.selected_tech_upgrade.mb_status
		
		%TUmodifyOptionButton.clear()
		for unit in EditorState.units_db:
			%TUmodifyOptionButton.add_item(unit)
		for building in EditorState.blg_names:
			%TUmodifyOptionButton.add_item(EditorState.blg_names[building])
		for modifier in %TechUpgradeModifiersContainer.get_children():
			modifier.queue_free()
		for vehicle_modifier in EditorState.selected_tech_upgrade.vehicles:
			if TECH_UPGRADE_MODIFIER_1:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tu_modifier1.vehicle_modifier = vehicle_modifier
				var vehicle_name: String
				for unit in EditorState.units_db:
					if EditorState.units_db[unit] == vehicle_modifier.vehicle_id:
						vehicle_name = unit
						break
				
				tu_modifier1.item_name = vehicle_name
				for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
					if weapon_modifier.weapon_id == vehicle_modifier.vehicle_id:
						tu_modifier1.weapon_modifier = weapon_modifier
				tu_modifier1.update_ui()
				%TechUpgradeModifiersContainer.add_child(tu_modifier1)
			else:
				printerr("TECH_UPGRADE_MODIFIER_1 scene could not be found")
		
		for weapon_modifier in EditorState.selected_tech_upgrade.weapons:
			if EditorState.selected_tech_upgrade.vehicles.any(func(vehicle):
				return vehicle.vehicle_id == weapon_modifier.weapon_id):
					continue
			
			# If weapon_modifier is just a single weapon then use "TECH_UPGRADE_MODIFIER_3" container
			# else if weapon_modifier is a squad then use "TECH_UPGRADE_MODIFIER_1" container
			var tu_modifier:VBoxContainer = null
			for weapon_id in EditorState.weapons_db.values():
				if weapon_id == weapon_modifier.weapon_id:
					tu_modifier = TECH_UPGRADE_MODIFIER_3.instantiate()
					break
			if tu_modifier == null:
				tu_modifier = TECH_UPGRADE_MODIFIER_1.instantiate()
			
			tu_modifier.weapon_modifier = weapon_modifier
			var vehicle_name: String
			for unit in EditorState.units_db:
				if EditorState.units_db[unit] == weapon_modifier.weapon_id:
					vehicle_name = unit
					break
			
			tu_modifier.item_name = vehicle_name
			tu_modifier.update_ui()
			%TechUpgradeModifiersContainer.add_child(tu_modifier)
		
		for building_modifier in EditorState.selected_tech_upgrade.buildings:
			var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
			tu_modifier2.building_modifier = building_modifier
			tu_modifier2.item_name = EditorState.blg_names[str(building_modifier.building_id)]
			tu_modifier2.update_ui()
			%TechUpgradeModifiersContainer.add_child(tu_modifier2)
	else:
		hide()

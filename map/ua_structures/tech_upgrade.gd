class_name TechUpgrade

var sec_x: int
var sec_y: int
var building_id := 4
var type := 99 # 99 identifies none
var vehicles: Array[ModifyVehicle] = []
var weapons: Array[ModifyWeapon] = []
var buildings: Array[ModifyBuilding] = []
var mb_status := false


func _init(x: int, y: int) -> void:
	sec_x = x
	sec_y = y


func synchronize(modifier, property: String) -> void:
	if vehicles.is_empty() and weapons.is_empty() and buildings.is_empty():
		if modifier is ModifyVehicle:
			vehicles.append(modifier)
			match property:
				'enable':
					var rng = randi_range(0,1)
					if rng: 
						building_id = 4
						CurrentMapData.typ_map[EditorState.selected_sector_idx] = 100
					else: 
						building_id = 7
						CurrentMapData.typ_map[EditorState.selected_sector_idx] = 73
					type = 3
				'energy','shield':
					building_id = 50
					type = 2
					CurrentMapData.typ_map[EditorState.selected_sector_idx] = 102
				'num_weapons':
					building_id = 15
					type = 1
					CurrentMapData.typ_map[EditorState.selected_sector_idx] = 104
				'radar':
					building_id = 15
					type = 5
					CurrentMapData.typ_map[EditorState.selected_sector_idx] = 104
		elif modifier is ModifyWeapon:
			weapons.append(modifier)
			match property:
				'energy':
					var found_weapon := false
					for weapon_id in EditorState.weapons_db.values():
						if weapon_id == modifier.weapon_id:
							found_weapon = true
							break
					if found_weapon:
						building_id = 61
						CurrentMapData.typ_map[EditorState.selected_sector_idx] = 113
					else:
						building_id = 51
						CurrentMapData.typ_map[EditorState.selected_sector_idx] = 101
					type = 1
				'shot_time', 'shot_time_user':
					building_id = 51
					type = 1
					CurrentMapData.typ_map[EditorState.selected_sector_idx] = 101
		elif modifier is ModifyBuilding:
			buildings.append(modifier)
			building_id = 16
			type = 4
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 103
	
	elif modifier is ModifyVehicle and not vehicles.has(modifier):
		vehicles.append(modifier)
	elif modifier is ModifyWeapon and not weapons.has(modifier):
		weapons.append(modifier)
	elif modifier is ModifyBuilding and not buildings.has(modifier):
		buildings.append(modifier)


func new_vehicle_modifier(vehicle_id: int) -> ModifyVehicle:
	if vehicles.any(func(vehicle): return vehicle.vehicle_id == vehicle_id):
		return null
	var vehicle_modifier = ModifyVehicle.new()
	vehicle_modifier.vehicle_id = vehicle_id
	return vehicle_modifier


func new_weapon_modifier(vehicle_id: int) -> ModifyWeapon:
	if weapons.any(func(weapon): return weapon.weapon_id == vehicle_id):
		return null
	var weapon_modifier = ModifyWeapon.new()
	weapon_modifier.weapon_id = vehicle_id
	return weapon_modifier


func new_building_modifier(_building_id: int) -> ModifyBuilding:
	if buildings.any(func(building): return building.building_id == _building_id):
		return null
	var building_modifier = ModifyBuilding.new()
	building_modifier.building_id = _building_id
	return building_modifier


func duplicate_modifiers(modifiers) -> void:
	for modifier in modifiers:
		var duplicated_modifier
		if modifier is ModifyVehicle: duplicated_modifier = ModifyVehicle.new()
		elif modifier is ModifyWeapon: duplicated_modifier = ModifyWeapon.new()
		elif modifier is ModifyBuilding: duplicated_modifier = ModifyBuilding.new()
		var modifier_members = modifier.get_script().get_script_property_list()
		for member in modifier_members:
			if member.name in modifier:
				duplicated_modifier[member.name] = modifier[member.name]
		
		if modifier is ModifyVehicle: vehicles.append(duplicated_modifier)
		elif modifier is ModifyWeapon: weapons.append(duplicated_modifier)
		elif modifier is ModifyBuilding: buildings.append(duplicated_modifier)


class ModifyVehicle:
	var vehicle_id := 0
	var res_enabled := false
	var ghor_enabled := false
	var taer_enabled := false
	var myko_enabled := false
	var sulg_enabled := false
	var blacksect_enabled := false
	var training_enabled := false
	var energy := 0
	var shield := 0
	var num_weapons := 0
	var radar := 0
	var fire_x := 30.0
	var fire_y := 5.0
	var fire_z := 15.0


class ModifyWeapon:
	var weapon_id := 0
	var energy := 0 # damage
	var shot_time := 0
	var shot_time_user := 0


class ModifyBuilding:
	var building_id := 0
	var res_enabled := false
	var ghor_enabled := false
	var taer_enabled := false
	var myko_enabled := false
	var sulg_enabled := false
	var blacksect_enabled := false
	var training_enabled := false

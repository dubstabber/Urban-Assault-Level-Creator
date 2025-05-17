extends HBoxContainer

@export var warning_icon: CompressedTexture2D
@export var no_warning_icon: CompressedTexture2D

@onready var logs_button: Button = %LogsButton


func _ready() -> void:
	EventSystem.warning_logs_updated.connect(func(refresh: bool):
		if refresh: refresh_warnings()
		logs_button.text = "0" if EditorState.warning_messages.is_empty() and EditorState.error_messages.is_empty() else str(EditorState.warning_messages.size() + EditorState.error_messages.size())
		logs_button.icon = no_warning_icon if EditorState.warning_messages.is_empty() and EditorState.error_messages.is_empty() else warning_icon
		)
	logs_button.pressed.connect(func():
		EventSystem.warning_logs_window_requested.emit()
		)
	EventSystem.map_created.connect(refresh_warnings)


func refresh_warnings() -> void:
	EditorState.warning_messages.clear()
	EditorState.error_messages.clear()
	
	# Check map sectors
	var idx := 0
	# Common building IDs that are valid but not in buildings_db
	var common_valid_buildings = [0, 5, 6, 25, 26, 60, 61, 4, 7, 15, 51, 50, 16, 65, 35, 36, 37, 68, 69, 70]
	for y in CurrentMapData.vertical_sectors:
		for x in CurrentMapData.horizontal_sectors:
			if CurrentMapData.own_map[idx] > 7:
				EditorState.warning_messages.append('Detected an invalid own_map value "%s (0x%x)" at X:%s, Y:%s' %
					[CurrentMapData.own_map[idx], CurrentMapData.own_map[idx], x + 1, y + 1])
			
			
			if CurrentMapData.blg_map[idx] not in EditorState.buildings_db and CurrentMapData.blg_map[idx] not in common_valid_buildings:
				EditorState.warning_messages.append('Detected an unknown blg_map value "%s (0x%x)" at X:%s, Y:%s' %
					[CurrentMapData.blg_map[idx], CurrentMapData.blg_map[idx], x + 1, y + 1])
			
			idx += 1
	
	# Check host stations
	for hoststation: HostStation in CurrentMapData.host_stations.get_children():
		if hoststation.owner_id < 1 or hoststation.owner_id > 7:
			EditorState.error_messages.append('Invalid host station detected with owner ID "%s" at x:%s, z:-%s' %
				[hoststation.owner_id, roundi(hoststation.position.x), roundi(hoststation.position.y)])
	
	# Check squads
	for squad: Squad in CurrentMapData.squads.get_children():
		if squad.owner_id < 1 or squad.owner_id > 7:
			EditorState.warning_messages.append('Invalid squad detected with owner ID "%s" at x:%s, z:-%s' %
				[squad.owner_id, roundi(squad.position.x), roundi(squad.position.y)])
		
		if squad.vehicle not in EditorState.units_db:
			EditorState.warning_messages.append('Detected an unknown squad with vehicle ID "%s" at x:%s, y:-%s' %
				[squad.vehicle, roundi(squad.position.x), roundi(squad.position.y)])
	
	# Check tech upgrades
	for tech_upgrade: TechUpgrade in CurrentMapData.tech_upgrades:
		# Check vehicles in tech upgrade
		for vehicle_modifier in tech_upgrade.vehicles:
			if vehicle_modifier.vehicle_id not in EditorState.units_db:
				EditorState.warning_messages.append('Detected an unknown unit in the tech upgrade at X:%s, Y:%s with vehicle ID "%s"' %
					[tech_upgrade.sec_x, tech_upgrade.sec_y, vehicle_modifier.vehicle_id])
		
		# Check buildings in tech upgrade
		for building_modifier in tech_upgrade.buildings:
			if building_modifier.building_id not in EditorState.buildings_db:
				EditorState.warning_messages.append('Detected an unknown building in the tech upgrade at X:%s, Y:%s with building ID "%s"' %
					[tech_upgrade.sec_x, tech_upgrade.sec_y, building_modifier.building_id])
		
		# Check weapons in tech upgrade
		for weapon_modifier in tech_upgrade.weapons:
			if weapon_modifier.weapon_id not in EditorState.weapons_db and weapon_modifier.weapon_id not in EditorState.units_db:
				EditorState.warning_messages.append('Detected an unknown weapon in the tech upgrade at X:%s, Y:%s with weapon ID "%s"' %
					[tech_upgrade.sec_x, tech_upgrade.sec_y, weapon_modifier.weapon_id])
	
	# Check enabled units for each faction
	var faction_units = {
		"resistance": CurrentMapData.resistance_enabled_units,
		"ghorkov": CurrentMapData.ghorkov_enabled_units,
		"taerkasten": CurrentMapData.taerkasten_enabled_units,
		"mykonian": CurrentMapData.mykonian_enabled_units,
		"sulgogar": CurrentMapData.sulgogar_enabled_units,
		"black sect": CurrentMapData.blacksect_enabled_units,
		"training": CurrentMapData.training_enabled_units
	}
	
	for faction_name in faction_units:
		check_enabled_units(faction_name, faction_units[faction_name])
	
	# Check enabled buildings for each faction
	var faction_buildings = {
		"resistance": CurrentMapData.resistance_enabled_buildings,
		"ghorkov": CurrentMapData.ghorkov_enabled_buildings,
		"taerkasten": CurrentMapData.taerkasten_enabled_buildings,
		"mykonian": CurrentMapData.mykonian_enabled_buildings,
		"sulgogar": CurrentMapData.sulgogar_enabled_buildings,
		"black sect": CurrentMapData.blacksect_enabled_buildings,
		"training": CurrentMapData.training_enabled_buildings
	}
	
	for faction_name in faction_buildings:
		check_enabled_buildings(faction_name, faction_buildings[faction_name])
	
	# Check unknown enabled entities
	for unit_data in CurrentMapData.unknown_enabled_units:
		EditorState.warning_messages.append('Detected an unknown owner ID "%s" in enabler for unit ID "%s"' %
			[unit_data.owner_id, unit_data.vehicle_id])
	
	for building_data in CurrentMapData.unknown_enabled_buildings:
		EditorState.warning_messages.append('Detected an unknown owner ID "%s" in enabler for building ID "%s"' %
			[building_data.owner_id, building_data.building_id])
	

func check_enabled_units(faction_name: String, unit_array: Array) -> void:
	for unit_id in unit_array:
		if unit_id not in EditorState.units_db:
			EditorState.warning_messages.append('Detected an unknown enabled unit for %s with vehicle ID "%s"' % [faction_name, unit_id])


func check_enabled_buildings(faction_name: String, building_array: Array) -> void:
	for building_id in building_array:
		if building_id not in EditorState.buildings_db:
			EditorState.warning_messages.append('Detected an unknown enabled building for %s with building ID "%s"' % [faction_name, building_id])
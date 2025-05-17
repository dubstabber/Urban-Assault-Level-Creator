extends Node

enum States {
	Select,
	TypMapDesign
}

var game_data_type: String:
	set(value):
		game_data_type = value
		EventSystem.game_type_changed.emit()
		EventSystem.map_updated.emit()


var mode: States = States.Select:
	set(value):
		mode = value
		EventSystem.editor_mode_changed.emit()

var selected_typ_map: int

var typ_map_images_visible := true:
	set(value):
		typ_map_images_visible = value
		EventSystem.map_view_updated.emit()
var typ_map_values_visible := false:
	set(value):
		typ_map_values_visible = value
		EventSystem.map_view_updated.emit()
var own_map_values_visible := false:
	set(value):
		own_map_values_visible = value
		EventSystem.map_view_updated.emit()
var hgt_map_values_visible := false:
	set(value):
		hgt_map_values_visible = value
		EventSystem.map_view_updated.emit()
var blg_map_values_visible := false:
	set(value):
		blg_map_values_visible = value
		EventSystem.map_view_updated.emit()

var selected_unit: Unit = null:
	set(value):
		selected_unit = value
		EventSystem.unit_selected.emit()
var selected_sector_idx: int = -1
var border_selected_sector_idx: int = -1
var selected_sector: Vector2i = Vector2i(-1, -1)
var selected_sectors: Array[Dictionary] = []
var selected_beam_gate: BeamGate = null
var selected_bomb: StoudsonBomb = null
var selected_tech_upgrade: TechUpgrade = null
var selected_bg_key_sector: Vector2i = Vector2i(-1, -1)
var selected_bomb_key_sector: Vector2i = Vector2i(-1, -1)

var mouse_over_unit: Unit = null

var sector_clipboard := {
	typ_map = -1,
	own_map = -1,
	blg_map = -1,
	beam_gate = null,
	stoudson_bomb = null,
	tech_upgrade = null,
	bg_key_sector_parent = null,
	bomb_key_sector_parent = null
}

var units_db := {}
var buildings_db := {}
var weapons_db := {}

var error_messages: Array[String] = []
var warning_messages: Array[String] = []


func _ready():
	if not Preloads.ua_data.data.has("original"): return
	game_data_type = Preloads.ua_data.data.keys()[0]
	reload()
	EventSystem.game_type_changed.connect(reload)
	EventSystem.map_created.connect(refresh_warnings)


func reload() -> void:
	# Cache commonly accessed data paths
	var game_data = Preloads.ua_data.data[game_data_type]
	var briefing_maps = game_data.missionBriefingMaps
	var debriefing_maps = game_data.missionDebriefingMaps
	
	# Validate and set map references
	if not (CurrentMapData.briefing_map in briefing_maps or CurrentMapData.briefing_map in debriefing_maps):
		CurrentMapData.briefing_map = briefing_maps[0]
		
	if not (CurrentMapData.debriefing_map in debriefing_maps or CurrentMapData.debriefing_map in briefing_maps):
		CurrentMapData.debriefing_map = debriefing_maps[0]
	
	# Clear databases
	units_db.clear()
	buildings_db.clear()
	weapons_db.clear()
	
	# Process hoststations if they exist
	if game_data.has("hoststations"):
		var hoststations = game_data.hoststations
		var host_station_children = [] if not CurrentMapData.host_stations else CurrentMapData.host_stations.get_children()

		var vehicle_to_hoststation = {}
		for hss in host_station_children:
			vehicle_to_hoststation[hss.vehicle] = hss

		for hs in hoststations:
			var hoststation_data = hoststations[hs]
			for robo in hoststation_data.robos:
				if robo.id in vehicle_to_hoststation:
					vehicle_to_hoststation[robo.id].player_vehicle = robo.get("player_id", -1)
			for unit in hoststation_data.units:
				units_db[int(unit.id)] = unit.name
			for building in hoststation_data.buildings:
				buildings_db[int(building.id)] = building.name
	
	# Process other buildings and units
	for building in game_data.other.buildings:
		buildings_db[int(building.id)] = building.name
	
	for unit in game_data.other.units:
		units_db[int(unit.id)] = unit.name
	
	# Process tech upgrades (weapons)
	for weapon in game_data.techUpgrade:
		var weapon_id = int(weapon.id)
		units_db[weapon_id] = weapon.name
		weapons_db[weapon_id] = weapon.name


func unselect_all() -> void:
	selected_unit = null
	selected_sector_idx = -1
	border_selected_sector_idx = -1
	selected_sector = Vector2i(-1, -1)
	selected_sectors.clear()
	selected_beam_gate = null
	selected_bomb = null
	selected_tech_upgrade = null
	selected_bg_key_sector = Vector2i(-1, -1)
	selected_bomb_key_sector = Vector2i(-1, -1)


func check_enabled_units(faction_name: String, unit_array: Array) -> void:
	for unit_id in unit_array:
		if unit_id not in units_db:
			warning_messages.append('Detected an unknown enabled unit for %s with vehicle ID "%s"' % [faction_name, unit_id])


func check_enabled_buildings(faction_name: String, building_array: Array) -> void:
	for building_id in building_array:
		if building_id not in buildings_db:
			warning_messages.append('Detected an unknown enabled building for %s with building ID "%s"' % [faction_name, building_id])


func refresh_warnings() -> void:
	warning_messages.clear()
	error_messages.clear()
	
	# Check map sectors
	var idx := 0
	# Common building IDs that are valid but not in buildings_db
	var common_valid_buildings = [0, 5, 6, 25, 26, 60, 61, 4, 7, 15, 51, 50, 16, 65, 35, 36, 37, 68, 69, 70]
	for y in CurrentMapData.vertical_sectors:
		for x in CurrentMapData.horizontal_sectors:
			if CurrentMapData.own_map[idx] > 7:
				warning_messages.append('Detected an invalid own_map value "%s (0x%x)" at X:%s, Y:%s' %
					[CurrentMapData.own_map[idx], CurrentMapData.own_map[idx], x + 1, y + 1])
			
			
			if CurrentMapData.blg_map[idx] not in buildings_db and CurrentMapData.blg_map[idx] not in common_valid_buildings:
				warning_messages.append('Detected an unknown blg_map value "%s (0x%x)" at X:%s, Y:%s' %
					[CurrentMapData.blg_map[idx], CurrentMapData.blg_map[idx], x + 1, y + 1])
			
			idx += 1
	
	# Check host stations
	for hoststation: HostStation in CurrentMapData.host_stations.get_children():
		if hoststation.owner_id < 1 or hoststation.owner_id > 7:
			error_messages.append('Invalid host station detected with owner ID "%s" at x:%s, z:-%s' %
				[hoststation.owner_id, roundi(hoststation.position.x), roundi(hoststation.position.y)])
	
	# Check squads
	for squad: Squad in CurrentMapData.squads.get_children():
		if squad.owner_id < 1 or squad.owner_id > 7:
			warning_messages.append('Invalid squad detected with owner ID "%s" at x:%s, z:-%s' %
				[squad.owner_id, roundi(squad.position.x), roundi(squad.position.y)])
		
		if squad.vehicle not in units_db:
			warning_messages.append('Detected an unknown squad with vehicle ID "%s" at x:%s, y:-%s' %
				[squad.vehicle, roundi(squad.position.x), roundi(squad.position.y)])
	
	# Check tech upgrades
	for tech_upgrade: TechUpgrade in CurrentMapData.tech_upgrades:
		# Check vehicles in tech upgrade
		for vehicle_modifier in tech_upgrade.vehicles:
			if vehicle_modifier.vehicle_id not in units_db:
				warning_messages.append('Detected an unknown unit in the tech upgrade at X:%s, Y:%s with vehicle ID "%s"' %
					[tech_upgrade.sec_x, tech_upgrade.sec_y, vehicle_modifier.vehicle_id])
		
		# Check buildings in tech upgrade
		for building_modifier in tech_upgrade.buildings:
			if building_modifier.building_id not in buildings_db:
				warning_messages.append('Detected an unknown building in the tech upgrade at X:%s, Y:%s with building ID "%s"' %
					[tech_upgrade.sec_x, tech_upgrade.sec_y, building_modifier.building_id])
		
		# Check weapons in tech upgrade
		for weapon_modifier in tech_upgrade.weapons:
			if weapon_modifier.weapon_id not in weapons_db and weapon_modifier.weapon_id not in units_db:
				warning_messages.append('Detected an unknown weapon in the tech upgrade at X:%s, Y:%s with weapon ID "%s"' %
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
		warning_messages.append('Detected an unknown owner ID "%s" in enabler for unit ID "%s"' %
			[unit_data.owner_id, unit_data.vehicle_id])
	
	for building_data in CurrentMapData.unknown_enabled_buildings:
		warning_messages.append('Detected an unknown owner ID "%s" in enabler for building ID "%s"' %
			[building_data.owner_id, building_data.building_id])
	
	EventSystem.warning_logs_updated.emit()

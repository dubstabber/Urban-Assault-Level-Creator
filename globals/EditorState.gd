extends Node

enum States {
	Select,
	TypMapDesign
}

var game_data_type:String:
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
var blg_names := {}
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
	if (not CurrentMapData.briefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps and
		not CurrentMapData.briefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps):
		CurrentMapData.briefing_map = Preloads.ua_data.data[game_data_type].missionBriefingMaps[0]
	if (not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_data_type].missionDebriefingMaps and 
		not CurrentMapData.debriefing_map in Preloads.ua_data.data[game_data_type].missionBriefingMaps):
		CurrentMapData.debriefing_map = Preloads.ua_data.data[game_data_type].missionDebriefingMaps[0]
	
	units_db.clear()
	blg_names.clear()
	weapons_db.clear()
	
	if Preloads.ua_data.data[game_data_type].has("hoststations"):
		for hs in Preloads.ua_data.data[game_data_type].hoststations:
			for robo: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].robos:
				if CurrentMapData.host_stations:
					for hss: HostStation in CurrentMapData.host_stations.get_children():
						if hss.vehicle == robo.id:
							if "player_id" in robo:
								hss.player_vehicle = robo.player_id
							else:
								hss.player_vehicle = -1
			for unit: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].units:
				units_db[unit.name] = int(unit.id)
			for building: Dictionary in Preloads.ua_data.data[game_data_type].hoststations[hs].buildings:
				blg_names[str(building.id)] = building.name
	for building: Dictionary in Preloads.ua_data.data[game_data_type].other.buildings:
		blg_names[str(building.id)] = building.name
	for unit: Dictionary in Preloads.ua_data.data[game_data_type].other.units:
		units_db[unit.name] = int(unit.id)
	for weapon in Preloads.ua_data.data[game_data_type].techUpgrade:
		units_db[weapon.name] = int(weapon.id)
		weapons_db[weapon.name] = int(weapon.id)


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


func refresh_warnings() -> void:
	warning_messages.clear()
	error_messages.clear()
	var idx := 0
	for y in CurrentMapData.vertical_sectors:
		for x in CurrentMapData.horizontal_sectors:
			if CurrentMapData.own_map[idx] > 7:
				warning_messages.append('Detected an invalid own_map value "%s (0x%x)" at X:%s, Y:%s' % [CurrentMapData.own_map[idx], CurrentMapData.own_map[idx], x+1, y+1])
			if str(CurrentMapData.blg_map[idx]) not in blg_names and CurrentMapData.blg_map[idx] not in [0, 5, 6, 25, 26, 60, 61, 4, 7, 15, 51, 50, 16, 65, 35, 36, 37, 68, 69, 70]:
				warning_messages.append('Detected an unknown blg_map value "%s (0x%x)" at X:%s, Y:%s' % [CurrentMapData.blg_map[idx], CurrentMapData.blg_map[idx], x+1, y+1])
			idx += 1
	
	for hoststation: HostStation in CurrentMapData.host_stations.get_children():
		if hoststation.owner_id < 1 or hoststation.owner_id > 7:
			error_messages.append('Invalid host station detected with owner ID "%s" at x:%s, z:-%s' % [hoststation.owner_id, hoststation.position.x, hoststation.position.y])
	
	for squad: Squad in CurrentMapData.squads.get_children():
		if squad.owner_id < 1 or squad.owner_id > 7:
			warning_messages.append('Invalid squad detected with owner ID "%s" at x:%s, z:-%s' % [squad.owner_id, squad.position.x, squad.position.y])
		if squad.vehicle not in units_db.values():
			warning_messages.append('Detected an unknown squad with vehicle ID "%s" at x:%s, y:-%s' % [squad.vehicle, squad.position.x, squad.position.y])
	
	for tech_upgrade: TechUpgrade in CurrentMapData.tech_upgrades:
		for vehicle_modifier in tech_upgrade.vehicles:
			if vehicle_modifier.vehicle_id not in units_db.values():
				warning_messages.append('Detected an unknown unit in the tech upgrade at X:%s, Y:%s with vehicle ID "%s"' % [tech_upgrade.sec_x, tech_upgrade.sec_y, vehicle_modifier.vehicle_id])
		for building_modifier in tech_upgrade.buildings:
			if str(building_modifier.building_id) not in blg_names:
				warning_messages.append('Detected an unknown building in the tech upgrade at X:%s, Y:%s with building ID "%s"' % [tech_upgrade.sec_x, tech_upgrade.sec_y, building_modifier.building_id])
		for weapon_modifier in tech_upgrade.weapons:
			if weapon_modifier.weapon_id not in weapons_db.values() and weapon_modifier.weapon_id not in units_db.values():
				warning_messages.append('Detected an unknown weapon in the tech upgrade at X:%s, Y:%s with weapon ID "%s"' % [tech_upgrade.sec_x, tech_upgrade.sec_y, weapon_modifier.weapon_id])
	
	for unit_id in CurrentMapData.resistance_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for resistance with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.ghorkov_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for ghorkov with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.taerkasten_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for taerkasten with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.mykonian_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for mykonian with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.sulgogar_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for sulgogar with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.blacksect_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for black sect with vehicle ID "%s"' % unit_id)
	for unit_id in CurrentMapData.training_enabled_units:
		if unit_id not in units_db.values():
			warning_messages.append('Detected an unknown enabled unit for training with vehicle ID "%s"' % unit_id)
	
	for building_id in CurrentMapData.resistance_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for resistance with building ID "%s"' % building_id)
	for building_id in CurrentMapData.ghorkov_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for ghorkov with building ID "%s"' % building_id)
	for building_id in CurrentMapData.taerkasten_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for taerkasten with building ID "%s"' % building_id)
	for building_id in CurrentMapData.mykonian_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for mykonian with building ID "%s"' % building_id)
	for building_id in CurrentMapData.sulgogar_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for sulgogar with building ID "%s"' % building_id)
	for building_id in CurrentMapData.blacksect_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for black sect with building ID "%s"' % building_id)
	for building_id in CurrentMapData.training_enabled_buildings:
		if str(building_id) not in blg_names:
			warning_messages.append('Detected an unknown enabled building for training with building ID "%s"' % building_id)
	
	EventSystem.warning_logs_updated.emit()

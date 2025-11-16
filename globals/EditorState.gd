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
		for hs in hoststations:
			var hoststation_data = hoststations[hs]
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

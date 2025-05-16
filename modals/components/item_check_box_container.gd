@tool
extends HBoxContainer

@export var item_texture: Texture2D
@export var label_text: String

var item_type: String
var owner_id: int
var item_id: int

@onready var unit_texture: TextureRect = $UnitTexture
@onready var unit_check_box: CheckBox = $UnitCheckBox


func _ready() -> void:
	if item_texture:
		unit_texture.texture = item_texture
	if label_text:
		unit_check_box.text = label_text
	
	if item_type == "squad":
		match owner_id:
			1: unit_check_box.button_pressed = CurrentMapData.resistance_enabled_units.has(item_id)
			2: unit_check_box.button_pressed = CurrentMapData.sulgogar_enabled_units.has(item_id)
			3: unit_check_box.button_pressed = CurrentMapData.mykonian_enabled_units.has(item_id)
			4: unit_check_box.button_pressed = CurrentMapData.taerkasten_enabled_units.has(item_id)
			5: unit_check_box.button_pressed = CurrentMapData.blacksect_enabled_units.has(item_id)
			6: unit_check_box.button_pressed = CurrentMapData.ghorkov_enabled_units.has(item_id)
			7: unit_check_box.button_pressed = CurrentMapData.training_enabled_units.has(item_id)
	elif item_type == "building":
		match owner_id:
			1: unit_check_box.button_pressed = CurrentMapData.resistance_enabled_buildings.has(item_id)
			2: unit_check_box.button_pressed = CurrentMapData.sulgogar_enabled_buildings.has(item_id)
			3: unit_check_box.button_pressed = CurrentMapData.mykonian_enabled_buildings.has(item_id)
			4: unit_check_box.button_pressed = CurrentMapData.taerkasten_enabled_buildings.has(item_id)
			5: unit_check_box.button_pressed = CurrentMapData.blacksect_enabled_buildings.has(item_id)
			6: unit_check_box.button_pressed = CurrentMapData.ghorkov_enabled_buildings.has(item_id)
			7: unit_check_box.button_pressed = CurrentMapData.training_enabled_buildings.has(item_id)

	unit_check_box.toggled.connect(enable_item)


func enable_item(toggled: bool) -> void:
	if toggled:
		if item_type == "squad":
			match owner_id:
				1: CurrentMapData.resistance_enabled_units.append(item_id)
				2: CurrentMapData.sulgogar_enabled_units.append(item_id)
				3: CurrentMapData.mykonian_enabled_units.append(item_id)
				4: CurrentMapData.taerkasten_enabled_units.append(item_id)
				5: CurrentMapData.blacksect_enabled_units.append(item_id)
				6: CurrentMapData.ghorkov_enabled_units.append(item_id)
				7: CurrentMapData.training_enabled_units.append(item_id)
		elif item_type == "building":
			match owner_id:
				1: CurrentMapData.resistance_enabled_buildings.append(item_id)
				2: CurrentMapData.sulgogar_enabled_buildings.append(item_id)
				3: CurrentMapData.mykonian_enabled_buildings.append(item_id)
				4: CurrentMapData.taerkasten_enabled_buildings.append(item_id)
				5: CurrentMapData.blacksect_enabled_buildings.append(item_id)
				6: CurrentMapData.ghorkov_enabled_buildings.append(item_id)
				7: CurrentMapData.training_enabled_buildings.append(item_id)
	else:
		if item_type == "squad":
			match owner_id:
				1: CurrentMapData.resistance_enabled_units.erase(item_id)
				2: CurrentMapData.sulgogar_enabled_units.erase(item_id)
				3: CurrentMapData.mykonian_enabled_units.erase(item_id)
				4: CurrentMapData.taerkasten_enabled_units.erase(item_id)
				5: CurrentMapData.blacksect_enabled_units.erase(item_id)
				6: CurrentMapData.ghorkov_enabled_units.erase(item_id)
				7: CurrentMapData.training_enabled_units.erase(item_id)
		elif item_type == "building":
			match owner_id:
				1: CurrentMapData.resistance_enabled_buildings.erase(item_id)
				2: CurrentMapData.sulgogar_enabled_buildings.erase(item_id)
				3: CurrentMapData.mykonian_enabled_buildings.erase(item_id)
				4: CurrentMapData.taerkasten_enabled_buildings.erase(item_id)
				5: CurrentMapData.blacksect_enabled_buildings.erase(item_id)
				6: CurrentMapData.ghorkov_enabled_buildings.erase(item_id)
				7: CurrentMapData.training_enabled_buildings.erase(item_id)
	CurrentMapData.is_saved = false


func change_button_availability(state: bool, enabler_owner: int) -> void:
	if enabler_owner != owner_id:
		unit_check_box.disabled = state

@tool
extends HBoxContainer

@export var item_texture: Texture2D
@export var label_text: String

var item_type: String
var owner_id: int
var item_id: int


func _ready() -> void:
	if item_texture:
		$UnitTexture.texture = item_texture
	if label_text:
		$UnitCheckBox.text = label_text
	
	if item_type == "squad":
		match owner_id:
			1: $UnitCheckBox.button_pressed = CurrentMapData.resistance_enabled_units.has(item_id)
			2: $UnitCheckBox.button_pressed = CurrentMapData.sulgogar_enabled_units.has(item_id)
			3: $UnitCheckBox.button_pressed = CurrentMapData.mykonian_enabled_units.has(item_id)
			4: $UnitCheckBox.button_pressed = CurrentMapData.taerkasten_enabled_units.has(item_id)
			5: $UnitCheckBox.button_pressed = CurrentMapData.blacksect_enabled_units.has(item_id)
			6: $UnitCheckBox.button_pressed = CurrentMapData.ghorkov_enabled_units.has(item_id)
			7: $UnitCheckBox.button_pressed = CurrentMapData.training_enabled_units.has(item_id)
	elif item_type == "building":
		match owner_id: 
			1: $UnitCheckBox.button_pressed = CurrentMapData.resistance_enabled_buildings.has(item_id)
			2: $UnitCheckBox.button_pressed = CurrentMapData.sulgogar_enabled_buildings.has(item_id)
			3: $UnitCheckBox.button_pressed = CurrentMapData.mykonian_enabled_buildings.has(item_id)
			4: $UnitCheckBox.button_pressed = CurrentMapData.taerkasten_enabled_buildings.has(item_id)
			5: $UnitCheckBox.button_pressed = CurrentMapData.blacksect_enabled_buildings.has(item_id)
			6: $UnitCheckBox.button_pressed = CurrentMapData.ghorkov_enabled_buildings.has(item_id)
			7: $UnitCheckBox.button_pressed = CurrentMapData.training_enabled_buildings.has(item_id)

	$UnitCheckBox.toggled.connect(enable_item)


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
		$UnitCheckBox.disabled = state

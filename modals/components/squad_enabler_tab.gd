extends TabBar

@export var ITEM_CHECK_BOX_CONTAINER: PackedScene
@export var host_station_owner_id: int

@onready var resistance_units_container: Container = %ResistanceUnitsContainer
@onready var resistance_buildings_container: Container = %ResistanceBuildingsContainer
@onready var ghorkov_units_container: Container = %GhorkovUnitsContainer
@onready var ghorkov_buildings_container: Container = %GhorkovBuildingsContainer
@onready var taerkasten_units_container: Container = %TaerkastenUnitsContainer
@onready var taerkasten_buildings_container: Container = %TaerkastenBuildingsContainer
@onready var mykonian_units_container: Container = %MykonianUnitsContainer
@onready var mykonian_buildings_container: Container = %MykonianBuildingsContainer
@onready var sulgogar_units_container: Container = %SulgogarUnitsContainer
@onready var blacksect_buildings_container: Container = %BlackSectBuildingsContainer
@onready var training_units_container: Container = %TrainingUnitsContainer
@onready var misc_units_container: Container = %MiscUnitsContainer
@onready var misc_buildings_container: Container = %MiscBuildingsContainer

@onready var unlock_items_check_box: CheckBox = %UnlockItemsCheckBox


func refresh() -> void:
	for child in resistance_units_container.get_children(): child.queue_free()
	for child in resistance_buildings_container.get_children(): child.queue_free()
	for child in ghorkov_units_container.get_children(): child.queue_free()
	for child in ghorkov_buildings_container.get_children(): child.queue_free()
	for child in taerkasten_units_container.get_children(): child.queue_free()
	for child in taerkasten_buildings_container.get_children(): child.queue_free()
	for child in mykonian_units_container.get_children(): child.queue_free()
	for child in mykonian_buildings_container.get_children(): child.queue_free()
	for child in sulgogar_units_container.get_children(): child.queue_free()
	for child in blacksect_buildings_container.get_children(): child.queue_free()
	for child in training_units_container.get_children(): child.queue_free()
	for child in misc_units_container.get_children(): child.queue_free()
	for child in misc_buildings_container.get_children(): child.queue_free()
	
	if ITEM_CHECK_BOX_CONTAINER == null: return
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		for squad in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].units:
			var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
			
			var squad_id = int(squad.id)
			item_check_box.item_texture = Preloads.squad_images[squad_id]
			item_check_box.label_text = squad.name
			item_check_box.item_type = "squad"
			item_check_box.owner_id = host_station_owner_id
			item_check_box.item_id = squad_id
			match hs:
				"Resistance": resistance_units_container.add_child(item_check_box)
				"Ghorkov": ghorkov_units_container.add_child(item_check_box)
				"Taerkasten": taerkasten_units_container.add_child(item_check_box)
				"Mykonian": mykonian_units_container.add_child(item_check_box)
				"Sulgogar": sulgogar_units_container.add_child(item_check_box)
				"Training": training_units_container.add_child(item_check_box)
			item_check_box.change_button_availability(true, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
			
		for building in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
			item_check_box.item_texture = Preloads.building_icons[building.icon_type]
			item_check_box.label_text = building.name
			item_check_box.item_type = "building"
			item_check_box.owner_id = host_station_owner_id
			item_check_box.item_id = int(building.id)
			match hs:
				"Resistance": resistance_buildings_container.add_child(item_check_box)
				"Ghorkov": ghorkov_buildings_container.add_child(item_check_box)
				"Taerkasten": taerkasten_buildings_container.add_child(item_check_box)
				"Mykonian": mykonian_buildings_container.add_child(item_check_box)
				"BlackSect": blacksect_buildings_container.add_child(item_check_box)
			item_check_box.change_button_availability(true, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
			
	for squad in Preloads.ua_data.data[EditorState.game_data_type].other.units:
		var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
		var squad_id = int(squad.id)
		item_check_box.item_texture = Preloads.squad_images[squad_id]
		item_check_box.label_text = squad.name
		item_check_box.item_type = "squad"
		item_check_box.owner_id = host_station_owner_id
		item_check_box.item_id = squad_id
		misc_units_container.add_child(item_check_box)
		item_check_box.change_button_availability(true, 0)
	for building in Preloads.ua_data.data[EditorState.game_data_type].other.buildings:
		var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
		var building_id = int(building.id)
		item_check_box.item_texture = Preloads.building_icons[building.icon_type]
		item_check_box.label_text = building.name
		item_check_box.item_type = "building"
		item_check_box.owner_id = host_station_owner_id
		item_check_box.item_id = building_id
		misc_buildings_container.add_child(item_check_box)
		item_check_box.change_button_availability(true, 0)
		
	unlock_items_check_box.button_pressed = false


func _on_unlock_items_check_box_toggled(toggled_on: bool) -> void:
		for item_check_box in resistance_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 1)
		for item_check_box in resistance_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 1)
		for item_check_box in ghorkov_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 6)
		for item_check_box in ghorkov_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 6)
		for item_check_box in taerkasten_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 4)
		for item_check_box in taerkasten_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 4)
		for item_check_box in mykonian_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 3)
		for item_check_box in mykonian_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 3)
		for item_check_box in sulgogar_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 2)
		for item_check_box in blacksect_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 5)
		for item_check_box in training_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 7)
		for item_check_box in misc_units_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 0)
		for item_check_box in misc_buildings_container.get_children():
			item_check_box.change_button_availability(not toggled_on, 0)

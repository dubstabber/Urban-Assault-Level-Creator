extends TabBar

@export var ITEM_CHECK_BOX_CONTAINER: PackedScene
@export var host_station_owner_id: int


func refresh() -> void:
	for child in %ResistanceUnitsContainer.get_children(): child.queue_free()
	for child in %ResistanceBuildingsContainer.get_children(): child.queue_free()
	for child in %GhorkovUnitsContainer.get_children(): child.queue_free()
	for child in %GhorkovBuildingsContainer.get_children(): child.queue_free()
	for child in %TaerkastenUnitsContainer.get_children(): child.queue_free()
	for child in %TaerkastenBuildingsContainer.get_children(): child.queue_free()
	for child in %MykonianUnitsContainer.get_children(): child.queue_free()
	for child in %MykonianBuildingsContainer.get_children(): child.queue_free()
	for child in %SulgogarUnitsContainer.get_children(): child.queue_free()
	for child in %BlackSectBuildingsContainer.get_children(): child.queue_free()
	for child in %TrainingUnitsContainer.get_children(): child.queue_free()
	for child in %MiscUnitsContainer.get_children(): child.queue_free()
	for child in %MiscBuildingsContainer.get_children(): child.queue_free()
	
	if ITEM_CHECK_BOX_CONTAINER == null: return
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		for squad in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].units:
			var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
			item_check_box.item_texture = Preloads.squad_images[str(squad.id)]
			item_check_box.label_text = squad.name
			item_check_box.item_type = "squad"
			item_check_box.owner_id = host_station_owner_id
			item_check_box.item_id = squad.id
			item_check_box.change_button_availability(true, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
			match hs:
				"Resistance": %ResistanceUnitsContainer.add_child(item_check_box)
				"Ghorkov": %GhorkovUnitsContainer.add_child(item_check_box)
				"Taerkasten": %TaerkastenUnitsContainer.add_child(item_check_box)
				"Mykonian": %MykonianUnitsContainer.add_child(item_check_box)
				"Sulgogar": %SulgogarUnitsContainer.add_child(item_check_box)
				"Training": %TrainingUnitsContainer.add_child(item_check_box)
		for building in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].buildings:
			var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
			item_check_box.item_texture = Preloads.building_icons[building.icon_type]
			item_check_box.label_text = building.name
			item_check_box.item_type = "building"
			item_check_box.owner_id = host_station_owner_id
			item_check_box.item_id = building.id
			item_check_box.change_button_availability(true, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
			match hs:
				"Resistance": %ResistanceBuildingsContainer.add_child(item_check_box)
				"Ghorkov": %GhorkovBuildingsContainer.add_child(item_check_box)
				"Taerkasten": %TaerkastenBuildingsContainer.add_child(item_check_box)
				"Mykonian": %MykonianBuildingsContainer.add_child(item_check_box)
				"BlackSect": %BlackSectBuildingsContainer.add_child(item_check_box)
	for squad in Preloads.ua_data.data[EditorState.game_data_type].other.units:
		var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
		item_check_box.item_texture = Preloads.squad_images[str(squad.id)]
		item_check_box.label_text = squad.name
		item_check_box.item_type = "squad"
		item_check_box.owner_id = host_station_owner_id
		item_check_box.item_id = squad.id
		item_check_box.change_button_availability(true, 0)
		%MiscUnitsContainer.add_child(item_check_box)
	for building in Preloads.ua_data.data[EditorState.game_data_type].other.buildings:
		var item_check_box = ITEM_CHECK_BOX_CONTAINER.instantiate()
		item_check_box.item_texture = Preloads.building_icons[building.icon_type]
		item_check_box.label_text = building.name
		item_check_box.item_type = "building"
		item_check_box.owner_id = host_station_owner_id
		item_check_box.item_id = building.id
		item_check_box.change_button_availability(true, 0)
		%MiscBuildingsContainer.add_child(item_check_box)
	%UnlockItemsCheckBox.button_pressed = false


func _on_unlock_items_check_box_toggled(toggled_on: bool) -> void:
		for item_check_box in %ResistanceUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 1)
		for item_check_box in %ResistanceBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 1)
		for item_check_box in %GhorkovUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 6)
		for item_check_box in %GhorkovBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 6)
		for item_check_box in %TaerkastenUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 4)
		for item_check_box in %TaerkastenBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 4)
		for item_check_box in %MykonianUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 3)
		for item_check_box in %MykonianBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 3)
		for item_check_box in %SulgogarUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 2)
		for item_check_box in %BlackSectBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 5)
		for item_check_box in %TrainingUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 7)
		for item_check_box in %MiscUnitsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 0)
		for item_check_box in %MiscBuildingsContainer.get_children():
			item_check_box.change_button_availability(not toggled_on, 0)

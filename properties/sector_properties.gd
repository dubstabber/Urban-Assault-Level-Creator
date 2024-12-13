extends TabBar


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)


func _update_properties() -> void:
	if (CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0 and 
		CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.border_selected_sector_idx >= 0):
		%NoSectorLabel.hide()
		
		if CurrentMapData.selected_sectors.size() > 1: return
		
		%SectorPropertiesContainer.show()
		%SectorPositionLabel.text = "Selected sector X: %s Y: %s" % [CurrentMapData.selected_sector.x, CurrentMapData.selected_sector.y]
		
		if (CurrentMapData.selected_sector.x == 0 or CurrentMapData.selected_sector.y == 0 or
			CurrentMapData.selected_sector.x == (CurrentMapData.horizontal_sectors+1) or
			CurrentMapData.selected_sector.y == (CurrentMapData.vertical_sectors+1)):
			%BorderInfoLabel.show()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/GridContainer.hide()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/HSeparator.hide()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/HSeparator2.hide()
			%BuildingTextLabel.hide()
			%BuildingTexture.hide()
			%InvalidTypMapLabel.hide()
			return
		else:
			%BorderInfoLabel.hide()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/GridContainer.show()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/HSeparator.show()
			$ScrollContainer/MarginContainer/SectorPropertiesContainer/HSeparator2.show()
			%BuildingTextLabel.show()
			%BuildingTexture.show()
		
		if CurrentMapData.own_map[CurrentMapData.selected_sector_idx] == 0:
			%SectorOwnerLabel.text = "Neutral"
		else:
			for faction in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
				if Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[faction].owner == CurrentMapData.own_map[CurrentMapData.selected_sector_idx]:
					%SectorOwnerLabel.text = faction
					break
		
		if CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] == 0:
			%SpecialBuildingLabel.text = 'None'
		elif CurrentMapData.blg_names.has(str(CurrentMapData.blg_map[CurrentMapData.selected_sector_idx])):
			%SpecialBuildingLabel.text = CurrentMapData.blg_names[(str(CurrentMapData.blg_map[CurrentMapData.selected_sector_idx]))]
		elif CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] in [5, 25]:
			%SpecialBuildingLabel.text = 'Beam gate'
		elif CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] in [35, 68]:
			%SpecialBuildingLabel.text = 'Stoudson bomb'
		elif CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] in [60, 61, 4, 7, 15, 51, 50, 16, 65]:
			%SpecialBuildingLabel.text = 'Tech upgrade'
		else:
			%SpecialBuildingLabel.text = 'Unknown'
		if CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] == 62 and CurrentMapData.level_set in [3, 4, 5]:
			%InvalidBlgMapLabel.show()
		else:
			%InvalidBlgMapLabel.hide()
		if CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] == 62 and CurrentMapData.level_set in [1, 6]:
			%WarningBlgMapLabel.show()
		else:
			%WarningBlgMapLabel.hide()
		
		%BuildingTextLabel.text = "Building %s" % CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]
		if Preloads.building_side_images[CurrentMapData.level_set].has(CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]):
			%BuildingTexture.show()
			%BuildingTexture.texture = Preloads.building_side_images[CurrentMapData.level_set][CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]]
			%InvalidTypMapLabel.hide()
		else:
			%BuildingTexture.hide()
			%InvalidTypMapLabel.show()
	else:
		%NoSectorLabel.show()
		%SectorPropertiesContainer.hide()

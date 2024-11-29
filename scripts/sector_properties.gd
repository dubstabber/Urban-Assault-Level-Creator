extends TabBar

var UNLOCKED_LEVEL_CONTAINER = preload("res://scenes/ui_components/level_unlocked_container.tscn")
var TECH_UPGRADE_MODIFIER_1 = preload("res://scenes/tech_upgrade_modifiers/tech_upgrade_modifier_1.tscn")
var TECH_UPGRADE_MODIFIER_2 = preload("res://scenes/tech_upgrade_modifiers/tech_upgrade_modifier_2.tscn")
var TECH_UPGRADE_MODIFIER_3 = preload("res://scenes/tech_upgrade_modifiers/tech_upgrade_modifier_3.tscn")
var BEAM_GATE_KEY_SECTOR_CONTAINER = preload("res://scenes/ui_components/beam_gate_key_sector_v_box.tscn")
var STOUDSON_BOMB_KEY_SECTOR_CONTAINER = preload("res://scenes/ui_components/bomb_key_sector_v_box.tscn")


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	%BGBuildingOptionButton.item_selected.connect(func(index: int):
		if not CurrentMapData.selected_beam_gate: return
		if index == 0:
			CurrentMapData.selected_beam_gate.closed_bp = 5
			CurrentMapData.selected_beam_gate.opened_bp = 6
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 202
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = 5
		elif index == 1:
			CurrentMapData.selected_beam_gate.closed_bp = 25
			CurrentMapData.selected_beam_gate.opened_bp = 26
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 3
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = 25
		EventSystem.map_updated.emit()
		)
	%BeamGateMBStatus.toggled.connect(func(toggled: bool):
		if not CurrentMapData.selected_beam_gate: return
		CurrentMapData.selected_beam_gate.mb_status = toggled
		)
	%AddLevelButton.pressed.connect(func():
		if not CurrentMapData.selected_beam_gate: return
		var level_index = %LevelsOptionButton.get_item_id(%LevelsOptionButton.selected)
		if not CurrentMapData.selected_beam_gate.target_levels.has(level_index):
			CurrentMapData.selected_beam_gate.target_levels.append(level_index)
			var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
			level_container.create(level_index)
			%UnlockLevelsContainer.add_child(level_container)
			EventSystem.map_updated.emit()
		if not CurrentMapData.selected_beam_gate.target_levels.is_empty():
			%NoUnlockedLevelLabel.hide()
		)
	
	%BombBuildingOptionButton.item_selected.connect(func(index:int):
		if not CurrentMapData.selected_bomb: return
		match index:
			0:
				CurrentMapData.selected_bomb.inactive_bp =  35
				CurrentMapData.selected_bomb.active_bp =  36
				CurrentMapData.selected_bomb.trigger_bp =  37
				CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 245
				CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = 35
			1:
				CurrentMapData.selected_bomb.inactive_bp =  68
				CurrentMapData.selected_bomb.active_bp =  69
				CurrentMapData.selected_bomb.trigger_bp =  70
				CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 235
				CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = 68
		EventSystem.map_updated.emit()
		)
	%SecondsSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0: return
		var minutes:int = int(value/60.0)
		var hours:int = int(minutes/60.0)
		%SecondsSpinBox.value = int(value)%60
		%MinutesSpinBox.value += minutes%60
		%HoursSpinBox.value += hours
		update_countdown()
		)
	%MinutesSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0: return
		var hours:int = int(value/60)
		%MinutesSpinBox.value = int(value)%60
		%HoursSpinBox.value += hours
		update_countdown()
		)
	%HoursSpinBox.value_changed.connect(func(value: float):
		if int(value) < 0: return
		%HoursSpinBox.value = int(value)
		update_countdown()
		)
	%TUOptionButton.item_selected.connect(func(index: int):
		if CurrentMapData.selected_tech_upgrade:
			var building_id = %TUOptionButton.get_item_id(index)
			CurrentMapData.selected_tech_upgrade.building_id = building_id
			match building_id:
				60: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 106
				61: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 113
				4: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 100
				7: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 73
				15: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 104
				51: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 101
				50: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 102
				16: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 103
				65: CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 110
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = building_id
			EventSystem.map_updated.emit()
		)
	%SoundTypeOptionButton.item_selected.connect(func(index: int):
		if CurrentMapData.selected_tech_upgrade:
			CurrentMapData.selected_tech_upgrade.type = %SoundTypeOptionButton.get_item_id(index)
		)
	%TechUpgradeMBstatusCheckBox.toggled.connect(func(toggled_on: bool):
		if CurrentMapData.selected_tech_upgrade:
			CurrentMapData.selected_tech_upgrade.mb_status = toggled_on
		)
	%TUAddItemButton.pressed.connect(func():
		if not CurrentMapData.selected_tech_upgrade: return
		var item_name = %TUmodifyOptionButton.get_item_text(%TUmodifyOptionButton.selected)
		for modifier in %TechUpgradeModifiersContainer.get_children():
			if modifier.item_name == item_name: return
		
		if item_name in CurrentMapData.weapons_db:
			var tu_modifier3 = TECH_UPGRADE_MODIFIER_3.instantiate()
			tu_modifier3.item_name = item_name
			%TechUpgradeModifiersContainer.add_child(tu_modifier3)
		elif item_name in CurrentMapData.units_db:
			var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
			tu_modifier1.item_name = item_name
			%TechUpgradeModifiersContainer.add_child(tu_modifier1)
		elif item_name in CurrentMapData.blg_names.values():
			var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
			tu_modifier2.item_name = item_name
			%TechUpgradeModifiersContainer.add_child(tu_modifier2)
		)


func _update_properties() -> void:
	if (CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0 and 
		CurrentMapData.selected_sector_idx >= 0 and CurrentMapData.border_selected_sector_idx >= 0):
		%NoSectorLabel.hide()
		%SectorPropertiesContainer.show()
		%SectorPositionLabel.text = "Sector X: %s Y: %s" % [CurrentMapData.selected_sector.x, CurrentMapData.selected_sector.y]
		
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
		else:
			%SpecialBuildingLabel.text = 'Unknown'
		
		%BuildingTextLabel.text = "Building %s" % CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]
		if Preloads.building_side_images[CurrentMapData.level_set].has(CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]):
			%BuildingTexture.show()
			%BuildingTexture.texture = Preloads.building_side_images[CurrentMapData.level_set][CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]]
			%InvalidTypMapLabel.hide()
		else:
			%BuildingTexture.hide()
			%InvalidTypMapLabel.show()
		
		if CurrentMapData.selected_beam_gate:
			%BeamGateSection.show()
			%BeamGateInfoLabel.text = 'Beam gate %s' % (CurrentMapData.beam_gates.find(CurrentMapData.selected_beam_gate)+1)
			if CurrentMapData.selected_beam_gate.closed_bp == 5:
				%BGBuildingOptionButton.selected = 0
			elif CurrentMapData.selected_beam_gate.closed_bp == 25:
				%BGBuildingOptionButton.selected = 1
			%BeamGateMBStatus.button_pressed = CurrentMapData.selected_beam_gate.mb_status
			if CurrentMapData.selected_beam_gate.key_sectors.size() > 0:
				%BGKeySectorLabel.show()
				%BGKeySectorsContainer.show()
				for ks_label in %BGKeySectorsContainer.get_children():
					ks_label.queue_free()
				
				for i in CurrentMapData.selected_beam_gate.key_sectors.size():
					var ks_label = Label.new()
					%BGKeySectorsContainer.add_child(ks_label)
					ks_label.text = 'Key sector %s at X:%s Y:%s' %[i+1, CurrentMapData.selected_beam_gate.key_sectors[i].x, CurrentMapData.selected_beam_gate.key_sectors[i].y]
					ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					ks_label["theme_override_font_sizes/font_size"] = 12
			else:
				%BGKeySectorLabel.hide()
				%BGKeySectorsContainer.hide()
				
			%LevelsOptionButton.clear()
			for level_id in Preloads.ua_data.data[CurrentMapData.game_data_type].levels:
				if level_id < 10:
					%LevelsOptionButton.add_item('L0%s0%s'% [level_id,level_id], level_id)
				else:
					%LevelsOptionButton.add_item('L%s%s'% [level_id,level_id], level_id)
			
			for lvl in %UnlockLevelsContainer.get_children():
				lvl.queue_free()
			if CurrentMapData.selected_beam_gate.target_levels.size() == 0:
				%NoUnlockedLevelLabel.show()
			else:
				%NoUnlockedLevelLabel.hide()
				for lvl_index in CurrentMapData.selected_beam_gate.target_levels:
					var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
					level_container.create(lvl_index)
					%UnlockLevelsContainer.add_child(level_container)
			 
		else:
			%BeamGateSection.hide()
		
		if CurrentMapData.selected_bomb:
			%StoudsonBombSection.show()
			%BombInfoLabel.text = "Stoudson bomb %s" % (CurrentMapData.stoudson_bombs.find(CurrentMapData.selected_bomb)+1)
			if CurrentMapData.selected_bomb.inactive_bp == 35:
				%BombBuildingOptionButton.selected = 0
			elif CurrentMapData.selected_bomb.inactive_bp == 68:
				%BombBuildingOptionButton.selected = 1
			
			var seconds:int = int(CurrentMapData.selected_bomb.countdown/1024.0)
			var minutes:int = int(seconds/60.0)
			var hours:int = int(minutes/60.0)
			%HoursSpinBox.value = hours%60
			%MinutesSpinBox.value = minutes%60
			%SecondsSpinBox.value = seconds%60
			
			if CurrentMapData.selected_bomb.key_sectors.size() > 0:
				%BombKeySectorsLabel.show()
				%BombKeySectorsListContainer.show()
				for bomb_ks in %BombKeySectorsListContainer.get_children():
					bomb_ks.queue_free()
				for i in CurrentMapData.selected_bomb.key_sectors.size():
					var ks_label = Label.new()
					%BombKeySectorsListContainer.add_child(ks_label)
					ks_label.text = 'Key sector %s at X: %s Y: %s' % [i+1, CurrentMapData.selected_bomb.key_sectors[i].x, CurrentMapData.selected_bomb.key_sectors[i].y]
					ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					ks_label["theme_override_font_sizes/font_size"] = 12
			else:
				%BombKeySectorsLabel.hide()
				%BombKeySectorsListContainer.hide()
		else:
			%StoudsonBombSection.hide()
		
		if CurrentMapData.selected_tech_upgrade:
			%TechUpgradeSection.show()
			%TUOptionButton.select(%TUOptionButton.get_item_index(CurrentMapData.selected_tech_upgrade.building_id))
			%SoundTypeOptionButton.select(%SoundTypeOptionButton.get_item_index(CurrentMapData.selected_tech_upgrade.type))
			%TechUpgradeMBstatusCheckBox.button_pressed = CurrentMapData.selected_tech_upgrade.mb_status
			
			%TUmodifyOptionButton.clear()
			for unit in CurrentMapData.units_db:
				%TUmodifyOptionButton.add_item(unit)
			for building in CurrentMapData.blg_names:
				%TUmodifyOptionButton.add_item(CurrentMapData.blg_names[building])
			for modifier in %TechUpgradeModifiersContainer.get_children():
				modifier.queue_free()
			for vehicle_modifier in CurrentMapData.selected_tech_upgrade.vehicles:
				var tu_modifier1 = TECH_UPGRADE_MODIFIER_1.instantiate()
				tu_modifier1.vehicle_modifier = vehicle_modifier
				var vehicle_name: String
				for unit in CurrentMapData.units_db:
					if CurrentMapData.units_db[unit] == vehicle_modifier.vehicle_id:
						vehicle_name = unit
						break
				
				tu_modifier1.item_name = vehicle_name
				for weapon_modifier in CurrentMapData.selected_tech_upgrade.weapons:
					if weapon_modifier.weapon_id == vehicle_modifier.vehicle_id:
						tu_modifier1.weapon_modifier = weapon_modifier
				tu_modifier1.update_ui()
				%TechUpgradeModifiersContainer.add_child(tu_modifier1)
			
			for weapon_modifier in CurrentMapData.selected_tech_upgrade.weapons:
				if CurrentMapData.selected_tech_upgrade.vehicles.any(func(vehicle):
					return vehicle.vehicle_id == weapon_modifier.weapon_id):
						continue
				
				# If weapon_modifier is just a single weapon then use "TECH_UPGRADE_MODIFIER_3" container
				# else if weapon_modifier is a squad then use "TECH_UPGRADE_MODIFIER_1" container
				var tu_modifier:VBoxContainer = null
				for weapon_id in CurrentMapData.weapons_db.values():
					if weapon_id == weapon_modifier.weapon_id:
						tu_modifier = TECH_UPGRADE_MODIFIER_3.instantiate()
						break
				if tu_modifier == null:
					tu_modifier = TECH_UPGRADE_MODIFIER_1.instantiate()
				
				tu_modifier.weapon_modifier = weapon_modifier
				var vehicle_name: String
				for unit in CurrentMapData.units_db:
					if CurrentMapData.units_db[unit] == weapon_modifier.weapon_id:
						vehicle_name = unit
						break
				
				tu_modifier.item_name = vehicle_name
				tu_modifier.update_ui()
				%TechUpgradeModifiersContainer.add_child(tu_modifier)
			
			
			for building_modifier in CurrentMapData.selected_tech_upgrade.buildings:
				var tu_modifier2 = TECH_UPGRADE_MODIFIER_2.instantiate()
				tu_modifier2.building_modifier = building_modifier
				tu_modifier2.item_name = CurrentMapData.blg_names[str(building_modifier.building_id)]
				tu_modifier2.update_ui()
				%TechUpgradeModifiersContainer.add_child(tu_modifier2)
		else:
			%TechUpgradeSection.hide()
			
		if CurrentMapData.selected_bg_key_sector:
			%BeamGateKeySectorSection.show()
			for child in %BeamGateKeySectorSection.get_children():
				child.queue_free()
			
			for bg_index in CurrentMapData.beam_gates.size():
				var ks_index = CurrentMapData.beam_gates[bg_index].key_sectors.find(CurrentMapData.selected_bg_key_sector)
				if ks_index >= 0:
					var beam_gate_key_sector_container = BEAM_GATE_KEY_SECTOR_CONTAINER.instantiate()
					beam_gate_key_sector_container.set_labels(ks_index+1, bg_index+1)
					%BeamGateKeySectorSection.add_child(beam_gate_key_sector_container)
				
		else:
			%BeamGateKeySectorSection.hide()
			
		if CurrentMapData.selected_bomb_key_sector:
			%BombKeySectorSection.show()
			for child in %BombKeySectorSection.get_children():
				child.queue_free()
			
			for bomb_index in CurrentMapData.stoudson_bombs.size():
				var ks_index = CurrentMapData.stoudson_bombs[bomb_index].key_sectors.find(CurrentMapData.selected_bomb_key_sector)
				if ks_index >= 0:
					var stoudson_bomb_key_sector_container = STOUDSON_BOMB_KEY_SECTOR_CONTAINER.instantiate()
					if CurrentMapData.stoudson_bombs[bomb_index].inactive_bp == 35:
						stoudson_bomb_key_sector_container.set_labels(ks_index+1, bomb_index+1,"normal")
					elif CurrentMapData.stoudson_bombs[bomb_index].inactive_bp == 68:
						stoudson_bomb_key_sector_container.set_labels(ks_index+1, bomb_index+1,"parasite")
					%BombKeySectorSection.add_child(stoudson_bomb_key_sector_container)
		else:
			%BombKeySectorSection.hide()
		
	else:
		%NoSectorLabel.show()
		%SectorPropertiesContainer.hide()


func update_countdown() -> void:
	if CurrentMapData.selected_bomb:
		var countdown_units = ((int(%HoursSpinBox.value)*60)*60)*1024
		countdown_units += (int(%MinutesSpinBox.value)*60)*1024
		countdown_units += int(%SecondsSpinBox.value)*1024
		CurrentMapData.selected_bomb.countdown = countdown_units

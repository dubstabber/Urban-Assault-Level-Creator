extends TabBar

var UNLOCKED_LEVEL_CONTAINER = preload("res://scenes/ui_components/level_unlocked_container.tscn")


func _ready() -> void:
	
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	%BGBuildingOptionButton.item_selected.connect(func(index: int):
		if not CurrentMapData.selected_beam_gate: return
		if index == 0:
			CurrentMapData.selected_beam_gate.closed_bp = 5
			CurrentMapData.selected_beam_gate.opened_bp = 6
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 202
		elif index == 1:
			CurrentMapData.selected_beam_gate.closed_bp = 25
			CurrentMapData.selected_beam_gate.opened_bp = 26
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 3
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
		if CurrentMapData.selected_beam_gate.target_levels.size() != 0:
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
			1:
				CurrentMapData.selected_bomb.inactive_bp =  68
				CurrentMapData.selected_bomb.active_bp =  69
				CurrentMapData.selected_bomb.trigger_bp =  70
				CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 235
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
	%HoursSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0: return
		%HoursSpinBox.value = int(value)
		update_countdown()
		)


func _update_properties() -> void:
	if CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0:
		%NoSectorLabel.hide()
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
				%BombKeySectorContainer.show()
				for bomb_ks in %BombKeySectorContainer.get_children():
					bomb_ks.queue_free()
				for i in CurrentMapData.selected_bomb.key_sectors.size():
					var ks_label = Label.new()
					%BombKeySectorContainer.add_child(ks_label)
					ks_label.text = 'Key sector %s at X: %s Y: %s' % [i+1, CurrentMapData.selected_bomb.key_sectors[i].x, CurrentMapData.selected_bomb.key_sectors[i].y]
					ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					ks_label["theme_override_font_sizes/font_size"] = 12
			else:
				%BombKeySectorsLabel.hide()
				%BombKeySectorContainer.hide()
		else:
			%StoudsonBombSection.hide()
		
		if CurrentMapData.selected_tech_upgrade:
			%TechUpgradeSection.show()
		else:
			%TechUpgradeSection.hide()
			
		if CurrentMapData.selected_bg_key_sector.x >= 0 or CurrentMapData.selected_bomb_key_sector.x >= 0:
			%KeySectorSection.show()
		else:
			%KeySectorSection.hide()
	else:
		%NoSectorLabel.show()
	

func update_countdown() -> void:
	if CurrentMapData.selected_bomb:
		var countdown_units = ((int(%HoursSpinBox.value)*60)*60)*1024
		countdown_units += (int(%MinutesSpinBox.value)*60)*1024
		countdown_units += int(%SecondsSpinBox.value)*1024
		CurrentMapData.selected_bomb.countdown = countdown_units

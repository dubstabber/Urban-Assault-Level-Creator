extends VBoxContainer


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	%BombBuildingOptionButton.item_selected.connect(func(index:int):
		if not EditorState.selected_bomb: return
		match index:
			0:
				EditorState.selected_bomb.inactive_bp =  35
				EditorState.selected_bomb.active_bp =  36
				EditorState.selected_bomb.trigger_bp =  37
				CurrentMapData.typ_map[EditorState.selected_sector_idx] = 245
				CurrentMapData.blg_map[EditorState.selected_sector_idx] = 35
			1:
				EditorState.selected_bomb.inactive_bp =  68
				EditorState.selected_bomb.active_bp =  69
				EditorState.selected_bomb.trigger_bp =  70
				CurrentMapData.typ_map[EditorState.selected_sector_idx] = 235
				CurrentMapData.blg_map[EditorState.selected_sector_idx] = 68
		EventSystem.map_updated.emit()
		)
	%SecondsSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0 or not EditorState.selected_bomb: return
		var minutes:int = int(value/60.0)
		var hours:int = int(minutes/60.0)
		var seconds_from_bomb:int = int(EditorState.selected_bomb.countdown/1024.0) % 60
		if %SecondsSpinBox.value != seconds_from_bomb: 
			%SecondsSpinBox.value = int(value)%60
			%MinutesSpinBox.value += minutes%60
			%HoursSpinBox.value += hours
			_update_countdown()
		)
	%MinutesSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0 or not EditorState.selected_bomb: return
		var hours:int = int(value/60)
		var seconds_from_bomb:int = int(EditorState.selected_bomb.countdown/1024.0)
		var minutes_from_bomb:int = int(seconds_from_bomb/60.0) % 60
		if %MinutesSpinBox.value != minutes_from_bomb: 
			%MinutesSpinBox.value = int(value)%60
			%HoursSpinBox.value += hours
			_update_countdown()
		)
	%HoursSpinBox.value_changed.connect(func(value: float):
		if int(value) < 0 or not EditorState.selected_bomb: return
		var seconds_from_bomb:int = int(EditorState.selected_bomb.countdown/1024.0)
		var minutes_from_bomb:int = int(seconds_from_bomb/60.0)
		var hours_from_bomb:int = int(minutes_from_bomb/60.0)
		if %HoursSpinBox.value != hours_from_bomb: 
			%HoursSpinBox.value = int(value)
			_update_countdown()
		)


func _update_properties() -> void:
	if EditorState.selected_bomb:
		show()
		%BombInfoLabel.text = "Stoudson bomb %s" % (CurrentMapData.stoudson_bombs.find(EditorState.selected_bomb)+1)
		
		if EditorState.selected_bomb.inactive_bp == 35:
			%BombBuildingOptionButton.selected = 0
			%InvalidBuildingLabel.hide()
			%WarningBuildingLabel.hide()
		elif EditorState.selected_bomb.inactive_bp == 68:
			%BombBuildingOptionButton.selected = 1
			if CurrentMapData.level_set in [2, 3, 4, 5]:
				%InvalidBuildingLabel.show()
				%WarningBuildingLabel.hide()
			elif CurrentMapData.level_set == 1:
				%WarningBuildingLabel.show()
				%InvalidBuildingLabel.hide()
			else:
				%InvalidBuildingLabel.hide()
				%WarningBuildingLabel.hide()
		
		var seconds:int = int(EditorState.selected_bomb.countdown/1024.0)
		var minutes:int = int(seconds/60.0)
		var hours:int = int(minutes/60.0)
		%HoursSpinBox.value = hours
		%MinutesSpinBox.value = minutes%60
		%SecondsSpinBox.value = seconds%60
		
		if EditorState.selected_bomb.key_sectors.size() > 0:
			%BombKeySectorsLabel.show()
			%BombKeySectorsListContainer.show()
			for bomb_ks in %BombKeySectorsListContainer.get_children():
				bomb_ks.queue_free()
			for i in EditorState.selected_bomb.key_sectors.size():
				var ks_label = Label.new()
				%BombKeySectorsListContainer.add_child(ks_label)
				ks_label.text = 'Key sector %s at X:%s Y:%s' % [i+1, EditorState.selected_bomb.key_sectors[i].x, EditorState.selected_bomb.key_sectors[i].y]
				ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ks_label["theme_override_font_sizes/font_size"] = 12
		else:
			%BombKeySectorsLabel.hide()
			%BombKeySectorsListContainer.hide()
	else:
		hide()


func _update_countdown() -> void:
	if EditorState.selected_bomb:
		var countdown_units = ((int(%HoursSpinBox.value)*60)*60)*1024
		countdown_units += (int(%MinutesSpinBox.value)*60)*1024
		countdown_units += int(%SecondsSpinBox.value)*1024
		if EditorState.selected_bomb.countdown != countdown_units: CurrentMapData.is_saved = false
		EditorState.selected_bomb.countdown = countdown_units

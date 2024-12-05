extends VBoxContainer


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
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
		_update_countdown()
		)
	%MinutesSpinBox.value_changed.connect(func(value: float) -> void:
		if int(value) < 0: return
		var hours:int = int(value/60)
		%MinutesSpinBox.value = int(value)%60
		%HoursSpinBox.value += hours
		_update_countdown()
		)
	%HoursSpinBox.value_changed.connect(func(value: float):
		if int(value) < 0: return
		%HoursSpinBox.value = int(value)
		_update_countdown()
		)


func _update_properties() -> void:
	if CurrentMapData.selected_bomb:
		show()
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
		hide()


func _update_countdown() -> void:
	if CurrentMapData.selected_bomb:
		var countdown_units = ((int(%HoursSpinBox.value)*60)*60)*1024
		countdown_units += (int(%MinutesSpinBox.value)*60)*1024
		countdown_units += int(%SecondsSpinBox.value)*1024
		CurrentMapData.selected_bomb.countdown = countdown_units
		CurrentMapData.is_saved = false

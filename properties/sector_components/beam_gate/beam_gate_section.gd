extends VBoxContainer


@export var UNLOCKED_LEVEL_CONTAINER: PackedScene


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	%BGBuildingOptionButton.item_selected.connect(func(index: int):
		if not EditorState.selected_beam_gate: return
		if index == 0:
			EditorState.selected_beam_gate.closed_bp = 5
			EditorState.selected_beam_gate.opened_bp = 6
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 202
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = 5
		elif index == 1:
			EditorState.selected_beam_gate.closed_bp = 25
			EditorState.selected_beam_gate.opened_bp = 26
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 3
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = 25
		EventSystem.map_updated.emit()
		)
	%BeamGateMBStatus.toggled.connect(func(toggled: bool):
		if not EditorState.selected_beam_gate: return
		if EditorState.selected_beam_gate.mb_status != toggled:
			CurrentMapData.is_saved = false
		EditorState.selected_beam_gate.mb_status = toggled
		)
	%AddLevelButton.pressed.connect(func():
		if not EditorState.selected_beam_gate: return
		var level_index = %LevelsOptionButton.get_item_id(%LevelsOptionButton.selected)
		if not EditorState.selected_beam_gate.target_levels.has(level_index):
			if UNLOCKED_LEVEL_CONTAINER:
				EditorState.selected_beam_gate.target_levels.append(level_index)
				var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
				level_container.create(level_index)
				%UnlockLevelsContainer.add_child(level_container)
				EventSystem.map_updated.emit()
			else:
				printerr("UNLOCKED_LEVEL_CONTAINER does not exist")
		if not EditorState.selected_beam_gate.target_levels.is_empty():
			%NoUnlockedLevelLabel.hide()
		)


func _update_properties() -> void:
	if EditorState.selected_beam_gate:
		show()
		%BeamGateInfoLabel.text = 'Beam gate %s' % (CurrentMapData.beam_gates.find(EditorState.selected_beam_gate)+1)
		if EditorState.selected_beam_gate.closed_bp == 5:
			%BGBuildingOptionButton.selected = 0
		elif EditorState.selected_beam_gate.closed_bp == 25:
			%BGBuildingOptionButton.selected = 1
			
		%BeamGateMBStatus.button_pressed = EditorState.selected_beam_gate.mb_status
		
		if EditorState.selected_beam_gate.key_sectors.size() > 0:
			%BGKeySectorLabel.show()
			%BGKeySectorsContainer.show()
			for ks_label in %BGKeySectorsContainer.get_children():
				%BGKeySectorsContainer.remove_child(ks_label)
				ks_label.queue_free()
			
			for i in EditorState.selected_beam_gate.key_sectors.size():
				var ks_label = Label.new()
				%BGKeySectorsContainer.add_child(ks_label)
				ks_label.text = 'Key sector %s at X:%s Y:%s' %[i+1, EditorState.selected_beam_gate.key_sectors[i].x, EditorState.selected_beam_gate.key_sectors[i].y]
				ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ks_label["theme_override_font_sizes/font_size"] = 12
		else:
			%BGKeySectorLabel.hide()
			%BGKeySectorsContainer.hide()
			
		%LevelsOptionButton.clear()
		for level_id in Preloads.ua_data.data[EditorState.game_data_type].levels:
			if level_id < 10:
				%LevelsOptionButton.add_item('L0%s0%s'% [level_id,level_id], level_id)
			else:
				%LevelsOptionButton.add_item('L%s%s'% [level_id,level_id], level_id)
		
		for lvl in %UnlockLevelsContainer.get_children():
			lvl.queue_free()
		if EditorState.selected_beam_gate.target_levels.size() == 0:
			%NoUnlockedLevelLabel.show()
		else:
			%NoUnlockedLevelLabel.hide()
			for lvl_index in EditorState.selected_beam_gate.target_levels:
				if UNLOCKED_LEVEL_CONTAINER:
					var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
					level_container.create(lvl_index)
					%UnlockLevelsContainer.add_child(level_container)
				else:
					printerr("UNLOCKED_LEVEL_CONTAINER does not exist")
	else:
		hide()

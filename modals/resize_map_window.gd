extends Window


func _on_about_to_popup() -> void:
	if CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0:
		%HorizontalSpinBox.value = CurrentMapData.horizontal_sectors
		%VerticalSpinBox.value = CurrentMapData.vertical_sectors


func _on_ok_button_pressed() -> void:
	if CurrentMapData.horizontal_sectors <= 0 or CurrentMapData.vertical_sectors <= 0:
		hide()
		return
	
	EditorState.unselect_all()
	
	var resized_typ_map: Array[int] = []
	var resized_own_map: Array[int] = []
	var resized_hgt_map: Array[int] = []
	var resized_blg_map: Array[int] = []
	var horizontal_sectors = int(%HorizontalSpinBox.value)
	var vertical_sectors = int(%VerticalSpinBox.value)
	resized_typ_map.resize(horizontal_sectors * vertical_sectors)
	resized_typ_map.fill(0)
	resized_own_map.resize(horizontal_sectors * vertical_sectors)
	resized_own_map.fill(0)
	resized_hgt_map.resize((horizontal_sectors+2) * (vertical_sectors+2))
	resized_hgt_map.fill(127)
	resized_blg_map.resize(horizontal_sectors * vertical_sectors)
	resized_blg_map.fill(0)
	
	for row in range(min(CurrentMapData.vertical_sectors ,vertical_sectors)):
		for col in range(min(CurrentMapData.horizontal_sectors ,horizontal_sectors)):
			resized_typ_map[row * horizontal_sectors + col] = CurrentMapData.typ_map[row * CurrentMapData.horizontal_sectors + col]
			resized_own_map[row * horizontal_sectors + col] = CurrentMapData.own_map[row * CurrentMapData.horizontal_sectors + col]
			resized_blg_map[row * horizontal_sectors + col] = CurrentMapData.blg_map[row * CurrentMapData.horizontal_sectors + col]
	
	for row in range(min(CurrentMapData.vertical_sectors+2, vertical_sectors+2)):
		for col in range(min(CurrentMapData.horizontal_sectors+2, horizontal_sectors+2)):
			resized_hgt_map[row * (horizontal_sectors+2) + col] = CurrentMapData.hgt_map[row * (CurrentMapData.horizontal_sectors+2) + col]
	
	CurrentMapData.beam_gates = CurrentMapData.beam_gates.filter(func(bg: BeamGate):
		return not(bg.sec_x > horizontal_sectors or bg.sec_y > vertical_sectors)
		)
	for bg: BeamGate in CurrentMapData.beam_gates:
		bg.key_sectors = bg.key_sectors.filter(func(ks):
			return not(ks.x > horizontal_sectors or ks.y > vertical_sectors)
			)
	
	CurrentMapData.stoudson_bombs = CurrentMapData.stoudson_bombs.filter(func(bomb: StoudsonBomb):
		return not(bomb.sec_x > horizontal_sectors or bomb.sec_y > vertical_sectors)
		)
	for bomb: StoudsonBomb in CurrentMapData.stoudson_bombs:
		bomb.key_sectors = bomb.key_sectors.filter(func(ks):
			return not(ks.x > horizontal_sectors or ks.y > vertical_sectors)
			)
	
	CurrentMapData.tech_upgrades = CurrentMapData.tech_upgrades.filter(func(tu: TechUpgrade):
		return not(tu.sec_x > horizontal_sectors or tu.sec_y > vertical_sectors)
		)
	
	CurrentMapData.vertical_sectors = vertical_sectors
	CurrentMapData.horizontal_sectors = horizontal_sectors
	CurrentMapData.typ_map = resized_typ_map
	CurrentMapData.own_map = resized_own_map
	CurrentMapData.hgt_map = resized_hgt_map
	CurrentMapData.blg_map = resized_blg_map
	
	var right_sector_limit: int = (int(%HorizontalSpinBox.value)+1)*1200
	var bottom_sector_limit: int = (int(%VerticalSpinBox.value)+1)*1200
	for hs: HostStation in CurrentMapData.host_stations.get_children():
		if hs.position.x > right_sector_limit or hs.position.y > bottom_sector_limit:
			if hs == EditorState.selected_unit: EditorState.selected_unit = null
			hs.queue_free()
		hs.recalculate_limits()
	for squad: Squad in CurrentMapData.squads.get_children():
		if squad.position.x > right_sector_limit or squad.position.y > bottom_sector_limit:
			if squad == EditorState.selected_unit: EditorState.selected_unit = null
			squad.queue_free()
		squad.recalculate_limits()
	
	EventSystem.map_updated.emit()
	get_tree().root.size_changed.emit()
	
	hide()


func close() -> void:
	hide()

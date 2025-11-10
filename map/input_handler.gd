extends Node

var number_key: int
var is_number_pressed := false
var is_left_pressed := false

@onready var map: Node2D = %Map


func _input(event):
	if not map: return

	# Early return if no map data
	if CurrentMapData.horizontal_sectors <= 0: return

	# Handle different input types
	if event is InputEventMouseButton:
		_handle_mouse_input(event)
	elif event is InputEventKey:
		_handle_keyboard_input(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_input(event: InputEventMouseButton):
	if event.is_action_pressed("select"):
		is_left_pressed = true
		if map.is_multi_selection:
			map.selection_start_point = map.get_local_mouse_position()
			return
		if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
			_handle_typ_map_design()
			return
		_handle_single_selection()
		EditorState.selected_unit = EditorState.mouse_over_unit
		if event.double_click:
			EventSystem.left_double_clicked.emit()
	elif event.is_action_released("select"):
		is_left_pressed = false
		if map.is_multi_selection:
			handle_batch_multi_selection(map.selection_start_point, map.current_mouse_pos)
			map.selection_start_point = Vector2.ZERO
		map.queue_redraw()

	if event.is_action_pressed("context_menu"):
		_handle_context_menu()

	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click and not EditorState.selected_unit:
		EventSystem.left_double_clicked.emit()


func _handle_keyboard_input(event: InputEventKey):
	if event.is_action_pressed("hold"):
		map.is_selection_kept = true
	elif event.is_action_released("hold"):
		map.is_selection_kept = false

	if event.is_action_pressed("multi_selection"):
		map.is_multi_selection = true
	elif event.is_action_released("multi_selection"):
		map.is_multi_selection = false
		map.selection_start_point = Vector2.ZERO
		map.queue_redraw()
	if event.pressed:
		number_key = event.unicode - KEY_0
		if number_key >= 0 and number_key <= 7:
			is_number_pressed = true
			if is_left_pressed:
				_handle_single_selection()
			if EditorState.selected_sector_idx >= 0 and CurrentMapData.own_map.size() > 0:
				_handle_ownership_change()
	elif event.is_released():
		is_number_pressed = false

	if event.is_action_pressed("select_all"):
		Utils.select_all_sectors()

	if event.is_action_pressed("increment_height") and CurrentMapData.hgt_map.size() > 0:
		_handle_height_change(1)

	if event.is_action_pressed("decrement_height") and CurrentMapData.hgt_map.size() > 0:
		_handle_height_change(-1)

	if event.is_action_pressed("previous_building"):
		_handle_building_change(-1)

	if event.is_action_pressed("next_building"):
		_handle_building_change(1)

	if event.is_action_pressed("show_height_window") and not CurrentMapData.hgt_map.is_empty():
		EventSystem.sector_height_window_requested.emit()

	if event.is_action_pressed("show_building_window") and not CurrentMapData.typ_map.is_empty():
		EventSystem.sector_building_windows_requested.emit()

	if event.is_action_pressed("clear_sector") and not CurrentMapData.typ_map.is_empty():
		_handle_clear_sector()

	if event.is_action_pressed("copy"):
		Utils.copy_sector()

	if event.is_action_pressed("paste"):
		Utils.paste_sector()

func _handle_mouse_motion(_event: InputEventMouseMotion):
	if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
		_handle_typ_map_design()
	elif is_number_pressed and number_key >= 0 and number_key <= 7 and is_left_pressed:
		_handle_single_selection()
	elif map.is_multi_selection and is_left_pressed:
		map.queue_redraw()

func _handle_typ_map_design():
	_handle_single_selection()
	CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.selected_typ_map
	CurrentMapData.is_saved = false

func _handle_single_selection():
	var mouse_pos = map.get_local_mouse_position()
	handle_selection(round(mouse_pos.x), round(mouse_pos.y))

func _handle_ownership_change():
	if CurrentMapData.blg_map[EditorState.selected_sector_idx] not in [0, 35, 68] and number_key == 0:
		CurrentMapData.own_map[EditorState.selected_sector_idx] = 7
	else:
		CurrentMapData.own_map[EditorState.selected_sector_idx] = number_key
	CurrentMapData.is_saved = false
	EventSystem.map_updated.emit()

func _handle_height_change(direction: int):
	if EditorState.selected_sectors.size() > 1:
		for sector_dict in EditorState.selected_sectors:
			var new_height = CurrentMapData.hgt_map[sector_dict.border_idx] + direction
			if new_height >= 0 and new_height <= 255:
				CurrentMapData.hgt_map[sector_dict.border_idx] = new_height
	elif EditorState.border_selected_sector_idx >= 0:
		var new_height = CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] + direction
		if new_height >= 0 and new_height <= 255:
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] = new_height
	CurrentMapData.is_saved = false
	map.queue_redraw()
	EventSystem.map_updated.emit()


func _handle_building_change(direction: int):
	if EditorState.selected_sectors.size() > 1:
		for sector_dict in EditorState.selected_sectors:
			if sector_dict.has("idx"):
				if direction > 0:
					Utils.increment_typ_map(sector_dict.idx)
				else:
					Utils.decrement_typ_map(sector_dict.idx)
	else:
		if direction > 0:
			Utils.increment_typ_map(EditorState.selected_sector_idx)
		else:
			Utils.decrement_typ_map(EditorState.selected_sector_idx)
	CurrentMapData.is_saved = false
	EventSystem.map_updated.emit()

func _handle_clear_sector():
	if EditorState.selected_sectors.size() > 1:
		for sector_dict in EditorState.selected_sectors:
			if sector_dict.has("idx"):
				CurrentMapData.clear_sector(sector_dict.idx, false)
	else:
		CurrentMapData.clear_sector(EditorState.selected_sector_idx)
	EventSystem.map_updated.emit()
	EventSystem.item_updated.emit()

func _handle_context_menu():
	map.right_clicked_x = round(map.get_local_mouse_position().x)
	map.right_clicked_y = round(map.get_local_mouse_position().y)

	if EditorState.selected_sectors.size() > 1:
		%MultiSectorMapContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
		%MultiSectorMapContextMenu.popup()
		return

	_handle_single_selection()
	EditorState.selected_unit = EditorState.mouse_over_unit

	if EditorState.selected_unit:
		%UnitContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
		%UnitContextMenu.popup()
	else:
		%MapContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
		%MapContextMenu.popup()

func handle_selection(clicked_x: int, clicked_y: int):
	if not map.is_selection_kept:
		EditorState.selected_sectors.clear()

	_find_clicked_sector(clicked_x, clicked_y)
	_update_special_selections()
	EventSystem.sector_selected.emit()
	map.queue_redraw()

func _find_clicked_sector(clicked_x: int, clicked_y: int):
	var sector_counter := 0
	var border_sector_counter := 0
	var h_size := 0
	var v_size := 0

	for y_sector in CurrentMapData.vertical_sectors + 2:
		for x_sector in CurrentMapData.horizontal_sectors + 2:
			var is_within_bounds := (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors + 1 and
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors + 1 and
				sector_counter < (CurrentMapData.vertical_sectors * CurrentMapData.horizontal_sectors)
				)
			if clicked_x > h_size and clicked_x < h_size + 1200 and clicked_y > v_size and clicked_y < v_size + 1200:
				_update_sector_selection(sector_counter, border_sector_counter, x_sector, y_sector, is_within_bounds)
				break
			h_size += 1200
			if is_within_bounds: sector_counter += 1
			border_sector_counter += 1

		v_size += 1200
		h_size = 0

func _update_sector_selection(sector_idx: int, border_sector_idx: int, x: int, y: int, is_within_bounds: bool):
	EditorState.selected_sector_idx = sector_idx if is_within_bounds else -1
	EditorState.border_selected_sector_idx = border_sector_idx
	EditorState.selected_sector.x = x
	EditorState.selected_sector.y = y

	var is_already_selected = EditorState.selected_sectors.any(func(dict): return dict.border_idx == border_sector_idx)
	if not is_already_selected:
		var new_selection = {
			"border_idx": border_sector_idx,
			"x": x,
			"y": y
		}
		if is_within_bounds:
			new_selection.idx = sector_idx
		EditorState.selected_sectors.append(new_selection)
	else:
		EditorState.selected_sectors = EditorState.selected_sectors.filter(func(dict): return dict.border_idx != border_sector_idx)
		if EditorState.selected_sectors.size() == 1:
			EditorState.selected_sector_idx = EditorState.selected_sectors[0].idx if EditorState.selected_sectors[0].has("idx") else -1
			EditorState.border_selected_sector_idx = EditorState.selected_sectors[0].border_idx
			EditorState.selected_sector.x = EditorState.selected_sectors[0].x
			EditorState.selected_sector.y = EditorState.selected_sectors[0].y

func _update_special_selections():
	EditorState.selected_beam_gate = null
	EditorState.selected_bomb = null
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	EditorState.selected_tech_upgrade = null

	if EditorState.selected_sectors.size() == 1:
		_update_beam_gate_selection()
		_update_bomb_selection()
		_update_tech_upgrade_selection()

func _update_beam_gate_selection():
	for bg in CurrentMapData.beam_gates:
		if bg.sec_x == EditorState.selected_sector.x and bg.sec_y == EditorState.selected_sector.y:
			EditorState.selected_beam_gate = bg
		for ks in bg.key_sectors:
			if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
				EditorState.selected_bg_key_sector = ks
				break

func _update_bomb_selection():
	for bomb in CurrentMapData.stoudson_bombs:
		if bomb.sec_x == EditorState.selected_sector.x and bomb.sec_y == EditorState.selected_sector.y:
			EditorState.selected_bomb = bomb
		for ks in bomb.key_sectors:
			if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
				EditorState.selected_bomb_key_sector = ks
				break

func _update_tech_upgrade_selection():
	for tu in CurrentMapData.tech_upgrades:
		if tu.sec_x == EditorState.selected_sector.x and tu.sec_y == EditorState.selected_sector.y:
			EditorState.selected_tech_upgrade = tu
			break

func handle_batch_multi_selection(start_pos: Vector2, end_pos: Vector2) -> void:
	var sector_counter := 0
	var border_sector_counter := 0
	var h_size := 0
	var v_size := 0

	for y_sector in CurrentMapData.vertical_sectors + 2:
		for x_sector in CurrentMapData.horizontal_sectors + 2:
			var is_within_bounds := (y_sector > 0 and y_sector < CurrentMapData.vertical_sectors + 1 and
				x_sector > 0 and x_sector < CurrentMapData.horizontal_sectors + 1 and
				sector_counter < (CurrentMapData.vertical_sectors * CurrentMapData.horizontal_sectors)
				)
			if (start_pos.x > h_size or end_pos.x > h_size) and (start_pos.x < h_size + 1200 or end_pos.x < h_size + 1200) and (start_pos.y > v_size or end_pos.y > v_size) and (start_pos.y < v_size + 1200 or end_pos.y < v_size + 1200):
				var is_already_selected = EditorState.selected_sectors.any(func(dict): return dict.border_idx == border_sector_counter)
				if not is_already_selected:
					EditorState.selected_sectors.append(
						{
							"border_idx": border_sector_counter,
							"x": x_sector,
							"y": y_sector
						})
					if is_within_bounds: EditorState.selected_sectors[-1].idx = sector_counter
			h_size += 1200
			if is_within_bounds: sector_counter += 1
			border_sector_counter += 1

		v_size += 1200
		h_size = 0

	EventSystem.sector_selected.emit()
	map.queue_redraw()

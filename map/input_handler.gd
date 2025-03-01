extends Node

var number_key: int
var is_number_pressed := false
var is_left_pressed := false

@onready var map: Node2D = %Map


func _input(event):
	if event.is_action_pressed("hold"):
		map.is_selection_kept = true
	elif event.is_action_released("hold"):
		map.is_selection_kept = false
	if event.is_action_pressed("select"):
		is_left_pressed = true
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
			map.handle_selection(round(map.get_local_mouse_position().x), round(map.get_local_mouse_position().y))
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.selected_typ_map
			CurrentMapData.is_saved = false
			return
		map.handle_selection(round(map.get_local_mouse_position().x), round(map.get_local_mouse_position().y))
		EditorState.selected_unit = EditorState.mouse_over_unit
		if event.double_click:
			EventSystem.left_double_clicked.emit()
	elif event.is_action_released("select"):
		is_left_pressed = false
	if event.is_action_pressed("context_menu"):
		if CurrentMapData.horizontal_sectors <= 0: return
		map.right_clicked_x = round(map.get_local_mouse_position().x)
		map.right_clicked_y = round(map.get_local_mouse_position().y)
		if EditorState.selected_sectors.size() > 1:
			%MultiSectorMapContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
			%MultiSectorMapContextMenu.popup()
			return
		map.handle_selection(map.right_clicked_x, map.right_clicked_y)
		EditorState.selected_unit = EditorState.mouse_over_unit
		if EditorState.selected_unit:
			%UnitContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
			%UnitContextMenu.popup()
		else:
			%MapContextMenu.position = Vector2(map.right_clicked_x_global, map.right_clicked_y_global)
			%MapContextMenu.popup()
	if event is InputEventKey and event.pressed:
		if CurrentMapData.horizontal_sectors <= 0: return
		number_key = event.unicode - KEY_0
		if number_key >= 0 and number_key <= 7:
			is_number_pressed = true
			if is_left_pressed:
				map.handle_selection(round(map.get_local_mouse_position().x), round(map.get_local_mouse_position().y))
			if EditorState.selected_sector_idx >= 0 and CurrentMapData.own_map.size() > 0:
				if CurrentMapData.blg_map[EditorState.selected_sector_idx] not in [0, 35, 68] and number_key == 0:
					CurrentMapData.own_map[EditorState.selected_sector_idx] = 7
				else:
					CurrentMapData.own_map[EditorState.selected_sector_idx] = number_key
				CurrentMapData.is_saved = false
				EventSystem.map_updated.emit()
	elif event is InputEventKey and event.is_released():
		is_number_pressed = false
	
	if event is InputEventMouseMotion:
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.mode == EditorState.States.TypMapDesign and is_left_pressed:
			map.handle_selection(round(map.get_local_mouse_position().x), round(map.get_local_mouse_position().y))
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = EditorState.selected_typ_map
			CurrentMapData.is_saved = false
		elif is_number_pressed and number_key >= 0 and number_key <= 7 and is_left_pressed:
			map.handle_selection(round(map.get_local_mouse_position().x), round(map.get_local_mouse_position().y))
	if (event.is_action_pressed("increment_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		EditorState.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] < 255):
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if CurrentMapData.hgt_map[sector_dict.border_idx] < 255:
					CurrentMapData.hgt_map[sector_dict.border_idx] += 1
		else:
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] += 1
		CurrentMapData.is_saved = false
		map.queue_redraw()
	if (event.is_action_pressed("decrement_height") and 
		CurrentMapData.hgt_map.size() > 0 and
		EditorState.border_selected_sector_idx >= 0 and
		CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] > 0):
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if CurrentMapData.hgt_map[sector_dict.border_idx] > 0:
					CurrentMapData.hgt_map[sector_dict.border_idx] -= 1
		else:
			CurrentMapData.hgt_map[EditorState.border_selected_sector_idx] -= 1
		CurrentMapData.is_saved = false
		map.queue_redraw()
	if event.is_action_pressed("previous_building"):
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if sector_dict.has("idx"):
					Utils.decrement_typ_map(sector_dict.idx)
		else:
			Utils.decrement_typ_map(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
		EventSystem.map_updated.emit()
	if event.is_action_pressed("next_building"):
		if CurrentMapData.horizontal_sectors <= 0: return
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				if sector_dict.has("idx"):
					Utils.increment_typ_map(sector_dict.idx)
		else:
			Utils.increment_typ_map(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
		EventSystem.map_updated.emit()
	if event.is_action_pressed("show_height_window") and not CurrentMapData.hgt_map.is_empty():
		EventSystem.sector_height_window_requested.emit()
	if event.is_action_pressed("show_building_window") and not CurrentMapData.typ_map.is_empty():
		EventSystem.sector_building_windows_requested.emit()
	if event.is_action_pressed("clear_sector") and not CurrentMapData.typ_map.is_empty():
		if EditorState.selected_sectors.size() > 1:
			for sector_dict in EditorState.selected_sectors:
				CurrentMapData.clear_sector(sector_dict.idx)
		else:
			CurrentMapData.clear_sector(EditorState.selected_sector_idx)
		CurrentMapData.is_saved = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if not EditorState.selected_unit:
			EventSystem.left_double_clicked.emit()
	if event.is_action_pressed("copy"):
		Utils.copy_sector()
	if event.is_action_pressed("paste"):
		Utils.paste_sector()

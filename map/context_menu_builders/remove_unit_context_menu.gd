extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().about_to_popup.connect(update_menu)
	get_parent().index_pressed.connect(_on_index_pressed)


func update_menu() -> void:
	if EditorState.selected_unit is HostStation:
		get_parent().add_item("Remove this host station")
	elif EditorState.selected_unit is Squad:
		get_parent().add_item("Remove this squad")
		

func _on_index_pressed(index: int) -> void:
	var text = get_parent().get_item_text(index)
	if not EditorState.selected_unit: return
	var undo_redo_manager = get_node("/root/UndoRedoManager")
	undo_redo_manager.begin_group("Remove unit")
	var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
	var selected_unit := EditorState.selected_unit
	var selected_unit_id := int(selected_unit.get_instance_id())
	var selected_kind := "host" if selected_unit is HostStation else ("squad" if selected_unit is Squad else "")
	if text == "Remove this host station":
		if selected_unit == CurrentMapData.player_host_station:
			if selected_kind == "host":
				EventSystem.unit_overlay_refresh_requested.emit(selected_kind, selected_unit_id)
			selected_unit.queue_free()
			EditorState.selected_unit = null
			if CurrentMapData.host_stations.get_child_count() > 0:
				CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
		else:
			if selected_kind == "host":
				EventSystem.unit_overlay_refresh_requested.emit(selected_kind, selected_unit_id)
			selected_unit.queue_free()
			EditorState.selected_unit = null
		CurrentMapData.is_saved = false
	elif text == "Remove this squad":
		if selected_kind == "squad":
			EventSystem.unit_overlay_refresh_requested.emit(selected_kind, selected_unit_id)
		selected_unit.queue_free()
		EditorState.selected_unit = null
		CurrentMapData.is_saved = false
	undo_redo_manager.record_unit_snapshot(unit_before, undo_redo_manager.create_unit_snapshot())
	undo_redo_manager.commit_group()

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
	if text == "Remove this host station":
		if EditorState.selected_unit == CurrentMapData.player_host_station:
			EditorState.selected_unit.queue_free()
			EditorState.selected_unit = null
			if CurrentMapData.host_stations.get_child_count() > 0:
				CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
		else:
			EditorState.selected_unit.queue_free()
			EditorState.selected_unit = null
		CurrentMapData.is_saved = false
	elif text == "Remove this squad":
		EditorState.selected_unit.queue_free()
		EditorState.selected_unit = null
		CurrentMapData.is_saved = false

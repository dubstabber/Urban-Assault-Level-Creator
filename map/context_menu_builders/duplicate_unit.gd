extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().about_to_popup.connect(update_menu)
	get_parent().index_pressed.connect(_on_index_pressed)


func update_menu() -> void:
	get_parent().clear(true)
	if EditorState.selected_unit is HostStation:
		get_parent().add_item("Duplicate this host station")
	elif EditorState.selected_unit is Squad:
		get_parent().add_item("Duplicate this squad")


func _on_index_pressed(index: int) -> void:
	var text = get_parent().get_item_text(index)
	if not EditorState.selected_unit: return
	if text == "Duplicate this host station":
		var hoststation = Preloads.HOSTSTATION.instantiate()
		CurrentMapData.host_stations.add_child(hoststation)
		hoststation.create(EditorState.selected_unit.owner_id, EditorState.selected_unit.vehicle)
		hoststation.position.x = EditorState.selected_unit.position.x
		hoststation.position.y = EditorState.selected_unit.position.y
		hoststation.pos_y = EditorState.selected_unit.pos_y
		hoststation.energy = EditorState.selected_unit.energy
		hoststation.view_angle = EditorState.selected_unit.view_angle
		hoststation.view_angle_enabled = EditorState.selected_unit.view_angle_enabled
		hoststation.reload_const = EditorState.selected_unit.reload_const
		hoststation.reload_const_enabled = EditorState.selected_unit.reload_const_enabled
		hoststation.con_budget = EditorState.selected_unit.con_budget
		hoststation.con_delay = EditorState.selected_unit.con_delay
		hoststation.def_budget = EditorState.selected_unit.def_budget
		hoststation.def_delay = EditorState.selected_unit.def_delay
		hoststation.rec_budget = EditorState.selected_unit.rec_budget
		hoststation.rec_delay = EditorState.selected_unit.rec_delay
		hoststation.rob_budget = EditorState.selected_unit.rob_budget
		hoststation.rob_delay = EditorState.selected_unit.rob_delay
		hoststation.pow_budget = EditorState.selected_unit.pow_budget
		hoststation.pow_delay = EditorState.selected_unit.pow_delay
		hoststation.rad_budget = EditorState.selected_unit.rad_budget
		hoststation.rad_delay = EditorState.selected_unit.rad_delay
		hoststation.saf_budget = EditorState.selected_unit.saf_budget
		hoststation.saf_delay = EditorState.selected_unit.saf_delay
		hoststation.cpl_budget = EditorState.selected_unit.cpl_budget
		hoststation.cpl_delay = EditorState.selected_unit.cpl_delay
		CurrentMapData.is_saved = false
		EditorState.selected_unit = hoststation
		if CurrentMapData.host_stations.get_child_count() > 8:
			EventSystem.safe_host_station_limit_exceeded.emit()
	elif text == "Duplicate this squad":
		var squad = Preloads.SQUAD.instantiate()
		CurrentMapData.squads.add_child(squad)
		squad.create(EditorState.selected_unit.owner_id, EditorState.selected_unit.vehicle)
		squad.quantity = EditorState.selected_unit.quantity
		squad.position.x = EditorState.selected_unit.position.x
		squad.position.y = EditorState.selected_unit.position.y
		squad.useable = EditorState.selected_unit.useable
		squad.mb_status = EditorState.selected_unit.mb_status
		CurrentMapData.is_saved = false
		EditorState.selected_unit = squad

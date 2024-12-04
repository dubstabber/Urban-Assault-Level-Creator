extends FileDialog


func _ready() -> void:
	EventSystem.save_hs_behavior_dialog_requested.connect(popup)
	%SaveBehaviorFileDialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if not file:
			printerr("File '%s' could not be saved" % path)
			return
		var behavior_data := {
			con_budget = CurrentMapData.selected_unit.con_budget,
			con_delay = CurrentMapData.selected_unit.con_delay,
			def_budget = CurrentMapData.selected_unit.def_budget,
			def_delay = CurrentMapData.selected_unit.def_delay,
			rec_budget = CurrentMapData.selected_unit.rec_budget,
			rec_delay = CurrentMapData.selected_unit.rec_delay,
			rob_budget = CurrentMapData.selected_unit.rob_budget,
			rob_delay = CurrentMapData.selected_unit.rob_delay,
			pow_budget = CurrentMapData.selected_unit.pow_budget,
			pow_delay = CurrentMapData.selected_unit.pow_delay,
			rad_budget = CurrentMapData.selected_unit.rad_budget,
			rad_delay = CurrentMapData.selected_unit.rad_delay,
			saf_budget = CurrentMapData.selected_unit.saf_budget,
			saf_delay = CurrentMapData.selected_unit.saf_delay,
			cpl_budget = CurrentMapData.selected_unit.cpl_budget,
			cpl_delay = CurrentMapData.selected_unit.cpl_delay
		}
		var behavior_data_json = JSON.stringify(behavior_data)
		file.store_line(behavior_data_json)
	)

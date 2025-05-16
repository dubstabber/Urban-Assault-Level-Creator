extends FileDialog


@onready var save_behavior_file_dialog: FileDialog = %SaveBehaviorFileDialog

func _ready() -> void:
	EventSystem.save_hs_behavior_dialog_requested.connect(popup)
	save_behavior_file_dialog.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if not file:
			printerr("File '%s' could not be saved" % path)
			EventSystem.save_enemy_settings_failed.emit(path)
			return
		var behavior_data := {
			con_budget = EditorState.selected_unit.con_budget,
			con_delay = EditorState.selected_unit.con_delay,
			def_budget = EditorState.selected_unit.def_budget,
			def_delay = EditorState.selected_unit.def_delay,
			rec_budget = EditorState.selected_unit.rec_budget,
			rec_delay = EditorState.selected_unit.rec_delay,
			rob_budget = EditorState.selected_unit.rob_budget,
			rob_delay = EditorState.selected_unit.rob_delay,
			pow_budget = EditorState.selected_unit.pow_budget,
			pow_delay = EditorState.selected_unit.pow_delay,
			rad_budget = EditorState.selected_unit.rad_budget,
			rad_delay = EditorState.selected_unit.rad_delay,
			saf_budget = EditorState.selected_unit.saf_budget,
			saf_delay = EditorState.selected_unit.saf_delay,
			cpl_budget = EditorState.selected_unit.cpl_budget,
			cpl_delay = EditorState.selected_unit.cpl_delay
		}
		var behavior_data_json = JSON.stringify(behavior_data)
		file.store_line(behavior_data_json)
	)

extends VBoxContainer


@export var UNLOCKED_LEVEL_CONTAINER: PackedScene

@onready var bg_building_option_button: OptionButton = %BGBuildingOptionButton
@onready var beam_gate_mb_status: CheckBox = %BeamGateMBStatus
@onready var add_level_button: Button = %AddLevelButton
@onready var levels_option_button: OptionButton = %LevelsOptionButton
@onready var unlock_levels_container: Control = %UnlockLevelsContainer
@onready var bg_key_sector_label: Label = %BGKeySectorLabel
@onready var bg_key_sectors_container: Control = %BGKeySectorsContainer
@onready var no_unlocked_level_label: Label = %NoUnlockedLevelLabel
@onready var sector_info_container: Control = %SectorInfoContainer
@onready var sector_info_container_separator: HSeparator = %HSeparator
@onready var sector_info_container_separator2: HSeparator = %HSeparator2
@onready var beam_gate_info_label: Label = %BeamGateInfoLabel


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	bg_building_option_button.item_selected.connect(func(index: int):
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
	beam_gate_mb_status.toggled.connect(func(toggled: bool):
		if not EditorState.selected_beam_gate: return
		if EditorState.selected_beam_gate.mb_status != toggled:
			CurrentMapData.is_saved = false
		EditorState.selected_beam_gate.mb_status = toggled
		)
	add_level_button.pressed.connect(func():
		if not EditorState.selected_beam_gate: return
		var level_index = levels_option_button.get_item_id(levels_option_button.selected)
		if not EditorState.selected_beam_gate.target_levels.has(level_index):
			if UNLOCKED_LEVEL_CONTAINER:
				EditorState.selected_beam_gate.target_levels.append(level_index)
				var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
				level_container.create(level_index)
				unlock_levels_container.add_child(level_container)
				EventSystem.map_updated.emit()
			else:
				printerr("UNLOCKED_LEVEL_CONTAINER does not exist")
		if not EditorState.selected_beam_gate.target_levels.is_empty():
			no_unlocked_level_label.hide()
		)


func _update_properties() -> void:
	if EditorState.selected_beam_gate:
		show()
		beam_gate_info_label.text = 'Beam gate %s' % (CurrentMapData.beam_gates.find(EditorState.selected_beam_gate) + 1)
		if EditorState.selected_beam_gate.closed_bp == 5:
			bg_building_option_button.selected = 0
		elif EditorState.selected_beam_gate.closed_bp == 25:
			bg_building_option_button.selected = 1
			
		beam_gate_mb_status.button_pressed = EditorState.selected_beam_gate.mb_status
		
		if EditorState.selected_beam_gate.key_sectors.size() > 0:
			bg_key_sector_label.show()
			bg_key_sectors_container.show()
			for ks_label in bg_key_sectors_container.get_children():
				bg_key_sectors_container.remove_child(ks_label)
				ks_label.queue_free()
			
			for i in EditorState.selected_beam_gate.key_sectors.size():
				var ks_label = Label.new()
				bg_key_sectors_container.add_child(ks_label)
				ks_label.text = 'Key sector %s at X:%s Y:%s' % [i + 1, EditorState.selected_beam_gate.key_sectors[i].x, EditorState.selected_beam_gate.key_sectors[i].y]
				ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ks_label["theme_override_font_sizes/font_size"] = 12
		else:
			bg_key_sector_label.hide()
			bg_key_sectors_container.hide()
			
		levels_option_button.clear()
		for level_id: int in Preloads.ua_data.data[EditorState.game_data_type].levels:
			levels_option_button.add_item('L%02d%02d' % [level_id, level_id], level_id)
		
		for lvl in unlock_levels_container.get_children():
			lvl.queue_free()
		if EditorState.selected_beam_gate.target_levels.size() == 0:
			no_unlocked_level_label.show()
		else:
			no_unlocked_level_label.hide()
			for lvl_index in EditorState.selected_beam_gate.target_levels:
				if UNLOCKED_LEVEL_CONTAINER:
					var level_container = UNLOCKED_LEVEL_CONTAINER.instantiate()
					level_container.create(lvl_index)
					unlock_levels_container.add_child(level_container)
				else:
					printerr("UNLOCKED_LEVEL_CONTAINER does not exist")
	else:
		hide()

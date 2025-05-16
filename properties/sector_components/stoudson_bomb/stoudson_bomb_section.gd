extends VBoxContainer

@onready var bomb_building_option_button: Button = %BombBuildingOptionButton

@onready var seconds_spin_box: SpinBox = %SecondsSpinBox
@onready var minutes_spin_box: SpinBox = %MinutesSpinBox
@onready var hours_spin_box: SpinBox = %HoursSpinBox

@onready var invalid_building_label: Label = %InvalidBuildingLabel
@onready var warning_building_label: Label = %WarningBuildingLabel

@onready var bomb_info_label: Label = %BombInfoLabel

@onready var bomb_key_sectors_label: Label = %BombKeySectorsLabel
@onready var bomb_key_sectors_list_container: Container = %BombKeySectorsListContainer


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	
	bomb_building_option_button.item_selected.connect(func(index: int):
		if not EditorState.selected_bomb: return
		match index:
			0:
				EditorState.selected_bomb.inactive_bp = 35
				EditorState.selected_bomb.active_bp = 36
				EditorState.selected_bomb.trigger_bp = 37
				CurrentMapData.typ_map[EditorState.selected_sector_idx] = 245
				CurrentMapData.blg_map[EditorState.selected_sector_idx] = 35
			1:
				EditorState.selected_bomb.inactive_bp = 68
				EditorState.selected_bomb.active_bp = 69
				EditorState.selected_bomb.trigger_bp = 70
				CurrentMapData.typ_map[EditorState.selected_sector_idx] = 235
				CurrentMapData.blg_map[EditorState.selected_sector_idx] = 68
		EventSystem.map_updated.emit()
		)
	seconds_spin_box.value_changed.connect(func(value: float) -> void:
		if int(value) < 0 or not EditorState.selected_bomb: return
		var minutes: int = int(value / 60.0)
		var hours: int = int(minutes / 60.0)
		var seconds_from_bomb: int = int(EditorState.selected_bomb.countdown / 1024.0) % 60
		if seconds_spin_box.value != seconds_from_bomb:
			seconds_spin_box.value = int(value) % 60
			minutes_spin_box.value += minutes % 60
			hours_spin_box.value += hours
			_update_countdown()
		)
	minutes_spin_box.value_changed.connect(func(value: float) -> void:
		if int(value) < 0 or not EditorState.selected_bomb: return
		var hours: int = int(value / 60)
		var seconds_from_bomb: int = int(EditorState.selected_bomb.countdown / 1024.0)
		var minutes_from_bomb: int = int(seconds_from_bomb / 60.0) % 60
		if minutes_spin_box.value != minutes_from_bomb:
			minutes_spin_box.value = int(value) % 60
			hours_spin_box.value += hours
			_update_countdown()
		)
	hours_spin_box.value_changed.connect(func(value: float):
		if int(value) < 0 or not EditorState.selected_bomb: return
		var seconds_from_bomb: int = int(EditorState.selected_bomb.countdown / 1024.0)
		var minutes_from_bomb: int = int(seconds_from_bomb / 60.0)
		var hours_from_bomb: int = int(minutes_from_bomb / 60.0)
		if hours_spin_box.value != hours_from_bomb:
			hours_spin_box.value = int(value)
			_update_countdown()
		)


func _update_properties() -> void:
	if EditorState.selected_bomb:
		show()
		bomb_info_label.text = "Stoudson bomb %s" % (CurrentMapData.stoudson_bombs.find(EditorState.selected_bomb) + 1)
		
		if EditorState.selected_bomb.inactive_bp == 35:
			bomb_building_option_button.selected = 0
			invalid_building_label.hide()
			warning_building_label.hide()
		elif EditorState.selected_bomb.inactive_bp == 68:
			bomb_building_option_button.selected = 1
			if CurrentMapData.level_set in [2, 3, 4, 5]:
				invalid_building_label.show()
				warning_building_label.hide()
			elif CurrentMapData.level_set == 1:
				warning_building_label.show()
				invalid_building_label.hide()
			else:
				invalid_building_label.hide()
				warning_building_label.hide()
		
		var seconds: int = int(EditorState.selected_bomb.countdown / 1024.0)
		var minutes: int = int(seconds / 60.0)
		var hours: int = int(minutes / 60.0)
		hours_spin_box.value = hours
		minutes_spin_box.value = minutes % 60
		seconds_spin_box.value = seconds % 60
		
		if EditorState.selected_bomb.key_sectors.size() > 0:
			bomb_key_sectors_label.show()
			bomb_key_sectors_list_container.show()
			for bomb_ks in bomb_key_sectors_list_container.get_children():
				bomb_ks.queue_free()
			for i in EditorState.selected_bomb.key_sectors.size():
				var ks_label = Label.new()
				bomb_key_sectors_list_container.add_child(ks_label)
				ks_label.text = 'Key sector %s at X:%s Y:%s' % [i + 1, EditorState.selected_bomb.key_sectors[i].x, EditorState.selected_bomb.key_sectors[i].y]
				ks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				ks_label["theme_override_font_sizes/font_size"] = 12
		else:
			bomb_key_sectors_label.hide()
			bomb_key_sectors_list_container.hide()
	else:
		hide()


func _update_countdown() -> void:
	if EditorState.selected_bomb:
		var countdown_units = ((int(hours_spin_box.value) * 60) * 60) * 1024
		countdown_units += (int(minutes_spin_box.value) * 60) * 1024
		countdown_units += int(seconds_spin_box.value) * 1024
		if EditorState.selected_bomb.countdown != countdown_units: CurrentMapData.is_saved = false
		EditorState.selected_bomb.countdown = countdown_units

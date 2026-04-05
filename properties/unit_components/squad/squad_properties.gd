extends VBoxContainer


@onready var squad_icon: TextureRect = %SquadIcon
@onready var squad_name_label: Label = %SquadNameLabel

@onready var quantity_spin_box: SpinBox = %QuantitySpinBox
@onready var faction_option_button: OptionButton = %FactionOptionButton

@onready var xpos_squad_line_edit: LineEdit = %XposSquadLineEdit
@onready var zpos_squad_line_edit: LineEdit = %ZposSquadLineEdit

@onready var useable_check_box: CheckBox = %UseableCheckBox
@onready var mb_status_squad_check_box: CheckBox = %MBstatusSquadCheckBox
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _record_unit_snapshot(label: String, before_snapshot: Dictionary) -> void:
	var coalesce_key := ""
	if label == "Edit squad properties" and EditorState.selected_unit:
		coalesce_key = "unit_edit_squad_%s" % int(EditorState.selected_unit.get_instance_id())
	undo_redo_manager.begin_group(label, coalesce_key)
	undo_redo_manager.record_unit_snapshot(before_snapshot, undo_redo_manager.create_unit_snapshot())
	undo_redo_manager.commit_group()


func _ready() -> void:
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	EventSystem.unit_selected.connect(_update_properties)
	
	quantity_spin_box.value_changed.connect(func(value: float):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		if EditorState.selected_unit is Squad:
			var new_quantity := int(value)
			var changed := int(EditorState.selected_unit.quantity) != new_quantity
			if changed:
				CurrentMapData.is_saved = false
			EditorState.selected_unit.quantity = new_quantity
			if changed:
				EventSystem.unit_overlay_refresh_requested.emit("squad", int(EditorState.selected_unit.get_instance_id()))
		_record_unit_snapshot("Edit squad properties", unit_before)
	)
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations.keys():
		faction_option_button.add_item(hs, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
	faction_option_button.item_selected.connect(func(index: int):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		EditorState.selected_unit.change_faction(faction_option_button.get_item_id(index))
		CurrentMapData.is_saved = false
		_record_unit_snapshot("Edit squad properties", unit_before)
	)
	xpos_squad_line_edit.text_submitted.connect(func(text_value: String):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		var pos_x := clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors + 1) * 1200) - 5)
		var moved: bool = EditorState.selected_unit.position.x != pos_x
		if moved:
			CurrentMapData.is_saved = false
			xpos_squad_line_edit.text = str(pos_x)
		EditorState.selected_unit.position.x = pos_x
		if moved:
			EventSystem.unit_position_committed.emit("squad", int(EditorState.selected_unit.get_instance_id()))
		_record_unit_snapshot("Move unit", unit_before)
	)
	zpos_squad_line_edit.text_submitted.connect(func(text_value: String):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		var pos_z := clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors + 1) * 1200) - 5)
		var moved: bool = EditorState.selected_unit.position.y != pos_z
		if moved:
			CurrentMapData.is_saved = false
			zpos_squad_line_edit.text = "-%s" % str(pos_z)
		EditorState.selected_unit.position.y = pos_z
		if moved:
			EventSystem.unit_position_committed.emit("squad", int(EditorState.selected_unit.get_instance_id()))
		_record_unit_snapshot("Move unit", unit_before)
	)
	useable_check_box.toggled.connect(func(toggled: bool):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		if EditorState.selected_unit.useable != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.useable = toggled
		_record_unit_snapshot("Edit squad properties", unit_before)
	)
	mb_status_squad_check_box.toggled.connect(func(toggled: bool):
		var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
		if EditorState.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.mb_status = toggled
		_record_unit_snapshot("Edit squad properties", unit_before)
	)


func _update_properties() -> void:
	if EditorState.selected_unit is Squad:
		if Preloads.squad_images.has(int(EditorState.selected_unit.vehicle)):
			squad_icon.texture = Preloads.squad_images[int(EditorState.selected_unit.vehicle)]
			squad_name_label.text = EditorState.selected_unit.unit_name
		else:
			squad_icon.texture = null
			squad_name_label.text = "Unknown unit"
		
		quantity_spin_box.value = EditorState.selected_unit.quantity
		faction_option_button.select(faction_option_button.get_item_index(EditorState.selected_unit.owner_id))
		
		xpos_squad_line_edit.text = str(roundi(EditorState.selected_unit.position.x))
		zpos_squad_line_edit.text = str(roundi(-EditorState.selected_unit.position.y))
		if not EditorState.selected_unit.position_changed.is_connected(_update_coordinates):
			EditorState.selected_unit.position_changed.connect(_update_coordinates)
		
		useable_check_box.button_pressed = EditorState.selected_unit.useable
		mb_status_squad_check_box.button_pressed = EditorState.selected_unit.mb_status
		
		show()


func _update_coordinates():
	if EditorState.selected_unit is Squad:
		xpos_squad_line_edit.text = str(roundi(EditorState.selected_unit.position.x))
		zpos_squad_line_edit.text = str(roundi(-EditorState.selected_unit.position.y))

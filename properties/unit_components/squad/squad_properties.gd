extends VBoxContainer


@onready var squad_icon: TextureRect = %SquadIcon
@onready var squad_name_label: Label = %SquadNameLabel

@onready var quantity_spin_box: SpinBox = %QuantitySpinBox
@onready var faction_option_button: OptionButton = %FactionOptionButton

@onready var xpos_squad_line_edit: LineEdit = %XposSquadLineEdit
@onready var zpos_squad_line_edit: LineEdit = %ZposSquadLineEdit

@onready var useable_check_box: CheckBox = %UseableCheckBox
@onready var mb_status_squad_check_box: CheckBox = %MBstatusSquadCheckBox


func _ready() -> void:
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	EventSystem.unit_selected.connect(_update_properties)
	
	quantity_spin_box.value_changed.connect(func(value: float):
		if EditorState.selected_unit is Squad:
			if EditorState.selected_unit.quantity != value: CurrentMapData.is_saved = false
			EditorState.selected_unit.quantity = value
	)
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations.keys():
		faction_option_button.add_item(hs, Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
	faction_option_button.item_selected.connect(func(index: int):
		EditorState.selected_unit.change_faction(faction_option_button.get_item_id(index))
		CurrentMapData.is_saved = false
	)
	xpos_squad_line_edit.text_submitted.connect(func(text_value: String):
		var pos_x := clampi(int(text_value), 1205, ((CurrentMapData.horizontal_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.x != pos_x:
			CurrentMapData.is_saved = false
			xpos_squad_line_edit.text = str(pos_x)
		EditorState.selected_unit.position.x = pos_x
	)
	zpos_squad_line_edit.text_submitted.connect(func(text_value: String):
		var pos_z := clampi(abs(int(text_value)), 1205, ((CurrentMapData.vertical_sectors + 1) * 1200) - 5)
		if EditorState.selected_unit.position.y != pos_z:
			CurrentMapData.is_saved = false
			zpos_squad_line_edit.text = "-%s" % str(pos_z)
		EditorState.selected_unit.position.y = pos_z
	)
	useable_check_box.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.useable != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.useable = toggled
	)
	mb_status_squad_check_box.toggled.connect(func(toggled: bool):
		if EditorState.selected_unit.mb_status != toggled: CurrentMapData.is_saved = false
		EditorState.selected_unit.mb_status = toggled
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

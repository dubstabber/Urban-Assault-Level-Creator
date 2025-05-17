extends VBoxContainer

var building_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name

@onready var enable_resistance_checkbox: CheckBox = %EnableResistanceCheckBox
@onready var enable_ghorkov_checkbox: CheckBox = %EnableGhorkovCheckBox
@onready var enable_taerkasten_checkbox: CheckBox = %EnableTaerkastenCheckBox
@onready var enable_mykonian_checkbox: CheckBox = %EnableMykonianCheckBox
@onready var enable_sulgogar_checkbox: CheckBox = %EnableSulgogarCheckBox
@onready var enable_blacksect_checkbox: CheckBox = %EnableBlackSectCheckBox
@onready var enable_training_checkbox: CheckBox = %EnableTrainingCheckBox
@onready var remove_button: Button = %RemoveButton


func _ready() -> void:
	enable_resistance_checkbox.toggled.connect(enable_building.bind("res_enabled"))
	enable_ghorkov_checkbox.toggled.connect(enable_building.bind("ghor_enabled"))
	enable_taerkasten_checkbox.toggled.connect(enable_building.bind("taer_enabled"))
	enable_mykonian_checkbox.toggled.connect(enable_building.bind("myko_enabled"))
	enable_sulgogar_checkbox.toggled.connect(enable_building.bind("sulg_enabled"))
	enable_blacksect_checkbox.toggled.connect(enable_building.bind("blacksect_enabled"))
	enable_training_checkbox.toggled.connect(enable_building.bind("training_enabled"))
	
	remove_button.pressed.connect(func():
		if building_modifier:
			EditorState.selected_tech_upgrade.buildings.erase(building_modifier)
			CurrentMapData.is_saved = false
		queue_free()
		)


func enable_building(toggled: bool, property: String) -> void:
	if not building_modifier: building_modifier = EditorState.selected_tech_upgrade.new_building_modifier(int(EditorState.buildings_db.find_key(item_name)))
	if building_modifier[property] == toggled: return
	building_modifier[property] = toggled
	EditorState.selected_tech_upgrade.synchronize(building_modifier, "enable")
	CurrentMapData.is_saved = false


func update_ui() -> void:
	if building_modifier:
		enable_resistance_checkbox.button_pressed = building_modifier.res_enabled
		enable_ghorkov_checkbox.button_pressed = building_modifier.ghor_enabled
		enable_taerkasten_checkbox.button_pressed = building_modifier.taer_enabled
		enable_mykonian_checkbox.button_pressed = building_modifier.myko_enabled
		enable_sulgogar_checkbox.button_pressed = building_modifier.sulg_enabled
		enable_blacksect_checkbox.button_pressed = building_modifier.blacksect_enabled
		enable_training_checkbox.button_pressed = building_modifier.training_enabled

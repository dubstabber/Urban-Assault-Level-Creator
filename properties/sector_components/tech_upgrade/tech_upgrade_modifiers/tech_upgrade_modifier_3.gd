extends VBoxContainer

var weapon_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name

@onready var add_damage_line_edit: LineEdit = %AddDamageLineEdit
@onready var add_shot_time_line_edit: LineEdit = %AddShotTimeLineEdit
@onready var add_shot_time_user_line_edit: LineEdit = %AddShotTimeUserLineEdit
@onready var remove_button: Button = %RemoveButton
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	add_damage_line_edit.text_changed.connect(modify_weapon.bind("energy"))
	add_shot_time_line_edit.text_changed.connect(modify_weapon.bind("shot_time"))
	add_shot_time_user_line_edit.text_changed.connect(modify_weapon.bind("shot_time_user"))
	remove_button.pressed.connect(func():
		undo_redo_manager.begin_group("Tech modifier remove")
		var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
		if weapon_modifier:
			EditorState.selected_tech_upgrade.weapons.erase(weapon_modifier)
			CurrentMapData.is_saved = false
		undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
		undo_redo_manager.commit_group()
		queue_free()
		)


func modify_weapon(new_text: String, property: String) -> void:
	undo_redo_manager.begin_group("Tech weapon modifier")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	if not weapon_modifier:
		weapon_modifier = EditorState.selected_tech_upgrade.new_weapon_modifier(find_id_by_name(item_name))
		if not weapon_modifier:
			undo_redo_manager.commit_group()
			return
	if property == "energy":
		weapon_modifier[property] = int(new_text) * 100
	else:
		weapon_modifier[property] = int(new_text)
	EditorState.selected_tech_upgrade.synchronize(weapon_modifier, property)
	CurrentMapData.is_saved = false
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()


func update_ui() -> void:
	if weapon_modifier:
		add_damage_line_edit.text = str(weapon_modifier.energy / 100)
		add_shot_time_line_edit.text = str(weapon_modifier.shot_time)
		add_shot_time_user_line_edit.text = str(weapon_modifier.shot_time_user)


func find_id_by_name(weapon_name: String) -> int:
	for id in EditorState.weapons_db:
		if EditorState.weapons_db[id] == weapon_name:
			return id
	return -1
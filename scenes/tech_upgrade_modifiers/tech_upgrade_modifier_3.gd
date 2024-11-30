extends VBoxContainer

var weapon_modifier
var item_name: String:
	set(value):
		item_name = value
		%ItemLabel.text = item_name


func _ready() -> void:
	%AddDamageLineEdit.text_changed.connect(modify_weapon.bind("energy"))
	%AddShotTimeLineEdit.text_changed.connect(modify_weapon.bind("shot_time"))
	%AddShotTimeUserLineEdit.text_changed.connect(modify_weapon.bind("shot_time_user"))
	%RemoveButton.pressed.connect(func():
		if weapon_modifier:
			CurrentMapData.selected_tech_upgrade.weapons.erase(weapon_modifier)
		queue_free()
		)

func modify_weapon(new_text: String, property: String) -> void:
	if not weapon_modifier: weapon_modifier = CurrentMapData.selected_tech_upgrade.new_weapon_modifier(CurrentMapData.units_db[item_name])
	if property == "energy":
		weapon_modifier[property] = int(new_text) * 100
	else:
		weapon_modifier[property] = int(new_text)
	CurrentMapData.selected_tech_upgrade.synchronize(weapon_modifier, property)


func update_ui() -> void:
	if weapon_modifier:
		%AddDamageLineEdit.text = str(weapon_modifier.energy / 100)
		%AddShotTimeLineEdit.text = str(weapon_modifier.shot_time)
		%AddShotTimeUserLineEdit.text = str(weapon_modifier.shot_time_user)

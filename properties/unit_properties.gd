extends TabBar


func _ready():
	EventSystem.unit_selected.connect(_update_properties)


func _update_properties():
	if EditorState.selected_unit:
		%NoUnitLabel.hide()
		if EditorState.selected_unit is HostStation: %SquadProperties.hide()
		elif EditorState.selected_unit is Squad: %HostStationProperties.hide()
	else:
		%NoUnitLabel.show()
		%HostStationProperties.hide()
		%SquadProperties.hide()

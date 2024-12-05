extends TabBar


func _ready():
	EventSystem.unit_selected.connect(_update_properties)


func _update_properties():
	if CurrentMapData.selected_unit:
		%NoUnitLabel.hide()
		if CurrentMapData.selected_unit is HostStation: %SquadProperties.hide()
		elif CurrentMapData.selected_unit is Squad: %HostStationProperties.hide()
	else:
		%NoUnitLabel.show()
		%HostStationProperties.hide()
		%SquadProperties.hide()

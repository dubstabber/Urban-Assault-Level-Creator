extends TabBar

@onready var no_unit_label: Label = %NoUnitLabel
@onready var squad_properties: Control = %SquadProperties
@onready var host_station_properties: Control = %HostStationProperties


func _ready():
	EventSystem.unit_selected.connect(_update_properties)


func _update_properties():
	if EditorState.selected_unit:
		no_unit_label.hide()
		if EditorState.selected_unit is HostStation: squad_properties.hide()
		elif EditorState.selected_unit is Squad: host_station_properties.hide()
	else:
		no_unit_label.show()
		host_station_properties.hide()
		squad_properties.hide()

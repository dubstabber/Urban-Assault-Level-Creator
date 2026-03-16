extends TabBar

@onready var no_unit_label: Label = %NoUnitLabel
@onready var squad_properties: Control = %SquadProperties
@onready var host_station_properties: Control = %HostStationProperties


func _ready():
	EventSystem.unit_selected.connect(_update_properties)


func _update_properties():
	if EditorState.selected_unit:
		no_unit_label.hide.call_deferred()
		if EditorState.selected_unit is HostStation: squad_properties.hide.call_deferred()
		elif EditorState.selected_unit is Squad: host_station_properties.hide.call_deferred()
	else:
		no_unit_label.show.call_deferred()
		host_station_properties.hide.call_deferred()
		squad_properties.hide.call_deferred()

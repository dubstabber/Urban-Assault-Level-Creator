extends Control


@onready var map_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer
@onready var sub_viewport_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer
@onready var map = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map

@onready var context_menu = $ContextMenu

@onready var properties_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer
@onready var no_unit_label = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer/TabContainer/Unit/ScrollContainer/MarginContainer/NoUnitLabel
@onready var host_station_properties = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer/TabContainer/Unit/ScrollContainer/MarginContainer/HostStationProperties
@onready var squad_properties = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer/TabContainer/Unit/ScrollContainer/MarginContainer/SquadProperties

@onready var host_stations = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/HostStations
@onready var squads = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/Squads


func _ready():
	get_tree().get_root().connect("size_changed",_on_resize)
	CurrentMapData.connect("selected", _update_properties)


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_local_mouse_position().x)
		var mouse_y = round(get_local_mouse_position().y)
		context_menu.position = Vector2(mouse_x, mouse_y - context_menu.size.y)
		context_menu.show_popup()
		#prints('main: right click, x:', mouse_x, " ,y:",mouse_y)


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	properties_container.size.x = DisplayServer.window_get_size().x/3.0
	map_container.custom_minimum_size.x = DisplayServer.window_get_size().x - properties_container.size.x
	map_container.custom_minimum_size.y = DisplayServer.window_get_size().y - 70
	
	map.recalculate_size()
	sub_viewport_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_container.custom_minimum_size.y = map.map_visible_height


func _update_properties():
	if CurrentMapData.selected_unit:
		no_unit_label.hide()
		var i = 1
		if CurrentMapData.selected_unit is HostStation:
			for hs in host_stations.get_children():
				if CurrentMapData.selected_unit == hs: break
				else: i += 1
			squad_properties.hide()
			host_station_properties.get_node("HBoxContainer/HSnumberLabel").text = "Host station " + str(i) + ": "
			host_station_properties.get_node("HBoxContainer/HSnameLabel").text = CurrentMapData.selected_unit.unit_name
			host_station_properties.get_node("HBoxContainer5/VBoxContainer2/EnergyLineEdit").text = str(CurrentMapData.selected_unit.energy/400)
			host_station_properties.get_node("HBoxContainer5/VBoxContainer2/EnergyLineEdit").text_changed.connect(func(new_value: String):
				var validated_value = int(new_value)
				if validated_value == 0: validated_value = 1
				if validated_value < 1: validated_value = -validated_value
				CurrentMapData.selected_unit.energy = validated_value * 400
				)
			#host_station_properties.get_node("HBoxContainer2/ViewAngleLineEdit")
			
			host_station_properties.show()
		elif CurrentMapData.selected_unit is Squad:
			host_station_properties.hide()
			squad_properties.get_node("HBoxContainer/SquadIcon").texture = Preloads.squad_images[str(CurrentMapData.selected_unit.vehicle)]
			squad_properties.get_node("HBoxContainer/SquadNumberLabel").text = "Squad: "
			squad_properties.get_node("HBoxContainer/SquadNameLabel").text = CurrentMapData.selected_unit.unit_name
			squad_properties.show()
	else:
		no_unit_label.show()
		host_station_properties.hide()
		squad_properties.hide()

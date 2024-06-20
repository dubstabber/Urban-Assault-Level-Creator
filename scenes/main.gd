extends Control


@onready var map_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer
@onready var sub_viewport_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer
@onready var map = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map

@onready var context_menu = $ContextMenu

@onready var properties_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PropertiesContainer

@onready var host_stations = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/HostStations
@onready var squads = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer/SubViewport/Map/Squads


func _ready():
	get_tree().get_root().connect("size_changed",_on_resize)


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



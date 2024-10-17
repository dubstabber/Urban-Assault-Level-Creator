extends Control

@onready var panel_container: PanelContainer = $PanelContainer

@onready var map_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer
@onready var sub_viewport_container = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/MapContainer/SubViewportContainer
@onready var map = %Map

@onready var properties_container = %PropertiesContainer


func _ready():
	get_tree().root.size_changed.connect(_on_resize)
	Signals.map_created.connect(_on_ui_map_created)
	_on_resize()


func _input(event):
	if event.is_action_pressed("context_menu"):
		var mouse_x = round(get_global_mouse_position().x)
		var mouse_y = round(get_global_mouse_position().y)
		map.right_clicked_x_global = mouse_x
		map.right_clicked_y_global = mouse_y


func _on_ui_map_created():
	_on_resize()


func _on_resize():
	properties_container.size.x = DisplayServer.window_get_size().x/3.0
	panel_container.custom_minimum_size.y = DisplayServer.window_get_size().y
	map_container.custom_minimum_size.x = DisplayServer.window_get_size().x - properties_container.size.x
	
	map.recalculate_size()
	sub_viewport_container.custom_minimum_size.x = map.map_visible_width
	sub_viewport_container.custom_minimum_size.y = map.map_visible_height

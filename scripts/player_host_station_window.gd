extends Window


@export var button_group: ButtonGroup


func _ready() -> void:
	button_group.pressed.connect(_update_host_station_for_player)


func _on_about_to_popup() -> void:
	if CurrentMapData.host_stations.get_child_count() <= 0:
		%NoHostStationLabel.show()
		%HostStationContainer.hide()
	else:
		%NoHostStationLabel.hide()
		%HostStationContainer.show()
		
		for child in %HostStationContainer.get_children():
			child.queue_free()
		
		for i in CurrentMapData.host_stations.get_child_count():
			var check_box = CheckBox.new()
			check_box.text = "Host station %s: %s" % [i+1, CurrentMapData.host_stations.get_child(i).unit_name]
			check_box["theme_override_font_sizes/font_size"] = 12
			check_box.button_group = button_group
			check_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			if CurrentMapData.player_host_station == CurrentMapData.host_stations.get_child(i):
				check_box.button_pressed = true
			%HostStationContainer.add_child(check_box)


func _update_host_station_for_player(button) -> void:
	for i in %HostStationContainer.get_child_count():
		if %HostStationContainer.get_child(i) == button:
			CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(i)
			EventSystem.unit_selected.emit()
			
			return


func close() -> void:
	hide()

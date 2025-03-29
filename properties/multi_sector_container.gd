extends VBoxContainer


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	EventSystem.map_view_updated.connect(_update_properties)


func _update_properties() -> void:
	for child in get_children():
		child.queue_free()
	if EditorState.selected_sectors.size() > 1:
		%SectorPropertiesContainer.hide()
		show()
		for sector_dict in EditorState.selected_sectors:
			var sector_label = Label.new()
			sector_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sector_label.text = "Selected sector X:%s Y:%s" % [sector_dict.x, sector_dict.y]
			add_child(sector_label)
	else:
		hide()

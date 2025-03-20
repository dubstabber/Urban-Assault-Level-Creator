extends Window

signal building_selected(index: int)

@onready var building_grid: GridContainer = %BuildingGrid


func _on_about_to_popup() -> void:
	for child in building_grid.get_children():
		child.queue_free()
		building_grid.remove_child(child)
	
	for building_idx in Preloads.building_top_images[CurrentMapData.level_set]:
		var building_button = Button.new()
		building_button.icon = Preloads.building_top_images[CurrentMapData.level_set][building_idx]
		building_button.custom_minimum_size = Vector2(200, 200)
		building_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		building_button.expand_icon = true
		building_button.tooltip_text = "Building " + str(building_idx)
		building_button.set_meta("building_index", building_idx)
		building_button.pressed.connect(func():
			building_selected.emit(building_button.get_meta("building_index"))
			hide()
			)
		building_grid.add_child(building_button)


func close() -> void:
	hide()

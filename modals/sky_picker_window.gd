extends Window

signal sky_selected(sky_name: String)

@onready var sky_grid: GridContainer = %SkyGrid


func _on_about_to_popup() -> void:
	for child in sky_grid.get_children():
		child.queue_free()
		sky_grid.remove_child(child)
	
	for sky in Preloads.skies:
		var sky_button = Button.new()
		sky_button.icon = Preloads.skies[sky]
		sky_button.custom_minimum_size = Vector2(400, 200)
		sky_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sky_button.expand_icon = true
		sky_button.set_meta("sky_name", sky)
		sky_button.pressed.connect(func():
			sky_selected.emit(sky_button.get_meta("sky_name"))
			hide()
			)
		sky_grid.add_child(sky_button)


func close() -> void:
	hide()

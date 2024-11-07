extends PopupMenu


func _ready() -> void:
	add_item("Change level parameters...")
	add_item("Squad enabler...")
	add_item("Change briefing/debriefing maps for this level...")
	add_item("Select a host station for the player...")
	add_item("Write level description...")
	add_item("Prototype modifications...")
	add_item("Generate buildings randomly")
	add_item("Additional game content...")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Change level parameters...":
			%LevelParametersWindow.popup()
		"Squad enabler...":
			print("Implement squad enabler")
		"Change briefing/debriefing maps for this level...":
			print("implement briefing/debriefing maps ui")
		"Select a host station for the player...":
			print("implement host station selection")
		"Write level description...":
			print("implement level description writer")
		"Prototype modifications...":
			print('implement prototype modifications writer')
		"Generate buildings randomly":
			print("implement typ_map random generation")
		"Additional game content...":
			print("implement game content changer")

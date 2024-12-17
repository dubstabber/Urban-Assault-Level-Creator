extends PopupMenu


func _ready() -> void:
	add_item("Change level parameters...")
	add_item("Squad enabler...")
	add_item("Change briefing/debriefing maps for this level...")
	add_item("Select a host station for the player...")
	add_item("Write level description...")
	add_item("Prototype modifications...")
	add_item("Additional game content...")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Change level parameters...":
			%LevelParametersWindow.popup()
		"Squad enabler...":
			%SquadEnablerWindow.popup()
		"Change briefing/debriefing maps for this level...":
			%MissionBriefingMapsWindow.popup()
		"Select a host station for the player...":
			%PlayerHostStationWindow.popup()
		"Write level description...":
			%LevelDescriptionWindow.popup()
		"Prototype modifications...":
			%PrototypeModificationsWindow.popup()
		"Additional game content...":
			%GameContentWindow.popup()

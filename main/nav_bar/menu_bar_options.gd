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
			%LevelParametersWindow.popup.call_deferred()
		"Squad enabler...":
			%SquadEnablerWindow.popup.call_deferred()
		"Change briefing/debriefing maps for this level...":
			%MissionBriefingMapsWindow.popup.call_deferred()
		"Select a host station for the player...":
			%PlayerHostStationWindow.popup.call_deferred()
		"Write level description...":
			%LevelDescriptionWindow.popup.call_deferred()
		"Prototype modifications...":
			%PrototypeModificationsWindow.popup.call_deferred()
		"Additional game content...":
			%GameContentWindow.popup.call_deferred()

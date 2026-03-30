extends PopupMenu


func _ready() -> void:
	add_item("Additional information")
	add_item("Campaign maps")
	add_item("Keyboard shortcuts")
	add_item("About")
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Additional information":
			%AdditionalInformationWindow.popup.call_deferred()
		"Campaign maps":
			%CampaignMapsWindow.popup.call_deferred()
		"Keyboard shortcuts":
			%KeyboardShortcutsWindow.popup.call_deferred()
		"About":
			%AboutWindow.popup.call_deferred()

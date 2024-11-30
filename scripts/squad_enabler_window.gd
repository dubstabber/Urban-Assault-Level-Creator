extends Window


func _on_about_to_popup() -> void:
	for tab in %TabContainer.get_children():
		if "refresh" in tab:
			tab.refresh()


func close() -> void:
	hide()

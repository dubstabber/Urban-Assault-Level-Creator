extends Window


func _on_about_to_popup() -> void:
	for tab in %TabContainer.get_children():
		if "refresh" in tab:
			tab.refresh()


func _on_close_requested() -> void:
	hide()

extends Window

@onready var tab_container: TabContainer = %TabContainer


func _on_about_to_popup() -> void:
	for tab in tab_container.get_children():
		if "refresh" in tab:
			tab.refresh()


func close() -> void:
	hide()

extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().about_to_popup.connect(update_menu)
	get_parent().index_pressed.connect(_on_index_pressed)


func update_menu() -> void:
	get_parent().clear(true)
	if CurrentMapData.selected_unit is HostStation:
		get_parent().add_item("Remove this host station")
	elif CurrentMapData.selected_unit is Squad:
		get_parent().add_item("Remove this squad")
		

func _on_index_pressed(index: int) -> void:
	var text = get_parent().get_item_text(index)
	if text == "Remove this host station" or text == "Remove this squad":
		CurrentMapData.selected_unit.queue_free()
		CurrentMapData.selected_unit = null
		

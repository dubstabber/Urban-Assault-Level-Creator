extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("Change sector height")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	var item_text = get_parent().get_item_text(index)
	if item_text == "Change sector height":
		
		%SectorHeightWindow.popup()

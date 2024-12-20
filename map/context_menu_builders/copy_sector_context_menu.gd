extends Node

func _ready() -> void:
	await get_parent().ready
	get_parent().add_separator()
	get_parent().add_item("Copy the sector")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	var item_text = get_parent().get_item_text(index)
	if item_text == "Copy the sector":
		Utils.copy_sector()

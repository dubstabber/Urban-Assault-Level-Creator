extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("Change sector height")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	if CurrentMapData.border_selected_sector >= 0 and CurrentMapData.hgt_map.size() > 0:
		match index:
			3:
				%SectorHeightWindow.popup()

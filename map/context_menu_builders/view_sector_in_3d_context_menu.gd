extends Node


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("View sector in 3D")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	if get_parent().get_item_text(index) != "View sector in 3D":
		return
	if EditorState.selected_sector_idx < 0:
		return
	if CurrentMapData.horizontal_sectors <= 0:
		return
	var sx := EditorState.selected_sector.x - 1
	var sy := EditorState.selected_sector.y - 1
	EditorState.view_mode_3d = true
	EventSystem.map_3d_focus_sector_requested.emit(sx, sy)

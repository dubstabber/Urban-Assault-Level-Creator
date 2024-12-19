extends VBoxContainer

@export var STOUDSON_BOMB_KEY_SECTOR_CONTAINER: PackedScene


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)


func _update_properties() -> void:
	if EditorState.selected_bomb_key_sector != Vector2i(-1, -1):
		show()
		for child in get_children():
			child.queue_free()
		
		for bomb_index in CurrentMapData.stoudson_bombs.size():
			var ks_index = CurrentMapData.stoudson_bombs[bomb_index].key_sectors.find(EditorState.selected_bomb_key_sector)
			if ks_index >= 0:
				var stoudson_bomb_key_sector_container = STOUDSON_BOMB_KEY_SECTOR_CONTAINER.instantiate()
				if CurrentMapData.stoudson_bombs[bomb_index].inactive_bp == 35:
					stoudson_bomb_key_sector_container.set_labels(ks_index+1, bomb_index+1,"normal")
				elif CurrentMapData.stoudson_bombs[bomb_index].inactive_bp == 68:
					stoudson_bomb_key_sector_container.set_labels(ks_index+1, bomb_index+1,"parasite")
				add_child(stoudson_bomb_key_sector_container)
	else:
		hide()

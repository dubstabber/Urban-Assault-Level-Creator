extends VBoxContainer

@export var BEAM_GATE_KEY_SECTOR_CONTAINER: PackedScene


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)


func _update_properties() -> void:
	if CurrentMapData.selected_bg_key_sector != Vector2i(-1, -1):
		show()
		for child in get_children():
			child.queue_free()
		
		for bg_index in CurrentMapData.beam_gates.size():
			var ks_index = CurrentMapData.beam_gates[bg_index].key_sectors.find(CurrentMapData.selected_bg_key_sector)
			if ks_index >= 0:
				var beam_gate_key_sector_container = BEAM_GATE_KEY_SECTOR_CONTAINER.instantiate()
				beam_gate_key_sector_container.set_labels(ks_index+1, bg_index+1)
				add_child(beam_gate_key_sector_container)
	else:
		hide()

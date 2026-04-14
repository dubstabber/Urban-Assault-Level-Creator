extends Node

@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	await get_parent().ready
	get_parent().add_item("Clean this sector")
	get_parent().index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	var item_text = get_parent().get_item_text(index)
	if item_text == "Clean this sector":
		if CurrentMapData.horizontal_sectors > 0:
			undo_redo_manager.begin_group("Clear sector")
			var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
			var edited_typ_indices: Array = []
			var edited_blg_indices: Array = []
			if EditorState.selected_sectors.size() > 1:
				for sector_dict in EditorState.selected_sectors:
					if sector_dict.has("idx"):
						var idx := int(sector_dict.idx)
						var typ_before := int(CurrentMapData.typ_map[idx])
						var own_before := int(CurrentMapData.own_map[idx])
						var blg_before := int(CurrentMapData.blg_map[idx])
						CurrentMapData.clear_sector(idx, false)
						CurrentMapData.append_edited_map_index(edited_typ_indices, idx, typ_before, int(CurrentMapData.typ_map[idx]))
						CurrentMapData.append_edited_map_index(edited_blg_indices, idx, blg_before, int(CurrentMapData.blg_map[idx]))
						undo_redo_manager.record_change({
							"map": "typ_map",
							"index": idx,
							"before": typ_before,
							"after": int(CurrentMapData.typ_map[idx])
						})
						undo_redo_manager.record_change({
							"map": "own_map",
							"index": idx,
							"before": own_before,
							"after": int(CurrentMapData.own_map[idx])
						})
						undo_redo_manager.record_change({
							"map": "blg_map",
							"index": idx,
							"before": blg_before,
							"after": int(CurrentMapData.blg_map[idx])
						})
			else:
				if EditorState.selected_sector_idx < 0:
					undo_redo_manager.commit_group()
					return
				var idx := EditorState.selected_sector_idx
				var typ_before := int(CurrentMapData.typ_map[idx])
				var own_before := int(CurrentMapData.own_map[idx])
				var blg_before := int(CurrentMapData.blg_map[idx])
				CurrentMapData.clear_sector(idx, false)
				CurrentMapData.append_edited_map_index(edited_typ_indices, idx, typ_before, int(CurrentMapData.typ_map[idx]))
				CurrentMapData.append_edited_map_index(edited_blg_indices, idx, blg_before, int(CurrentMapData.blg_map[idx]))
				undo_redo_manager.record_change({
					"map": "typ_map",
					"index": idx,
					"before": typ_before,
					"after": int(CurrentMapData.typ_map[idx])
				})
				undo_redo_manager.record_change({
					"map": "own_map",
					"index": idx,
					"before": own_before,
					"after": int(CurrentMapData.own_map[idx])
				})
				undo_redo_manager.record_change({
					"map": "blg_map",
					"index": idx,
					"before": blg_before,
					"after": int(CurrentMapData.blg_map[idx])
				})
			undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
			undo_redo_manager.commit_group()
			EventSystem.map_updated.emit()
			EventSystem.item_updated.emit()

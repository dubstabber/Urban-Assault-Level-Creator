extends RefCounted

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _check_eq(a, b, msg: String) -> void:
	if a != b:
		var full_msg := "%s (got %s, expected %s)" % [msg, str(a), str(b)]
		push_error(full_msg)
		_errors.append(full_msg)


func _snapshot_state() -> Dictionary:
	return {
		"horizontal_sectors": CurrentMapData.horizontal_sectors,
		"vertical_sectors": CurrentMapData.vertical_sectors,
		"typ_map": CurrentMapData.typ_map.duplicate(),
		"own_map": CurrentMapData.own_map.duplicate(),
		"blg_map": CurrentMapData.blg_map.duplicate(),
		"beam_gates": CurrentMapData.beam_gates.duplicate(),
		"stoudson_bombs": CurrentMapData.stoudson_bombs.duplicate(),
		"tech_upgrades": CurrentMapData.tech_upgrades.duplicate(),
		"selected_sector_idx": EditorState.selected_sector_idx,
		"selected_sector": EditorState.selected_sector,
		"selected_sectors": EditorState.selected_sectors.duplicate(true),
		"selected_beam_gate": EditorState.selected_beam_gate,
		"selected_bomb": EditorState.selected_bomb,
		"selected_tech_upgrade": EditorState.selected_tech_upgrade,
		"selected_bg_key_sector": EditorState.selected_bg_key_sector,
		"selected_bomb_key_sector": EditorState.selected_bomb_key_sector,
		"sector_clipboard": EditorState.sector_clipboard.duplicate(true),
	}


func _restore_state(snapshot: Dictionary) -> void:
	var typ_map_snapshot: PackedByteArray = snapshot.get("typ_map", PackedByteArray())
	var own_map_snapshot: PackedByteArray = snapshot.get("own_map", PackedByteArray())
	var blg_map_snapshot: PackedByteArray = snapshot.get("blg_map", PackedByteArray())
	CurrentMapData.horizontal_sectors = int(snapshot.get("horizontal_sectors", 0))
	CurrentMapData.vertical_sectors = int(snapshot.get("vertical_sectors", 0))
	CurrentMapData.typ_map = typ_map_snapshot.duplicate()
	CurrentMapData.own_map = own_map_snapshot.duplicate()
	CurrentMapData.blg_map = blg_map_snapshot.duplicate()
	CurrentMapData.beam_gates = snapshot.get("beam_gates", []).duplicate()
	CurrentMapData.stoudson_bombs = snapshot.get("stoudson_bombs", []).duplicate()
	CurrentMapData.tech_upgrades = snapshot.get("tech_upgrades", []).duplicate()
	EditorState.selected_sector_idx = int(snapshot.get("selected_sector_idx", -1))
	EditorState.selected_sector = snapshot.get("selected_sector", Vector2i(-1, -1))
	EditorState.selected_sectors = snapshot.get("selected_sectors", []).duplicate(true)
	EditorState.selected_beam_gate = snapshot.get("selected_beam_gate", null)
	EditorState.selected_bomb = snapshot.get("selected_bomb", null)
	EditorState.selected_tech_upgrade = snapshot.get("selected_tech_upgrade", null)
	EditorState.selected_bg_key_sector = snapshot.get("selected_bg_key_sector", Vector2i(-1, -1))
	EditorState.selected_bomb_key_sector = snapshot.get("selected_bomb_key_sector", Vector2i(-1, -1))
	EditorState.sector_clipboard = snapshot.get("sector_clipboard", {}).duplicate(true)


func _capture_event_sequence(callback: Callable) -> Array:
	var events: Array = []
	var hgt_cb := func(indices: Array) -> void:
		events.append({"name": "hgt", "payload": indices.duplicate()})
	var typ_cb := func(indices: Array) -> void:
		events.append({"name": "typ", "payload": indices.duplicate()})
	var blg_cb := func(indices: Array) -> void:
		events.append({"name": "blg", "payload": indices.duplicate()})
	var updated_cb := func() -> void:
		events.append({"name": "updated"})
	EventSystem.hgt_map_cells_edited.connect(hgt_cb)
	EventSystem.typ_map_cells_edited.connect(typ_cb)
	EventSystem.blg_map_cells_edited.connect(blg_cb)
	EventSystem.map_updated.connect(updated_cb)
	callback.call()
	EventSystem.hgt_map_cells_edited.disconnect(hgt_cb)
	EventSystem.typ_map_cells_edited.disconnect(typ_cb)
	EventSystem.blg_map_cells_edited.disconnect(blg_cb)
	EventSystem.map_updated.disconnect(updated_cb)
	return events


func test_emit_map_edit_update_orders_fine_grained_signals_before_map_updated() -> bool:
	_reset_errors()
	var events := _capture_event_sequence(func() -> void:
		CurrentMapData.emit_map_edit_update([7], [3], [5])
	)
	_check_eq(events.size(), 4, "emit_map_edit_update should emit three fine-grained signals plus map_updated")
	if events.size() >= 4:
		_check_eq(String(events[0].get("name", "")), "hgt", "emit_map_edit_update should emit hgt edits first")
		_check_eq(String(events[1].get("name", "")), "typ", "emit_map_edit_update should emit typ edits second")
		_check_eq(String(events[2].get("name", "")), "blg", "emit_map_edit_update should emit blg edits third")
		_check_eq(String(events[3].get("name", "")), "updated", "emit_map_edit_update should emit map_updated last")
	return _errors.is_empty()


func test_clear_sector_emits_typ_and_blg_before_map_updated() -> bool:
	_reset_errors()
	var snapshot := _snapshot_state()
	CurrentMapData.horizontal_sectors = 1
	CurrentMapData.vertical_sectors = 1
	CurrentMapData.typ_map = PackedByteArray([12])
	CurrentMapData.own_map = PackedByteArray([3])
	CurrentMapData.blg_map = PackedByteArray([44])
	CurrentMapData.beam_gates.clear()
	CurrentMapData.stoudson_bombs.clear()
	CurrentMapData.tech_upgrades.clear()
	EditorState.selected_beam_gate = null
	EditorState.selected_bomb = null
	EditorState.selected_tech_upgrade = null
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	var events := _capture_event_sequence(func() -> void:
		CurrentMapData.clear_sector(0, true)
	)
	_check_eq(CurrentMapData.typ_map[0], 0, "clear_sector should clear typ_map")
	_check_eq(CurrentMapData.blg_map[0], 0, "clear_sector should clear blg_map")
	_check_eq(events.size(), 3, "clear_sector should emit typ, blg, then map_updated")
	if events.size() >= 3:
		_check_eq(String(events[0].get("name", "")), "typ", "clear_sector should emit typ edits before map_updated")
		_check_eq(String(events[1].get("name", "")), "blg", "clear_sector should emit blg edits before map_updated")
		_check_eq(String(events[2].get("name", "")), "updated", "clear_sector should emit map_updated last")
		_check_eq(events[0].get("payload", []), [0], "clear_sector should report the edited typ sector")
		_check_eq(events[1].get("payload", []), [0], "clear_sector should report the edited blg sector")
	_restore_state(snapshot)
	return _errors.is_empty()


func test_paste_sector_emits_typ_and_blg_before_map_updated() -> bool:
	_reset_errors()
	var snapshot := _snapshot_state()
	CurrentMapData.horizontal_sectors = 1
	CurrentMapData.vertical_sectors = 1
	CurrentMapData.typ_map = PackedByteArray([2])
	CurrentMapData.own_map = PackedByteArray([1])
	CurrentMapData.blg_map = PackedByteArray([8])
	CurrentMapData.beam_gates.clear()
	CurrentMapData.stoudson_bombs.clear()
	CurrentMapData.tech_upgrades.clear()
	EditorState.selected_sector_idx = 0
	EditorState.selected_sector = Vector2i(1, 1)
	EditorState.selected_sectors.clear()
	EditorState.selected_bg_key_sector = Vector2i(-1, -1)
	EditorState.selected_bomb_key_sector = Vector2i(-1, -1)
	EditorState.sector_clipboard = {
		"typ_map": 23,
		"own_map": 6,
		"blg_map": 51,
		"beam_gate": null,
		"stoudson_bomb": null,
		"tech_upgrade": null,
		"bg_key_sector_parent": null,
		"bomb_key_sector_parent": null
	}
	UndoRedoManager.clear_history()
	var events := _capture_event_sequence(func() -> void:
		Utils.paste_sector()
	)
	_check_eq(CurrentMapData.typ_map[0], 23, "paste_sector should update typ_map")
	_check_eq(CurrentMapData.own_map[0], 6, "paste_sector should update own_map")
	_check_eq(CurrentMapData.blg_map[0], 51, "paste_sector should update blg_map")
	_check_eq(events.size(), 3, "paste_sector should emit typ, blg, then map_updated")
	if events.size() >= 3:
		_check_eq(String(events[0].get("name", "")), "typ", "paste_sector should emit typ edits before map_updated")
		_check_eq(String(events[1].get("name", "")), "blg", "paste_sector should emit blg edits before map_updated")
		_check_eq(String(events[2].get("name", "")), "updated", "paste_sector should emit map_updated last")
		_check_eq(events[0].get("payload", []), [0], "paste_sector should report the edited typ sector")
		_check_eq(events[1].get("payload", []), [0], "paste_sector should report the edited blg sector")
	_restore_state(snapshot)
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for name in [
		"test_emit_map_edit_update_orders_fine_grained_signals_before_map_updated",
		"test_clear_sector_emits_typ_and_blg_before_map_updated",
		"test_paste_sector_emits_typ_and_blg_before_map_updated",
	]:
		print("RUN ", name)
		if bool(call(name)):
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

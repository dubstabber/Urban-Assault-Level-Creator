extends Node

var add_bg_key_sector_submenu: PopupMenu
var add_bomb_key_sector_submenu: PopupMenu
@onready var undo_redo_manager = get_node("/root/UndoRedoManager")


func _ready() -> void:
	await get_parent().ready
	var add_item_submenu: PopupMenu = PopupMenu.new()
	add_item_submenu.name = 'add_item'
	add_item_submenu["theme_override_fonts/font"] = Preloads.font
	get_parent().add_child(add_item_submenu)
	
	var new_item_submenu: PopupMenu = PopupMenu.new()
	new_item_submenu.name = 'new_item'
	new_item_submenu["theme_override_fonts/font"] = Preloads.font
	add_item_submenu.add_child(new_item_submenu)
	
	var new_beam_gate: PopupMenu = PopupMenu.new()
	new_beam_gate.name = 'beam_gate'
	new_item_submenu.add_item('Beam Gate')
	var new_stoudson_bomb: PopupMenu = PopupMenu.new()
	new_stoudson_bomb.name = 'stoudson_bomb'
	new_item_submenu.add_item('Stoudson Bomb')
	var new_tech_upgrade: PopupMenu = PopupMenu.new()
	new_tech_upgrade.name = 'tech_upgrade'
	new_item_submenu.add_item('Tech Upgrade')
	
	add_bg_key_sector_submenu = PopupMenu.new()
	add_bg_key_sector_submenu.name = 'add_beam_gate_key_sector'
	add_bg_key_sector_submenu["theme_override_fonts/font"] = Preloads.font
	add_item_submenu.add_child(add_bg_key_sector_submenu)
	
	add_bomb_key_sector_submenu = PopupMenu.new()
	add_bomb_key_sector_submenu.name = 'add_bomb_key_sector'
	add_bomb_key_sector_submenu["theme_override_fonts/font"] = Preloads.font
	add_item_submenu.add_child(add_bomb_key_sector_submenu)
	
	new_item_submenu.index_pressed.connect(_new_item.bind(new_item_submenu))
	add_bg_key_sector_submenu.index_pressed.connect(_add_beam_gate_key_sector)
	add_bomb_key_sector_submenu.index_pressed.connect(_add_bomb_key_sector)
	
	add_item_submenu.add_submenu_item('New item', 'new_item')
	add_item_submenu.add_submenu_item('Add beam gate key sector to', 'add_beam_gate_key_sector')
	add_item_submenu.add_submenu_item('Add stoudson bomb key sector to', 'add_bomb_key_sector')
	
	get_parent().add_submenu_item('Add sector item', 'add_item')
	EventSystem.item_updated.connect(update_beam_gate_key_sector_submenu)
	EventSystem.item_updated.connect(update_bomb_key_sector_submenu)


func _new_item(index:int, new_item_submenu: PopupMenu) -> void:
	if not(EditorState.selected_sector.x > 0 and 
	EditorState.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	EditorState.selected_sector.y > 0 and 
	EditorState.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	var item_text = new_item_submenu.get_item_text(index)
	match item_text:
		'Beam Gate':
			for bg in CurrentMapData.beam_gates:
				if bg.sec_x == EditorState.selected_sector.x and bg.sec_y == EditorState.selected_sector.y:
					return
		'Stoudson Bomb':
			for bomb in CurrentMapData.stoudson_bombs:
				if bomb.sec_x == EditorState.selected_sector.x and bomb.sec_y == EditorState.selected_sector.y:
					return
		'Tech Upgrade':
			for tu in CurrentMapData.tech_upgrades:
				if tu.sec_x == EditorState.selected_sector.x and tu.sec_y == EditorState.selected_sector.y:
					return

	undo_redo_manager.begin_group("Add sector item")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	var typ_before := int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
	var blg_before := int(CurrentMapData.blg_map[EditorState.selected_sector_idx])
	match item_text:
		'Beam Gate':
			var bg = BeamGate.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			CurrentMapData.beam_gates.append(bg)
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 3
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = bg.closed_bp
			EditorState.selected_beam_gate = bg
			EventSystem.item_updated.emit()
		'Stoudson Bomb':
			var bomb = StoudsonBomb.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			CurrentMapData.stoudson_bombs.append(bomb)
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 245
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = bomb.inactive_bp
			EditorState.selected_bomb = bomb
			EventSystem.item_updated.emit()
		'Tech Upgrade':
			var tu = TechUpgrade.new(EditorState.selected_sector.x, EditorState.selected_sector.y)
			CurrentMapData.tech_upgrades.append(tu)
			CurrentMapData.typ_map[EditorState.selected_sector_idx] = 100
			CurrentMapData.blg_map[EditorState.selected_sector_idx] = tu.building_id
			EditorState.selected_tech_upgrade = tu
			EventSystem.item_updated.emit()
	EventSystem.item_added.emit()
	undo_redo_manager.record_change({
		"map": "typ_map",
		"index": EditorState.selected_sector_idx,
		"before": typ_before,
		"after": int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
	})
	undo_redo_manager.record_change({
		"map": "blg_map",
		"index": EditorState.selected_sector_idx,
		"before": blg_before,
		"after": int(CurrentMapData.blg_map[EditorState.selected_sector_idx])
	})
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()
	var edited_typ_indices: Array = []
	var edited_blg_indices: Array = []
	CurrentMapData.append_edited_map_index(edited_typ_indices, EditorState.selected_sector_idx, typ_before, int(CurrentMapData.typ_map[EditorState.selected_sector_idx]))
	CurrentMapData.append_edited_map_index(edited_blg_indices, EditorState.selected_sector_idx, blg_before, int(CurrentMapData.blg_map[EditorState.selected_sector_idx]))
	EventSystem.map_updated.emit()


func _add_beam_gate_key_sector(index: int) -> void:
	if not(EditorState.selected_sector.x > 0 and 
	EditorState.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	EditorState.selected_sector.y > 0 and 
	EditorState.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	
	# Prevent key sector duplication in the same sector
	for ks in CurrentMapData.beam_gates[index].key_sectors:
		if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
			return
	
	undo_redo_manager.begin_group("Add beam gate key sector")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	var key_sector = Vector2i(EditorState.selected_sector.x, EditorState.selected_sector.y)
	CurrentMapData.beam_gates[index].key_sectors.append(key_sector)
	EditorState.selected_bg_key_sector = key_sector
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()
	EventSystem.map_updated.emit()


func _add_bomb_key_sector(index: int) -> void:
	if not(EditorState.selected_sector.x > 0 and 
	EditorState.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	EditorState.selected_sector.y > 0 and 
	EditorState.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	
	# Prevent key sector duplication in the same sector
	for ks in CurrentMapData.stoudson_bombs[index].key_sectors:
		if ks.x == EditorState.selected_sector.x and ks.y == EditorState.selected_sector.y:
			return
	
	undo_redo_manager.begin_group("Add bomb key sector")
	var item_before: Dictionary = undo_redo_manager.create_item_snapshot()
	var typ_before := int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
	var bomb_key_sector = Vector2i(EditorState.selected_sector.x, EditorState.selected_sector.y)
	CurrentMapData.stoudson_bombs[index].key_sectors.append(bomb_key_sector)
	CurrentMapData.typ_map[EditorState.selected_sector_idx] = 243
	EditorState.selected_bomb_key_sector = bomb_key_sector
	undo_redo_manager.record_change({
		"map": "typ_map",
		"index": EditorState.selected_sector_idx,
		"before": typ_before,
		"after": int(CurrentMapData.typ_map[EditorState.selected_sector_idx])
	})
	undo_redo_manager.record_item_snapshot(item_before, undo_redo_manager.create_item_snapshot())
	undo_redo_manager.commit_group()
	var edited_typ_indices: Array = []
	CurrentMapData.append_edited_map_index(edited_typ_indices, EditorState.selected_sector_idx, typ_before, int(CurrentMapData.typ_map[EditorState.selected_sector_idx]))
	EventSystem.map_updated.emit()


func update_beam_gate_key_sector_submenu() -> void:
	add_bg_key_sector_submenu.clear(true)
	for i in CurrentMapData.beam_gates.size():
		add_bg_key_sector_submenu.add_item('Beam Gate '+str(i+1))


func update_bomb_key_sector_submenu() -> void:
	add_bomb_key_sector_submenu.clear(true)
	for i in CurrentMapData.stoudson_bombs.size():
		add_bomb_key_sector_submenu.add_item('Stoudson Bomb '+str(i+1))

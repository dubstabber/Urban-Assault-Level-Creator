extends Node

var add_bg_key_sector_submenu: PopupMenu
var add_bomb_key_sector_submenu: PopupMenu


func _ready() -> void:
	await get_parent().ready
	var add_item_submenu: PopupMenu = PopupMenu.new()
	add_item_submenu.name = 'add_item'
	get_parent().add_child(add_item_submenu)
	
	var new_item_submenu: PopupMenu = PopupMenu.new()
	new_item_submenu.name = 'new_item'
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
	add_item_submenu.add_child(add_bg_key_sector_submenu)
	
	add_bomb_key_sector_submenu = PopupMenu.new()
	add_bomb_key_sector_submenu.name = 'add_bomb_key_sector'
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
	if not(CurrentMapData.selected_sector.x > 0 and 
	CurrentMapData.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	CurrentMapData.selected_sector.y > 0 and 
	CurrentMapData.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	var item_text = new_item_submenu.get_item_text(index)
	match item_text:
		'Beam Gate':
			for bg in CurrentMapData.beam_gates:
				if bg.sec_x == CurrentMapData.selected_sector.x and bg.sec_y == CurrentMapData.selected_sector.y:
					return
			
			var bg = BeamGate.new(CurrentMapData.selected_sector.x,CurrentMapData.selected_sector.y)
			CurrentMapData.beam_gates.append(bg)
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 202
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = bg.closed_bp
			CurrentMapData.selected_beam_gate = bg
			EventSystem.item_updated.emit()
		'Stoudson Bomb':
			for bomb in CurrentMapData.stoudson_bombs:
				if bomb.sec_x == CurrentMapData.selected_sector.x and bomb.sec_y == CurrentMapData.selected_sector.y:
					return
			
			var bomb = StoudsonBomb.new(CurrentMapData.selected_sector.x,CurrentMapData.selected_sector.y)
			CurrentMapData.stoudson_bombs.append(bomb)
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 245
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = bomb.inactive_bp
			CurrentMapData.selected_bomb = bomb
			EventSystem.item_updated.emit()
		'Tech Upgrade':
			for tu in CurrentMapData.tech_upgrades:
				if tu.sec_x == CurrentMapData.selected_sector.x and tu.sec_y == CurrentMapData.selected_sector.y:
					return
			
			var tu = TechUpgrade.new(CurrentMapData.selected_sector.x,CurrentMapData.selected_sector.y)
			CurrentMapData.tech_upgrades.append(tu)
			CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 100
			CurrentMapData.blg_map[CurrentMapData.selected_sector_idx] = tu.building_id
			CurrentMapData.selected_tech_upgrade = tu
			EventSystem.item_updated.emit()
	EventSystem.map_updated.emit()


func _add_beam_gate_key_sector(index: int) -> void:
	if not(CurrentMapData.selected_sector.x > 0 and 
	CurrentMapData.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	CurrentMapData.selected_sector.y > 0 and 
	CurrentMapData.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	
	# Prevent key sector duplication in the same sector
	for ks in CurrentMapData.beam_gates[index].key_sectors:
		if ks.x == CurrentMapData.selected_sector.x and ks.y == CurrentMapData.selected_sector.y:
			return
	
	var key_sector = Vector2i(CurrentMapData.selected_sector.x, CurrentMapData.selected_sector.y)
	CurrentMapData.beam_gates[index].key_sectors.append(key_sector)
	CurrentMapData.selected_bg_key_sector = key_sector
	EventSystem.map_updated.emit()


func _add_bomb_key_sector(index: int) -> void:
	if not(CurrentMapData.selected_sector.x > 0 and 
	CurrentMapData.selected_sector.x < CurrentMapData.horizontal_sectors+1 and
	CurrentMapData.selected_sector.y > 0 and 
	CurrentMapData.selected_sector.y < CurrentMapData.vertical_sectors+1):
		return
	
	# Prevent key sector duplication in the same sector
	for ks in CurrentMapData.stoudson_bombs[index].key_sectors:
		if ks.x == CurrentMapData.selected_sector.x and ks.y == CurrentMapData.selected_sector.y:
			return
	
	var bomb_key_sector = Vector2i(CurrentMapData.selected_sector.x, CurrentMapData.selected_sector.y)
	CurrentMapData.stoudson_bombs[index].key_sectors.append(bomb_key_sector)
	CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = 243
	CurrentMapData.selected_bomb_key_sector = bomb_key_sector
	EventSystem.map_updated.emit()


func update_beam_gate_key_sector_submenu() -> void:
	add_bg_key_sector_submenu.clear(true)
	for i in CurrentMapData.beam_gates.size():
		add_bg_key_sector_submenu.add_item('Beam Gate '+str(i+1))


func update_bomb_key_sector_submenu() -> void:
	add_bomb_key_sector_submenu.clear(true)
	for i in CurrentMapData.stoudson_bombs.size():
		add_bomb_key_sector_submenu.add_item('Stoudson Bomb '+str(i+1))

extends Node


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
	
	new_item_submenu.index_pressed.connect(_new_item.bind(new_item_submenu))
	
	add_item_submenu.add_submenu_item('New item', 'new_item')
	
	get_parent().add_submenu_item('Add sector item', 'add_item')


func _new_item(index:int, new_item_submenu: PopupMenu) -> void:
	var item_text = new_item_submenu.get_item_text(index)
	match item_text:
		'Beam Gate':
			var is_added := false
			for bg in CurrentMapData.beam_gates:
				if bg.sec_x == CurrentMapData.selected_sector_x and bg.sec_y == CurrentMapData.selected_sector_y:
					is_added = true
					break
			
			if not is_added:
				var bg = BeamGate.new(CurrentMapData.selected_sector_x,CurrentMapData.selected_sector_y)
				CurrentMapData.beam_gates.append(bg)
		'Stoudson Bomb':
			var is_added := false
			for bomb in CurrentMapData.stoudson_bombs:
				if bomb.sec_x == CurrentMapData.selected_sector_x and bomb.sec_y == CurrentMapData.selected_sector_y:
					is_added = true
					break
			
			if not is_added:
				var bomb = StoudsonBomb.new(CurrentMapData.selected_sector_x,CurrentMapData.selected_sector_y)
				CurrentMapData.stoudson_bombs.append(bomb)
		'Tech Upgrade':
			print('add tech upgrade here')
	EventSystem.map_updated.emit()

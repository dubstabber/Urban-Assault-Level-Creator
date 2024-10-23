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
			print('add beam gate here')
		'Stoudson Bomb':
			print('add stoudson bomb here')
		'Tech Upgrade':
			print('add tech upgrade here')

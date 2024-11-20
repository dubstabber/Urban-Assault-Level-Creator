extends Node

var squad_submenu: PopupMenu = PopupMenu.new()


func _ready() -> void:
	await get_parent().ready
	squad_submenu.name = "squad"
	get_parent().add_child(squad_submenu)
	update_menus()
	get_parent().add_submenu_item("Add squad", "squad")
	EventSystem.game_type_changed.connect(update_menus)


func update_menus() -> void:
	for menu in squad_submenu.get_children():
		menu.queue_free()
	squad_submenu.clear(true)
	
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		var squads: PopupMenu = PopupMenu.new()
		squads.name = hs+"-squads"
		squad_submenu.add_child(squads)
		if Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].units.size() > 0:
			for squad in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].units:
				var squad_image = Preloads.squad_images[str(squad.id)]
				squads.add_icon_item(squad_image, squad.name)
			squad_submenu.add_submenu_item(hs+" units", squads.name)
		
		squads.connect("index_pressed", add_squad.bind(squads, hs, 
			Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner))
	
	if Preloads.ua_data.data[CurrentMapData.game_data_type].other.units.size() > 0:
		var squads: PopupMenu = PopupMenu.new()
		squads.name = "special-squads"
		squad_submenu.add_child(squads)
		for squad in Preloads.ua_data.data[CurrentMapData.game_data_type].other.units:
			var squad_image = Preloads.squad_images[str(squad.id)]
			squads.add_icon_item(squad_image, squad.name)
		squad_submenu.add_submenu_item("Special units", squads.name)
		squads.connect("index_pressed", add_squad.bind(squads, 
			Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations.keys()[0], 
			Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations.values()[0].owner, 
			true))
	


func add_squad(idx: int, squads_menu: PopupMenu, faction: String, owner_id: int, is_other := false):
	if not CurrentMapData.typ_map.size() > 0: return
	var squad_name = squads_menu.get_item_text(idx)
	var squad_data: Dictionary
	if not is_other: 
		for sq in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[faction].units:
			if sq.name == squad_name:
				squad_data = sq
				break
	else:
		for sq in Preloads.ua_data.data[CurrentMapData.game_data_type].other.units:
			if sq.name == squad_name:
				squad_data = sq
				break
	EventSystem.squad_added.emit(squad_data, owner_id)

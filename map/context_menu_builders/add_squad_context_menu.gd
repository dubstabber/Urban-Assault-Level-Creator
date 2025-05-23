extends Node

var squad_submenu: PopupMenu = PopupMenu.new()


func _ready() -> void:
	await get_parent().ready
	if not Preloads.ua_data.data.has("original"): return
	squad_submenu.name = "squad"
	squad_submenu["theme_override_fonts/font"] = Preloads.font
	get_parent().add_child(squad_submenu)
	update_menus()
	get_parent().add_submenu_item("Add squad", "squad")
	EventSystem.game_type_changed.connect(update_menus)


func update_menus() -> void:
	for menu in squad_submenu.get_children():
		menu.queue_free()
	squad_submenu.clear(true)
	
	if Preloads.ua_data.data[EditorState.game_data_type].has("hoststations"):
		for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
			var squads: PopupMenu = PopupMenu.new()
			squads.name = hs+"-squads"
			squads["theme_override_fonts/font"] = Preloads.font
			squad_submenu.add_child(squads)
			if Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].units.size() > 0:
				for squad in Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].units:
					var squad_image = Preloads.squad_images[int(squad.id)]
					squads.add_icon_item(squad_image, squad.name, int(squad.id))
				squad_submenu.add_submenu_item(hs+" units", squads.name)
			
			squads.connect("index_pressed", add_squad.bind(squads, 
				Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner))
		
		if Preloads.ua_data.data[EditorState.game_data_type].other.units.size() > 0:
			var squads: PopupMenu = PopupMenu.new()
			squads.name = "special-squads"
			squads["theme_override_fonts/font"] = Preloads.font
			squad_submenu.add_child(squads)
			for squad in Preloads.ua_data.data[EditorState.game_data_type].other.units:
				var squad_id = int(squad.id)
				var squad_image = Preloads.squad_images[squad_id]
				squads.add_icon_item(squad_image, squad.name, squad_id)
			squad_submenu.add_submenu_item("Special units", squads.name)
			squads.connect("index_pressed", add_squad.bind(squads, 
				Preloads.ua_data.data[EditorState.game_data_type].hoststations.values()[0].owner))


func add_squad(idx: int, squads_menu: PopupMenu, owner_id: int):
	if CurrentMapData.typ_map.is_empty(): return
	var vehicle_id = squads_menu.get_item_id(idx)
	EventSystem.squad_added.emit(owner_id, vehicle_id)

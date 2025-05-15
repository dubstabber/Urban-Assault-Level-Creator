extends Node


func _ready() -> void:
	await get_parent().ready
	if not Preloads.ua_data.data.has("original") or not Preloads.ua_data.data["original"].has("hoststations"): return
	var hs_submenu: PopupMenu = PopupMenu.new()
	hs_submenu.name = "hoststation"
	hs_submenu["theme_override_fonts/font"] = Preloads.font
	get_parent().add_child(hs_submenu)
	
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		var hs_owner_id = int(Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner)
		var hs_image = Preloads.hs_images[hs_owner_id]
		hs_submenu.add_icon_item(hs_image, hs, int(hs_owner_id))
	
	hs_submenu.connect("index_pressed", add_hoststation.bind(hs_submenu))
	get_parent().add_submenu_item("Add host station", "hoststation")


func add_hoststation(idx, submenu) -> void:
	if CurrentMapData.typ_map.is_empty(): return
	var owner_id = submenu.get_item_id(idx)
	var vehicle_id: int
	for hs in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
		if Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].owner == owner_id:
			vehicle_id = int(Preloads.ua_data.data[EditorState.game_data_type].hoststations[hs].robos[0].id)
			EventSystem.hoststation_added.emit(owner_id, vehicle_id)
			return

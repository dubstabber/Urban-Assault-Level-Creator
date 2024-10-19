extends Node


func _ready() -> void:
	await get_parent().ready
	var hs_submenu: PopupMenu = PopupMenu.new()
	hs_submenu.name = "hoststation"
	get_parent().add_child(hs_submenu)
	for hs in Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations:
		var hs_owner_id = str(Preloads.ua_data.data[CurrentMapData.game_data_type].hoststations[hs].owner)
		var hs_image = Preloads.hs_images[hs_owner_id]
		hs_submenu.add_icon_item(hs_image, hs)
	hs_submenu.connect("index_pressed", add_hoststation.bind(hs_submenu))
	get_parent().add_submenu_item("Add host station", "hoststation")


func add_hoststation(idx, submenu):
	Signals.hoststation_added.emit(submenu.get_item_text(idx))

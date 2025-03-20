extends PopupMenu

var resistance_swap: PopupMenu = PopupMenu.new()
var ghorkov_swap: PopupMenu = PopupMenu.new()
var taerkasten_swap: PopupMenu = PopupMenu.new()
var mykonian_swap: PopupMenu = PopupMenu.new()
var sulgogar_swap: PopupMenu = PopupMenu.new()
var blacksect_swap: PopupMenu = PopupMenu.new()
var training_swap: PopupMenu = PopupMenu.new()


func _ready() -> void:
	add_item("Select all sectors")
	add_item("Select all sectors except the borders")
	
	add_separator()
	
	resistance_swap.name = "resistance-swap"
	resistance_swap["theme_override_fonts/font"] = Preloads.font
	add_child(resistance_swap)
	add_submenu_item("Swap resistance sectors with", "resistance-swap")
	
	ghorkov_swap.name = "ghorkov-swap"
	ghorkov_swap["theme_override_fonts/font"] = Preloads.font
	add_child(ghorkov_swap)
	add_submenu_item("Swap ghorkov sectors with", "ghorkov-swap")
	
	taerkasten_swap.name = "taerkasten-swap"
	taerkasten_swap["theme_override_fonts/font"] = Preloads.font
	add_child(taerkasten_swap)
	add_submenu_item("Swap taerkasten sectors with", "taerkasten-swap")
	
	mykonian_swap.name = "mykonian-swap"
	mykonian_swap["theme_override_fonts/font"] = Preloads.font
	add_child(mykonian_swap)
	add_submenu_item("Swap mykonian sectors with", "mykonian-swap")
	
	sulgogar_swap.name = "sulgogar-swap"
	sulgogar_swap["theme_override_fonts/font"] = Preloads.font
	add_child(sulgogar_swap)
	add_submenu_item("Swap sulgogar sectors with", "sulgogar-swap")
	
	blacksect_swap.name = "blacksect-swap"
	blacksect_swap["theme_override_fonts/font"] = Preloads.font
	add_child(blacksect_swap)
	add_submenu_item("Swap black sect sectors with", "blacksect-swap")
	
	training_swap.name = "training-swap"
	training_swap["theme_override_fonts/font"] = Preloads.font
	add_child(training_swap)
	add_submenu_item("Swap training sectors with", "training-swap")
	
	for faction in Preloads.ua_data.data[EditorState.game_data_type].hoststations.keys():
		var owner_id = Preloads.ua_data.data[EditorState.game_data_type].hoststations[faction].owner
		if owner_id != 1: resistance_swap.add_item(faction, owner_id)
		if owner_id != 6: ghorkov_swap.add_item(faction, owner_id)
		if owner_id != 4: taerkasten_swap.add_item(faction, owner_id)
		if owner_id != 3: mykonian_swap.add_item(faction, owner_id)
		if owner_id != 2: sulgogar_swap.add_item(faction, owner_id)
		if owner_id != 5: blacksect_swap.add_item(faction, owner_id)
		if owner_id != 7: training_swap.add_item(faction, owner_id)
	
	resistance_swap.id_pressed.connect(swap_sector_owners.bind(1))
	ghorkov_swap.id_pressed.connect(swap_sector_owners.bind(6))
	taerkasten_swap.id_pressed.connect(swap_sector_owners.bind(4))
	mykonian_swap.id_pressed.connect(swap_sector_owners.bind(3))
	sulgogar_swap.id_pressed.connect(swap_sector_owners.bind(2))
	blacksect_swap.id_pressed.connect(swap_sector_owners.bind(5))
	training_swap.id_pressed.connect(swap_sector_owners.bind(7))
	
	index_pressed.connect(_on_index_pressed)


func _on_index_pressed(index: int) -> void:
	match get_item_text(index):
		"Select all sectors":
			Utils.select_all_sectors()
		"Select all sectors except the borders":
			Utils.select_all_sectors(true)


func swap_sector_owners(to_owner: int, from_owner: int ) -> void:
	if CurrentMapData.own_map.size() > 0:
		for i in CurrentMapData.own_map.size():
			if CurrentMapData.own_map[i] == from_owner:
				CurrentMapData.own_map[i] = to_owner
			elif CurrentMapData.own_map[i] == to_owner:
				CurrentMapData.own_map[i] = from_owner
		EventSystem.map_updated.emit()

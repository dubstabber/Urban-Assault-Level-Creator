extends TabBar

@onready var no_sector_label: Label = %NoSectorLabel
@onready var sector_properties_container: Control = %SectorPropertiesContainer
@onready var sector_position_label: Label = %SectorPositionLabel
@onready var border_info_label: Label = %BorderInfoLabel
@onready var building_text_label: Label = %BuildingTextLabel
@onready var building_texture: TextureRect = %BuildingTexture
@onready var invalid_typ_map_label: Label = %InvalidTypMapLabel
@onready var invalid_blg_map_label: Label = %InvalidBlgMapLabel
@onready var warning_blg_map_label: Label = %WarningBlgMapLabel
@onready var sector_owner_label: Label = %SectorOwnerLabel
@onready var special_building_label: Label = %SpecialBuildingLabel
@onready var sector_info_container: Control = %SectorInfoContainer
@onready var sector_info_container_separator: HSeparator = %HSeparator
@onready var sector_info_container_separator2: HSeparator = %HSeparator2


func _ready() -> void:
	EventSystem.sector_selected.connect(_update_properties)
	EventSystem.map_updated.connect(_update_properties)
	EventSystem.map_view_updated.connect(_update_properties)


func _update_properties() -> void:
	if EditorState.selected_sectors.size() > 1:
		no_sector_label.hide()
		return
	if (CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0
		and EditorState.border_selected_sector_idx >= 0):
		no_sector_label.hide()
		
		sector_properties_container.show()
		sector_position_label.text = "Selected sector X:%s Y:%s" % [EditorState.selected_sector.x, EditorState.selected_sector.y]
		
		if (EditorState.selected_sector.x == 0 or EditorState.selected_sector.y == 0 or
			EditorState.selected_sector.x == (CurrentMapData.horizontal_sectors + 1) or
			EditorState.selected_sector.y == (CurrentMapData.vertical_sectors + 1)):
			border_info_label.show()
			sector_info_container.hide()
			sector_info_container_separator.hide()
			sector_info_container_separator2.hide()
			building_text_label.hide()
			building_texture.hide()
			invalid_typ_map_label.hide()
			return
		else:
			border_info_label.hide()
			sector_info_container.show()
			sector_info_container_separator.show()
			sector_info_container_separator2.show()
			building_text_label.show()
			building_texture.show()
		
		if CurrentMapData.own_map[EditorState.selected_sector_idx] == 0:
			sector_owner_label.text = "Neutral"
		else:
			for faction in Preloads.ua_data.data[EditorState.game_data_type].hoststations:
				if Preloads.ua_data.data[EditorState.game_data_type].hoststations[faction].owner == CurrentMapData.own_map[EditorState.selected_sector_idx]:
					sector_owner_label.text = faction
					break
		
		if CurrentMapData.blg_map[EditorState.selected_sector_idx] == 0:
			special_building_label.text = 'None'
		elif EditorState.blg_names.has(CurrentMapData.blg_map[EditorState.selected_sector_idx]):
			special_building_label.text = EditorState.blg_names[CurrentMapData.blg_map[EditorState.selected_sector_idx]]
		elif CurrentMapData.blg_map[EditorState.selected_sector_idx] in [5, 25]:
			special_building_label.text = 'Beam gate'
		elif CurrentMapData.blg_map[EditorState.selected_sector_idx] in [35, 68]:
			special_building_label.text = 'Stoudson bomb'
		elif CurrentMapData.blg_map[EditorState.selected_sector_idx] in [60, 61, 4, 7, 15, 51, 50, 16, 65]:
			special_building_label.text = 'Tech upgrade'
		else:
			special_building_label.text = 'Unknown'
		if ((CurrentMapData.blg_map[EditorState.selected_sector_idx] == 62 and CurrentMapData.level_set in [3, 4, 5]) or
			(CurrentMapData.blg_map[EditorState.selected_sector_idx] == 55 and CurrentMapData.level_set in [2, 5])):
			invalid_blg_map_label.show()
		else:
			invalid_blg_map_label.hide()
		if CurrentMapData.blg_map[EditorState.selected_sector_idx] == 62 and CurrentMapData.level_set in [1, 6]:
			warning_blg_map_label.show()
		else:
			warning_blg_map_label.hide()
		
		building_text_label.text = "Building %s" % CurrentMapData.typ_map[EditorState.selected_sector_idx]
		if Preloads.building_side_images[CurrentMapData.level_set].has(CurrentMapData.typ_map[EditorState.selected_sector_idx]):
			building_texture.show()
			building_texture.texture = Preloads.building_side_images[CurrentMapData.level_set][CurrentMapData.typ_map[EditorState.selected_sector_idx]]
			invalid_typ_map_label.hide()
		else:
			building_texture.hide()
			invalid_typ_map_label.show()
	else:
		no_sector_label.show()
		sector_properties_container.hide()

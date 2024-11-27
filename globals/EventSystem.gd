extends Node


signal map_created
signal unit_selected
signal unit_right_selected
signal sector_selected
signal game_type_changed

signal hoststation_added(owner_id: int, vehicle_id: int)
signal squad_added(owner_id: int, vehicle_id: int)
signal map_updated
signal item_updated

signal sector_faction_changed(faction_id: int)
signal sector_height_changed(height_value: int)
signal special_building_added(blg_map: int, typ_map: int, own_map: int)
signal building_added(typ_map: int)

signal toggled_values_visibility(type: String)
signal toggled_typ_map_images_visibility

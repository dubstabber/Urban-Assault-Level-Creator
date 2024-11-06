extends Node


signal map_created
signal unit_selected
signal unit_right_selected
signal sector_selected

signal hoststation_added(hs_name: String)
signal squad_added(squad_data: Dictionary, owner_id: int)
signal map_updated
signal item_updated

signal sector_faction_changed(faction_id: int)
signal sector_height_changed(height_value: int)
signal special_building_added(blg_map: int, typ_map: int, own_map: int)
signal building_added(typ_map: int)

signal toggled_values_visibility(type: String)
signal toggled_typ_map_images_visibility

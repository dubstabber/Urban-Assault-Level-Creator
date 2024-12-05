extends Node

signal new_map_requested
signal open_map_requested
signal save_map_requested
signal save_as_map_requested
signal close_map_requested
signal exit_editor_requested
signal load_hs_behavior_dialog_requested
signal save_hs_behavior_dialog_requested
signal behavior_loaded(behavior_data: Dictionary)
signal sector_height_window_requested
signal sector_building_windows_requested

signal map_created
signal unit_selected
signal sector_selected
signal left_double_clicked
signal global_right_clicked(clicked_x: int, clicked_y: int)

signal game_type_changed
signal hoststation_added(owner_id: int, vehicle_id: int)
signal squad_added(owner_id: int, vehicle_id: int)
signal map_updated
signal item_updated

signal sector_faction_changed(faction_id: int)
signal sector_height_changed(height_value: int)
signal special_building_added(blg_map: int, typ_map: int, own_map: int)
signal building_added(typ_map: int)

signal open_map_failed

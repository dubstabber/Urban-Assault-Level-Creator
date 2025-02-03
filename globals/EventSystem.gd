extends Node

signal new_map_requested
signal open_map_requested
signal open_map_drag_requested(file_path: String)
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
signal level_set_changed

signal game_type_changed
signal hoststation_added(owner_id: int, vehicle_id: int)
signal squad_added(owner_id: int, vehicle_id: int)
signal map_updated
signal map_view_updated
signal item_added
signal item_updated

signal sector_faction_changed(faction_id: int)
signal sector_height_changed(height_value: int)
signal special_building_added(blg_map: int, typ_map: int, own_map: int)
signal building_added(typ_map: int)

signal open_map_failed
signal invalid_set_detected(level_set: int)

signal editor_mode_changed
signal too_many_sectors_provided
signal safe_host_station_limit_exceeded
signal saved_with_no_hoststation

extends Node


signal map_created

signal hoststation_added(hs_name: String)
signal squad_added(squad_data: Dictionary, owner_id: int)
signal sector_faction_changed(faction_id: int)
signal sector_height_changed(height_value: int)

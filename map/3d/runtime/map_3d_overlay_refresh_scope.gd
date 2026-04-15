extends RefCounted


var _localized_overlay_dirty_sectors: Dictionary = {}
var _localized_dynamic_overlay_dirty_sectors: Dictionary = {}


func record_sectors(sectors: Array) -> void:
	for sector_value in sectors:
		if sector_value is Vector2i:
			var sector := Vector2i(sector_value)
			_localized_overlay_dirty_sectors[sector] = true
			_localized_dynamic_overlay_dirty_sectors[sector] = true


func overlay_sector_list() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for key in _localized_overlay_dirty_sectors.keys():
		if key is Vector2i:
			sectors.append(Vector2i(key))
	return sectors


func dynamic_sector_list() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for key in _localized_dynamic_overlay_dirty_sectors.keys():
		if key is Vector2i:
			sectors.append(Vector2i(key))
	return sectors


func clear() -> void:
	_localized_overlay_dirty_sectors.clear()
	_localized_dynamic_overlay_dirty_sectors.clear()

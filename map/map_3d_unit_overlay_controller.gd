extends RefCounted
class_name Map3DUnitOverlayController

const AuthoredOverlayManager := preload("res://map/map_3d_authored_overlay_manager.gd")
const OverlayProducers := preload("res://map/map_3d_overlay_descriptor_producers.gd")


static func apply_unit_changes(root: Node3D, changes: Array, map_data: Node, support_descriptors: Array, game_data_type: String) -> bool:
	if root == null or not is_instance_valid(root) or map_data == null or changes.is_empty():
		return false
	var w := int(map_data.horizontal_sectors)
	var h := int(map_data.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	var hgt: PackedByteArray = map_data.hgt_map
	if hgt.size() != (w + 2) * (h + 2):
		return false
	var set_id := int(map_data.level_set)
	var processed := {}
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		var unit_kind := String(change.get("kind", ""))
		var unit_id := int(change.get("unit_id", 0))
		if unit_kind.is_empty() or unit_id <= 0:
			continue
		var key := "%s:%d" % [unit_kind, unit_id]
		if processed.has(key):
			continue
		processed[key] = true
		var descriptors: Array = []
		if String(change.get("action", "")) != "removed":
			var unit_node := _find_unit_by_identity(_container_for_kind(map_data, unit_kind), unit_id)
			if unit_node != null:
				if unit_kind == "host":
					descriptors = OverlayProducers.build_host_station_descriptors([unit_node], set_id, hgt, w, h, support_descriptors)
				elif unit_kind == "squad":
					descriptors = OverlayProducers.build_squad_descriptors([unit_node], set_id, hgt, w, h, support_descriptors, game_data_type)
		AuthoredOverlayManager.apply_overlay_for_prefixes(root, _prefixes_for_unit(unit_kind, unit_id), descriptors)
	return true


static func find_unit_by_identity(container: Node, unit_id: int) -> Node2D:
	return _find_unit_by_identity(container, unit_id)


static func _find_unit_by_identity(container: Node, unit_id: int) -> Node2D:
	if container == null or not is_instance_valid(container) or unit_id <= 0:
		return null
	for child_any in container.get_children():
		if not (child_any is Node2D):
			continue
		var child := child_any as Node2D
		var editor_unit_id: Variant = child.get("editor_unit_id")
		if editor_unit_id != null and int(editor_unit_id) == unit_id:
			return child
	for child_any in container.get_children():
		if child_any is Node2D and int(child_any.get_instance_id()) == unit_id:
			return child_any as Node2D
	return null


static func _container_for_kind(map_data: Node, unit_kind: String) -> Node:
	if unit_kind == "host":
		return map_data.host_stations
	if unit_kind == "squad":
		return map_data.squads
	return null


static func _prefixes_for_unit(unit_kind: String, unit_id: int) -> Array:
	var prefixes: Array = []
	if unit_kind == "host":
		for set_id in range(1, 7):
			prefixes.append("host:%d:%d:" % [set_id, unit_id])
			prefixes.append("host_gun:%d:%d:" % [set_id, unit_id])
	elif unit_kind == "squad":
		for set_id in range(1, 7):
			prefixes.append("squad:%d:%d:" % [set_id, unit_id])
	return prefixes

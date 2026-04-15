extends RefCounted

const SECTOR_SIZE := 1200.0

var _nodes_by_kind: Dictionary = {
	"host": {},
	"squad": {},
}
var _sector_by_unit: Dictionary = {
	"host": {},
	"squad": {},
}
var _unit_ids_by_sector: Dictionary = {
	"host": {},
	"squad": {},
}


func clear() -> void:
	for kind in _nodes_by_kind.keys():
		_nodes_by_kind[kind].clear()
		_sector_by_unit[kind].clear()
		_unit_ids_by_sector[kind].clear()


func is_empty() -> bool:
	for kind in _nodes_by_kind.keys():
		if not _nodes_by_kind[kind].is_empty():
			return false
	return true


func rebuild_from_map(map_data: Node) -> void:
	clear()
	_index_container(_container_for_kind(map_data, "host"), "host")
	_index_container(_container_for_kind(map_data, "squad"), "squad")


func apply_changes(map_data: Node, changes: Array) -> void:
	if map_data == null:
		return
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		var unit_kind := String(change.get("kind", ""))
		var unit_id := int(change.get("unit_id", 0))
		var action := String(change.get("action", ""))
		if not _nodes_by_kind.has(unit_kind) or unit_id <= 0:
			continue
		if action == "removed":
			remove_unit(unit_kind, unit_id)
			continue
		refresh_unit(map_data, unit_kind, unit_id)


func refresh_unit(map_data: Node, unit_kind: String, unit_id: int) -> Node2D:
	if not _nodes_by_kind.has(unit_kind) or unit_id <= 0:
		return null
	var cached = _nodes_by_kind[unit_kind].get(unit_id, null)
	if cached != null and is_instance_valid(cached):
		_reindex_unit(unit_kind, unit_id, cached)
		return cached as Node2D
	var container := _container_for_kind(map_data, unit_kind)
	if container == null or not is_instance_valid(container):
		remove_unit(unit_kind, unit_id)
		return null
	for child_any in container.get_children():
		if not (child_any is Node2D):
			continue
		var child := child_any as Node2D
		if _unit_id_for(child) != unit_id:
			continue
		_nodes_by_kind[unit_kind][unit_id] = child
		_reindex_unit(unit_kind, unit_id, child)
		return child
	remove_unit(unit_kind, unit_id)
	return null


func find_unit(map_data: Node, unit_kind: String, unit_id: int) -> Node2D:
	return refresh_unit(map_data, unit_kind, unit_id)


func remove_unit(unit_kind: String, unit_id: int) -> void:
	if not _nodes_by_kind.has(unit_kind) or unit_id <= 0:
		return
	var previous_sector = _sector_by_unit[unit_kind].get(unit_id, null)
	if previous_sector is Vector2i:
		var sector_bucket: Dictionary = _unit_ids_by_sector[unit_kind]
		if sector_bucket.has(previous_sector):
			var ids: Dictionary = sector_bucket[previous_sector]
			ids.erase(unit_id)
			if ids.is_empty():
				sector_bucket.erase(previous_sector)
	_sector_by_unit[unit_kind].erase(unit_id)
	_nodes_by_kind[unit_kind].erase(unit_id)


func units_for_sectors(map_data: Node, unit_kind: String, sectors: Array) -> Array:
	if sectors.is_empty() or not _nodes_by_kind.has(unit_kind):
		return []
	var results: Array = []
	var seen_ids := {}
	for sector_value in sectors:
		if not (sector_value is Vector2i):
			continue
		var sector := Vector2i(sector_value)
		var ids_for_sector: Dictionary = _unit_ids_by_sector[unit_kind].get(sector, {})
		for unit_id_value in ids_for_sector.keys():
			var unit_id := int(unit_id_value)
			if seen_ids.has(unit_id):
				continue
			seen_ids[unit_id] = true
			var node := refresh_unit(map_data, unit_kind, unit_id)
			if node != null:
				results.append(node)
	return results


func _index_container(container: Node, unit_kind: String) -> void:
	if container == null or not is_instance_valid(container):
		return
	for child_any in container.get_children():
		if not (child_any is Node2D):
			continue
		var child := child_any as Node2D
		var unit_id := _unit_id_for(child)
		if unit_id <= 0:
			continue
		_nodes_by_kind[unit_kind][unit_id] = child
		_reindex_unit(unit_kind, unit_id, child)


func _reindex_unit(unit_kind: String, unit_id: int, unit_node: Node2D) -> void:
	var previous_sector = _sector_by_unit[unit_kind].get(unit_id, null)
	if previous_sector is Vector2i:
		var previous_ids: Dictionary = _unit_ids_by_sector[unit_kind].get(previous_sector, {})
		previous_ids.erase(unit_id)
		if previous_ids.is_empty():
			_unit_ids_by_sector[unit_kind].erase(previous_sector)
	var sector := _sector_for_node(unit_node)
	_sector_by_unit[unit_kind][unit_id] = sector
	var ids_for_sector: Dictionary = _unit_ids_by_sector[unit_kind].get(sector, {})
	ids_for_sector[unit_id] = true
	_unit_ids_by_sector[unit_kind][sector] = ids_for_sector


func _container_for_kind(map_data: Node, unit_kind: String) -> Node:
	if map_data == null:
		return null
	if unit_kind == "host":
		return map_data.host_stations
	if unit_kind == "squad":
		return map_data.squads
	return null


func _unit_id_for(unit: Node) -> int:
	if unit == null or not is_instance_valid(unit):
		return 0
	var raw_id = unit.get("editor_unit_id")
	if raw_id != null and int(raw_id) > 0:
		return int(raw_id)
	if unit.has_method("ensure_editor_unit_id"):
		return int(unit.ensure_editor_unit_id())
	return int(unit.get_instance_id())


func _sector_for_node(unit_node: Node2D) -> Vector2i:
	var world_x := float(unit_node.position.x)
	var world_z := absf(float(unit_node.position.y))
	return Vector2i(_world_to_sector_index(world_x), _world_to_sector_index(world_z))


func _world_to_sector_index(world_coord: float) -> int:
	return int(floor(world_coord / SECTOR_SIZE)) - 1

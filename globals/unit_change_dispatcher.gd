extends RefCounted
class_name UnitChangeDispatcher


static func _event_system() -> Node:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("EventSystem")
	return null


static func kind_for_unit(unit: Node) -> String:
	if unit == null or not is_instance_valid(unit):
		return ""
	if unit is HostStation:
		return "host"
	if unit is Squad:
		return "squad"
	return ""


static func unit_id_for(unit: Node) -> int:
	if unit == null or not is_instance_valid(unit):
		return 0
	var raw_id = unit.get("editor_unit_id")
	if raw_id != null and int(raw_id) > 0:
		return int(raw_id)
	if unit.has_method("ensure_editor_unit_id"):
		return int(unit.ensure_editor_unit_id())
	return int(unit.get_instance_id())


static func change_for_unit(unit: Node, action: String, unit_kind: String = "") -> Dictionary:
	var resolved_kind := unit_kind if not unit_kind.is_empty() else kind_for_unit(unit)
	return {
		"kind": resolved_kind,
		"unit_id": unit_id_for(unit),
		"action": action,
	}


static func emit_changes(changes: Array, event_system: Node = null) -> void:
	if event_system == null:
		event_system = _event_system()
	if event_system == null or changes.is_empty():
		return
	var normalized: Array = []
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		var kind := String(change.get("kind", ""))
		var unit_id := int(change.get("unit_id", 0))
		var action := String(change.get("action", ""))
		if kind.is_empty() or unit_id <= 0 or action.is_empty():
			continue
		normalized.append({
			"kind": kind,
			"unit_id": unit_id,
			"action": action,
		})
	if normalized.is_empty():
		return
	if event_system.has_signal("units_changed"):
		event_system.units_changed.emit(normalized)


static func emit_for_unit(unit: Node, action: String, event_system: Node = null, unit_kind: String = "") -> void:
	emit_changes([change_for_unit(unit, action, unit_kind)], event_system)

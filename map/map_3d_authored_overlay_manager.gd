extends RefCounted
class_name Map3DAuthoredOverlayManager

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")


static func build_overlay_node(descriptors: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredOverlay"
	apply_overlay_node(root, descriptors)
	return root


static func apply_overlay_node(root: Node3D, descriptors: Array) -> void:
	if root == null or not is_instance_valid(root):
		return
	if root.name != "AuthoredOverlay":
		root.name = "AuthoredOverlay"

	var desired := _desired_descriptors_by_key(descriptors)
	var existing := _existing_nodes_by_key(root)

	var to_remove: Array[String] = []
	for key_value in existing.keys():
		var key := String(key_value)
		if not desired.has(key):
			to_remove.append(key)
	for key in to_remove:
		var node: Node = existing.get(key, null)
		if node != null and is_instance_valid(node):
			node.queue_free()
		existing.erase(key)

	for key_value in desired.keys():
		var key := String(key_value)
		var desc: Dictionary = desired.get(key, {}) as Dictionary
		var set_id := int(desc.get("set_id", 1))
		var base_name := String(desc.get("base_name", ""))
		var raw_id := int(desc.get("raw_id", -1))
		var node: Node = existing.get(key, null)
		var needs_rebuild := false
		if node == null or not is_instance_valid(node):
			needs_rebuild = true
		else:
			var node_base := String(node.get_meta("base_name", ""))
			var node_set := int(node.get_meta("set_id", 0))
			if node_set != set_id or node_base.to_lower() != base_name.to_lower():
				needs_rebuild = true

		var piece_node: Node3D = null
		if needs_rebuild:
			if node != null and is_instance_valid(node):
				node.queue_free()
			piece_node = PieceLibraryScript.build_piece_scene_root(set_id, base_name, raw_id)
			if piece_node == null:
				continue
			piece_node.set_meta("instance_key", key)
			piece_node.set_meta("set_id", set_id)
			piece_node.set_meta("base_name", base_name)
			piece_node.set_meta("raw_id", raw_id)
			piece_node.set_meta("warp_sig", "")
			root.add_child(piece_node)
		else:
			piece_node = node as Node3D
			if piece_node == null:
				continue

		piece_node.position = _piece_position_from_desc(desc)
		PieceLibraryScript._apply_optional_piece_orientation(piece_node, desc)

		var warp_sig := _warp_signature(desc)
		var prev_warp_sig := String(piece_node.get_meta("warp_sig", ""))
		if warp_sig != prev_warp_sig:
			PieceLibraryScript._apply_optional_piece_deform(piece_node, desc)
			piece_node.set_meta("warp_sig", warp_sig)


static func _desired_descriptors_by_key(descriptors: Array) -> Dictionary:
	var desired := {}
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := _descriptor_key(d)
		desired[key] = d
	return desired


static func _descriptor_key(desc: Dictionary) -> String:
	var key := String(desc.get("instance_key", ""))
	if key.is_empty():
		key = "%d:%s:%d:%s" % [
			int(desc.get("set_id", 1)),
			String(desc.get("base_name", "")).to_lower(),
			int(desc.get("raw_id", -1)),
			_str_position_key(Vector3(desc.get("origin", Vector3.ZERO)))
		]
	return key


static func _existing_nodes_by_key(root: Node3D) -> Dictionary:
	var existing := {}
	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var node := child as Node
		var key := ""
		if node.has_meta("instance_key"):
			key = String(node.get_meta("instance_key"))
		if key.is_empty():
			key = String(node.name)
		existing[key] = node
	return existing


static func _warp_signature(desc: Dictionary) -> String:
	var warp_mode := String(desc.get("warp_mode", ""))
	if warp_mode.is_empty():
		return ""
	var parts: Array[String] = [warp_mode]
	for key in [
		"anchor_height",
		"left_height",
		"right_height",
		"top_avg",
		"bottom_avg",
		"top_height",
		"bottom_height",
		"left_avg",
		"right_avg"
	]:
		if desc.has(key):
			parts.append("%s=%.3f" % [key, float(desc.get(key, 0.0))])
	return "|".join(parts)


static func _str_position_key(pos: Vector3) -> String:
	return "%.2f,%.2f,%.2f" % [pos.x, pos.y, pos.z]


static func _piece_position_from_desc(desc: Dictionary) -> Vector3:
	return Vector3(desc.get("origin", Vector3.ZERO)) + Vector3(0.0, PieceLibraryScript.OVERLAY_Y_BIAS + float(desc.get("y_offset", 0.0)), 0.0)

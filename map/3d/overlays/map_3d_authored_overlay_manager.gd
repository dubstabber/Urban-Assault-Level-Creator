extends RefCounted

const _NODE_INDEX_META := "_overlay_node_index"


static func build_overlay_node(overlay_descriptors: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "AuthoredOverlay"
	apply_overlay_node(root, overlay_descriptors)
	return root


static func apply_overlay_node(root: Node3D, overlay_descriptors: Array) -> void:
	var manager: RefCounted = load("res://map/3d/overlays/map_3d_authored_overlay_manager.gd").new()
	var state: Dictionary = manager.begin_apply_overlay_node(root, overlay_descriptors)
	if state.is_empty():
		return
	while not manager.apply_overlay_node_step(root, state, 256):
		pass
	manager.finalize_apply_overlay_node(root, state)


static func apply_overlay_for_prefixes(root: Node3D, key_prefixes: Array, overlay_descriptors: Array) -> void:
	if root == null or not is_instance_valid(root):
		return
	if key_prefixes.is_empty():
		apply_overlay_node(root, overlay_descriptors)
		return
	if root.name.is_empty():
		root.name = "AuthoredOverlay"

	var desired := _desired_descriptors_by_key(overlay_descriptors)
	var existing := _existing_nodes_by_key(root)

	for key_value in existing.keys():
		var key := String(key_value)
		if not _key_matches_prefixes(key, key_prefixes):
			continue
		if desired.has(key):
			continue
		var node: Node = existing.get(key, null)
		if node != null and is_instance_valid(node):
			var parent := node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.queue_free()
		existing.erase(key)

	for key_value in desired.keys():
		var key := String(key_value)
		if not _key_matches_prefixes(key, key_prefixes):
			continue
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
			else:
				var wants_static: bool = UATerrainPieceLibrary.is_force_static_terrain_overlays()
				if not node.has_meta("overlay_force_static") or bool(node.get_meta("overlay_force_static")) != wants_static:
					needs_rebuild = true

		var piece_node: Node3D = null
		if needs_rebuild:
			if node != null and is_instance_valid(node):
				var parent := node.get_parent()
				if parent != null:
					parent.remove_child(node)
				node.queue_free()
			piece_node = UATerrainPieceLibrary.build_piece_scene_root(set_id, base_name, raw_id)
			if piece_node == null:
				continue
			piece_node.set_meta("instance_key", key)
			piece_node.set_meta("set_id", set_id)
			piece_node.set_meta("base_name", base_name)
			piece_node.set_meta("raw_id", raw_id)
			piece_node.set_meta("overlay_force_static", UATerrainPieceLibrary.is_force_static_terrain_overlays())
			piece_node.set_meta("warp_sig", "")
			piece_node.position = _piece_position_from_desc(desc)
			UATerrainPieceLibrary._apply_optional_piece_orientation(piece_node, desc)
			var initial_warp_sig := _warp_signature(desc)
			if not initial_warp_sig.is_empty():
				UATerrainPieceLibrary._apply_optional_piece_deform(piece_node, desc)
				piece_node.set_meta("warp_sig", initial_warp_sig)
			root.add_child(piece_node)
			existing[key] = piece_node
		else:
			piece_node = node as Node3D
			if piece_node == null:
				continue
			existing[key] = piece_node

		if not needs_rebuild:
			piece_node.position = _piece_position_from_desc(desc)
			UATerrainPieceLibrary._apply_optional_piece_orientation(piece_node, desc)
			var warp_sig := _warp_signature(desc)
			var prev_warp_sig := String(piece_node.get_meta("warp_sig", ""))
			if warp_sig != prev_warp_sig:
				UATerrainPieceLibrary._apply_optional_piece_deform(piece_node, desc)
				piece_node.set_meta("warp_sig", warp_sig)


static func _key_matches_prefixes(key: String, key_prefixes: Array) -> bool:
	for prefix_value in key_prefixes:
		var prefix := String(prefix_value)
		if not prefix.is_empty() and key.begins_with(prefix):
			return true
	return false


func begin_apply_overlay_node(root: Node3D, overlay_descriptors: Array) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return {}
	if root.name.is_empty():
		root.name = "AuthoredOverlay"
	if root.get_child_count() == 0:
		return {
			"cold_start": true,
			"cold_start_descriptors": _cold_start_descriptors(overlay_descriptors),
			"cold_start_index": 0,
			"existing": {},
			"descriptor_count": overlay_descriptors.size(),
			"desired_count": overlay_descriptors.size(),
			"existing_count_before": 0,
			"root_children_before": 0,
			"rebuilt_count": 0,
			"reused_count": 0,
		}

	var desired := _desired_descriptors_by_key(overlay_descriptors)
	var existing := _existing_nodes_by_key(root)
	var existing_count_before := existing.size()
	var root_children_before := root.get_child_count()

	var to_remove: Array[String] = []
	for key_value in existing.keys():
		var key := String(key_value)
		if not desired.has(key):
			to_remove.append(key)
	var upsert_keys: Array[String] = []
	for key_value in desired.keys():
		upsert_keys.append(String(key_value))

	return {
		"desired": desired,
		"existing": existing,
		"to_remove": to_remove,
		"upsert_keys": upsert_keys,
		"remove_index": 0,
		"upsert_index": 0,
		"rebuilt_count": 0,
		"reused_count": 0,
		"descriptor_count": overlay_descriptors.size(),
		"desired_count": desired.size(),
		"existing_count_before": existing_count_before,
		"root_children_before": root_children_before,
	}


func apply_overlay_node_step(root: Node3D, state: Dictionary, max_ops: int = 64) -> bool:
	if root == null or not is_instance_valid(root) or state.is_empty():
		return true
	if bool(state.get("cold_start", false)):
		return _apply_overlay_node_cold_start_step(root, state, max_ops)
	var ops_done := 0
	var desired: Dictionary = state.get("desired", {})
	var existing: Dictionary = state.get("existing", {})
	var to_remove: Array[String] = state.get("to_remove", [])
	var upsert_keys: Array[String] = state.get("upsert_keys", [])
	var remove_index := int(state.get("remove_index", 0))
	var upsert_index := int(state.get("upsert_index", 0))

	while remove_index < to_remove.size() and ops_done < max_ops:
		var key := String(to_remove[remove_index])
		var node: Node = existing.get(key, null)
		if node != null and is_instance_valid(node):
			var parent := node.get_parent()
			if parent != null:
				parent.remove_child(node)
			node.queue_free()
		existing.erase(key)
		remove_index += 1
		ops_done += 1

	while remove_index >= to_remove.size() and upsert_index < upsert_keys.size() and ops_done < max_ops:
		var key := String(upsert_keys[upsert_index])
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
			else:
				var wants_static: bool = UATerrainPieceLibrary.is_force_static_terrain_overlays()
				if not node.has_meta("overlay_force_static") or bool(node.get_meta("overlay_force_static")) != wants_static:
					needs_rebuild = true

		var piece_node: Node3D = null
		if needs_rebuild:
			if node != null and is_instance_valid(node):
				var parent := node.get_parent()
				if parent != null:
					parent.remove_child(node)
				node.queue_free()
			piece_node = UATerrainPieceLibrary.build_piece_scene_root(set_id, base_name, raw_id)
			if piece_node != null:
				piece_node.set_meta("instance_key", key)
				piece_node.set_meta("set_id", set_id)
				piece_node.set_meta("base_name", base_name)
				piece_node.set_meta("raw_id", raw_id)
				piece_node.set_meta("overlay_force_static", UATerrainPieceLibrary.is_force_static_terrain_overlays())
				piece_node.set_meta("warp_sig", "")
				piece_node.position = _piece_position_from_desc(desc)
				UATerrainPieceLibrary._apply_optional_piece_orientation(piece_node, desc)
				var initial_warp_sig := _warp_signature(desc)
				if not initial_warp_sig.is_empty():
					UATerrainPieceLibrary._apply_optional_piece_deform(piece_node, desc)
					piece_node.set_meta("warp_sig", initial_warp_sig)
				root.add_child(piece_node)
				existing[key] = piece_node
				state["rebuilt_count"] = int(state.get("rebuilt_count", 0)) + 1
		else:
			piece_node = node as Node3D
			if piece_node != null:
				existing[key] = piece_node
				state["reused_count"] = int(state.get("reused_count", 0)) + 1

		if piece_node != null and not needs_rebuild:
			piece_node.position = _piece_position_from_desc(desc)
			UATerrainPieceLibrary._apply_optional_piece_orientation(piece_node, desc)
			var warp_sig := _warp_signature(desc)
			var prev_warp_sig := String(piece_node.get_meta("warp_sig", ""))
			if warp_sig != prev_warp_sig:
				UATerrainPieceLibrary._apply_optional_piece_deform(piece_node, desc)
				piece_node.set_meta("warp_sig", warp_sig)

		upsert_index += 1
		ops_done += 1

	state["remove_index"] = remove_index
	state["upsert_index"] = upsert_index
	state["existing"] = existing
	return remove_index >= to_remove.size() and upsert_index >= upsert_keys.size()


func _apply_overlay_node_cold_start_step(root: Node3D, state: Dictionary, max_ops: int) -> bool:
	var descriptors: Array = state.get("cold_start_descriptors", [])
	var index := int(state.get("cold_start_index", 0))
	var existing: Dictionary = state.get("existing", {})
	var ops_done := 0
	while index < descriptors.size() and ops_done < max_ops:
		var desc_value = descriptors[index]
		if typeof(desc_value) == TYPE_DICTIONARY:
			var node := _apply_new_descriptor(root, desc_value as Dictionary)
			if node != null and is_instance_valid(node):
				existing[String(node.get_meta("instance_key", node.name))] = node
				state["rebuilt_count"] = int(state.get("rebuilt_count", 0)) + 1
		index += 1
		ops_done += 1
	state["cold_start_index"] = index
	state["existing"] = existing
	return index >= descriptors.size()


func finalize_apply_overlay_node(root: Node3D, state: Dictionary) -> void:
	if root == null or not is_instance_valid(root) or state.is_empty():
		return
	var existing = state.get("existing", {})
	if typeof(existing) == TYPE_DICTIONARY:
		root.set_meta(_NODE_INDEX_META, existing)


func overlay_apply_progress(state: Dictionary) -> Dictionary:
	if state.is_empty():
		return {"done": 0, "total": 0}
	if bool(state.get("cold_start", false)):
		var descriptors: Array = state.get("cold_start_descriptors", [])
		var done_cold := int(state.get("cold_start_index", 0))
		return {"done": done_cold, "total": descriptors.size()}
	var to_remove: Array = state.get("to_remove", [])
	var upsert_keys: Array = state.get("upsert_keys", [])
	var total := to_remove.size() + upsert_keys.size()
	var done := int(state.get("remove_index", 0)) + int(state.get("upsert_index", 0))
	return {"done": done, "total": total}


static func _desired_descriptors_by_key(overlay_descriptors: Array) -> Dictionary:
	var desired := {}
	for desc in overlay_descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := _descriptor_key(d)
		desired[key] = d
	return desired


static func _cold_start_descriptors(overlay_descriptors: Array) -> Array:
	var descriptors: Array = []
	var seen := {}
	for desc_value in overlay_descriptors:
		if typeof(desc_value) != TYPE_DICTIONARY:
			continue
		var desc := desc_value as Dictionary
		var key := _descriptor_key(desc)
		if seen.has(key):
			continue
		seen[key] = true
		descriptors.append(desc)
	return descriptors


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
	if root.has_meta(_NODE_INDEX_META):
		var cached = root.get_meta(_NODE_INDEX_META)
		if typeof(cached) == TYPE_DICTIONARY:
			var existing_cached := cached as Dictionary
			var stale_keys: Array = []
			for key_value in existing_cached.keys():
				var node_any = existing_cached.get(key_value, null)
				if node_any == null or not is_instance_valid(node_any):
					stale_keys.append(key_value)
			for stale_key in stale_keys:
				existing_cached.erase(stale_key)
			return existing_cached
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
	root.set_meta(_NODE_INDEX_META, existing)
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
	return Vector3(desc.get("origin", Vector3.ZERO)) + Vector3(0.0, UATerrainPieceLibrary.OVERLAY_Y_BIAS + float(desc.get("y_offset", 0.0)), 0.0)


static func _apply_new_descriptor(root: Node3D, desc: Dictionary) -> Node3D:
	var set_id := int(desc.get("set_id", 1))
	var base_name := String(desc.get("base_name", ""))
	var raw_id := int(desc.get("raw_id", -1))
	var key := _descriptor_key(desc)
	var piece_node := UATerrainPieceLibrary.build_piece_scene_root(set_id, base_name, raw_id)
	if piece_node == null:
		return null
	piece_node.set_meta("instance_key", key)
	piece_node.set_meta("set_id", set_id)
	piece_node.set_meta("base_name", base_name)
	piece_node.set_meta("raw_id", raw_id)
	piece_node.set_meta("overlay_force_static", UATerrainPieceLibrary.is_force_static_terrain_overlays())
	piece_node.set_meta("warp_sig", "")
	piece_node.position = _piece_position_from_desc(desc)
	UATerrainPieceLibrary._apply_optional_piece_orientation(piece_node, desc)
	var warp_sig := _warp_signature(desc)
	if not warp_sig.is_empty():
		UATerrainPieceLibrary._apply_optional_piece_deform(piece_node, desc)
		piece_node.set_meta("warp_sig", warp_sig)
	root.add_child(piece_node)
	return piece_node

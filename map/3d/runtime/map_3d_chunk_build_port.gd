extends RefCounted


var _chunk_runtime = null
var _effective_typ_service = null
var _rebuild_policy = null
var _runtime_state = null


func bind(chunk_runtime, effective_typ_service, rebuild_policy, runtime_state) -> void:
	_chunk_runtime = chunk_runtime
	_effective_typ_service = effective_typ_service
	_rebuild_policy = rebuild_policy
	_runtime_state = runtime_state


func chunk_runtime():
	return _chunk_runtime


func effective_typ_service():
	return _effective_typ_service


func compute_effective_typ_for_map(cmd: Node, w: int, h: int, typ: PackedByteArray, blg: PackedByteArray, game_data_type: String) -> PackedByteArray:
	return _effective_typ_service.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)


func invalidate_all_chunks(w: int, h: int) -> void:
	_chunk_runtime.invalidate_all_chunks(w, h)


func needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	return _rebuild_policy.needs_full_rebuild(w, h, level_set)


func dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	return _rebuild_policy.dirty_chunks_sorted_by_priority(w, h)


func mark_chunks_dirty(chunk_coords: Array) -> void:
	_rebuild_policy.mark_chunks_dirty(chunk_coords)


func edge_overlay_enabled() -> bool:
	return bool(_runtime_state.edge_overlay_enabled)

extends RefCounted


var _coordinator = null
var _async_map_snapshot = null
var _async_refresh_driver = null


func bind(coordinator, async_map_snapshot, async_refresh_driver = null) -> void:
	_coordinator = coordinator
	_async_map_snapshot = async_map_snapshot
	_async_refresh_driver = async_refresh_driver


func coordinator():
	return _coordinator


func is_async_build_active() -> bool:
	return _coordinator.is_async_build_active()


func is_async_overlay_descriptor_active() -> bool:
	return _coordinator.is_async_overlay_descriptor_active()


func is_async_pipeline_active(overlay_apply_active: bool = false) -> bool:
	return _coordinator.is_async_pipeline_active(overlay_apply_active)


func is_async_cancel_requested(generation_id: int) -> bool:
	return _coordinator.is_async_cancel_requested(generation_id)


func cancel_async_build(overlay_apply_active: bool = false) -> void:
	_coordinator.cancel_async_build(overlay_apply_active)


func cancel_async_initial_build() -> void:
	var overlay_apply_active := false
	if _async_refresh_driver != null:
		overlay_apply_active = _async_refresh_driver.is_async_overlay_apply_active()
	cancel_async_build(overlay_apply_active)


func join_async_thread() -> void:
	_coordinator.join_async_thread()


func join_async_overlay_descriptor_thread() -> void:
	_coordinator.join_async_overlay_descriptor_thread()


func reset_async_state() -> void:
	_coordinator.reset_async_state()


func set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	_coordinator.set_async_worker_state(done, failed, message)


func get_async_worker_state() -> Dictionary:
	return _coordinator.get_async_worker_state()


func push_async_chunk_payload(payload: Dictionary) -> void:
	_coordinator.push_async_chunk_payload(payload)


func pop_async_chunk_payload() -> Dictionary:
	return _coordinator.pop_async_chunk_payload()


func clear_async_chunk_payloads() -> void:
	_coordinator.clear_async_chunk_payloads()


func async_chunk_payload_count() -> int:
	return _coordinator.async_chunk_payload_count()


func set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	_coordinator.set_async_overlay_descriptor_state(done, failed, result, metrics)


func get_async_overlay_descriptor_state() -> Dictionary:
	return _coordinator.get_async_overlay_descriptor_state()


func set_async_overlay_descriptor_stage(stage: String) -> void:
	_coordinator.set_async_overlay_descriptor_stage(stage)


func get_async_overlay_descriptor_stage() -> String:
	return _coordinator.get_async_overlay_descriptor_stage()


func set_async_map_snapshot(effective_typ: PackedByteArray, blg: PackedByteArray, w: int, h: int, level_set: int, game_data_type: String) -> void:
	_async_map_snapshot.set_snapshot(effective_typ, blg, w, h, level_set, game_data_type)


func async_effective_typ() -> PackedByteArray:
	return _async_map_snapshot.effective_typ


func set_async_effective_typ(value: PackedByteArray) -> void:
	_async_map_snapshot.effective_typ = value


func async_blg() -> PackedByteArray:
	return _async_map_snapshot.blg


func set_async_blg(value: PackedByteArray) -> void:
	_async_map_snapshot.blg = value


func async_w() -> int:
	return _async_map_snapshot.w


func set_async_w(value: int) -> void:
	_async_map_snapshot.w = int(value)


func async_h() -> int:
	return _async_map_snapshot.h


func set_async_h(value: int) -> void:
	_async_map_snapshot.h = int(value)


func async_level_set() -> int:
	return _async_map_snapshot.level_set


func set_async_level_set(value: int) -> void:
	_async_map_snapshot.level_set = int(value)


func async_game_data_type() -> String:
	return _async_map_snapshot.game_data_type


func set_async_game_data_type(value: String) -> void:
	_async_map_snapshot.game_data_type = String(value)


func is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	return _coordinator.is_map_signature_changed(w, h, level_set, hgt, typ, blg)


func record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	_coordinator.record_map_signature(w, h, level_set, hgt, typ, blg)


func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
	_coordinator.mark_localized_signature_change(w, h, level_set)


func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
	return _coordinator.can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)


func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
	_coordinator.record_map_signature_metadata_only(w, h, level_set)

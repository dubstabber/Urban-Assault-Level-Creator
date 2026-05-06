extends RefCounted


var _view_actions = null
var _async_state = null


func bind(view_action_port, async_state_port) -> void:
	_view_actions = view_action_port
	_async_state = async_state_port


func apply_preview_activity_state() -> void:
	_view_actions.apply_preview_activity_state()


func apply_visibility_range_from_editor_state() -> void:
	_view_actions.apply_visibility_range_from_editor_state()


func cancel_async_initial_build() -> void:
	_async_state.cancel_async_initial_build()


func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
	_async_state.mark_localized_signature_change(w, h, level_set)


func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
	return _async_state.can_skip_map_signature_check(w, h, level_set, has_localized_invalidation)


func is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	return _async_state.is_map_signature_changed(w, h, level_set, hgt, typ, blg)


func record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	_async_state.record_map_signature(w, h, level_set, hgt, typ, blg)


func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
	_async_state.record_map_signature_metadata_only(w, h, level_set)

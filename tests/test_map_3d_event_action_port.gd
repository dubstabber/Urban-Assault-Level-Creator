extends RefCounted

const EventActionPort = preload("res://map/3d/runtime/map_3d_event_action_port.gd")

var _errors: Array[String] = []


class ViewActionsStub extends RefCounted:
	var apply_preview_activity_state_calls := 0
	var apply_visibility_range_calls := 0

	func apply_preview_activity_state() -> void:
		apply_preview_activity_state_calls += 1

	func apply_visibility_range_from_editor_state() -> void:
		apply_visibility_range_calls += 1


class AsyncStateStub extends RefCounted:
	var cancel_calls := 0
	var localized_marks: Array = []
	var skip_signature_check := false
	var signature_changed := false
	var checked_signatures: Array = []
	var recorded_signatures: Array = []
	var metadata_records: Array = []

	func cancel_async_initial_build() -> void:
		cancel_calls += 1

	func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
		localized_marks.append(Vector3i(w, h, level_set))

	func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
		checked_signatures.append({
			"w": w,
			"h": h,
			"level_set": level_set,
			"localized": has_localized_invalidation,
			"kind": "skip",
		})
		return skip_signature_check

	func is_map_signature_changed(w: int, h: int, level_set: int, _hgt: PackedByteArray, _typ: PackedByteArray, _blg: PackedByteArray) -> bool:
		checked_signatures.append({
			"w": w,
			"h": h,
			"level_set": level_set,
			"kind": "changed",
		})
		return signature_changed

	func record_map_signature(w: int, h: int, level_set: int, _hgt: PackedByteArray, _typ: PackedByteArray, _blg: PackedByteArray) -> void:
		recorded_signatures.append(Vector3i(w, h, level_set))

	func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
		metadata_records.append(Vector3i(w, h, level_set))


func _reset_errors() -> void:
	_errors.clear()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func test_delegates_view_and_async_event_actions() -> bool:
	_reset_errors()
	var view_actions := ViewActionsStub.new()
	var async_state := AsyncStateStub.new()
	async_state.skip_signature_check = true
	async_state.signature_changed = true
	var port := EventActionPort.new()
	port.bind(view_actions, async_state)

	port.apply_preview_activity_state()
	port.apply_visibility_range_from_editor_state()
	port.cancel_async_initial_build()
	port.mark_localized_signature_change(4, 5, 6)
	var can_skip := port.can_skip_map_signature_check(7, 8, 9, true)
	var changed := port.is_map_signature_changed(1, 2, 3, PackedByteArray([1]), PackedByteArray([2]), PackedByteArray([3]))
	port.record_map_signature(10, 11, 12, PackedByteArray(), PackedByteArray(), PackedByteArray())
	port.record_map_signature_metadata_only(13, 14, 15)

	_check(view_actions.apply_preview_activity_state_calls == 1, "Expected preview activity to delegate to view actions")
	_check(view_actions.apply_visibility_range_calls == 1, "Expected visibility range to delegate to view actions")
	_check(async_state.cancel_calls == 1, "Expected async cancellation to delegate to async state")
	_check(async_state.localized_marks == [Vector3i(4, 5, 6)], "Expected localized signature mark to delegate to async state")
	_check(can_skip, "Expected signature skip result to come from async state")
	_check(changed, "Expected signature changed result to come from async state")
	_check(async_state.recorded_signatures == [Vector3i(10, 11, 12)], "Expected signature record to delegate to async state")
	_check(async_state.metadata_records == [Vector3i(13, 14, 15)], "Expected metadata-only signature record to delegate to async state")
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	for test_name in [
		"test_delegates_view_and_async_event_actions",
	]:
		print("RUN ", test_name)
		if bool(call(test_name)):
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1
	return failures

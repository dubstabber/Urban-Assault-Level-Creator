extends RefCounted

# Owns thread-safe async build state, chunk payload queues, and map signature
# tracking that were previously embedded in Map3DRenderer.  The renderer
# delegates all mutex-protected operations and map-signature queries here.

# ---- Generation IDs ----
var build_generation_id := 0
var active_build_generation_id := 0
var cancel_requested_generation_id := 0

# ---- Map signature ----
var _map_signature_valid := false
var _map_signature_dims: Vector2i = Vector2i.ZERO
var _map_signature_level_set: int = -1
var _map_signature_hgt_checksum: int = 0
var _map_signature_typ_checksum: int = 0
var _map_signature_blg_checksum: int = 0
var _map_signature_checksums_current := false
var _localized_signature_pending := false

# ---- Async initial-build thread ----
var _async_initial_thread: Thread = null
var _async_state_mutex: Mutex = Mutex.new()
var _async_queue_mutex: Mutex = Mutex.new()
var _async_chunk_results: Array = []
var _async_worker_done := false
var _async_worker_failed := false
var _async_worker_error := ""

# Cross-thread cancellation flag. ALL access goes through `_async_state_mutex`:
# workers read it via is_async_cancel_requested(); the main thread sets it via
# cancel_async_build(), clears it via clear_async_cancel_requested(), and reads
# it via read_async_cancel_requested(). Do not touch this field directly from
# outside the coordinator, or the worker-side locked reads stop being safe.
var _async_cancel_requested := false

# ---- Async overlay descriptor thread ----
var _async_overlay_descriptor_thread: Thread = null
var _async_overlay_descriptor_done := false
var _async_overlay_descriptor_failed := false
var _async_overlay_descriptor_result: Variant = {}
var _async_overlay_descriptor_metrics: Dictionary = {}
var _async_overlay_descriptor_stage := ""
var _async_overlay_descriptor_mutex: Mutex = Mutex.new()


# ---- Thread-safe state accessors ----

func is_async_build_active() -> bool:
	_async_state_mutex.lock()
	var active := _async_initial_thread != null
	_async_state_mutex.unlock()
	return active


func is_async_overlay_descriptor_active() -> bool:
	_async_overlay_descriptor_mutex.lock()
	var active := _async_overlay_descriptor_thread != null
	_async_overlay_descriptor_mutex.unlock()
	return active


func is_async_pipeline_active(overlay_apply_active: bool) -> bool:
	return is_async_build_active() or is_async_overlay_descriptor_active() or overlay_apply_active


func set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	_async_overlay_descriptor_mutex.lock()
	_async_overlay_descriptor_done = done
	_async_overlay_descriptor_failed = failed
	_async_overlay_descriptor_result = result
	_async_overlay_descriptor_metrics = metrics
	_async_overlay_descriptor_mutex.unlock()


func set_async_overlay_descriptor_stage(stage: String) -> void:
	_async_overlay_descriptor_mutex.lock()
	_async_overlay_descriptor_stage = stage
	_async_overlay_descriptor_mutex.unlock()


func get_async_overlay_descriptor_stage() -> String:
	_async_overlay_descriptor_mutex.lock()
	var stage := _async_overlay_descriptor_stage
	_async_overlay_descriptor_mutex.unlock()
	return stage


func get_async_overlay_descriptor_state() -> Dictionary:
	_async_overlay_descriptor_mutex.lock()
	var state := {
		"done": _async_overlay_descriptor_done,
		"failed": _async_overlay_descriptor_failed,
		"result": _async_overlay_descriptor_result,
		"metrics": _async_overlay_descriptor_metrics,
	}
	_async_overlay_descriptor_mutex.unlock()
	return state


func set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	_async_state_mutex.lock()
	_async_worker_done = done
	_async_worker_failed = failed
	_async_worker_error = message
	_async_state_mutex.unlock()


func get_async_worker_state() -> Dictionary:
	_async_state_mutex.lock()
	var state := {
		"done": _async_worker_done,
		"failed": _async_worker_failed,
		"error": _async_worker_error,
	}
	_async_state_mutex.unlock()
	return state


func is_async_cancel_requested(generation_id: int) -> bool:
	_async_state_mutex.lock()
	var cancelled := _async_cancel_requested and generation_id == active_build_generation_id
	_async_state_mutex.unlock()
	return cancelled


# Generation-agnostic locked read of the cancel flag, for main-thread pump code
# that wants to know whether a cancel is in flight regardless of generation.
func read_async_cancel_requested() -> bool:
	_async_state_mutex.lock()
	var requested := _async_cancel_requested
	_async_state_mutex.unlock()
	return requested


func clear_async_cancel_requested() -> void:
	_async_state_mutex.lock()
	_async_cancel_requested = false
	_async_state_mutex.unlock()


# Atomically open a new async build generation: bump the generation id, make it
# the active generation, clear the cancel-request generation + cancel flag, and
# drain any stale chunk payloads left by a previous generation. Returns the new
# active generation id. Precondition: no worker from a prior generation is still
# running -- the apply-pending-refresh path guarantees this because a new build
# only starts once the pipeline is inactive (the previous worker is joined in
# finish_async_initial_build / the overlay pump before restarting).
func begin_generation() -> int:
	_async_state_mutex.lock()
	build_generation_id += 1
	active_build_generation_id = build_generation_id
	cancel_requested_generation_id = 0
	_async_cancel_requested = false
	var generation_id := active_build_generation_id
	_async_state_mutex.unlock()
	clear_async_chunk_payloads()
	return generation_id


# ---- Chunk payload queue ----

func push_async_chunk_payload(payload: Dictionary) -> void:
	_async_queue_mutex.lock()
	_async_chunk_results.append(payload)
	_async_queue_mutex.unlock()


func pop_async_chunk_payload() -> Dictionary:
	_async_queue_mutex.lock()
	var payload := {}
	if not _async_chunk_results.is_empty():
		payload = _async_chunk_results.pop_front()
	_async_queue_mutex.unlock()
	return payload


func clear_async_chunk_payloads() -> void:
	_async_queue_mutex.lock()
	_async_chunk_results.clear()
	_async_queue_mutex.unlock()


func async_chunk_payload_count() -> int:
	_async_queue_mutex.lock()
	var count := _async_chunk_results.size()
	_async_queue_mutex.unlock()
	return count


# ---- Thread lifecycle ----

func set_async_initial_thread(thread: Thread) -> void:
	_async_state_mutex.lock()
	_async_initial_thread = thread
	_async_state_mutex.unlock()


func join_async_thread() -> void:
	var thread: Thread = null
	_async_state_mutex.lock()
	thread = _async_initial_thread
	_async_initial_thread = null
	_async_state_mutex.unlock()
	if thread != null:
		thread.wait_to_finish()


func set_async_overlay_descriptor_thread(thread: Thread) -> void:
	_async_overlay_descriptor_mutex.lock()
	_async_overlay_descriptor_thread = thread
	_async_overlay_descriptor_mutex.unlock()


func join_async_overlay_descriptor_thread() -> void:
	var thread: Thread = null
	_async_overlay_descriptor_mutex.lock()
	thread = _async_overlay_descriptor_thread
	_async_overlay_descriptor_thread = null
	_async_overlay_descriptor_mutex.unlock()
	if thread != null:
		thread.wait_to_finish()


# ---- Cancellation ----

func cancel_async_build(overlay_apply_active: bool) -> void:
	# Capture activity flags first (each takes its own mutex), then set the cancel
	# flag once under `_async_state_mutex`. Previously the descriptor/overlay-apply
	# cases wrote the flag without the mutex, which raced with the worker-side
	# locked reads in is_async_cancel_requested().
	var build_active := is_async_build_active()
	var descriptor_active := is_async_overlay_descriptor_active()
	_async_state_mutex.lock()
	if build_active:
		cancel_requested_generation_id = active_build_generation_id
	if build_active or descriptor_active or overlay_apply_active:
		_async_cancel_requested = true
	_async_state_mutex.unlock()


# ---- State reset (coordinator-owned portion) ----

func reset_async_state() -> void:
	_async_state_mutex.lock()
	_async_worker_done = false
	_async_worker_failed = false
	_async_worker_error = ""
	_async_cancel_requested = false
	_async_state_mutex.unlock()
	clear_async_chunk_payloads()
	set_async_overlay_descriptor_state(false, false, {}, {})
	set_async_overlay_descriptor_stage("")


# ---- Map signature ----

static func _checksum_packed_byte_array(data: PackedByteArray) -> int:
	var h: int = 2166136261
	for b in data:
		h = int((h ^ int(b)) * 16777619)
		h = h & 0xFFFFFFFF
	return h


func is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	if not _map_signature_valid:
		return true
	if _map_signature_dims != Vector2i(w, h):
		return true
	if _map_signature_level_set != level_set:
		return true
	if not _map_signature_checksums_current:
		return true
	if _map_signature_hgt_checksum != _checksum_packed_byte_array(hgt):
		return true
	if _map_signature_typ_checksum != _checksum_packed_byte_array(typ):
		return true
	if _map_signature_blg_checksum != _checksum_packed_byte_array(blg):
		return true
	return false


func record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	_map_signature_valid = true
	_map_signature_dims = Vector2i(w, h)
	_map_signature_level_set = level_set
	_map_signature_hgt_checksum = _checksum_packed_byte_array(hgt)
	_map_signature_typ_checksum = _checksum_packed_byte_array(typ)
	_map_signature_blg_checksum = _checksum_packed_byte_array(blg)
	_map_signature_checksums_current = true
	_localized_signature_pending = false


func mark_localized_signature_change(w: int, h: int, level_set: int) -> void:
	_map_signature_valid = true
	_map_signature_dims = Vector2i(w, h)
	_map_signature_level_set = level_set
	_map_signature_checksums_current = false
	_localized_signature_pending = true


func can_skip_map_signature_check(w: int, h: int, level_set: int, has_localized_invalidation: bool) -> bool:
	return has_localized_invalidation and _localized_signature_pending and _map_signature_dims == Vector2i(w, h) and _map_signature_level_set == level_set


func record_map_signature_metadata_only(w: int, h: int, level_set: int) -> void:
	_map_signature_valid = true
	_map_signature_dims = Vector2i(w, h)
	_map_signature_level_set = level_set
	_map_signature_checksums_current = false
	_localized_signature_pending = false

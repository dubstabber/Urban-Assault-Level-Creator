extends Node3D
class_name Map3DRenderer

signal build_state_changed(is_building: bool, completed: int, total: int, status: String)
signal build_finished(success: bool)

const UATerrainPieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")
const VisualLookupService := preload("res://map/map_3d_visual_lookup_service.gd")
const TerrainBuilder := preload("res://map/map_3d_terrain_builder.gd")
const SlurpBuilder := preload("res://map/map_3d_slurp_builder.gd")
const AuthoredOverlayManager := preload("res://map/map_3d_authored_overlay_manager.gd")
const ViewController := preload("res://map/map_3d_view_controller.gd")
const UALegacyText := preload("res://map/ua_legacy_text.gd")

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
# The 2D editor / UA coordinate system uses a 1200-unit sector span.
# The 3D preview + authored-piece sampling operates in scaled-world units
# where that span is 1.0. This constant is used to convert UA->scaled.
const WORLD_SCALE := 1.0 / SECTOR_SIZE
const EDGE_SLOPE := 150.0 # Per-side width; UA fillers span ~300 across seam (~150 into each sector)
const BORDER_TYP_TOP_LEFT := 248
const BORDER_TYP_TOP := 252
const BORDER_TYP_TOP_RIGHT := 249
const BORDER_TYP_LEFT := 255
const BORDER_TYP_RIGHT := 253
const BORDER_TYP_BOTTOM_LEFT := 251
const BORDER_TYP_BOTTOM := 254
const BORDER_TYP_BOTTOM_RIGHT := 250
const TERRAIN_PREVIEW_COLOR := Color(0.62, 0.66, 0.58, 1.0)
const EDGE_PREVIEW_COLOR := Color(0.82, 0.48, 0.24, 0.55)
const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"
const SUBQUAD_UV_INSET := 0.002 # Prevent internal 1/3 and 2/3 seam sampling bleed
const _DEBUG_DISABLE_CHUNKED_EXPERIMENT := false
const UA_NORMAL_RENDER_SECTORS := 5
const UA_NORMAL_GEOMETRY_CULL_DISTANCE := float(UA_NORMAL_RENDER_SECTORS) * SECTOR_SIZE + SECTOR_SIZE * 0.5
const _ASYNC_APPLY_RESULTS_PER_FRAME := 1
const _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 20

#region debug NDJSON logging (runtime evidence)
const _NDJSON_DEBUG_LOG_PATH := "/run/media/ydro/WDC/gamedev-workspace/Urban Assault Level Creator/.cursor/debug-324b35.log"
static var _ndjson_debug_log_count: int = 0
static func _ndjson_log_once(run_id: String, hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	if _ndjson_debug_log_count >= 200:
		return
	_ndjson_debug_log_count += 1
	var payload := {
		"sessionId": "324b35",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	var f := FileAccess.open(_NDJSON_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_NDJSON_DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	# Ensure we append instead of truncating.
	var end_pos := f.get_length()
	f.seek(end_pos)
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion
const HOST_STATION_BASE_NAMES := {
	56: "VP_ROBO",
	57: "VP_KROBO",
	58: "VP_BRGRO",
	59: "VP_GIGNT",
	60: "VP_TAERO",
	61: "VP_SULG1",
	62: "VP_BSECT",
	132: "VP_TRAIN",
	176: "VP_GIGNT",
	177: "VP_KROBO",
	178: "VP_TAERO",
}
const HOST_STATION_VISIBLE_GUN_BASE_NAMES := {
	90: "VP_MFLAK",
	91: "VP_MFLAK",
	92: "VP_MFLAK",
	93: "VP_FLAK2",
	94: "VP_FLAK2",
	95: "VP_FLAK2",
}
const HOST_STATION_GUN_ATTACHMENTS := {
	56: [
		{"gun_type": 90, "ua_offset": Vector3(0.0, -200.0, 55.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 91, "ua_offset": Vector3(0.0, -180.0, -80.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
		{"gun_type": 92, "ua_offset": Vector3(0.0, -390.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 93, "ua_offset": Vector3(0.0, 150.0, 0.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
	],
	62: [
		{"gun_type": 95, "ua_offset": Vector3(0.0, -150.0, 375.0), "ua_direction": Vector3(0.0, 0.0, 1.0)},
		{"gun_type": 94, "ua_offset": Vector3(0.0, -120.0, -380.0), "ua_direction": Vector3(0.0, 0.0, -1.0)},
	],
}
const TECH_UPGRADE_EDITOR_TYP_OVERRIDES := {
	4: 100,
	7: 73,
	15: 104,
	16: 103,
	50: 102,
	51: 101,
	60: 106,
	61: 113,
	65: 110,
}
const SQUAD_FORMATION_SPACING := 100.0
const SQUAD_EXTRA_Y_OFFSET := 8.0
const UA_DATA_JSON = preload("res://resources/UAdata.json")

static var _blg_typ_override_cache: Dictionary = {}


# Preview top surfaces use world-space tiling with one repeat per sector.
func _compute_tile_scale() -> float:
	return 1.0 / SECTOR_SIZE

static func visibility_range_fade_start(viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> float:
	return ViewController.visibility_range_fade_start(viz_limit, fade_length)

static func visibility_range_config(viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> Dictionary:
	return ViewController.visibility_range_config(viz_limit, fade_length)

static func apply_visibility_range_to_environment(environment: Environment, enabled: bool, viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> bool:
	return ViewController.apply_visibility_range_to_environment(environment, enabled, viz_limit, fade_length)

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _edge_mesh: MeshInstance3D = $EdgeMesh if has_node("EdgeMesh") else null
@onready var _authored_overlay: Node3D = $AuthoredOverlay if has_node("AuthoredOverlay") else null
@onready var _dynamic_overlay: Node3D = $DynamicOverlay if has_node("DynamicOverlay") else null
# Keep seam/slurp strips visible in the live preview; redundant flat/same-surface
# seams are filtered out in the builder to avoid needless overdraw.
var _edge_overlay_enabled := true

@onready var _camera: Camera3D = $Camera3D
@onready var _world_environment: WorldEnvironment = $WorldEnvironment if has_node("WorldEnvironment") else null

var _mouselook := false
var _yaw := 0.0
var _pitch := -0.6
var _move_speed := 1200.0
var _sprint_mult := 2.0
var _look_sens := 0.0025
var _framed := false
var _debug_shader_mode: int = 0 # Debug visualization for the current surface-type preview shader.
var _event_system_override: Node = null
var _current_map_data_override: Node = null
var _editor_state_override: Node = null
var _preloads_override: Node = null
var _preloads_override_set := false
var _refresh_pending := false
var _refresh_reframe_pending := false
var _refresh_deferred := false
var _refresh_requested_at_usec := 0
var _last_build_metrics: Dictionary = {}

var _chunked_terrain_enabled := true
var _terrain_chunk_nodes: Dictionary = {}
var _edge_chunk_nodes: Dictionary = {}
var _dirty_chunks: Dictionary = {}
var _last_map_dimensions: Vector2i = Vector2i.ZERO
var _last_level_set: int = -1

# Cache to avoid recomputing `effective_typ` when only `hgt_map` changes.
var _effective_typ_cache_valid := false
var _effective_typ_cache_game_data_type := ""
var _effective_typ_cache_dims: Vector2i = Vector2i(-1, -1)
var _effective_typ_cache: PackedByteArray = PackedByteArray()
var _effective_typ_dirty := true
var _effective_typ_cache_typ_checksum: int = 0
var _effective_typ_cache_blg_checksum: int = 0

# Terrain/edge authored piece descriptor cache.
# Used to keep incremental chunk rebuilds from accidentally queue-free'ing
# unaffected authored pieces.
var _terrain_authored_cache_by_key: Dictionary = {}
# Instance-key reference counts across chunks.
# Border-inclusive chunk meshes generate overlapping authored descriptors, so
# keys can contribute to multiple chunks simultaneously. We must not erase
# a key globally just because one chunk rebuild dropped its contribution.
var _terrain_authored_cache_key_ref_counts: Dictionary = {}
# Maps a chunk coord to the authored descriptor instance-keys it contributed last time.
var _terrain_chunk_authored_cache_keys: Dictionary = {}

# Initial-load batching for large maps.
var _initial_build_in_progress := false
var _initial_build_batch_size := 4
var _initial_build_accumulated_authored_descriptors: Array = []
# When the renderer fell back to a full rebuild (e.g. because dirty chunk tracking
# didn't get signaled), the incremental cache bookkeeping may not be exact for
# border-inclusive chunk meshes.
# Force exactly one follow-up full rebuild on the next map update to restore
# consistent edge/slurp + authored-overlay behavior.
var _force_full_rebuild_next_update := false
var _force_full_rebuild_was_applied := false
var _geometry_distance_culling_enabled := false
var _geometry_cull_distance := UA_NORMAL_GEOMETRY_CULL_DISTANCE

# Async initial-build state (exposed for UI loading indicator and cancellation).
var build_generation_id := 0
var active_build_generation_id := 0
var cancel_requested_generation_id := 0
var is_building_3d := false
var total_chunks := 0
var completed_chunks := 0
var status_text := ""

var _async_initial_thread: Thread = null
var _async_state_mutex: Mutex = Mutex.new()
var _async_queue_mutex: Mutex = Mutex.new()
var _async_chunk_results: Array = []
var _async_worker_done := false
var _async_worker_failed := false
var _async_worker_error := ""
var _async_pending_reframe_camera := false
var _async_effective_typ: PackedByteArray = PackedByteArray()
var _async_blg: PackedByteArray = PackedByteArray()
var _async_w := 0
var _async_h := 0
var _async_level_set := 0
var _async_game_data_type := "original"
var _async_cancel_requested := false
var _async_requested_restart := false
var _async_requested_reframe := false
var _async_overlay_descriptor_thread: Thread = null
var _async_overlay_descriptor_done := false
var _async_overlay_descriptor_failed := false
var _async_overlay_descriptor_result: Variant = {}
var _async_overlay_descriptor_metrics: Dictionary = {}
var _async_overlay_descriptor_mutex: Mutex = Mutex.new()
var _async_overlay_apply_active := false
var _async_overlay_apply_state: Dictionary = {}
var _async_overlay_descriptors: Array = []
var _async_overlay_metrics: Dictionary = {}
var _async_overlay_apply_started_usec := 0
var _overlay_apply_manager := Map3DAuthoredOverlayManager.new()
var _overlay_only_refresh_requested := false
var _dynamic_overlay_refresh_requested := false
var _async_dynamic_overlay_descriptors: Array = []
var _async_overlay_descriptor_dynamic_only := false


func set_event_system_override(event_system: Node) -> void:
	_event_system_override = event_system


func set_current_map_data_override(current_map_data: Node) -> void:
	_current_map_data_override = current_map_data


func set_editor_state_override(editor_state: Node) -> void:
	_editor_state_override = editor_state


func set_preloads_override(preloads: Node) -> void:
	_preloads_override = preloads
	_preloads_override_set = true


func has_pending_refresh() -> bool:
	return _refresh_pending


func get_last_build_metrics() -> Dictionary:
	if _last_build_metrics.is_empty():
		return _make_empty_build_metrics()
	return _last_build_metrics.duplicate(true)


func _make_empty_build_metrics() -> Dictionary:
	return {
		"used_textured_preloads": false,
		"invalid_input": false,
		"terrain_build_ms": 0.0,
		"edge_slurp_build_ms": 0.0,
		"overlay_descriptor_generation_ms": 0.0,
		"overlay_node_creation_ms": 0.0,
		"support_height_query_ms": 0.0,
		"support_height_query_count": 0,
		"terrain_authored_descriptor_count": 0,
		"edge_authored_descriptor_count": 0,
		"overlay_descriptor_count": 0,
		"piece_overlay_fast_path": 0,
		"piece_overlay_slow_path": 0,
		"build_total_ms": 0.0,
		"refresh_end_to_end_ms": 0.0,
	}


func _emit_build_state(building: bool, completed: int, total: int, status: String) -> void:
	is_building_3d = building
	completed_chunks = maxi(completed, 0)
	total_chunks = maxi(total, 0)
	status_text = status
	build_state_changed.emit(is_building_3d, completed_chunks, total_chunks, status_text)


func _begin_build_state(total_chunk_count: int, status: String) -> void:
	_emit_build_state(true, 0, total_chunk_count, status)


func _update_build_progress(completed: int, total: int, status: String = "") -> void:
	var text := status_text if status.is_empty() else status
	_emit_build_state(true, completed, total, text)


func _end_build_state(success: bool, status: String = "") -> void:
	_emit_build_state(false, completed_chunks, total_chunks, status)
	build_finished.emit(success)


func _is_async_build_active() -> bool:
	_async_state_mutex.lock()
	var active := _async_initial_thread != null
	_async_state_mutex.unlock()
	return active


func _is_async_pipeline_active() -> bool:
	return _is_async_build_active() or _is_async_overlay_descriptor_active() or _async_overlay_apply_active


func _is_async_overlay_descriptor_active() -> bool:
	_async_overlay_descriptor_mutex.lock()
	var active := _async_overlay_descriptor_thread != null
	_async_overlay_descriptor_mutex.unlock()
	return active


func _set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	_async_overlay_descriptor_mutex.lock()
	_async_overlay_descriptor_done = done
	_async_overlay_descriptor_failed = failed
	_async_overlay_descriptor_result = result
	_async_overlay_descriptor_metrics = metrics
	_async_overlay_descriptor_mutex.unlock()


func _get_async_overlay_descriptor_state() -> Dictionary:
	_async_overlay_descriptor_mutex.lock()
	var state := {
		"done": _async_overlay_descriptor_done,
		"failed": _async_overlay_descriptor_failed,
		"result": _async_overlay_descriptor_result,
		"metrics": _async_overlay_descriptor_metrics,
	}
	_async_overlay_descriptor_mutex.unlock()
	return state


func _set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	_async_state_mutex.lock()
	_async_worker_done = done
	_async_worker_failed = failed
	_async_worker_error = message
	_async_state_mutex.unlock()


func _get_async_worker_state() -> Dictionary:
	_async_state_mutex.lock()
	var state := {
		"done": _async_worker_done,
		"failed": _async_worker_failed,
		"error": _async_worker_error,
	}
	_async_state_mutex.unlock()
	return state


func _is_async_cancel_requested(generation_id: int) -> bool:
	_async_state_mutex.lock()
	var cancelled := _async_cancel_requested and generation_id == active_build_generation_id
	_async_state_mutex.unlock()
	return cancelled


func _push_async_chunk_payload(payload: Dictionary) -> void:
	_async_queue_mutex.lock()
	_async_chunk_results.append(payload)
	_async_queue_mutex.unlock()


func _pop_async_chunk_payload() -> Dictionary:
	_async_queue_mutex.lock()
	var payload := {}
	if not _async_chunk_results.is_empty():
		payload = _async_chunk_results.pop_front()
	_async_queue_mutex.unlock()
	return payload


func _clear_async_chunk_payloads() -> void:
	_async_queue_mutex.lock()
	_async_chunk_results.clear()
	_async_queue_mutex.unlock()


func _async_chunk_payload_count() -> int:
	_async_queue_mutex.lock()
	var count := _async_chunk_results.size()
	_async_queue_mutex.unlock()
	return count


func _compute_effective_typ_for_map(
	cmd: Node,
	w: int,
	h: int,
	typ: PackedByteArray,
	blg: PackedByteArray,
	game_data_type: String
) -> PackedByteArray:
	var typ_checksum := _checksum_packed_byte_array(typ)
	var blg_checksum := _checksum_packed_byte_array(blg)
	var can_reuse_effective_typ := _effective_typ_cache_valid and (not _effective_typ_dirty) and _effective_typ_cache_dims == Vector2i(w, h) and _effective_typ_cache_game_data_type == game_data_type and _effective_typ_cache_typ_checksum == typ_checksum and _effective_typ_cache_blg_checksum == blg_checksum
	if can_reuse_effective_typ:
		return _effective_typ_cache
	var effective_typ := _effective_typ_map_for_3d(
		typ,
		blg,
		game_data_type,
		w,
		h,
		cmd.beam_gates,
		cmd.tech_upgrades,
		cmd.stoudson_bombs
	)
	_effective_typ_cache = effective_typ
	_effective_typ_cache_valid = true
	_effective_typ_cache_game_data_type = game_data_type
	_effective_typ_cache_dims = Vector2i(w, h)
	_effective_typ_cache_typ_checksum = typ_checksum
	_effective_typ_cache_blg_checksum = blg_checksum
	_effective_typ_dirty = false
	return effective_typ


static func _elapsed_ms_since(started_usec: int) -> float:
	if started_usec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)


static func _checksum_packed_byte_array(data: PackedByteArray) -> int:
	# Small, deterministic checksum to invalidate caches when packed maps change.
	# Maps are small enough that the O(n) scan is acceptable on editor edits.
	var h: int = 2166136261
	for b in data:
		h = int((h ^ int(b)) * 16777619)
		h = h & 0xFFFFFFFF
	return h


static func _profile_add_duration(profile, key: String, duration_ms: float) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = float(profile.get(key, 0.0)) + maxf(duration_ms, 0.0)


static func _profile_increment(profile, key: String, amount: int = 1) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = int(profile.get(key, 0)) + amount


static func _overlay_key_bounds_stats(descriptors: Array, w: int, h: int) -> Dictionary:
	var terrain_oob := 0
	var terrain_in := 0
	var slurp_oob := 0
	var slurp_in := 0
	for d_any in descriptors:
		if typeof(d_any) != TYPE_DICTIONARY:
			continue
		var d := d_any as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.is_empty():
			continue
		if key.begins_with("terrain:"):
			var parts_t := key.split(":")
			if parts_t.size() >= 4:
				var tx := int(parts_t[2])
				var ty := int(parts_t[3])
				if tx < 0 or tx >= w or ty < 0 or ty >= h:
					terrain_oob += 1
				else:
					terrain_in += 1
		elif key.begins_with("slurp:"):
			var parts_s := key.split(":")
			if parts_s.size() >= 5:
				var sx := int(parts_s[3])
				var sy := int(parts_s[4])
				var oob := (sx < 0 or sx >= w or sy < 0 or sy >= h)
				if oob:
					slurp_oob += 1
				else:
					slurp_in += 1
	return {
		"terrain_in_bounds": terrain_in,
		"terrain_out_of_bounds": terrain_oob,
		"slurp_in_bounds": slurp_in,
		"slurp_out_of_bounds": slurp_oob,
		"total_descriptors": descriptors.size()
	}


static func _descriptor_key_set(descriptors: Array) -> Dictionary:
	var out := {}
	for d_any in descriptors:
		if typeof(d_any) != TYPE_DICTIONARY:
			continue
		var key := String((d_any as Dictionary).get("instance_key", ""))
		if key.is_empty():
			continue
		out[key] = true
	return out


static func _descriptor_key_diff_sample(a_keys: Dictionary, b_keys: Dictionary, limit: int = 6) -> Array:
	var sample: Array = []
	for key in a_keys.keys():
		if b_keys.has(key):
			continue
		sample.append(String(key))
		if sample.size() >= limit:
			break
	return sample


static func _terrain_slot_conflict_stats(descriptors: Array) -> Dictionary:
	var slot_to_keys := {}
	var terrain_descriptor_count := 0
	for d_any in descriptors:
		if typeof(d_any) != TYPE_DICTIONARY:
			continue
		var d := d_any as Dictionary
		var key := String(d.get("instance_key", ""))
		if not key.begins_with("terrain:"):
			continue
		terrain_descriptor_count += 1
		var parts := key.split(":")
		var slot := ""
		if parts.size() >= 7:
			slot = "%s:%s:%s:%s" % [parts[2], parts[3], parts[4], parts[5]]
		elif parts.size() >= 5:
			slot = "%s:%s:main:0" % [parts[2], parts[3]]
		else:
			continue
		var keys_for_slot: Dictionary = slot_to_keys.get(slot, {})
		keys_for_slot[key] = true
		slot_to_keys[slot] = keys_for_slot

	var conflict_slot_count := 0
	var conflict_extra_key_count := 0
	var conflict_samples: Array = []
	for slot_key in slot_to_keys.keys():
		var keys_for_slot: Dictionary = slot_to_keys[slot_key]
		if keys_for_slot.size() <= 1:
			continue
		conflict_slot_count += 1
		conflict_extra_key_count += keys_for_slot.size() - 1
		if conflict_samples.size() < 8:
			conflict_samples.append({
				"slot": String(slot_key),
				"keys": keys_for_slot.keys()
			})
	return {
		"terrain_descriptor_count": terrain_descriptor_count,
		"terrain_slot_count": slot_to_keys.size(),
		"conflict_slot_count": conflict_slot_count,
		"conflict_extra_key_count": conflict_extra_key_count,
		"conflict_samples": conflict_samples
	}


func _finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	metrics["build_total_ms"] = _elapsed_ms_since(build_started_usec)
	if _refresh_requested_at_usec > 0:
		metrics["refresh_end_to_end_ms"] = _elapsed_ms_since(_refresh_requested_at_usec)
		_refresh_requested_at_usec = 0
	_last_build_metrics = metrics.duplicate(true)


func _event_system() -> Node:
	if _event_system_override != null and is_instance_valid(_event_system_override):
		return _event_system_override
	return get_node_or_null("/root/EventSystem")


func _current_map_data() -> Node:
	if _current_map_data_override != null and is_instance_valid(_current_map_data_override):
		return _current_map_data_override
	return get_node_or_null("/root/CurrentMapData")


func _editor_state() -> Node:
	if _editor_state_override != null and is_instance_valid(_editor_state_override):
		return _editor_state_override
	return get_node_or_null("/root/EditorState")


func _preloads() -> Node:
	if _preloads_override_set:
		if _preloads_override != null and is_instance_valid(_preloads_override):
			return _preloads_override
		return null
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("Preloads")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("Preloads")
	return null


func _preview_refresh_active() -> bool:
	var editor_state := _editor_state()
	if editor_state != null:
		return bool(editor_state.get("view_mode_3d"))
	return true


func _apply_preview_activity_state() -> void:
	var active := _preview_refresh_active()
	set_physics_process(active)
	set_process_unhandled_input(active)


func _request_refresh(reframe_camera: bool) -> void:
	if not _refresh_pending and _refresh_requested_at_usec <= 0:
		_refresh_requested_at_usec = Time.get_ticks_usec()
	_refresh_pending = true
	_refresh_reframe_pending = _refresh_reframe_pending or reframe_camera
	if not _preview_refresh_active():
		return
	if _refresh_deferred:
		return
	_refresh_deferred = true
	call_deferred("_apply_pending_refresh")


func _apply_pending_refresh() -> void:
	_refresh_deferred = false
	if not _refresh_pending or not _preview_refresh_active():
		return
	var reframe_camera := _refresh_reframe_pending
	_refresh_pending = false
	_refresh_reframe_pending = false
	if _is_async_pipeline_active():
		_async_requested_restart = true
		_async_requested_reframe = _async_requested_reframe or reframe_camera
		_cancel_async_initial_build()
		return
	if _dynamic_overlay_refresh_requested:
		if _start_async_dynamic_overlay_refresh(reframe_camera):
			return
	if _overlay_only_refresh_requested or _can_use_overlay_only_refresh():
		if _start_async_overlay_only_refresh(reframe_camera):
			return
	if _try_start_async_initial_build(reframe_camera):
		return
	build_from_current_map()
	_bump_3d_viewport_rendering()
	if reframe_camera and is_inside_tree():
		_framed = false
		_frame_if_needed()

func _ready() -> void:
	var test_mesh := get_node_or_null("TestMesh")
	if test_mesh:
		_ensure_edge_node()

		test_mesh.visible = false
	# Ensure we have an active camera in the SubViewport
	if _camera:
		_camera.current = true
		print("[Map3D] _ready: camera active, current=", _camera.current)
	# Listen for map events (guarded for test environment without autoloads)

	var _es = _event_system()
	if _es:
		_es.map_created.connect(_on_map_created)
		_es.map_updated.connect(_on_map_updated)
		_es.level_set_changed.connect(_on_level_set_changed)
		_es.map_view_updated.connect(_on_map_view_updated)
		_es.map_3d_overlay_animations_changed.connect(_on_map_3d_overlay_animations_changed)
		if _es.has_signal("hoststation_added"):
			_es.hoststation_added.connect(_on_host_station_added)
		if _es.has_signal("unit_position_committed"):
			_es.unit_position_committed.connect(_on_unit_position_committed)
		if _es.has_signal("hgt_map_cells_edited"):
			_es.hgt_map_cells_edited.connect(_on_hgt_map_cells_edited)
		if _es.has_signal("typ_map_cells_edited"):
			_es.typ_map_cells_edited.connect(_on_typ_map_cells_edited)
	_apply_preview_activity_state()
	_apply_visibility_range_from_editor_state()
	var _cmd = _current_map_data()

	if _cmd:
		print("[Map3D] _ready: initial dims w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt=", _cmd.hgt_map.size())
		# Initial build if data already present
		if _cmd.horizontal_sectors > 0 and _cmd.vertical_sectors > 0 and not _cmd.hgt_map.is_empty():
			print("[Map3D] _ready: scheduling initial build from current map")
			_request_refresh(true)

func _apply_visibility_range_from_editor_state() -> void:
	var editor_state := _editor_state()
	var enabled := false
	if editor_state != null:
		enabled = bool(editor_state.get("map_3d_visibility_range_enabled"))
	if _world_environment != null and _world_environment.environment != null:
		apply_visibility_range_to_environment(_world_environment.environment, enabled)
	_apply_geometry_distance_culling_state(enabled)

func _on_map_view_updated() -> void:
	_apply_preview_activity_state()
	_apply_visibility_range_from_editor_state()
	if _preview_refresh_active():
		_bump_3d_viewport_rendering()
	if _refresh_pending:
		_request_refresh(_refresh_reframe_pending)


func _on_map_3d_overlay_animations_changed() -> void:
	if _preview_refresh_active():
		_request_overlay_only_refresh()


func _on_host_station_added(_owner_id: int, _vehicle_id: int) -> void:
	if _preview_refresh_active():
		_request_dynamic_overlay_refresh()


func _on_unit_position_committed() -> void:
	if _preview_refresh_active():
		_request_dynamic_overlay_refresh()


func _request_overlay_only_refresh() -> void:
	_overlay_only_refresh_requested = true
	_request_refresh(false)


func _request_dynamic_overlay_refresh() -> void:
	_dynamic_overlay_refresh_requested = true
	_request_refresh(false)


func _can_use_overlay_only_refresh() -> bool:
	if _initial_build_in_progress:
		return false
	if not _dirty_chunks.is_empty():
		return false
	if _terrain_chunk_nodes.is_empty() and _edge_chunk_nodes.is_empty():
		return false
	var cmd := _current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	if Vector2i(w, h) != _last_map_dimensions:
		return false
	if int(cmd.level_set) != _last_level_set:
		return false
	return true


func _start_async_overlay_only_refresh(reframe_camera: bool) -> bool:
	if not _can_use_overlay_only_refresh():
		_overlay_only_refresh_requested = false
		return false
	_overlay_only_refresh_requested = false
	build_generation_id += 1
	active_build_generation_id = build_generation_id
	cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_begin_build_state(1, "Preparing overlays...")
	_start_async_overlay_descriptor_build()
	return true


func _start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	if not _can_use_overlay_only_refresh():
		_dynamic_overlay_refresh_requested = false
		return false
	_dynamic_overlay_refresh_requested = false
	_overlay_only_refresh_requested = false
	build_generation_id += 1
	active_build_generation_id = build_generation_id
	cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_begin_build_state(1, "Updating vehicles...")
	_start_async_overlay_descriptor_build(true)
	return true


func _try_start_async_initial_build(reframe_camera: bool) -> bool:
	if not _initial_build_in_progress:
		return false
	if _dirty_chunks.is_empty():
		return false
	var cmd := _current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	var hgt: PackedByteArray = cmd.hgt_map
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2) or typ.size() != w * h:
		return false
	var pre := _preloads()
	if pre == null:
		return false
	if _terrain_chunk_nodes.is_empty():
		_invalidate_all_chunks(w, h)
	var chunk_list := _dirty_chunks_sorted_by_priority(w, h)
	if chunk_list.is_empty():
		return false
	var game_data_type := _current_game_data_type()
	UATerrainPieceLibraryScript.set_piece_game_data_type(game_data_type)
	var effective_typ := _compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	var level_set := int(cmd.level_set)
	var snapshot := {
		"w": w,
		"h": h,
		"hgt": hgt,
		"effective_typ": effective_typ,
		"level_set": level_set,
		"chunk_list": chunk_list,
		"edge_overlay_enabled": _edge_overlay_enabled,
		"surface_type_map": pre.surface_type_map,
		"subsector_patterns": pre.subsector_patterns,
		"tile_mapping": pre.tile_mapping,
		"tile_remap": pre.tile_remap,
		"subsector_idx_remap": pre.subsector_idx_remap,
		"lego_defs": pre.lego_defs,
	}
	build_generation_id += 1
	active_build_generation_id = build_generation_id
	cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_effective_typ = effective_typ
	_async_blg = blg
	_async_w = w
	_async_h = h
	_async_level_set = level_set
	_async_game_data_type = game_data_type
	_async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_clear_async_chunk_payloads()
	_set_async_worker_state(false, false, "")
	var total := chunk_list.size()
	_begin_build_state(total, "Rendering map...")
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_initial_build_worker").bind(snapshot, active_build_generation_id))
	if err != OK:
		_end_build_state(false, "3D render worker could not start")
		return false
	_async_state_mutex.lock()
	_async_initial_thread = thread
	_async_state_mutex.unlock()
	return true


func _async_initial_build_worker(snapshot: Dictionary, generation_id: int) -> void:
	var w := int(snapshot.get("w", 0))
	var h := int(snapshot.get("h", 0))
	var hgt: PackedByteArray = snapshot.get("hgt", PackedByteArray())
	var effective_typ: PackedByteArray = snapshot.get("effective_typ", PackedByteArray())
	var level_set := int(snapshot.get("level_set", 0))
	var edge_overlay_enabled := bool(snapshot.get("edge_overlay_enabled", true))
	var surface_type_map = snapshot.get("surface_type_map", {})
	var subsector_patterns = snapshot.get("subsector_patterns", {})
	var tile_mapping = snapshot.get("tile_mapping", {})
	var tile_remap = snapshot.get("tile_remap", {})
	var subsector_idx_remap = snapshot.get("subsector_idx_remap", {})
	var lego_defs = snapshot.get("lego_defs", {})
	var chunk_list: Array = snapshot.get("chunk_list", [])
	for chunk_entry in chunk_list:
		if _is_async_cancel_requested(generation_id):
			break
		var chunk_coord := Vector2i(chunk_entry)
		var terrain_result := TerrainBuilder.build_chunk_mesh_with_textures(
			chunk_coord,
			hgt,
			effective_typ,
			w,
			h,
			surface_type_map,
			subsector_patterns,
			tile_mapping,
			tile_remap,
			subsector_idx_remap,
			lego_defs,
			level_set,
			true
		)
		var edge_result := {}
		if edge_overlay_enabled:
			edge_result = SlurpBuilder.build_chunk_edge_overlay_result(
				chunk_coord,
				hgt,
				w,
				h,
				effective_typ,
				surface_type_map,
				level_set
			)
		_push_async_chunk_payload({
			"generation_id": generation_id,
			"chunk_coord": chunk_coord,
			"terrain_result": terrain_result,
			"edge_result": edge_result,
			"has_edge_result": edge_overlay_enabled,
		})
	_set_async_worker_state(true, false, "")


func _pump_async_initial_build() -> void:
	if not _is_async_build_active():
		return
	for _i in _ASYNC_APPLY_RESULTS_PER_FRAME:
		var payload := _pop_async_chunk_payload()
		if payload.is_empty():
			break
		if int(payload.get("generation_id", -1)) != active_build_generation_id:
			continue
		if _async_cancel_requested:
			continue
		_apply_async_chunk_payload(payload)
	var state := _get_async_worker_state()
	if bool(state.get("done", false)):
		if _async_chunk_payload_count() == 0:
			_finish_async_initial_build()


func _apply_async_chunk_payload(payload: Dictionary) -> void:
	var chunk_coord := Vector2i(payload.get("chunk_coord", Vector2i.ZERO))
	var terrain_result: Dictionary = payload.get("terrain_result", {})
	var chunk_node := _get_or_create_terrain_chunk_node(chunk_coord)
	chunk_node.mesh = terrain_result.get("mesh", null)
	var pre := _preloads()
	if pre != null and chunk_node.mesh != null:
		_apply_sector_top_materials(chunk_node.mesh, pre, terrain_result.get("surface_to_surface_type", {}))
	var chunk_authored_descriptors: Array = terrain_result.get("authored_piece_descriptors", []).duplicate()
	if bool(payload.get("has_edge_result", false)):
		var edge_result: Dictionary = payload.get("edge_result", {})
		var edge_chunk_node := _get_or_create_edge_chunk_node(chunk_coord)
		edge_chunk_node.mesh = edge_result.get("mesh", null)
		if pre != null and edge_chunk_node.mesh != null:
			_apply_edge_surface_materials(
				edge_chunk_node.mesh,
				pre,
				edge_result.get("fallback_horiz_keys", []),
				edge_result.get("fallback_vert_keys", [])
			)
		chunk_authored_descriptors.append_array(edge_result.get("authored_piece_descriptors", []))
	_update_terrain_authored_cache_for_chunk(chunk_coord, chunk_authored_descriptors)
	_dirty_chunks.erase(chunk_coord)
	var done := completed_chunks + 1
	_update_build_progress(done, total_chunks, "Rendering map... %d / %d" % [done, total_chunks])
	_bump_3d_viewport_rendering()


func _finish_async_initial_build() -> void:
	_join_async_thread()
	var cancelled := _async_cancel_requested
	var failed := bool(_get_async_worker_state().get("failed", false))
	var should_restart := _async_requested_restart
	var restart_reframe := _async_requested_reframe
	if cancelled:
		_end_build_state(false, "3D render cancelled")
		_reset_async_build_state()
		if should_restart:
			_request_refresh(restart_reframe)
		return
	if failed:
		_end_build_state(false, "3D render failed")
		_reset_async_build_state()
		_request_refresh(restart_reframe)
		return
	_start_async_overlay_descriptor_build()


func _start_async_overlay_descriptor_build(dynamic_only: bool = false) -> void:
	_update_build_progress(total_chunks, total_chunks, "Preparing overlays...")
	var support_descriptors: Array = _terrain_authored_cache_by_key.values().duplicate()
	var cmd := _current_map_data()
	if cmd == null:
		_start_async_overlay_apply(support_descriptors, [], _make_empty_build_metrics())
		return
	var host_station_snapshot: Array = []
	var squad_snapshot: Array = []
	if cmd.host_stations != null and is_instance_valid(cmd.host_stations):
		host_station_snapshot = _snapshot_host_station_nodes(cmd.host_stations.get_children())
	if cmd.squads != null and is_instance_valid(cmd.squads):
		squad_snapshot = _snapshot_squad_nodes(cmd.squads.get_children())
	var payload := {
		"generation_id": active_build_generation_id,
		"dynamic_only": dynamic_only,
		"support_descriptors": support_descriptors,
		"blg": _async_blg,
		"effective_typ": _async_effective_typ,
		"set_id": _async_level_set,
		"hgt": cmd.hgt_map,
		"w": _async_w,
		"h": _async_h,
		"game_data_type": _async_game_data_type,
		"host_station_snapshot": host_station_snapshot,
		"squad_snapshot": squad_snapshot,
	}
	_async_overlay_descriptor_dynamic_only = dynamic_only
	_set_async_overlay_descriptor_state(false, false, {}, {})
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_overlay_descriptor_worker").bind(payload))
	if err != OK:
		# Fallback to immediate apply of terrain-only descriptors if descriptor worker cannot start.
		_start_async_overlay_apply(support_descriptors, [], _make_empty_build_metrics())
		return
	_async_overlay_descriptor_mutex.lock()
	_async_overlay_descriptor_thread = thread
	_async_overlay_descriptor_mutex.unlock()


func _async_overlay_descriptor_worker(payload: Dictionary) -> void:
	var generation_id := int(payload.get("generation_id", -1))
	var dynamic_only := bool(payload.get("dynamic_only", false))
	if _is_async_cancel_requested(generation_id):
		_set_async_overlay_descriptor_state(true, false, {}, {})
		return
	var metrics := _make_empty_build_metrics()
	var started_usec := Time.get_ticks_usec()
	var support_descriptors: Array = payload.get("support_descriptors", []).duplicate()
	var static_descriptors: Array = support_descriptors.duplicate()
	var dynamic_descriptors: Array = []
	var blg: PackedByteArray = payload.get("blg", PackedByteArray())
	var effective_typ: PackedByteArray = payload.get("effective_typ", PackedByteArray())
	var set_id := int(payload.get("set_id", 1))
	var hgt: PackedByteArray = payload.get("hgt", PackedByteArray())
	var w := int(payload.get("w", 0))
	var h := int(payload.get("h", 0))
	var game_data_type := String(payload.get("game_data_type", "original"))
	var host_station_snapshot: Array = payload.get("host_station_snapshot", [])
	var squad_snapshot: Array = payload.get("squad_snapshot", [])
	if not dynamic_only:
		static_descriptors.append_array(_build_blg_attachment_descriptors(blg, effective_typ, set_id, hgt, w, h, support_descriptors, game_data_type))
	if _is_async_cancel_requested(generation_id):
		_set_async_overlay_descriptor_state(true, false, {}, {})
		return
	dynamic_descriptors.append_array(_build_host_station_descriptors_from_snapshot(host_station_snapshot, set_id, hgt, w, h, support_descriptors, metrics))
	if _is_async_cancel_requested(generation_id):
		_set_async_overlay_descriptor_state(true, false, {}, {})
		return
	dynamic_descriptors.append_array(_build_squad_descriptors_from_snapshot(squad_snapshot, set_id, hgt, w, h, support_descriptors, game_data_type, metrics))
	metrics["overlay_descriptor_generation_ms"] = _elapsed_ms_since(started_usec)
	metrics["overlay_descriptor_count"] = static_descriptors.size() + dynamic_descriptors.size()
	_set_async_overlay_descriptor_state(true, false, {
		"static_descriptors": static_descriptors,
		"dynamic_descriptors": dynamic_descriptors,
	}, metrics)


func _pump_async_overlay_descriptor_build() -> void:
	if not _is_async_overlay_descriptor_active():
		return
	if _async_cancel_requested:
		_join_async_overlay_descriptor_thread()
		var should_restart := _async_requested_restart
		var restart_reframe := _async_requested_reframe
		_end_build_state(false, "3D render cancelled")
		_reset_async_build_state()
		if should_restart:
			_request_refresh(restart_reframe)
		return
	var state := _get_async_overlay_descriptor_state()
	if not bool(state.get("done", false)):
		return
	_join_async_overlay_descriptor_thread()
	if _async_cancel_requested:
		return
	if bool(state.get("failed", false)):
		_end_build_state(false, "Overlay descriptor generation failed")
		_reset_async_build_state()
		if _async_requested_restart:
			_request_refresh(_async_requested_reframe)
		return
	var result_payload: Dictionary = state.get("result", {})
	var static_descriptors: Array = result_payload.get("static_descriptors", [])
	var dynamic_descriptors: Array = result_payload.get("dynamic_descriptors", [])
	var metrics: Dictionary = state.get("metrics", {})
	if _async_overlay_descriptor_dynamic_only:
		_apply_dynamic_overlay(dynamic_descriptors)
		_last_build_metrics = metrics
		_end_build_state(true, "3D map ready")
		_bump_3d_viewport_rendering()
		if _async_pending_reframe_camera and is_inside_tree():
			_framed = false
			_frame_if_needed()
		var should_restart := _async_requested_restart
		var restart_reframe := _async_requested_reframe
		_reset_async_build_state()
		if should_restart:
			_request_refresh(restart_reframe)
		return
	_start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)


func _join_async_overlay_descriptor_thread() -> void:
	var thread: Thread = null
	_async_overlay_descriptor_mutex.lock()
	thread = _async_overlay_descriptor_thread
	_async_overlay_descriptor_thread = null
	_async_overlay_descriptor_mutex.unlock()
	if thread != null:
		thread.wait_to_finish()


func _ensure_overlay_nodes() -> void:
	if _authored_overlay == null or not is_instance_valid(_authored_overlay):
		_authored_overlay = Node3D.new()
		_authored_overlay.name = "AuthoredOverlay"
		add_child(_authored_overlay)
	if _dynamic_overlay == null or not is_instance_valid(_dynamic_overlay):
		_dynamic_overlay = Node3D.new()
		_dynamic_overlay.name = "DynamicOverlay"
		add_child(_dynamic_overlay)


func _apply_dynamic_overlay(dynamic_descriptors: Array) -> void:
	_ensure_overlay_nodes()
	AuthoredOverlayManager.apply_overlay_node(_dynamic_overlay, dynamic_descriptors)
	_apply_geometry_distance_culling_to_overlay()


func _start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_ensure_overlay_nodes()
	_async_overlay_descriptors = static_descriptors
	_async_dynamic_overlay_descriptors = dynamic_descriptors
	_async_overlay_metrics = metrics.duplicate(true)
	_async_overlay_apply_state = _overlay_apply_manager.begin_apply_overlay_node(_authored_overlay, _async_overlay_descriptors)
	_async_overlay_apply_started_usec = Time.get_ticks_usec()
	_async_overlay_apply_active = true
	UATerrainPieceLibraryScript.reset_piece_overlay_build_counters()
	_update_build_progress(total_chunks, total_chunks, "Finalizing overlays... 0%")


func _pump_async_overlay_apply() -> void:
	if not _async_overlay_apply_active:
		return
	if _async_cancel_requested:
		_async_overlay_apply_active = false
		_end_build_state(false, "3D render cancelled")
		_reset_async_build_state()
		if _async_requested_restart:
			_request_refresh(_async_requested_reframe)
		return
	var done: bool = _overlay_apply_manager.apply_overlay_node_step(_authored_overlay, _async_overlay_apply_state, _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME)
	var progress: Dictionary = _overlay_apply_manager.overlay_apply_progress(_async_overlay_apply_state)
	var progress_done := int(progress.get("done", 0))
	var progress_total := int(progress.get("total", 0))
	var pct := 100
	if progress_total > 0:
		pct = int(round((float(progress_done) / float(progress_total)) * 100.0))
	_update_build_progress(total_chunks, total_chunks, "Finalizing overlays... %d%%" % clampi(pct, 0, 100))
	_bump_3d_viewport_rendering()
	if done:
		_finalize_async_overlay_apply()


func _finalize_async_overlay_apply() -> void:
	if _authored_overlay != null and is_instance_valid(_authored_overlay):
		_overlay_apply_manager.finalize_apply_overlay_node(_authored_overlay, _async_overlay_apply_state)
	_apply_dynamic_overlay(_async_dynamic_overlay_descriptors)
	_apply_geometry_distance_culling_to_overlay()
	var metrics := _async_overlay_metrics
	var pc: Dictionary = UATerrainPieceLibraryScript.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	metrics["overlay_node_creation_ms"] = _elapsed_ms_since(_async_overlay_apply_started_usec)
	_last_build_metrics = metrics
	_initial_build_in_progress = false
	_initial_build_accumulated_authored_descriptors.clear()
	_async_overlay_apply_active = false
	_end_build_state(true, "3D map ready")
	_bump_3d_viewport_rendering()
	if _async_pending_reframe_camera and is_inside_tree():
		_framed = false
		_frame_if_needed()
	var should_restart := _async_requested_restart
	var restart_reframe := _async_requested_reframe
	_reset_async_build_state()
	if should_restart:
		_request_refresh(restart_reframe)
	elif _refresh_pending and _preview_refresh_active():
		_request_refresh(_refresh_reframe_pending)


func _cancel_async_initial_build() -> void:
	if _is_async_build_active():
		_async_state_mutex.lock()
		cancel_requested_generation_id = active_build_generation_id
		_async_cancel_requested = true
		_async_state_mutex.unlock()
	if _is_async_overlay_descriptor_active():
		_async_cancel_requested = true
	if _async_overlay_apply_active:
		_async_cancel_requested = true


func _join_async_thread() -> void:
	var thread: Thread = null
	_async_state_mutex.lock()
	thread = _async_initial_thread
	_async_initial_thread = null
	_async_state_mutex.unlock()
	if thread != null:
		thread.wait_to_finish()


func _reset_async_build_state() -> void:
	_async_state_mutex.lock()
	_async_worker_done = false
	_async_worker_failed = false
	_async_worker_error = ""
	_async_cancel_requested = false
	_async_state_mutex.unlock()
	_clear_async_chunk_payloads()
	_async_pending_reframe_camera = false
	_async_effective_typ = PackedByteArray()
	_async_blg = PackedByteArray()
	_async_w = 0
	_async_h = 0
	_async_level_set = 0
	_async_game_data_type = "original"
	_async_requested_restart = false
	_async_requested_reframe = false
	_async_overlay_apply_active = false
	_async_overlay_apply_state.clear()
	_async_overlay_descriptors.clear()
	_async_dynamic_overlay_descriptors.clear()
	_async_overlay_metrics.clear()
	_async_overlay_apply_started_usec = 0
	_set_async_overlay_descriptor_state(false, false, {}, {})
	_async_overlay_descriptor_dynamic_only = false
	_overlay_only_refresh_requested = false
	_dynamic_overlay_refresh_requested = false


func _sync_terrain_overlay_animation_mode_from_editor() -> void:
	var es := _editor_state()
	var anims_on := true
	if es != null:
		var raw: Variant = es.get("map_3d_terrain_overlay_animations_enabled")
		if typeof(raw) == TYPE_BOOL:
			anims_on = raw
	UATerrainPieceLibraryScript.set_force_static_terrain_overlays(not anims_on)


func _apply_debug_mode_to_existing_materials() -> void:
	if _terrain_mesh == null or _terrain_mesh.mesh == null:
		return
	var mesh := _terrain_mesh.mesh
	for si in mesh.get_surface_count():
		var mat := mesh.surface_get_material(si)
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("debug_mode", _debug_shader_mode)
			_frame_if_needed()

func _process(_delta: float) -> void:
	# Keep mouse mode sane if window focus changes
	if not _mouselook and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_pump_async_initial_build()
	_pump_async_overlay_descriptor_build()
	_pump_async_overlay_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _preview_refresh_active():
		_bump_3d_viewport_rendering()


func _exit_tree() -> void:
	if _is_async_pipeline_active():
		_cancel_async_initial_build()
		_join_async_thread()
		_join_async_overlay_descriptor_thread()


func _get_map_subviewport() -> SubViewport:
	var vp := get_viewport()
	if vp is SubViewport:
		return vp as SubViewport
	return null


func _bump_3d_viewport_rendering() -> void:
	if not _preview_refresh_active():
		return
	var vp := _get_map_subviewport()
	if vp == null:
		return
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE


func _physics_process(delta: float) -> void:
	# Simple spectator-style movement (WASD + QE), raw keys to avoid changing project InputMap
	if not is_visible_in_tree():
		return
	var move := Vector3.ZERO
	var cam_basis := _camera.global_transform.basis
	var forward := -cam_basis.z.normalized()
	var right := cam_basis.x.normalized()
	if Input.is_physical_key_pressed(KEY_W): move += forward
	if Input.is_physical_key_pressed(KEY_S): move -= forward
	if Input.is_physical_key_pressed(KEY_D): move += right
	if Input.is_physical_key_pressed(KEY_A): move -= right
	if Input.is_physical_key_pressed(KEY_E): move += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q): move -= Vector3.UP
	if move.length() > 0.0:
		move = move.normalized()
	var speed := _move_speed * (_sprint_mult if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	_camera.global_translate(move * speed * delta)
	_update_geometry_distance_culling_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_mouselook = mb.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _mouselook else Input.MOUSE_MODE_VISIBLE)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camera.translate_local(Vector3(0, 0, -_wheel_step()))
			_update_geometry_distance_culling_visibility()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.translate_local(Vector3(0, 0, _wheel_step()))
			_update_geometry_distance_culling_visibility()
	elif event is InputEventMouseMotion and _mouselook:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * _look_sens
		_pitch = clampf(_pitch - mm.relative.y * _look_sens, deg_to_rad(-85.0), deg_to_rad(85.0))
		_update_camera_rotation()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kev := event as InputEventKey
		if kev.keycode == KEY_F9:
			_debug_shader_mode = (_debug_shader_mode + 1) % 3
			print("[Map3D] shader debug_mode=", _debug_shader_mode, " (0=normal,1=file,2=variant)")
			_apply_debug_mode_to_existing_materials()
			_bump_3d_viewport_rendering()

func _wheel_step() -> float:
	return ViewController.wheel_step(_current_map_data(), SECTOR_SIZE)

func _update_camera_rotation() -> void:
	ViewController.apply_camera_rotation(_camera, _yaw, _pitch)

func _frame_if_needed() -> void:
	if _framed:
		return
	var frame_result := ViewController.frame_camera_to_map(_camera, _current_map_data(), SECTOR_SIZE, HEIGHT_SCALE)
	if frame_result.is_empty():
		return
	_pitch = float(frame_result.get("pitch", _pitch))
	_yaw = float(frame_result.get("yaw", _yaw))
	print("[Map3D] frame_if_needed: dist=", float(frame_result.get("dist", 0.0)),
		" near=", _camera.near, " far=", _camera.far,
		" center=", frame_result.get("center", Vector3.ZERO),
		" y_offset=", float(frame_result.get("y_offset", 0.0)),
		" min_h=", int(frame_result.get("min_h", 0)),
		" max_h=", int(frame_result.get("max_h", 0)),
		" avg_h=", float(frame_result.get("avg_h", 0.0)))
	_framed = bool(frame_result.get("framed", false))
	_update_geometry_distance_culling_visibility()

func _on_map_changed() -> void:
	_cancel_async_initial_build()
	_overlay_only_refresh_requested = false
	_dynamic_overlay_refresh_requested = false
	var _cmd = _current_map_data()
	if _cmd:
		print("[Map3D] map_changed signal: w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt_size=", _cmd.hgt_map.size())
		_request_refresh(false)

func _on_map_created() -> void:
	_cancel_async_initial_build()
	var _cmd = _current_map_data()
	if _cmd:
		print("[Map3D] map_created signal: w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt_size=", _cmd.hgt_map.size())
		_effective_typ_cache_valid = false
		_effective_typ_dirty = true
		# Seed dirty chunks for non-blocking initial terrain creation.
		# This enables the incremental chunk path immediately after map load.
		var w := int(_cmd.horizontal_sectors)
		var h := int(_cmd.vertical_sectors)
		var level_set := int(_cmd.level_set)
		_last_map_dimensions = Vector2i(w, h)
		_last_level_set = level_set
		_clear_chunk_nodes()
		_set_authored_overlay([])
		_dirty_chunks.clear()
		_terrain_authored_cache_by_key.clear()
		_terrain_authored_cache_key_ref_counts.clear()
		_terrain_chunk_authored_cache_keys.clear()
		var all_chunks := TerrainBuilder.all_chunks_for_map(w, h)
		for chunk_coord in all_chunks:
			_dirty_chunks[chunk_coord] = true
		_initial_build_in_progress = true
		_initial_build_accumulated_authored_descriptors.clear()
	_request_refresh(true)

func _on_map_updated() -> void:
	_on_map_changed()


func _on_hgt_map_cells_edited(border_indices: Array) -> void:
	_cancel_async_initial_build()
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	# hgt-only edit: `effective_typ` depends on typ/blg/entities; keep cached value if possible.
	_effective_typ_dirty = false

	var bw := w + 2
	# Convert `hgt_map` border indices to a conservative set of affected playable sectors.
	# This intentionally rebuilds a small neighborhood to cover seam/edge-dependent geometry.
	var seen_playable := {}
	for idx_value in border_indices:
		var border_idx := int(idx_value)
		if border_idx < 0 or border_idx >= (bw * (h + 2)):
			continue
		var bx := border_idx % bw
		var by: int = int(border_idx / bw)
		var sx: int = bx - 1
		var sy: int = by - 1
		for oy in [-1, 0, 1]:
			var py: int = sy + oy
			if py < 0 or py >= h:
				continue
			for ox in [-1, 0, 1]:
				var px: int = sx + ox
				if px < 0 or px >= w:
					continue
				var key := "%d:%d" % [px, py]
				if seen_playable.has(key):
					continue
				seen_playable[key] = true
				mark_sector_dirty(px, py, "hgt")


func _on_typ_map_cells_edited(typ_indices: Array) -> void:
	_cancel_async_initial_build()
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	# typ-only edit: recompute effective typ for correct surface + piece selection.
	_effective_typ_dirty = true

	var seen_playable := {}
	for idx_value in typ_indices:
		var typ_idx := int(idx_value)
		if typ_idx < 0 or typ_idx >= (w * h):
			continue
		var sx := typ_idx % w
		var sy: int = int(typ_idx / w)
		var key := "%d:%d" % [sx, sy]
		if seen_playable.has(key):
			continue
		seen_playable[key] = true
		mark_sector_dirty(sx, sy, "typ")

func build_from_current_map() -> void:
	var build_started_usec := Time.get_ticks_usec()
	var metrics := _make_empty_build_metrics()
	_sync_terrain_overlay_animation_mode_from_editor()
	var _cmd = _current_map_data()
	if _cmd == null:
		print("[Map3D] build_from_current_map: no CurrentMapData autoload, clearing mesh")
		clear()
		_finalize_build_metrics(metrics, build_started_usec)
		return
	var w: int = int(_cmd.horizontal_sectors)
	var h: int = int(_cmd.vertical_sectors)
	var hgt: PackedByteArray = _cmd.hgt_map
	var typ: PackedByteArray = _cmd.typ_map
	var blg: PackedByteArray = _cmd.blg_map
	var expected := (w + 2) * (h + 2)
	print("[Map3D] build_from_current_map: w=", w, " h=", h, " hgt_size=", hgt.size(), " expected=", expected)
	if w <= 0 or h <= 0 or hgt.size() != expected or typ.size() != w * h:
		print("[Map3D] build_from_current_map: invalid data, clearing mesh")
		metrics["invalid_input"] = true
		var clear_started_usec := Time.get_ticks_usec()
		clear()
		metrics["overlay_node_creation_ms"] = _elapsed_ms_since(clear_started_usec)
		_finalize_build_metrics(metrics, build_started_usec)
		return

	var game_data_type := _current_game_data_type()
	UATerrainPieceLibraryScript.set_piece_game_data_type(game_data_type)
	_async_blg = blg
	_async_w = w
	_async_h = h
	_async_level_set = int(_cmd.level_set)
	_async_game_data_type = game_data_type
	var effective_typ: PackedByteArray
	var typ_checksum := _checksum_packed_byte_array(typ)
	var blg_checksum := _checksum_packed_byte_array(blg)
	var can_reuse_effective_typ := _effective_typ_cache_valid and (not _effective_typ_dirty) and _effective_typ_cache_dims == Vector2i(w, h) and _effective_typ_cache_game_data_type == game_data_type and _effective_typ_cache_typ_checksum == typ_checksum and _effective_typ_cache_blg_checksum == blg_checksum

	if can_reuse_effective_typ:
		effective_typ = _effective_typ_cache
	else:
		effective_typ = _effective_typ_map_for_3d(
			typ,
			blg,
			game_data_type,
			w,
			h,
			_cmd.beam_gates,
			_cmd.tech_upgrades,
			_cmd.stoudson_bombs
		)
		_effective_typ_cache = effective_typ
		_effective_typ_cache_valid = true
		_effective_typ_cache_game_data_type = game_data_type
		_effective_typ_cache_dims = Vector2i(w, h)
		_effective_typ_cache_typ_checksum = typ_checksum
		_effective_typ_cache_blg_checksum = blg_checksum
		_effective_typ_dirty = false
	_async_effective_typ = effective_typ

	var pre = _preloads()
	if pre == null:
		var fallback_started_usec := Time.get_ticks_usec()
		var fallback_mesh := build_mesh(hgt, w, h)
		metrics["terrain_build_ms"] = _elapsed_ms_since(fallback_started_usec)
		print("[Map3D] build_from_current_map: Preloads unavailable, using untextured mesh with surfaces=", fallback_mesh.get_surface_count())
		if _terrain_mesh:
			_terrain_mesh.mesh = fallback_mesh
			_apply_untextured_materials(fallback_mesh)
		var fallback_overlay_started_usec := Time.get_ticks_usec()
		_set_authored_overlay([])
		var pc_fb: Dictionary = UATerrainPieceLibraryScript.get_piece_overlay_build_counters()
		metrics["piece_overlay_fast_path"] = int(pc_fb.get("piece_overlay_fast_path", 0))
		metrics["piece_overlay_slow_path"] = int(pc_fb.get("piece_overlay_slow_path", 0))
		metrics["overlay_node_creation_ms"] = _elapsed_ms_since(fallback_overlay_started_usec)
		if _edge_mesh:
			_edge_mesh.mesh = null
		_finalize_build_metrics(metrics, build_started_usec)
		return

	metrics["used_textured_preloads"] = true
	var level_set := int(_cmd.level_set)
	var use_chunked := _chunked_terrain_enabled and not _needs_full_rebuild(w, h, level_set) and not _DEBUG_DISABLE_CHUNKED_EXPERIMENT
	#region agent log
	_ndjson_log_once(
		"pre_fix",
		"H9_build_mode_selection",
		"Map3DRenderer.build_from_current_map",
		"Selected build mode and edge source state",
		{
			"use_chunked": use_chunked,
			"dirty_chunk_count": _dirty_chunks.size(),
			"terrain_chunk_node_count": _terrain_chunk_nodes.size(),
			"edge_chunk_node_count": _edge_chunk_nodes.size(),
			"edge_mesh_has_surface": (_edge_mesh != null and _edge_mesh.mesh != null),
			"debug_disable_chunked_experiment": _DEBUG_DISABLE_CHUNKED_EXPERIMENT
		}
	)
	#endregion

	var terrain_started_usec := Time.get_ticks_usec()
	var authored_piece_descriptors: Array = []
	var support_descriptors: Array = []
	var overlay_descriptors: Array = []

	if use_chunked and not _dirty_chunks.is_empty():
		# Incremental chunk rebuild
		_force_full_rebuild_next_update = false
		_force_full_rebuild_was_applied = false
		if _terrain_chunk_nodes.is_empty():
			# We may be transitioning from the legacy full-mesh path into chunked mode.
			# Seed all chunk nodes before clearing the shared terrain mesh, otherwise the
			# first incremental edit would redraw only the dirty chunk subset and leave
			# the rest of the map missing.
			_invalidate_all_chunks(w, h)
		# Snapshot the last known-good terrain/support descriptors before we apply
		# any incremental cache updates. If our chunk overlap bookkeeping ever
		# underflows and wipes the cache, we'd otherwise remove the entire authored
		# overlay and leave only the edge meshes (the black grid).
		var terrain_cache_snapshot_descriptors: Array = _terrain_authored_cache_by_key.values().duplicate()
		if _terrain_mesh:
			_terrain_mesh.mesh = null
		if _edge_mesh:
			_edge_mesh.mesh = null
		#region agent log
		_ndjson_log_once(
			"pre_fix",
			"H10_incremental_edge_source_clear",
			"Map3DRenderer.build_from_current_map",
			"Cleared shared edge mesh before chunked rebuild",
			{
				"edge_chunk_node_count_before_rebuild": _edge_chunk_nodes.size(),
				"dirty_chunk_count_before_rebuild": _dirty_chunks.size()
			}
		)
		#endregion
		var max_chunks := -1
		var is_initial_batch := _initial_build_in_progress
		if is_initial_batch:
			max_chunks = _initial_build_batch_size
		var batch_authored_descriptors := _rebuild_dirty_chunks(hgt, effective_typ, w, h, pre, level_set, metrics, max_chunks)
		metrics["terrain_build_ms"] = _elapsed_ms_since(terrain_started_usec)
		metrics["incremental_rebuild"] = true

		if is_initial_batch:
			_initial_build_accumulated_authored_descriptors.append_array(batch_authored_descriptors)
			metrics["terrain_authored_descriptor_count"] = _initial_build_accumulated_authored_descriptors.size()

			# Keep building chunks until the accumulator is complete, then proceed with overlay generation.
			if not _dirty_chunks.is_empty():
				_finalize_build_metrics(metrics, build_started_usec)
				_request_refresh(false)
				return

			authored_piece_descriptors = _initial_build_accumulated_authored_descriptors
			_initial_build_in_progress = false
			_initial_build_accumulated_authored_descriptors.clear()
		else:
			authored_piece_descriptors = batch_authored_descriptors
			metrics["terrain_authored_descriptor_count"] = authored_piece_descriptors.size()

		var cached_terrain_descriptors: Array = _terrain_authored_cache_by_key.values()
		if cached_terrain_descriptors.is_empty():
			if not terrain_cache_snapshot_descriptors.is_empty():
				cached_terrain_descriptors = terrain_cache_snapshot_descriptors.duplicate()
			else:
				cached_terrain_descriptors = authored_piece_descriptors.duplicate()
		else:
			# `_terrain_authored_cache_by_key` is already updated per rebuilt chunk;
			# appending `authored_piece_descriptors` here duplicates keys and inflates
			# overlay descriptors during incremental rebuilds.
			cached_terrain_descriptors = cached_terrain_descriptors.duplicate()
		support_descriptors = cached_terrain_descriptors
		overlay_descriptors = cached_terrain_descriptors.duplicate()
		metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
		#region agent log
		_ndjson_log_once(
			"pre_fix",
			"H13_overlay_key_bounds",
			"Map3DRenderer.build_from_current_map",
			"Collected overlay descriptor in-bounds vs out-of-bounds key stats",
			_overlay_key_bounds_stats(overlay_descriptors, w, h)
		)
		_ndjson_log_once(
			"pre_fix",
			"H14_incremental_terrain_slot_conflicts",
			"Map3DRenderer.build_from_current_map",
			"Collected incremental terrain slot-key conflict stats",
			_terrain_slot_conflict_stats(overlay_descriptors)
		)
		if w <= 12 and h <= 12:
			var full_cmp := TerrainBuilder.build_mesh_with_textures(
				hgt,
				effective_typ,
				w,
				h,
				pre.surface_type_map,
				pre.subsector_patterns,
				pre.tile_mapping,
				pre.tile_remap,
				pre.subsector_idx_remap,
				pre.lego_defs,
				level_set
			)
			var full_desc: Array = full_cmp.get("authored_piece_descriptors", [])
			var inc_keys := _descriptor_key_set(overlay_descriptors)
			var full_keys := _descriptor_key_set(full_desc)
			_ndjson_log_once(
				"pre_fix",
				"H15_incremental_vs_full_descriptor_diff",
				"Map3DRenderer.build_from_current_map",
				"Compared incremental overlay keys against full-build keys",
				{
					"incremental_key_count": inc_keys.size(),
					"full_key_count": full_keys.size(),
					"incremental_not_in_full_sample": _descriptor_key_diff_sample(inc_keys, full_keys, 8),
					"full_not_in_incremental_sample": _descriptor_key_diff_sample(full_keys, inc_keys, 8)
				}
			)
		#endregion
		print(
			"[Map3D] incremental rebuild stats: cached_terrain=",
			cached_terrain_descriptors.size(),
			" new_authored=",
			authored_piece_descriptors.size(),
			" overlay_start=",
			overlay_descriptors.size()
		)
		print("[Map3D] build_from_current_map: incremental chunk rebuild, chunks=", metrics.get("chunks_rebuilt", 0))
		#region agent log
		_ndjson_log_once(
			"pre_fix",
			"H11_incremental_edge_source_result",
			"Map3DRenderer.build_from_current_map",
			"Incremental rebuild edge source post-state",
			{
				"chunks_rebuilt": int(metrics.get("chunks_rebuilt", 0)),
				"edge_chunk_node_count_after_rebuild": _edge_chunk_nodes.size(),
				"shared_edge_mesh_present": (_edge_mesh != null and _edge_mesh.mesh != null),
				"overlay_descriptor_count_after_merge": overlay_descriptors.size()
			}
		)
		#endregion
	else:
		# Full rebuild (legacy path or first build)
		_clear_chunk_nodes()
		_invalidate_all_chunks(w, h)
		_last_map_dimensions = Vector2i(w, h)
		_last_level_set = level_set

		var result := build_mesh_with_textures(
			hgt,
			effective_typ,
			w,
			h,
			pre.surface_type_map,
			pre.subsector_patterns,
			pre.tile_mapping,
			pre.tile_remap,
			pre.subsector_idx_remap,
			pre.lego_defs,
			level_set
		)
		metrics["terrain_build_ms"] = _elapsed_ms_since(terrain_started_usec)
		var mesh: ArrayMesh = result["mesh"]
		var surface_to_surface_type: Dictionary = result["surface_to_surface_type"]
		authored_piece_descriptors = result.get("authored_piece_descriptors", [])
		metrics["terrain_authored_descriptor_count"] = authored_piece_descriptors.size()
		metrics["incremental_rebuild"] = false
		support_descriptors = authored_piece_descriptors.duplicate()
		overlay_descriptors = authored_piece_descriptors.duplicate()
		print("[Map3D] build_from_current_map: full rebuild, textured mesh surfaces=", mesh.get_surface_count())
		if w == 6 and h == 6:
			var terrain_cnt: int = 0
			var slurp_cnt: int = 0
			var terrain_examples: Array[String] = []
			var slurp_examples: Array[String] = []
			for d_any in overlay_descriptors:
				if typeof(d_any) != TYPE_DICTIONARY:
					continue
				var d := d_any as Dictionary
				var ik := String(d.get("instance_key", ""))
				var bn := String(d.get("base_name", ""))
				if ik.begins_with("terrain:"):
					terrain_cnt += 1
					if terrain_examples.size() < 3 and not bn.is_empty():
						terrain_examples.append(bn)
				elif ik.begins_with("slurp:"):
					slurp_cnt += 1
					if slurp_examples.size() < 3 and not bn.is_empty():
						slurp_examples.append(bn)
			print("[Map3D] full rebuild overlay kinds: terrain=", terrain_cnt, " slurp=", slurp_cnt, " terrain_ex=", terrain_examples, " slurp_ex=", slurp_examples)
		print(
			"[Map3D] full rebuild stats: authored_terrain=",
			authored_piece_descriptors.size(),
			" support=",
			support_descriptors.size(),
			" overlay_start=",
			overlay_descriptors.size()
		)
		if _terrain_mesh:
			_terrain_mesh.mesh = mesh
			print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")
			_apply_sector_top_materials(mesh, pre, surface_to_surface_type)

		# Edge overlay uses ordered neighboring SurfaceType-pair seam strips for the live preview.
		var edge_started_usec := Time.get_ticks_usec()
		if _edge_overlay_enabled and effective_typ.size() == w * h:
			var edge_result := _build_edge_overlay_result(hgt, w, h, effective_typ, pre.surface_type_map, level_set, pre)
			var edge_authored_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
			metrics["edge_authored_descriptor_count"] = edge_authored_descriptors.size()
			support_descriptors.append_array(edge_authored_descriptors)
			overlay_descriptors.append_array(edge_authored_descriptors)
			_ensure_edge_node()
			_edge_mesh.mesh = edge_result.get("mesh", null)
			#region agent log
			var edge_mesh_variant_full: Variant = edge_result.get("mesh", null)
			var edge_mesh_surfaces_full := -1
			if edge_mesh_variant_full != null:
				edge_mesh_surfaces_full = edge_mesh_variant_full.get_surface_count()
			_ndjson_log_once(
				"pre_fix",
				"H12_full_edge_source_result",
				"Map3DRenderer.build_from_current_map",
				"Full rebuild edge source post-state",
				{
					"edge_mesh_surface_count": edge_mesh_surfaces_full,
					"edge_chunk_node_count_after_clear": _edge_chunk_nodes.size(),
					"edge_authored_descriptor_count": edge_authored_descriptors.size()
				}
			)
			#endregion
		else:
			if _edge_mesh:
				_edge_mesh.mesh = null
		metrics["edge_slurp_build_ms"] = _elapsed_ms_since(edge_started_usec)
		_dirty_chunks.clear()
		# Ensure authored-terrain cache matches the current full rebuild.
		_reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)
		if not _force_full_rebuild_was_applied:
			_force_full_rebuild_next_update = true
		_force_full_rebuild_was_applied = false
	var overlay_descriptor_started_usec := Time.get_ticks_usec()
	overlay_descriptors.append_array(_build_blg_attachment_descriptors(blg, effective_typ, int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type))
	if _cmd.host_stations != null and is_instance_valid(_cmd.host_stations):
		overlay_descriptors.append_array(_build_host_station_descriptors(_cmd.host_stations.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors, metrics))
	if _cmd.squads != null and is_instance_valid(_cmd.squads):
		overlay_descriptors.append_array(_build_squad_descriptors(_cmd.squads.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type, metrics))
	metrics["overlay_descriptor_generation_ms"] = _elapsed_ms_since(overlay_descriptor_started_usec)
	metrics["overlay_descriptor_count"] = overlay_descriptors.size()
	var overlay_node_started_usec := Time.get_ticks_usec()
	_set_authored_overlay(overlay_descriptors)
	var pc: Dictionary = UATerrainPieceLibraryScript.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	metrics["overlay_node_creation_ms"] = _elapsed_ms_since(overlay_node_started_usec)
	_finalize_build_metrics(metrics, build_started_usec)

func _current_game_data_type() -> String:
	var editor_state := _editor_state()
	var game_data_type := "original"
	if editor_state != null:
		var editor_game_data_type = editor_state.get("game_data_type")
		if editor_game_data_type != null:
			game_data_type = String(editor_game_data_type)
	if game_data_type.is_empty():
		return "original"
	return game_data_type

func clear() -> void:
	if _terrain_mesh:
		_terrain_mesh.mesh = null
	if _edge_mesh:
		_edge_mesh.mesh = null
	_clear_chunk_nodes()
	_set_authored_overlay([])


func _clear_chunk_nodes() -> void:
	for chunk_key in _terrain_chunk_nodes.keys():
		var node: Node = _terrain_chunk_nodes[chunk_key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_terrain_chunk_nodes.clear()
	for chunk_key in _edge_chunk_nodes.keys():
		var node: Node = _edge_chunk_nodes[chunk_key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_edge_chunk_nodes.clear()
	_dirty_chunks.clear()


func _invalidate_all_chunks(w: int, h: int) -> void:
	_dirty_chunks.clear()
	var all_chunks := TerrainBuilder.all_chunks_for_map(w, h)
	for chunk_coord in all_chunks:
		_dirty_chunks[chunk_coord] = true


func _invalidate_chunks_for_sector_edit(sx: int, sy: int, w: int, h: int, edit_type: String) -> void:
	var affected: Array[Vector2i]
	if edit_type == "hgt" or edit_type == "typ":
		affected = TerrainBuilder.chunks_for_hgt_edit(sx, sy, w, h)
	else:
		affected = TerrainBuilder.chunks_for_blg_edit(sx, sy, w, h)
	for chunk_coord in affected:
		_dirty_chunks[chunk_coord] = true


func mark_sector_dirty(sx: int, sy: int, edit_type: String = "hgt") -> void:
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_invalidate_chunks_for_sector_edit(sx, sy, w, h, edit_type)


func mark_sectors_dirty(sectors: Array, edit_type: String = "hgt") -> void:
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	for sector in sectors:
		if sector is Vector2i:
			_invalidate_chunks_for_sector_edit(sector.x, sector.y, w, h, edit_type)
		elif sector is Vector2:
			_invalidate_chunks_for_sector_edit(int(sector.x), int(sector.y), w, h, edit_type)


func get_dirty_chunk_count() -> int:
	return _dirty_chunks.size()


func is_using_chunked_terrain() -> bool:
	return _chunked_terrain_enabled


func set_chunked_terrain_enabled(enabled: bool) -> void:
	_chunked_terrain_enabled = enabled


func _needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	if _force_full_rebuild_next_update:
		_force_full_rebuild_next_update = false
		_force_full_rebuild_was_applied = true
		return true
	var dims := Vector2i(w, h)
	if dims != _last_map_dimensions:
		return true
	if level_set != _last_level_set:
		return true
	if _terrain_chunk_nodes.is_empty() and _dirty_chunks.is_empty():
		return true
	return false


func _get_or_create_terrain_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	if _terrain_chunk_nodes.has(chunk_coord):
		var existing = _terrain_chunk_nodes[chunk_coord]
		if existing != null and is_instance_valid(existing):
			return existing as MeshInstance3D
	var node := MeshInstance3D.new()
	node.name = "TerrainChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	if _terrain_mesh:
		_terrain_mesh.add_child(node)
	_terrain_chunk_nodes[chunk_coord] = node
	_apply_geometry_distance_culling_to_chunk_node(node, chunk_coord)
	return node


func _get_or_create_edge_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	if _edge_chunk_nodes.has(chunk_coord):
		var existing = _edge_chunk_nodes[chunk_coord]
		if existing != null and is_instance_valid(existing):
			return existing as MeshInstance3D
	var node := MeshInstance3D.new()
	node.name = "EdgeChunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	_ensure_edge_node()
	if _edge_mesh:
		_edge_mesh.add_child(node)
	_edge_chunk_nodes[chunk_coord] = node
	_apply_geometry_distance_culling_to_chunk_node(node, chunk_coord)
	return node


func _update_terrain_authored_cache_for_chunk(chunk_coord: Vector2i, chunk_descriptors: Array) -> void:
	# Remove previously cached authored pieces for this chunk.
	if _terrain_chunk_authored_cache_keys.has(chunk_coord):
		for key in _terrain_chunk_authored_cache_keys[chunk_coord]:
			var k := String(key)
			if _terrain_authored_cache_key_ref_counts.has(k):
				var new_ref_count := int(_terrain_authored_cache_key_ref_counts[k]) - 1
				if new_ref_count <= 0:
					_terrain_authored_cache_key_ref_counts.erase(k)
					_terrain_authored_cache_by_key.erase(k)
				else:
					_terrain_authored_cache_key_ref_counts[k] = new_ref_count
		_terrain_chunk_authored_cache_keys.erase(chunk_coord)

	var new_keys: Array = []
	var seen_in_chunk := {}
	for desc in chunk_descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.is_empty():
			continue
		if seen_in_chunk.has(key):
			continue
		seen_in_chunk[key] = true
		_terrain_authored_cache_by_key[key] = d
		_terrain_authored_cache_key_ref_counts[key] = int(_terrain_authored_cache_key_ref_counts.get(key, 0)) + 1
		new_keys.append(key)

	_terrain_chunk_authored_cache_keys[chunk_coord] = new_keys


func _reset_terrain_authored_cache_from_descriptors(support_descriptors: Array, w: int, h: int) -> void:
	_terrain_authored_cache_by_key.clear()
	_terrain_chunk_authored_cache_keys.clear()
	_terrain_authored_cache_key_ref_counts.clear()
	if w <= 0 or h <= 0:
		return

	var chunk_count := TerrainBuilder.chunk_count_for_map(w, h)

	for desc in support_descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.is_empty():
			continue

		# Cache lookups for chunk invalidation rely on being able to associate a descriptor
		# with all chunks that could have generated it when building chunk meshes with
		# `include_border=true` (so border/seam geometry is produced redundantly).
		var cell_x := 0
		var cell_y := 0
		var cache_mode: String = "terrain"
		if key.begins_with("terrain:"):
			var parts := key.split(":")
			# terrain:<set_id>:<x>:<y>:...
			if parts.size() >= 4:
				cell_x = int(parts[2])
				cell_y = int(parts[3])
		elif key.begins_with("slurp:v:"):
			cache_mode = "slurp_v"
			var parts := key.split(":")
			# slurp:v:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])
		elif key.begins_with("slurp:h:"):
			cache_mode = "slurp_h"
			var parts := key.split(":")
			# slurp:h:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])
		elif key.begins_with("slurp:"):
			# Fallback for unknown slurp variants; keep old behavior.
			cache_mode = "slurp_unknown"
			var parts := key.split(":")
			# slurp:<family>:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])

		_terrain_authored_cache_by_key[key] = d

		# Determine conservatively which chunk coords are eligible to include this raw
		# cell coordinate based on border-expanded chunk ranges.
		var candidate_chunks: Array[Vector2i] = []
		var cx_center := int(cell_x) >> TerrainBuilder.CHUNK_SHIFT
		var cy_center := int(cell_y) >> TerrainBuilder.CHUNK_SHIFT
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cx := cx_center + dx
				var cy := cy_center + dy
				if cx < 0 or cy < 0 or cx >= chunk_count.x or cy >= chunk_count.y:
					continue

				var main_sx_min := cx * TerrainBuilder.CHUNK_SIZE
				var main_sy_min := cy * TerrainBuilder.CHUNK_SIZE
				var main_sx_max := mini(main_sx_min + TerrainBuilder.CHUNK_SIZE, w)
				var main_sy_max := mini(main_sy_min + TerrainBuilder.CHUNK_SIZE, h)

				# Match the loop extents used by the generators for the given instance key type.
				# This ensures refcounts for shared seam descriptors don't underflow when
				# only a neighboring chunk is rebuilt.
				var exp_sx_min := maxi(main_sx_min - 1, -1)
				var exp_sy_min := maxi(main_sy_min - 1, -1)
				var exp_sx_max: int
				var exp_sy_max: int
				if cache_mode == "terrain" or cache_mode == "slurp_unknown":
					# Map3DTerrainBuilder.build_chunk_mesh_with_textures(..., include_border=true)
					# loop extents for x/y indices.
					exp_sx_max = mini(main_sx_max + 1, w + 1) # exclusive
					exp_sy_max = mini(main_sy_max + 1, h + 1) # exclusive
				elif cache_mode == "slurp_v":
					# Map3DSlurpBuilder.build_chunk_edge_overlay_result vertical loop:
					#   x == -1 only for the first chunk, otherwise sx_min <= x < sx_max
					#   y == -1 only for the top chunk, y == h only for the bottom chunk,
					#   otherwise sy_min <= y < sy_max
					exp_sx_min = (-1 if main_sx_min == 0 else main_sx_min)
					exp_sy_min = (-1 if main_sy_min == 0 else main_sy_min)
					exp_sx_max = main_sx_max # exclusive
					exp_sy_max = (h + 1 if main_sy_max == h else main_sy_max) # exclusive
				elif cache_mode == "slurp_h":
					# Map3DSlurpBuilder.build_chunk_edge_overlay_result horizontal loop:
					#   x == -1 only for the left chunk, x == w only for the right chunk,
					#   otherwise sx_min <= x < sx_max
					#   y == -1 only for the top chunk, otherwise sy_min <= y < sy_max
					exp_sx_min = (-1 if main_sx_min == 0 else main_sx_min)
					exp_sy_min = (-1 if main_sy_min == 0 else main_sy_min)
					exp_sx_max = (w + 1 if main_sx_max == w else main_sx_max) # exclusive
					exp_sy_max = main_sy_max # exclusive
				else:
					# Defensive fallback.
					exp_sx_max = mini(main_sx_max + 1, w + 1) # exclusive
					exp_sy_max = mini(main_sy_max + 1, h + 1) # exclusive

				if cell_x >= exp_sx_min and cell_x < exp_sx_max and cell_y >= exp_sy_min and cell_y < exp_sy_max:
					candidate_chunks.append(Vector2i(cx, cy))

		# Fallback: if no candidates matched, associate with clamped cell coordinates.
		if candidate_chunks.is_empty():
			var playable_x := clampi(cell_x, 0, w - 1)
			var playable_y := clampi(cell_y, 0, h - 1)
			candidate_chunks.append(TerrainBuilder.sector_to_chunk(playable_x, playable_y))

		# Deduplicate candidates.
		var seen_chunks: Dictionary = {}
		var unique_chunks: Array[Vector2i] = []
		for cc in candidate_chunks:
			var kk := "%d:%d" % [cc.x, cc.y]
			if seen_chunks.has(kk):
				continue
			seen_chunks[kk] = true
			unique_chunks.append(cc)

		_terrain_authored_cache_key_ref_counts[key] = unique_chunks.size()
		for chunk_coord in unique_chunks:
			var chunk_keys: Array = _terrain_chunk_authored_cache_keys.get(chunk_coord, [])
			if not chunk_keys.has(key):
				chunk_keys.append(key)
			_terrain_chunk_authored_cache_keys[chunk_coord] = chunk_keys


func _rebuild_dirty_chunks(
	hgt: PackedByteArray,
	effective_typ: PackedByteArray,
	w: int,
	h: int,
	pre: Node,
	level_set: int,
	metrics: Dictionary,
	max_chunks: int = -1
) -> Array:
	var all_authored_descriptors: Array = []
	var chunks_rebuilt := 0
	var processed: Array[Vector2i] = []
	var dirty_chunk_list := _dirty_chunks_sorted_by_priority(w, h)

	for chunk_coord in dirty_chunk_list:
		if max_chunks > 0 and chunks_rebuilt >= max_chunks:
			break
		var terrain_result := TerrainBuilder.build_chunk_mesh_with_textures(
			chunk_coord,
			hgt,
			effective_typ,
			w,
			h,
			pre.surface_type_map,
			pre.subsector_patterns,
			pre.tile_mapping,
			pre.tile_remap,
			pre.subsector_idx_remap,
			pre.lego_defs,
			level_set,
			true
		)
		if w == 6 and h == 6:
			var terrain_surfaces: int = -1
			var terrain_mesh_variant: Variant = terrain_result.get("mesh", null)
			if terrain_mesh_variant != null:
				terrain_surfaces = terrain_mesh_variant.get_surface_count()
			var terrain_authored_cnt: int = terrain_result.get("authored_piece_descriptors", []).size()
			if terrain_surfaces == 0 or terrain_authored_cnt > 0:
				print(
					"[Map3D] rebuild chunk=",
					chunk_coord,
					" terrain_surfaces=",
					terrain_surfaces,
					" terrain_authored=",
					terrain_authored_cnt
				)
		var chunk_node := _get_or_create_terrain_chunk_node(chunk_coord)
		chunk_node.mesh = terrain_result["mesh"]
		_apply_sector_top_materials(terrain_result["mesh"], pre, terrain_result["surface_to_surface_type"])

		var terrain_descriptors: Array = terrain_result.get("authored_piece_descriptors", [])
		var chunk_authored_descriptors: Array = terrain_descriptors.duplicate()

		if _edge_overlay_enabled:
			var edge_result := SlurpBuilder.build_chunk_edge_overlay_result(
				chunk_coord,
				hgt,
				w,
				h,
				effective_typ,
				pre.surface_type_map,
				level_set
			)
			if w == 6 and h == 6:
				var edge_surfaces: int = -1
				var edge_mesh_variant: Variant = edge_result.get("mesh", null)
				if edge_mesh_variant != null:
					edge_surfaces = edge_mesh_variant.get_surface_count()
				var edge_authored_cnt: int = edge_result.get("authored_piece_descriptors", []).size()
				if edge_surfaces == 0 or edge_authored_cnt > 0:
					print(
						"[Map3D] rebuild chunk=",
						chunk_coord,
						" edge_surfaces=",
						edge_surfaces,
						" edge_authored=",
						edge_authored_cnt
					)
			var edge_chunk_node := _get_or_create_edge_chunk_node(chunk_coord)
			edge_chunk_node.mesh = edge_result.get("mesh", null)
			_apply_edge_surface_materials(
				edge_chunk_node.mesh,
				pre,
				edge_result.get("fallback_horiz_keys", []),
				edge_result.get("fallback_vert_keys", [])
			)

			var edge_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
			chunk_authored_descriptors.append_array(edge_descriptors)

		all_authored_descriptors.append_array(chunk_authored_descriptors)
		_update_terrain_authored_cache_for_chunk(chunk_coord, chunk_authored_descriptors)

		chunks_rebuilt += 1
		processed.append(chunk_coord)

	for chunk_coord in processed:
		_dirty_chunks.erase(chunk_coord)
	metrics["chunks_rebuilt"] = chunks_rebuilt
	return all_authored_descriptors


static func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy


func _dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	var ordered: Array[Vector2i] = []
	for key in _dirty_chunks.keys():
		if key is Vector2i:
			ordered.append(key)
	if ordered.size() <= 1:
		return ordered
	var focus_chunk := _chunk_focus_coord(w, h)
	ordered.sort_custom(func(a, b) -> bool:
		return _chunk_distance_sq(Vector2i(a), focus_chunk) < _chunk_distance_sq(Vector2i(b), focus_chunk)
	)
	return ordered


func _chunk_focus_coord(w: int, h: int) -> Vector2i:
	if _camera != null and is_instance_valid(_camera):
		var world_pos := _camera.global_position if _camera.is_inside_tree() else _camera.position
		var sx := clampi(_world_to_sector_index(world_pos.x), 0, maxi(w - 1, 0))
		var sy := clampi(_world_to_sector_index(world_pos.z), 0, maxi(h - 1, 0))
		return TerrainBuilder.sector_to_chunk(sx, sy)
	var center_sx := maxi(w / 2, 0)
	var center_sy := maxi(h / 2, 0)
	return TerrainBuilder.sector_to_chunk(center_sx, center_sy)

func _set_authored_overlay(descriptors: Array) -> void:
	_ensure_overlay_nodes()
	var static_descriptors: Array = []
	var dynamic_descriptors: Array = []
	for desc_any in descriptors:
		if typeof(desc_any) != TYPE_DICTIONARY:
			continue
		var desc := desc_any as Dictionary
		var instance_key := String(desc.get("instance_key", ""))
		if instance_key.begins_with("host:") or instance_key.begins_with("host_gun:") or instance_key.begins_with("squad:"):
			dynamic_descriptors.append(desc)
		else:
			static_descriptors.append(desc)
	UATerrainPieceLibraryScript.reset_piece_overlay_build_counters()
	AuthoredOverlayManager.apply_overlay_node(_authored_overlay, static_descriptors)
	AuthoredOverlayManager.apply_overlay_node(_dynamic_overlay, dynamic_descriptors)
	_apply_geometry_distance_culling_to_overlay()


func _apply_geometry_distance_culling_state(enabled: bool) -> void:
	_geometry_distance_culling_enabled = enabled
	_geometry_cull_distance = UA_NORMAL_GEOMETRY_CULL_DISTANCE
	if not enabled:
		_set_all_distance_culled_nodes_visible(true)
		return
	_update_geometry_distance_culling_visibility()


func _set_all_distance_culled_nodes_visible(make_visible: bool) -> void:
	for chunk_coord in _terrain_chunk_nodes.keys():
		var terrain_chunk := _terrain_chunk_nodes[chunk_coord] as MeshInstance3D
		if terrain_chunk != null and is_instance_valid(terrain_chunk):
			terrain_chunk.visible = make_visible and terrain_chunk.mesh != null
	for chunk_coord in _edge_chunk_nodes.keys():
		var edge_chunk := _edge_chunk_nodes[chunk_coord] as MeshInstance3D
		if edge_chunk != null and is_instance_valid(edge_chunk):
			edge_chunk.visible = make_visible and edge_chunk.mesh != null
	if _authored_overlay != null and is_instance_valid(_authored_overlay):
		for child in _authored_overlay.get_children():
			if child is Node3D:
				(child as Node3D).visible = make_visible
	if _dynamic_overlay != null and is_instance_valid(_dynamic_overlay):
		for child in _dynamic_overlay.get_children():
			if child is Node3D:
				(child as Node3D).visible = make_visible


func _update_geometry_distance_culling_visibility() -> void:
	if not _geometry_distance_culling_enabled:
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	var cam_pos := _camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var cull_sq := _geometry_cull_distance * _geometry_cull_distance

	for chunk_coord_any in _terrain_chunk_nodes.keys():
		var chunk_coord := Vector2i(chunk_coord_any)
		var terrain_chunk := _terrain_chunk_nodes[chunk_coord] as MeshInstance3D
		if terrain_chunk == null or not is_instance_valid(terrain_chunk):
			continue
		var center := _chunk_center_world_xz(chunk_coord)
		var within_range := cam_xz.distance_squared_to(center) <= cull_sq
		terrain_chunk.visible = within_range and terrain_chunk.mesh != null

	for chunk_coord_any in _edge_chunk_nodes.keys():
		var chunk_coord := Vector2i(chunk_coord_any)
		var edge_chunk := _edge_chunk_nodes[chunk_coord] as MeshInstance3D
		if edge_chunk == null or not is_instance_valid(edge_chunk):
			continue
		var center := _chunk_center_world_xz(chunk_coord)
		var within_range := cam_xz.distance_squared_to(center) <= cull_sq
		edge_chunk.visible = within_range and edge_chunk.mesh != null

	_apply_geometry_distance_culling_to_overlay()


func _apply_geometry_distance_culling_to_chunk_node(chunk_node: MeshInstance3D, chunk_coord: Vector2i) -> void:
	if chunk_node == null or not is_instance_valid(chunk_node):
		return
	if not _geometry_distance_culling_enabled:
		chunk_node.visible = chunk_node.mesh != null
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	var center := _chunk_center_world_xz(chunk_coord)
	var cam_pos := _camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	chunk_node.visible = cam_xz.distance_squared_to(center) <= (_geometry_cull_distance * _geometry_cull_distance) and chunk_node.mesh != null


func _apply_geometry_distance_culling_to_overlay() -> void:
	if not _geometry_distance_culling_enabled:
		if _authored_overlay != null and is_instance_valid(_authored_overlay):
			for child in _authored_overlay.get_children():
				if child is Node3D:
					(child as Node3D).visible = true
		if _dynamic_overlay != null and is_instance_valid(_dynamic_overlay):
			for child in _dynamic_overlay.get_children():
				if child is Node3D:
					(child as Node3D).visible = true
		return
	if _camera == null or not is_instance_valid(_camera):
		return
	var cam_pos := _camera.global_position
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var cull_sq := _geometry_cull_distance * _geometry_cull_distance
	if _authored_overlay != null and is_instance_valid(_authored_overlay):
		for child in _authored_overlay.get_children():
			if not (child is Node3D):
				continue
			var node := child as Node3D
			var p := node.global_position
			var within_range := cam_xz.distance_squared_to(Vector2(p.x, p.z)) <= cull_sq
			node.visible = within_range
	if _dynamic_overlay != null and is_instance_valid(_dynamic_overlay):
		for child in _dynamic_overlay.get_children():
			if not (child is Node3D):
				continue
			var node := child as Node3D
			var p := node.global_position
			var within_range := cam_xz.distance_squared_to(Vector2(p.x, p.z)) <= cull_sq
			node.visible = within_range


func _chunk_center_world_xz(chunk_coord: Vector2i) -> Vector2:
	var w := maxi(_last_map_dimensions.x, 0)
	var h := maxi(_last_map_dimensions.y, 0)
	if w <= 0 or h <= 0:
		return Vector2.ZERO
	var sx_min := chunk_coord.x * TerrainBuilder.CHUNK_SIZE
	var sy_min := chunk_coord.y * TerrainBuilder.CHUNK_SIZE
	var sx_max := mini(sx_min + TerrainBuilder.CHUNK_SIZE, w)
	var sy_max := mini(sy_min + TerrainBuilder.CHUNK_SIZE, h)
	var center_sector_x := (float(sx_min + sx_max) * 0.5) + 1.0
	var center_sector_y := (float(sy_min + sy_max) * 0.5) + 1.0
	return Vector2(center_sector_x * SECTOR_SIZE, center_sector_y * SECTOR_SIZE)

static func _make_preview_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _apply_untextured_materials(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	for surface_idx in mesh.get_surface_count():
		mesh.surface_set_material(surface_idx, _make_preview_material(TERRAIN_PREVIEW_COLOR))

# Static, pure builder (useful for tests)
# Retail constants confirmed from UA.EXE (`1200.0` sector size / `600.0` center offset).
# The strongest current retail evidence shows one raw height per playable cell, with
# flat cell-top placement and separate filler/slurp geometry bridging neighboring cells.
static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var bw := w + 2
	if hgt.size() != bw * (h + 2) or w <= 0 or h <= 0:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var sector_y := _sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			_draw_flat_sector_geometry(st, x0, x1, z0, z1, sector_y)

	# Index and generate normals
	st.index()
	st.generate_normals()
	var mesh2: ArrayMesh = st.commit()
	return mesh2

static func _sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	var bh := h + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, bh - 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE

static func _implicit_border_typ_value(w: int, h: int, sx: int, sy: int) -> int:
	var at_left := sx < 0
	var at_right := sx >= w
	var at_top := sy < 0
	var at_bottom := sy >= h
	if at_top:
		if at_left:
			return BORDER_TYP_TOP_LEFT
		if at_right:
			return BORDER_TYP_TOP_RIGHT
		return BORDER_TYP_TOP
	if at_bottom:
		if at_left:
			return BORDER_TYP_BOTTOM_LEFT
		if at_right:
			return BORDER_TYP_BOTTOM_RIGHT
		return BORDER_TYP_BOTTOM
	if at_left:
		return BORDER_TYP_LEFT
	if at_right:
		return BORDER_TYP_RIGHT
	return -1

static func _typ_value_with_implicit_border(typ: PackedByteArray, w: int, h: int, sx: int, sy: int) -> int:
	if sx >= 0 and sx < w and sy >= 0 and sy < h:
		return int(typ[sy * w + sx])
	return _implicit_border_typ_value(w, h, sx, sy)

static func _corner_average_h(hgt: PackedByteArray, w: int, h: int, corner_x: int, corner_y: int) -> float:
	var h_nw := _sample_hgt_height(hgt, w, h, corner_x - 1, corner_y - 1)
	var h_ne := _sample_hgt_height(hgt, w, h, corner_x, corner_y - 1)
	var h_sw := _sample_hgt_height(hgt, w, h, corner_x - 1, corner_y)
	var h_se := _sample_hgt_height(hgt, w, h, corner_x, corner_y)
	return (h_nw + h_ne + h_sw + h_se) * 0.25

static func _draw_flat_sector_geometry(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var nw := Vector3(x0, y, z0)
	var ne := Vector3(x1, y, z0)
	var se := Vector3(x1, y, z1)
	var sw := Vector3(x0, y, z1)
	st.add_vertex(nw); st.add_vertex(ne); st.add_vertex(se)
	st.add_vertex(nw); st.add_vertex(se); st.add_vertex(sw)

static func _preview_surface_type_for_typ(mapping: Dictionary, typ_value: int) -> int:
	if not mapping.has(typ_value):
		return -1
	return clampi(int(mapping.get(typ_value, 0)), 0, 5)

static func _retail_slurp_bucket_key(surface_a: int, surface_b: int, neighbor_dx: int, neighbor_dy: int) -> String:
	# Retail draw-list helpers (`sub_4D8498` / `sub_4D85B8`) select slurp tables by the
	# ordered neighboring SurfaceType pair and by seam orientation.
	# - left/right neighboring sectors -> `vside`
	# - top/bottom neighboring sectors -> `hside`
	if neighbor_dx != 0 and neighbor_dy == 0:
		return "vside_%d_%d" % [surface_a, surface_b]
	if neighbor_dy != 0 and neighbor_dx == 0:
		return "hside_%d_%d" % [surface_a, surface_b]
	return ""

static func _surface_pair_from_slurp_bucket_key(bucket_key: String) -> Dictionary:
	var parts := bucket_key.split("_")
	if parts.size() != 3:
		return {}
	if parts[0] != "vside" and parts[0] != "hside":
		return {}
	return {
		"family": parts[0],
		"surface_a": clampi(int(parts[1]), 0, 5),
		"surface_b": clampi(int(parts[2]), 0, 5),
	}

static func _authored_slurp_base_name(surface_a: int, surface_b: int, vertical: bool) -> String:
	return "S%d%d%s" % [clampi(surface_a, 0, 5), clampi(surface_b, 0, 5), ("V" if vertical else "H")]

static func _sector_center_origin(sx: int, sy: int, sector_y: float) -> Vector3:
	# UA-space sector center origin. Used by edge/slurp overlay descriptor tests.
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE, sector_y, (float(sy) + 1.5) * SECTOR_SIZE)

static func _sector_center_origin_scaled(sx: int, sy: int, sector_y: float) -> Vector3:
	# Scaled-world sector center origin. Used by host-station / BLG placement tests.
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE * WORLD_SCALE, sector_y * WORLD_SCALE, (float(sy) + 1.5) * SECTOR_SIZE * WORLD_SCALE)

static func _host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return String(HOST_STATION_BASE_NAMES.get(vehicle_id, ""))

static func _host_station_gun_base_name_for_type(gun_type: int) -> String:
	return String(HOST_STATION_VISIBLE_GUN_BASE_NAMES.get(gun_type, ""))

static func _vector3_from_variant(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return Vector3(value)
	if typeof(value) != TYPE_DICTIONARY:
		return Vector3.ZERO
	var dict := Dictionary(value)
	return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))

static func _host_station_godot_offset_from_ua(ua_offset: Vector3) -> Vector3:
	return Vector3(ua_offset.x, -ua_offset.y, -ua_offset.z)

static func _host_station_godot_direction_from_ua(ua_direction: Vector3) -> Vector3:
	var godot_direction := Vector3(ua_direction.x, -ua_direction.y, -ua_direction.z)
	var horizontal_direction := Vector3(godot_direction.x, 0.0, godot_direction.z)
	if horizontal_direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return horizontal_direction.normalized()

static func _world_to_sector_index(world_coord: float) -> int:
	return int(floor(world_coord / SECTOR_SIZE)) - 1

static func _ground_height_at_world_position(hgt: PackedByteArray, w: int, h: int, world_x: float, world_z: float) -> float:
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2):
		return 0.0
	return _sample_hgt_height(hgt, w, h, _world_to_sector_index(world_x), _world_to_sector_index(world_z))

static func _support_height_at_world_position(hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, world_x: float, world_z: float, profile = null) -> float:
	var started_usec := Time.get_ticks_usec()
	var terrain_height := _ground_height_at_world_position(hgt, w, h, world_x, world_z)
	var authored_support: Variant = null
	if support_descriptors.size() > 0:
		authored_support = UATerrainPieceLibraryScript.support_height_at_world_position(support_descriptors, world_x, world_z)
	_profile_increment(profile, "support_height_query_count")
	_profile_add_duration(profile, "support_height_query_ms", _elapsed_ms_since(started_usec))
	if authored_support != null:
		return max(float(authored_support), terrain_height)
	return terrain_height

static func _host_station_origin(host_station: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	var pos_y_value = host_station.get("pos_y")
	var ua_x := float(host_station.position.x)
	var world_z := absf(float(host_station.position.y))
	var ua_y := float(pos_y_value if pos_y_value != null else 0.0)
	var world_x := ua_x
	var support_y := _support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile)
	return Vector3(world_x, support_y - ua_y, world_z)

static func _snapshot_host_station_nodes(host_stations: Array) -> Array:
	var snapshot: Array = []
	for host_station in host_stations:
		if host_station == null or not is_instance_valid(host_station):
			continue
		if not (host_station is Node2D):
			continue
		var vehicle_value = host_station.get("vehicle")
		if vehicle_value == null:
			continue
		var station := host_station as Node2D
		var pos_y_value = host_station.get("pos_y")
		snapshot.append({
			"id": int(host_station.get_instance_id()),
			"vehicle": int(vehicle_value),
			"x": float(station.position.x),
			"y": float(station.position.y),
			"pos_y": float(pos_y_value if pos_y_value != null else 0.0),
		})
	return snapshot


static func _build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	var descriptors: Array = []
	for host_station in host_stations:
		if typeof(host_station) != TYPE_DICTIONARY:
			continue
		var hs := host_station as Dictionary
		var vehicle := int(hs.get("vehicle", -1))
		if vehicle < 0:
			continue
		var base_name := _host_station_base_name_for_vehicle(vehicle)
		if base_name.is_empty():
			continue
		if not UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
			continue
		var world_x := float(hs.get("x", 0.0))
		var world_z := absf(float(hs.get("y", 0.0)))
		var ua_y := float(hs.get("pos_y", 0.0))
		var support_y := _support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile)
		var origin := Vector3(world_x, support_y - ua_y, world_z)
		var station_key_id := int(hs.get("id", 0))
		descriptors.append({
			"set_id": set_id,
			"raw_id": - 1,
			"base_name": base_name,
			"instance_key": "host:%d:%d:%s" % [set_id, station_key_id, base_name],
			"origin": origin,
		})
		var gun_attachments_value = HOST_STATION_GUN_ATTACHMENTS.get(vehicle, [])
		if gun_attachments_value is Array:
			for attachment in gun_attachments_value:
				if typeof(attachment) != TYPE_DICTIONARY:
					continue
				var gun_type := int(attachment.get("gun_type", -1))
				var gun_base_name := _host_station_gun_base_name_for_type(gun_type)
				if gun_base_name.is_empty():
					continue
				if not UATerrainPieceLibraryScript.has_piece_source(set_id, gun_base_name):
					continue
				var ua_offset := _vector3_from_variant(attachment.get("ua_offset", Vector3.ZERO))
				var gun_descriptor := {
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": gun_base_name,
					"instance_key": "host_gun:%d:%d:%d:%s" % [set_id, station_key_id, gun_type, gun_base_name],
					"origin": origin + _host_station_godot_offset_from_ua(ua_offset),
				}
				var ua_direction := _vector3_from_variant(attachment.get("ua_direction", Vector3.ZERO))
				var godot_direction := _host_station_godot_direction_from_ua(ua_direction)
				if godot_direction.length_squared() > 0.000001:
					gun_descriptor["forward"] = godot_direction
				descriptors.append(gun_descriptor)
	return descriptors


static func _build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return _build_host_station_descriptors_from_snapshot(_snapshot_host_station_nodes(host_stations), set_id, hgt, w, h, support_descriptors, profile)

static func _normalized_game_data_type(game_data_type: String) -> String:
	return "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"

static func _clear_runtime_lookup_caches_for_tests() -> void:
	_blg_typ_override_cache.clear()
	VisualLookupService._clear_runtime_lookup_caches_for_tests()

static func _append_blg_typ_entries_from_building_list(target: Dictionary, buildings_value: Variant) -> void:
	if not (buildings_value is Array):
		return
	for entry in buildings_value:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var building := entry as Dictionary
		var building_id := int(building.get("id", -1))
		var typ_map := int(building.get("typ_map", -1))
		if building_id >= 0 and typ_map >= 0:
			target[building_id] = typ_map

static func _blg_typ_overrides_for_game_data_type(game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if _blg_typ_override_cache.has(normalized_game_data_type):
		return _blg_typ_override_cache[normalized_game_data_type]
	var result := {}
	if UA_DATA_JSON == null or typeof(UA_DATA_JSON.data) != TYPE_DICTIONARY:
		_blg_typ_override_cache[normalized_game_data_type] = result
		return result
	var root_data: Dictionary = UA_DATA_JSON.data
	if not root_data.has(normalized_game_data_type):
		_blg_typ_override_cache[normalized_game_data_type] = result
		return result
	var game_data: Dictionary = root_data[normalized_game_data_type]
	var hoststations_value = game_data.get("hoststations", {})
	if typeof(hoststations_value) == TYPE_DICTIONARY:
		for station_name in hoststations_value.keys():
			var station_value = hoststations_value[station_name]
			if typeof(station_value) != TYPE_DICTIONARY:
				continue
			_append_blg_typ_entries_from_building_list(result, Dictionary(station_value).get("buildings", []))
	var other_value = game_data.get("other", {})
	if typeof(other_value) == TYPE_DICTIONARY:
		_append_blg_typ_entries_from_building_list(result, Dictionary(other_value).get("buildings", []))
	_blg_typ_override_cache[normalized_game_data_type] = result
	return result

static func _building_sec_type_overrides_from_definitions(definitions: Array) -> Dictionary:
	var result := {}
	var ambiguous_building_ids := {}
	for definition_value in definitions:
		if typeof(definition_value) != TYPE_DICTIONARY:
			continue
		var definition := definition_value as Dictionary
		var building_id := int(definition.get("building_id", -1))
		var sec_type := int(definition.get("sec_type", -1))
		if building_id < 0 or sec_type < 0:
			continue
		if ambiguous_building_ids.has(building_id):
			continue
		if result.has(building_id) and int(result[building_id]) != sec_type:
			result.erase(building_id)
			ambiguous_building_ids[building_id] = true
			continue
		result[building_id] = sec_type
	return result

static func _building_sec_type_overrides_for_script_names(set_id: int, game_data_type: String, script_names: Array[String]) -> Dictionary:
	return VisualLookupService._building_sec_type_overrides_for_script_names(set_id, game_data_type, script_names)

static func _tech_upgrade_typ_overrides_for_3d(set_id: int, game_data_type: String) -> Dictionary:
	return VisualLookupService._tech_upgrade_typ_overrides_for_3d(set_id, game_data_type)

static func _entity_property(entity: Variant, property_names: Array[String], default_value: Variant = null) -> Variant:
	if typeof(entity) == TYPE_DICTIONARY:
		var dict := entity as Dictionary
		for property_name in property_names:
			if dict.has(property_name):
				return dict[property_name]
		return default_value
	if typeof(entity) != TYPE_OBJECT or entity == null:
		return default_value
	var object := entity as Object
	var available_properties := {}
	for property_value in object.get_property_list():
		if typeof(property_value) != TYPE_DICTIONARY:
			continue
		var property_name := String(Dictionary(property_value).get("name", ""))
		if property_name.is_empty():
			continue
		available_properties[property_name] = true
	for property_name in property_names:
		if available_properties.has(property_name):
			return object.get(property_name)
	return default_value

static func _entity_int_property(entity: Variant, property_names: Array[String], default_value := -1) -> int:
	var value = _entity_property(entity, property_names, null)
	if value == null:
		return default_value
	return int(value)

static func _apply_sector_building_overrides_from_entities(
		effective: PackedByteArray,
		w: int,
		h: int,
		entities: Array,
		building_property_names: Array[String],
		building_sec_type_overrides: Dictionary
	) -> void:
	if w <= 0 or h <= 0 or effective.size() != w * h:
		return
	for entity in entities:
		var sector_x := _entity_int_property(entity, ["sec_x"], -1)
		var sector_y := _entity_int_property(entity, ["sec_y"], -1)
		# Beam gates, tech upgrades, and Stoudson bombs store playable-sector
		# coordinates the same way the 2D editor does: 1-based within the
		# non-border typ_map footprint. Normalize those to the renderer's
		# 0-based flat typ_map indexing before applying preview-only overrides.
		if sector_x <= 0 or sector_y <= 0 or sector_x > w or sector_y > h:
			continue
		var sec_x := sector_x - 1
		var sec_y := sector_y - 1
		var building_id := _entity_int_property(entity, building_property_names, -1)
		if building_id < 0 or not building_sec_type_overrides.has(building_id):
			continue
		effective[sec_y * w + sec_x] = clampi(int(building_sec_type_overrides[building_id]), 0, 255)

static func _effective_typ_map_for_3d(
		typ: PackedByteArray,
		blg: PackedByteArray,
		game_data_type: String,
		w: int = -1,
		h: int = -1,
		beam_gates: Array = [],
		tech_upgrades: Array = [],
		stoudson_bombs: Array = [],
		set_id: int = 1
	) -> PackedByteArray:
	var effective: PackedByteArray = typ.duplicate()
	var blg_overrides := _blg_typ_overrides_for_game_data_type(game_data_type)
	if blg.size() == typ.size():
		for i in min(typ.size(), blg.size()):
			var building_id := int(blg[i])
			if not blg_overrides.has(building_id):
				continue
			effective[i] = clampi(int(blg_overrides[building_id]), 0, 255)
	if w <= 0 or h <= 0 or typ.size() != w * h:
		return effective
	var build_script_overrides := _building_sec_type_overrides_for_script_names(set_id, game_data_type, ["BUILD.SCR"])
	var tech_upgrade_overrides := _tech_upgrade_typ_overrides_for_3d(set_id, game_data_type)
	_apply_sector_building_overrides_from_entities(effective, w, h, beam_gates, ["closed_bp"], build_script_overrides)
	_apply_sector_building_overrides_from_entities(effective, w, h, tech_upgrades, ["building_id", "building"], tech_upgrade_overrides)
	_apply_sector_building_overrides_from_entities(effective, w, h, stoudson_bombs, ["inactive_bp"], build_script_overrides)
	return effective

static func _empty_building_attachment() -> Dictionary:
	return {
		"act": - 1,
		"vehicle_id": - 1,
		"ua_offset": Vector3.ZERO,
		"ua_direction": Vector3.ZERO,
	}

static func _append_building_attachment(target_building: Dictionary, attachment: Dictionary) -> void:
	if target_building.is_empty() or attachment.is_empty():
		return
	var attachments: Array = target_building.get("attachments", [])
	attachments.append(attachment.duplicate(true))
	target_building["attachments"] = attachments

static func _append_building_definition(result: Array, building: Dictionary) -> void:
	if building.is_empty():
		return
	if int(building.get("building_id", -1)) < 0 or int(building.get("sec_type", -1)) < 0:
		return
	result.append(building.duplicate(true))

static func _script_assignment_text(raw_line: String, prefix: String) -> String:
	var equals_index := raw_line.find("=")
	if equals_index >= 0:
		return raw_line.substr(equals_index + 1).strip_edges()
	return raw_line.replacen(prefix, "").strip_edges()

static func _parse_building_definitions(script_path: String) -> Array:
	var result: Array = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var full := UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_building := {}
	var current_attachment := {}
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_building"):
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {
				"building_id": int(_script_assignment_text(line, "new_building")),
				"sec_type": - 1,
				"attachments": [],
			}
			current_attachment = {}
			continue
		if line == "end":
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {}
			current_attachment = {}
			continue
		if current_building.is_empty():
			continue
		if line.begins_with("sec_type"):
			current_building["sec_type"] = int(_script_assignment_text(line, "sec_type"))
		elif line.begins_with("sbact_act"):
			_append_building_attachment(current_building, current_attachment)
			current_attachment = _empty_building_attachment()
			current_attachment["act"] = int(_script_assignment_text(line, "sbact_act"))
		elif line.begins_with("sbact_vehicle"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			current_attachment["vehicle_id"] = int(_script_assignment_text(line, "sbact_vehicle"))
		elif line.begins_with("sbact_pos_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_x := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_x.x = float(_script_assignment_text(line, "sbact_pos_x"))
			current_attachment["ua_offset"] = ua_offset_x
		elif line.begins_with("sbact_pos_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_y := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_y.y = float(_script_assignment_text(line, "sbact_pos_y"))
			current_attachment["ua_offset"] = ua_offset_y
		elif line.begins_with("sbact_pos_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_z := _vector3_from_variant(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_z.z = float(_script_assignment_text(line, "sbact_pos_z"))
			current_attachment["ua_offset"] = ua_offset_z
		elif line.begins_with("sbact_dir_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_x := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_x.x = float(_script_assignment_text(line, "sbact_dir_x"))
			current_attachment["ua_direction"] = ua_direction_x
		elif line.begins_with("sbact_dir_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_y := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_y.y = float(_script_assignment_text(line, "sbact_dir_y"))
			current_attachment["ua_direction"] = ua_direction_y
		elif line.begins_with("sbact_dir_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_z := _vector3_from_variant(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_z.z = float(_script_assignment_text(line, "sbact_dir_z"))
			current_attachment["ua_direction"] = ua_direction_z
	_append_building_attachment(current_building, current_attachment)
	_append_building_definition(result, current_building)
	return result

static func _building_definitions_for_game_data_type(set_id: int, game_data_type: String) -> Array:
	return VisualLookupService._building_definitions_for_game_data_type(set_id, game_data_type)

static func _building_definition_for_id_and_sec_type(building_id: int, sec_type: int, set_id_or_game_data_type = 1, game_data_type: String = "original") -> Dictionary:
	var resolved_set_id := 1
	var resolved_game_data_type := game_data_type
	if typeof(set_id_or_game_data_type) == TYPE_STRING:
		resolved_game_data_type = String(set_id_or_game_data_type)
	else:
		resolved_set_id = max(int(set_id_or_game_data_type), 1)
	return VisualLookupService._building_definition_for_id_and_sec_type(building_id, sec_type, resolved_set_id, resolved_game_data_type)

static func _build_blg_attachment_descriptors(blg: PackedByteArray, effective_typ: PackedByteArray, set_id: int, hgt: PackedByteArray, w: int, h: int, _support_descriptors: Array, game_data_type: String) -> Array:
	var descriptors: Array = []
	if blg.size() != w * h or effective_typ.size() != w * h:
		return descriptors
	# Source-backed building turret/radar sockets (`sbact_pos_*`) are defined relative to
	# the sector center, so their Y anchor should stay on the terrain sector height rather
	# than snapping up to the authored support mesh used by squads/host stations.
	for sy in h:
		for sx in w:
			var idx := sy * w + sx
			var building_id := int(blg[idx])
			if building_id <= 0:
				continue
			var definition := _building_definition_for_id_and_sec_type(building_id, int(effective_typ[idx]), set_id, game_data_type)
			if definition.is_empty():
				continue
			var world_x := (float(sx) + 1.5) * SECTOR_SIZE
			var world_z := (float(sy) + 1.5) * SECTOR_SIZE
			var sector_origin := _sector_center_origin(sx, sy, _ground_height_at_world_position(hgt, w, h, world_x, world_z))
			var attachments: Array = definition.get("attachments", [])
			for attachment_idx in attachments.size():
				var attachment_value = attachments[attachment_idx]
				if typeof(attachment_value) != TYPE_DICTIONARY:
					continue
				var attachment := attachment_value as Dictionary
				var base_name := _building_attachment_base_name_for_vehicle(int(attachment.get("vehicle_id", -1)), set_id, game_data_type)
				if base_name.is_empty():
					continue
				if not UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
					continue
				var descriptor := {
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "blg_attach:%d:%d:%d:%d:%d:%s" % [
						set_id,
						sx,
						sy,
						building_id,
						int(attachment.get("vehicle_id", -1)),
						str(attachment_idx)
					],
					"origin": sector_origin + _host_station_godot_offset_from_ua(_vector3_from_variant(attachment.get("ua_offset", Vector3.ZERO))),
				}
				var godot_direction := _host_station_godot_direction_from_ua(_vector3_from_variant(attachment.get("ua_direction", Vector3.ZERO)))
				if godot_direction.length_squared() > 0.000001:
					descriptor["forward"] = godot_direction
				descriptors.append(descriptor)
	return descriptors

static func _append_vehicle_visual_entry(result: Dictionary, vehicle_id: int, entry: Dictionary) -> void:
	if vehicle_id < 0:
		return
	if not entry.has("wait") and not entry.has("normal"):
		return
	var entries: Array = result.get(vehicle_id, [])
	entries.append(entry.duplicate(true))
	result[vehicle_id] = entries

static func _parse_vehicle_visual_entries(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var full := UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_vehicle_id := -1
	var current_entry: Dictionary = {}
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_vehicle"):
			_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
			var vehicle_text := line.replacen("new_vehicle", "").strip_edges()
			current_vehicle_id = int(vehicle_text)
			current_entry = {"model": ""}
			continue
		if line == "end":
			_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
			current_vehicle_id = -1
			current_entry = {}
			continue
		if current_vehicle_id < 0:
			continue
		if line.begins_with("model"):
			current_entry["model"] = _script_assignment_text(line, "model")
			continue
		if line.begins_with("vp_wait") or line.begins_with("vp_normal"):
			var slot_name := "wait" if line.begins_with("vp_wait") else "normal"
			var slot_prefix := "vp_wait" if slot_name == "wait" else "vp_normal"
			var vp_text := line.replacen(slot_prefix, "").replacen("=", "").strip_edges()
			if not vp_text.is_empty():
				current_entry[slot_name] = int(vp_text)
	_append_vehicle_visual_entry(result, current_vehicle_id, current_entry)
	return result

static func _vehicle_visual_entries_for_game_data_type(set_id: int, game_data_type: String) -> Dictionary:
	return VisualLookupService._vehicle_visual_entries_for_game_data_type(set_id, game_data_type)

static func _parse_vehicle_visual_pairs(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var full := UALegacyText.read_file(script_path)
	if full.is_empty():
		return result
	var current_vehicle_id := -1
	for line_raw in full.split("\n"):
		var line := line_raw.get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_vehicle"):
			var vehicle_text := line.replacen("new_vehicle", "").strip_edges()
			current_vehicle_id = int(vehicle_text)
			continue
		if current_vehicle_id >= 0 and (line.begins_with("vp_wait") or line.begins_with("vp_normal")):
			var slot_name := "wait" if line.begins_with("vp_wait") else "normal"
			var slot_prefix := "vp_wait" if slot_name == "wait" else "vp_normal"
			var vp_text := line.replacen(slot_prefix, "").replacen("=", "").strip_edges()
			if not vp_text.is_empty():
				var visuals: Dictionary = result.get(current_vehicle_id, {})
				visuals[slot_name] = int(vp_text)
				result[current_vehicle_id] = visuals
	return result

static func _squad_vehicle_visuals_for_game_data_type(set_id: int, game_data_type: String) -> Dictionary:
	return VisualLookupService._squad_vehicle_visuals_for_game_data_type(set_id, game_data_type)

static func _visproto_base_names_for_set(set_id: int, game_data_type: String) -> Array:
	return VisualLookupService._visproto_base_names_for_set(set_id, game_data_type)

static func _base_name_from_visproto_index(visproto_base_names: Array, visual_index: int) -> String:
	if visual_index < 0 or visual_index >= visproto_base_names.size():
		return ""
	var base_name := String(visproto_base_names[visual_index])
	if base_name.is_empty():
		return ""
	if base_name.to_lower().begins_with("dummy"):
		return ""
	return base_name

static func _preferred_squad_visual_base_name(vehicle_visuals: Dictionary, visproto_base_names: Array) -> String:
	for slot_name in ["wait", "normal"]:
		if not vehicle_visuals.has(slot_name):
			continue
		var base_name := _base_name_from_visproto_index(visproto_base_names, int(vehicle_visuals[slot_name]))
		if not base_name.is_empty():
			return base_name
	return ""

static func _building_attachment_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func _squad_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func _squad_quantity(squad: Object) -> int:
	var quantity_value = squad.get("quantity")
	if quantity_value == null:
		return 1
	return max(1, int(quantity_value))

static func _squad_anchor_origin(squad: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	var world_x := float(squad.position.x)
	var world_z := absf(float(squad.position.y))
	return Vector3(world_x, _support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile), world_z)

static func _squad_formation_offsets(quantity: int) -> Array:
	var offsets: Array = []
	var columns := int(sqrt(float(quantity))) + 2
	for unit_index in range(quantity):
		# Latest user-validated preview parity keeps the recovered spacing/column-count rule,
		# but fills each row left-to-right and advances subsequent rows upward in preview space
		# while preserving the same shared snapped anchor rules.
		var x_offset := SQUAD_FORMATION_SPACING * (float(unit_index % columns) - float(columns) / 2.0)
		var z_offset: float = - SQUAD_FORMATION_SPACING * floor(float(unit_index) / float(columns))
		offsets.append(Vector3(x_offset, 0.0, z_offset))
	return offsets

static func _snapshot_squad_nodes(squads: Array) -> Array:
	var snapshot: Array = []
	for squad in squads:
		if squad == null or not is_instance_valid(squad):
			continue
		if not (squad is Node2D):
			continue
		var vehicle_value = squad.get("vehicle")
		if vehicle_value == null:
			continue
		var squad_node := squad as Node2D
		snapshot.append({
			"id": int(squad.get_instance_id()),
			"vehicle": int(vehicle_value),
			"x": float(squad_node.position.x),
			"y": float(squad_node.position.y),
			"quantity": max(1, int(squad.get("quantity") if squad.get("quantity") != null else 1)),
		})
	return snapshot


static func _build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	var descriptors: Array = []
	for squad in squads:
		if typeof(squad) != TYPE_DICTIONARY:
			continue
		var sq := squad as Dictionary
		var vehicle := int(sq.get("vehicle", -1))
		if vehicle < 0:
			continue
		var base_name := _squad_base_name_for_vehicle(vehicle, set_id, game_data_type)
		if base_name.is_empty():
			continue
		if not UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
			continue
		var world_x := float(sq.get("x", 0.0))
		var world_z := absf(float(sq.get("y", 0.0)))
		var anchor := Vector3(world_x, _support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile), world_z)
		var squad_key_id := int(sq.get("id", 0))
		var quantity: int = max(1, int(sq.get("quantity", 1)))
		var offsets := _squad_formation_offsets(quantity)
		for unit_index in offsets.size():
			var formation_offset: Vector3 = offsets[unit_index]
			descriptors.append({
				"set_id": set_id,
				"raw_id": - 1,
				"base_name": base_name,
				"origin": anchor + Vector3(formation_offset),
				"instance_key": "squad:%d:%d:%s:%d" % [set_id, squad_key_id, base_name, unit_index],
				"y_offset": SQUAD_EXTRA_Y_OFFSET,
			})
	return descriptors


static func _build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return _build_squad_descriptors_from_snapshot(_snapshot_squad_nodes(squads), set_id, hgt, w, h, support_descriptors, game_data_type, profile)

static func _draw_quad(st: SurfaceTool, xl: float, xr: float, zt: float, zb: float, y: float, f: int, cells: int, v: int, rot_deg: int = 0, u0: float = 0.0, vv0: float = 0.0, u1: float = 1.0, vv1: float = 1.0) -> void:
	var rot := ((rot_deg % 360) + 360) % 360
	var uv_nw := Vector2(u0, vv0)
	var uv_ne := Vector2(u1, vv0)
	var uv_se := Vector2(u1, vv1)
	var uv_sw := Vector2(u0, vv1)
	if rot == 90:
		uv_nw = Vector2(u1, vv0)
		uv_ne = Vector2(u1, vv1)
		uv_se = Vector2(u0, vv1)
		uv_sw = Vector2(u0, vv0)
	elif rot == 180:
		uv_nw = Vector2(u1, vv1)
		uv_ne = Vector2(u0, vv1)
		uv_se = Vector2(u0, vv0)
		uv_sw = Vector2(u1, vv0)
	elif rot == 270:
		uv_nw = Vector2(u0, vv1)
		uv_ne = Vector2(u0, vv0)
		uv_se = Vector2(u1, vv0)
		uv_sw = Vector2(u1, vv1)
	st.set_color(Color((float(v) + 0.5) / float(cells), (float(f) + 0.5) / 6.0, 0.0))
	st.set_uv(uv_nw)
	st.add_vertex(Vector3(xl, y, zt))
	st.set_uv(uv_ne)
	st.add_vertex(Vector3(xr, y, zt))
	st.set_uv(uv_se)
	st.add_vertex(Vector3(xr, y, zb))
	st.set_uv(uv_nw)
	st.add_vertex(Vector3(xl, y, zt))
	st.set_uv(uv_se)
	st.add_vertex(Vector3(xr, y, zb))
	st.set_uv(uv_sw)
	st.add_vertex(Vector3(xl, y, zb))

static func _decode_raw_to_fcv(raw_val: int, default_file: int) -> Array:
	var f: int
	var cells: int
	var v: int
	var n := maxi(raw_val, 0)
	if n <= 3:
		f = default_file
		cells = (16 if f == 4 else 4)
		v = n
	elif n <= 7:
		f = 1
		cells = 4
		v = n - 4
	elif n <= 11:
		f = 2
		cells = 4
		v = n - 8
	elif n <= 15:
		f = 3
		cells = 4
		v = n - 12
	elif n <= 31:
		f = 4
		cells = 16
		v = n - 16
	elif n <= 35:
		f = 5
		cells = 4
		v = n - 32
	elif n <= 127:
		var file_idx := (n - 36) % 6
		f = (default_file if file_idx == 0 else file_idx)
		cells = (16 if f == 4 else 4)
		v = 0
	else:
		f = default_file
		cells = (16 if f == 4 else 4)
		v = 0
	return [f, cells, v]

static func _decode_raw_to_fcv_with_remap(raw_val: int, default_file: int, tile_remap: Dictionary) -> Array:
	if tile_remap:
		var raw_key := str(raw_val)
		if tile_remap.has(raw_key):
			var remap_entry: Dictionary = tile_remap[raw_key]
			var file_idx := int(remap_entry.get("file", default_file))
			var cells := (16 if file_idx == 4 else 4)
			var variant_idx := clampi(int(remap_entry.get("variant", 0)), 0, cells - 1)
			return [file_idx, cells, variant_idx]
	return _decode_raw_to_fcv(raw_val, default_file)

static func _remap_subsector_idx(subsector_idx: int, remap_table: Dictionary) -> int:
	if remap_table:
		var key := str(subsector_idx)
		if remap_table.has(key):
			return int(remap_table[key])
		if remap_table.has(subsector_idx):
			return int(remap_table[subsector_idx])
	return subsector_idx

static func _tile_desc_for_subsector(tile_mapping: Dictionary, subsector_idx: int) -> Dictionary:
	if tile_mapping.is_empty():
		return {}
	if tile_mapping.has(subsector_idx):
		return tile_mapping[subsector_idx]
	var key := str(subsector_idx)
	if tile_mapping.has(key):
		return tile_mapping[key]
	return {}

static func _sector_pattern_for_typ(subsector_patterns: Dictionary, typ_value: int, fallback_surface_type: int) -> Dictionary:
	if subsector_patterns.is_empty():
		return {
			"surface_type": fallback_surface_type,
			"sector_type": 1,
			"subsectors": PackedInt32Array()
		}
	if subsector_patterns.has(typ_value):
		return subsector_patterns[typ_value]
	var key := str(typ_value)
	if subsector_patterns.has(key):
		return subsector_patterns[key]
	return {
		"surface_type": fallback_surface_type,
		"sector_type": 1,
		"subsectors": PackedInt32Array()
	}

static func _default_file_variant_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Array:
	return _default_piece_selection_for_subsector(surface_type, subsector_idx, tile_mapping, tile_remap, subsector_idx_remap).get("piece", [clampi(surface_type, 0, 5), (16 if surface_type == 4 else 4), 0])

static func _default_stage_slot_for_raw(raw_value: int) -> int:
	if raw_value <= 0:
		return 3
	if raw_value <= 99:
		return 2
	if raw_value <= 199:
		return 1
	return 0

static func _selected_raw_id_for_tile_desc(tile_desc: Dictionary) -> int:
	var vals: Array[int] = [
		int(tile_desc.get("val0", 0)),
		int(tile_desc.get("val1", 0)),
		int(tile_desc.get("val2", 0)),
		int(tile_desc.get("val3", 0)),
	]
	# Conservative preview-only exception: shipped typ155 in sets 2..6 uses a one-off payload
	# {203,203,203,35,flag 0}. It is the only repeated "three identical non-zero stage
	# entries plus a different val3" signature in the bundled set data, and selecting val3
	# produces the known wrong bottom-left subsector. Prefer the repeated steady-state piece.
	if int(tile_desc.get("flag", 0)) == 0 and vals[0] != 0 and vals[0] == vals[1] and vals[1] == vals[2] and vals[3] != 0 and vals[3] != vals[0]:
		return vals[0]
	var raw_val := vals[_default_stage_slot_for_raw(int(tile_desc.get("flag", 0)))]
	if raw_val != 0:
		return raw_val
	var single_nonzero_raw := 0
	for candidate in vals:
		if candidate == 0:
			continue
		if single_nonzero_raw == 0:
			single_nonzero_raw = candidate
			continue
		if candidate != single_nonzero_raw:
			return raw_val
	return single_nonzero_raw

static func _default_piece_selection_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Dictionary:
	var default_file := clampi(surface_type, 0, 5)
	var remapped_idx := _remap_subsector_idx(subsector_idx, subsector_idx_remap)
	var tile_desc := _tile_desc_for_subsector(tile_mapping, remapped_idx)
	if tile_desc.is_empty():
		return {"raw_id": - 1, "piece": [default_file, (16 if default_file == 4 else 4), 0]}
	var raw_val := _selected_raw_id_for_tile_desc(tile_desc)
	return {"raw_id": raw_val, "piece": _decode_raw_to_fcv_with_remap(raw_val, default_file, tile_remap)}

static func _authored_origin_for_subsector(x0: float, z0: float, sector_y: float, sub_x: int, sub_y: int) -> Vector3:
	var sector_center_x := x0 + SECTOR_SIZE * 0.5
	var sector_center_z := z0 + SECTOR_SIZE * 0.5
	var lattice_step := SECTOR_SIZE * 0.25
	return Vector3(
		sector_center_x + (float(sub_x) - 1.0) * lattice_step,
		sector_y,
		sector_center_z + (float(sub_y) - 1.0) * lattice_step
	)

static func _append_vertical_seam_strip(st: SurfaceTool, x0: float, seam_x: float, x1: float, z0: float, z1: float, y_left: float, y_right: float, y_top_avg: float, y_bottom_avg: float) -> void:
	var lt := Vector3(x0, y_left, z0)
	var st_top := Vector3(seam_x, y_top_avg, z0)
	var rt := Vector3(x1, y_right, z0)
	var lb := Vector3(x0, y_left, z1)
	var st_bottom := Vector3(seam_x, y_bottom_avg, z1)
	var rb := Vector3(x1, y_right, z1)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(lt)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(lb)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(rt)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(st_top)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(rb)
	st.set_uv(Vector2(0.5, 1.0)); st.add_vertex(st_bottom)

static func _append_horizontal_seam_strip(st: SurfaceTool, x0: float, x1: float, z0: float, seam_z: float, z1: float, y_top: float, y_bottom: float, y_left_avg: float, y_right_avg: float) -> void:
	var tl := Vector3(x0, y_top, z0)
	var top_right := Vector3(x1, y_top, z0)
	var sl := Vector3(x0, y_left_avg, seam_z)
	var sr := Vector3(x1, y_right_avg, seam_z)
	var bl := Vector3(x0, y_bottom, z1)
	var br := Vector3(x1, y_bottom, z1)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(top_right)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(tl)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 0.5)); st.add_vertex(sr)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
	st.set_uv(Vector2(0.0, 0.5)); st.add_vertex(sl)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(br)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(bl)

static func _should_emit_seam_strip(_surface_a: int, _surface_b: int, _outer_a: float, _outer_b: float, _seam_mid_a: float, _seam_mid_b: float) -> bool:
	# Keep seams for all adjacent pairs (including same-surface and border-ring pairs)
	# so sector joins stay stable and authored slurp selection remains valid.
	return true

static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or typ.size() != w * h or w <= 0 or h <= 0:
		return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}, "authored_piece_descriptors": []}

	# Retail evidence shows each playable sector stays at a single hgt_map height, but the visible
	# top can still be composed from authored subsector pieces. Compact sectors render as 1x1,
	# while non-compact sectors render a 3x3 grid. For the read-only preview we reuse the set.sdf
	# subsector/tile tables to choose the default visible piece for each cell, then feed the ground
	# shader per-piece file/variant data while keeping seam/slurp handling in the overlay mesh.

	var surface_tools := {}
	var surface_type_order: Array[int] = []
	for i in 6:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface_tools[i] = st
		surface_type_order.append(i)
	var st_invalid := SurfaceTool.new()
	st_invalid.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tools[-1] = st_invalid
	surface_type_order.append(-1)
	var authored_piece_descriptors: Array = []

	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			var typ_value := _typ_value_with_implicit_border(typ, w, h, x, y)
			var surface_type := _preview_surface_type_for_typ(mapping, typ_value)
			var st: SurfaceTool = surface_tools[surface_type]
			var sector_y := _sample_hgt_height(hgt, w, h, x, y)
			var x0 := float(x + 1) * SECTOR_SIZE
			var x1 := float(x + 2) * SECTOR_SIZE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			if surface_type == -1:
				_draw_quad(st, x0, x1, z0, z1, sector_y, 0, 1, 0)
				continue

			var pattern := _sector_pattern_for_typ(subsector_patterns, typ_value, surface_type)
			var sector_type := int(pattern.get("sector_type", 1))
			var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
			if sector_type == 0 and subsectors.size() >= 9:
				var piece_w := SECTOR_SIZE / 3.0
				var piece_h := SECTOR_SIZE / 3.0
				for sub_y in 3:
					for sub_x in 3:
						var sub_idx := sub_y * 3 + sub_x
						var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[sub_idx]), tile_mapping, tile_remap, subsector_idx_remap)
						var piece: Array = selection.get("piece", [surface_type, (16 if surface_type == 4 else 4), 0])
						var piece_x0 := x0 + float(sub_x) * piece_w
						var piece_x1 := x0 + float(sub_x + 1) * piece_w
						var piece_z0 := z0 + float(sub_y) * piece_h
						var piece_z1 := z0 + float(sub_y + 1) * piece_h
						var authored := UATerrainPieceLibraryScript.resolve_authored_descriptor(
							set_id,
							int(selection.get("raw_id", -1)),
							lego_defs,
							_authored_origin_for_subsector(x0, z0, sector_y, sub_x, sub_y)
						)
						if not authored.is_empty():
							authored["instance_key"] = "terrain:%d:%d:%d:%d:%d:%d" % [
								set_id,
								x,
								y,
								sub_x,
								sub_y,
								int(authored.get("raw_id", -1))
							]
							authored_piece_descriptors.append(authored)
							continue
						_draw_quad(
							st,
							piece_x0,
							piece_x1,
							piece_z0,
							piece_z1,
							sector_y,
							int(piece[0]),
							int(piece[1]),
							int(piece[2]),
							0,
							clampf(float(sub_x) / 3.0 + SUBQUAD_UV_INSET, 0.0, 1.0),
							clampf(1.0 - float(sub_y + 1) / 3.0 + SUBQUAD_UV_INSET, 0.0, 1.0),
							clampf(float(sub_x + 1) / 3.0 - SUBQUAD_UV_INSET, 0.0, 1.0),
							clampf(1.0 - float(sub_y) / 3.0 - SUBQUAD_UV_INSET, 0.0, 1.0)
						)
			else:
				var piece := [surface_type, (16 if surface_type == 4 else 4), 0]
				var authored := {}
				if subsectors.size() > 0:
					var selection := _default_piece_selection_for_subsector(surface_type, int(subsectors[0]), tile_mapping, tile_remap, subsector_idx_remap)
					piece = selection.get("piece", piece)
					authored = UATerrainPieceLibraryScript.resolve_authored_descriptor(
						set_id,
						int(selection.get("raw_id", -1)),
						lego_defs,
						Vector3((x0 + x1) * 0.5, sector_y, (z0 + z1) * 0.5)
					)
				if authored.is_empty():
					_draw_quad(st, x0, x1, z0, z1, sector_y, int(piece[0]), int(piece[1]), int(piece[2]))
				else:
					authored["instance_key"] = "terrain:%d:%d:%d:%d" % [
						set_id,
						x,
						y,
						int(authored.get("raw_id", -1))
					]
					authored_piece_descriptors.append(authored)
					continue

	var mesh := ArrayMesh.new()
	var surface_to_surface_type := {}
	for i in surface_type_order.size():
		var surface_type: int = surface_type_order[i]
		var st: SurfaceTool = surface_tools[surface_type]
		var before := mesh.get_surface_count()
		st.index()
		st.generate_normals()
		st.commit(mesh)
		var after := mesh.get_surface_count()
		if after > before:
			surface_to_surface_type[before] = surface_type
	#region debug NDJSON logging (runtime evidence) - fullbuild summary
	if w == 6 and h == 6:
		var terrain_cnt: int = 0
		var slurp_cnt: int = 0
		for d_any in authored_piece_descriptors:
			if typeof(d_any) != TYPE_DICTIONARY:
				continue
			var ik := String((d_any as Dictionary).get("instance_key", ""))
			if ik.begins_with("terrain:"):
				terrain_cnt += 1
			elif ik.begins_with("slurp:"):
				slurp_cnt += 1
		_ndjson_log_once(
			"H2_fullbuild_summary",
			"pre_fix_attempt",
			"Map3DRenderer.build_mesh_with_textures:summary",
			"Log full-rebuild surface/descriptor summary",
			{
				"mesh_surface_count": mesh.get_surface_count(),
				"authored_piece_count": authored_piece_descriptors.size(),
				"terrain_cnt": terrain_cnt,
				"slurp_cnt": slurp_cnt
			}
		)
	#endregion
	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type, "authored_piece_descriptors": authored_piece_descriptors}

func _apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	if mesh == null:
		return
	if preloads == null:
		_apply_untextured_materials(mesh)
		return

	var shader: Shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	if shader == null:
		push_warning("[Map3D] Could not load sector_top.gdshader")
		_apply_untextured_materials(mesh)
		return

	for surface_idx in surface_to_surface_type.keys():
		var surface_type: int = int(surface_to_surface_type[surface_idx])
		if surface_type == -1:
			var dbg := StandardMaterial3D.new()
			dbg.albedo_color = Color(1.0, 0.0, 1.0, 0.45)
			dbg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.surface_set_material(surface_idx, dbg)
			continue

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("ground_texture", preloads.get_ground_texture(clampi(surface_type, 0, 5)))
		for ground_idx in 6:
			mat.set_shader_parameter("ground%d" % ground_idx, preloads.get_ground_texture(ground_idx))
		mat.set_shader_parameter("tile_scale", _compute_tile_scale())
		mat.set_shader_parameter("use_mesh_uv", true)
		mat.set_shader_parameter("use_multi_textures", true)
		mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
		mat.set_shader_parameter("use_vertex_variant", true)
		mat.set_shader_parameter("variant", 0)
		mat.set_shader_parameter("debug_mode", _debug_shader_mode)
		mesh.surface_set_material(surface_idx, mat)

# ---- UA edge-based strip rendering ----
func _on_level_set_changed() -> void:
	# Rebuild the current preview for the newly selected set.
	_request_refresh(false)

func _ensure_edge_node() -> void:
	if _edge_mesh == null:
		var mi := MeshInstance3D.new()
		mi.name = "EdgeMesh"
		add_child(mi)
		_edge_mesh = mi

func _build_edges_from_current_map() -> void:
	var cmd = _current_map_data()
	if cmd == null:
		return
	var w: int = int(cmd.horizontal_sectors)
	var h: int = int(cmd.vertical_sectors)
	var hgt: PackedByteArray = cmd.hgt_map
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2) or typ.size() != w * h:
		if _edge_mesh: _edge_mesh.mesh = null
		return
	var pre = _preloads()
	var mapping: Dictionary = pre.surface_type_map if pre else {}
	var effective_typ := _effective_typ_map_for_3d(
		typ,
		blg,
		_current_game_data_type(),
		w,
		h,
		cmd.beam_gates,
		cmd.tech_upgrades,
		cmd.stoudson_bombs
	)
	var result := _build_edge_overlay_result(hgt, w, h, effective_typ, mapping, int(cmd.level_set), pre)
	_ensure_edge_node()
	_edge_mesh.mesh = result.get("mesh", null)

func _build_edge_overlay_result(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary, set_id: int, preloads = null) -> Dictionary:
	var authored_piece_descriptors: Array = []
	var fallback_horiz := {}
	var fallback_vert := {}
	var vertical_checked := 0
	var vertical_emitted := 0
	var vertical_missing_mapping := 0
	var vertical_same_surface_emitted := 0
	var horizontal_checked := 0
	var horizontal_emitted := 0
	var horizontal_missing_mapping := 0
	var horizontal_same_surface_emitted := 0
	if preloads == null and is_inside_tree():
		preloads = _preloads()

	for y in range(-1, h + 1):
		for x in range(-1, w):
			vertical_checked += 1
			var a := _typ_value_with_implicit_border(typ, w, h, x, y)
			var b := _typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				vertical_missing_mapping += 1
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := _center_h(hgt, w, h, x, y)
			var yR := _center_h(hgt, w, h, x + 1, y)
			var yTopAvg := _corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := _corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			var base_name := _authored_slurp_base_name(sa, sb, true)
			if UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name,
					"instance_key": "slurp:v:%d:%d:%d:%d:%d" % [set_id, x, y, sa, sb],
					"origin": _sector_center_origin(x + 1, y, yR),
					"y_offset": TerrainBuilder.TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "vside",
					"anchor_height": yR,
					"left_height": yL,
					"right_height": yR,
					"top_avg": yTopAvg,
					"bottom_avg": yBottomAvg,
				})
				continue
			if sa == sb:
				# Avoid same-surface fallback strips when no authored seam exists; these are
				# perceived as "floating" edge textures during height edits.
				continue
			vertical_emitted += 1
			if sa == sb:
				vertical_same_surface_emitted += 1
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

	for y2 in range(-1, h):
		for x2 in range(-1, w + 1):
			horizontal_checked += 1
			var a2 := _typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := _typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				horizontal_missing_mapping += 1
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := _center_h(hgt, w, h, x2, y2)
			var yB := _center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := _corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := _corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			var base_name_h := _authored_slurp_base_name(sa2, sb2, false)
			if UATerrainPieceLibraryScript.has_piece_source(set_id, base_name_h):
				authored_piece_descriptors.append({
					"set_id": set_id,
					"raw_id": - 1,
					"base_name": base_name_h,
					"instance_key": "slurp:h:%d:%d:%d:%d:%d" % [set_id, x2, y2, sa2, sb2],
					"origin": _sector_center_origin(x2, y2 + 1, yB),
					"y_offset": TerrainBuilder.TERRAIN_AUTHORED_Y_OFFSET,
					"warp_mode": "hside",
					"anchor_height": yB,
					"top_height": yT,
					"bottom_height": yB,
					"left_avg": yLeftAvg,
					"right_avg": yRightAvg,
				})
				continue
			if sa2 == sb2:
				continue
			horizontal_emitted += 1
			if sa2 == sb2:
				horizontal_same_surface_emitted += 1
			_append_horizontal_fallback_group(fallback_vert, _retail_slurp_bucket_key(sa2, sb2, 0, 1), float(x2 + 1) * SECTOR_SIZE, float(x2 + 2) * SECTOR_SIZE, float(y2 + 2) * SECTOR_SIZE, yT, yB, yLeftAvg, yRightAvg)

	var fallback_mesh := ArrayMesh.new()
	for key_h in fallback_horiz.keys():
		var st_h: SurfaceTool = fallback_horiz[key_h]
		st_h.index(); st_h.generate_normals(); st_h.commit(fallback_mesh)
		fallback_mesh.surface_set_material(fallback_mesh.get_surface_count() - 1, _make_edge_blend_material(String(key_h), preloads, false))
	for key_v in fallback_vert.keys():
		var st_v: SurfaceTool = fallback_vert[key_v]
		st_v.index(); st_v.generate_normals(); st_v.commit(fallback_mesh)
		fallback_mesh.surface_set_material(fallback_mesh.get_surface_count() - 1, _make_edge_blend_material(String(key_v), preloads, true))
	#region agent log
	_ndjson_log_once(
		"pre_fix",
		"H1_full_edge_emission_stats",
		"Map3DRenderer._build_edge_overlay_result",
		"Collected full edge-overlay seam emission statistics",
		{
			"map_w": w,
			"map_h": h,
			"vertical_checked": vertical_checked,
			"vertical_emitted": vertical_emitted,
			"vertical_missing_mapping": vertical_missing_mapping,
			"vertical_same_surface_emitted": vertical_same_surface_emitted,
			"horizontal_checked": horizontal_checked,
			"horizontal_emitted": horizontal_emitted,
			"horizontal_missing_mapping": horizontal_missing_mapping,
			"horizontal_same_surface_emitted": horizontal_same_surface_emitted,
			"fallback_horiz_group_count": fallback_horiz.size(),
			"fallback_vert_group_count": fallback_vert.size(),
			"mesh_surface_count": fallback_mesh.get_surface_count()
		}
	)
	#endregion
	return {"authored_piece_descriptors": authored_piece_descriptors, "mesh": fallback_mesh if fallback_mesh.get_surface_count() > 0 else null}

func _append_vertical_fallback_group(groups: Dictionary, bucket_key: String, seam_x: float, z0: float, z1: float, left_height: float, right_height: float, top_avg: float, bottom_avg: float) -> void:
	if bucket_key.is_empty():
		return
	var st: SurfaceTool = groups.get(bucket_key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[bucket_key] = st
	_append_vertical_seam_strip(st, seam_x - EDGE_SLOPE, seam_x, seam_x + EDGE_SLOPE, z0, z1, left_height, right_height, top_avg, bottom_avg)

func _append_horizontal_fallback_group(groups: Dictionary, bucket_key: String, x0: float, x1: float, seam_z: float, top_height: float, bottom_height: float, left_avg: float, right_avg: float) -> void:
	if bucket_key.is_empty():
		return
	var st: SurfaceTool = groups.get(bucket_key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[bucket_key] = st
	_append_horizontal_seam_strip(st, x0, x1, seam_z - EDGE_SLOPE, seam_z, seam_z + EDGE_SLOPE, top_height, bottom_height, left_avg, right_avg)

func _make_edge_blend_material(bucket_key: String, preloads, use_uv_y_for_blend: bool) -> Material:
	# Retail slurps/fillers are pre-authored objects loaded from orientation-specific 6x6 tables.
	# The preview reuses the same ordered SurfaceType-pair key, but approximates the visible result
	# by blending the two set ground textures across a narrow seam strip.
	var pair := _surface_pair_from_slurp_bucket_key(bucket_key)
	if pair.is_empty() or preloads == null:
		return _make_preview_material(EDGE_PREVIEW_COLOR)
	var shader: Shader = load(EDGE_BLEND_SHADER_PATH)
	if shader == null:
		push_warning("[Map3D] Could not load edge_blend.gdshader")
		return _make_preview_material(EDGE_PREVIEW_COLOR)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("texture_a", preloads.get_ground_texture(int(pair["surface_a"])))
	mat.set_shader_parameter("texture_b", preloads.get_ground_texture(int(pair["surface_b"])))
	mat.set_shader_parameter("vertical_seam", use_uv_y_for_blend)
	mat.set_shader_parameter("tile_scale", _compute_tile_scale())
	mat.set_shader_parameter("atlas_grid", Vector2(1.0, 1.0))
	mat.set_shader_parameter("variant_a", 0)
	mat.set_shader_parameter("variant_b", 0)
	return mat

func _build_edges_mesh(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary, preloads = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if preloads == null and is_inside_tree():
		preloads = _preloads()
	# Collect per (surfaceA, surfaceB) pair to minimize materials
	var horiz := {}
	var vert := {}

	# Retail `vside` slurps apply to left/right neighboring sector pairs across the
	# entire rendered grid, including the implicit border ring.
	for y in range(-1, h + 1):
		for x in range(-1, w):
			var a := _typ_value_with_implicit_border(typ, w, h, x, y)
			var b := _typ_value_with_implicit_border(typ, w, h, x + 1, y)
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var yL := _center_h(hgt, w, h, x, y)
			var yR := _center_h(hgt, w, h, x + 1, y)
			var yTopAvg := _corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := _corner_average_h(hgt, w, h, x + 1, y + 1)
			if not _should_emit_seam_strip(sa, sb, yL, yR, yTopAvg, yBottomAvg):
				continue
			if sa == sb:
				continue
			var key := _retail_slurp_bucket_key(sa, sb, 1, 0)
			if key.is_empty():
				continue
			var st: SurfaceTool = horiz.get(key)
			if st == null:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				horiz[key] = st
			var seam_x := float(x + 2) * SECTOR_SIZE
			var x0 := seam_x - EDGE_SLOPE
			var x1 := seam_x + EDGE_SLOPE
			var z0 := float(y + 1) * SECTOR_SIZE
			var z1 := float(y + 2) * SECTOR_SIZE
			_append_vertical_seam_strip(st, x0, seam_x, x1, z0, z1, yL, yR, yTopAvg, yBottomAvg)

	# Retail `hside` slurps apply to top/bottom neighboring sector pairs across the
	# full rendered grid, including border-to-border joins.
	for y2 in range(-1, h):
		for x2 in range(-1, w + 1):
			var a2 := _typ_value_with_implicit_border(typ, w, h, x2, y2)
			var b2 := _typ_value_with_implicit_border(typ, w, h, x2, y2 + 1)
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var yT := _center_h(hgt, w, h, x2, y2)
			var yB := _center_h(hgt, w, h, x2, y2 + 1)
			var yLeftAvg := _corner_average_h(hgt, w, h, x2, y2 + 1)
			var yRightAvg := _corner_average_h(hgt, w, h, x2 + 1, y2 + 1)
			if not _should_emit_seam_strip(sa2, sb2, yT, yB, yLeftAvg, yRightAvg):
				continue
			if sa2 == sb2:
				continue
			var key2 := _retail_slurp_bucket_key(sa2, sb2, 0, 1)
			if key2.is_empty():
				continue
			var st2: SurfaceTool = vert.get(key2)
			if st2 == null:
				st2 = SurfaceTool.new()
				st2.begin(Mesh.PRIMITIVE_TRIANGLES)
				vert[key2] = st2
			var seam_z := float(y2 + 2) * SECTOR_SIZE
			var z0v := seam_z - EDGE_SLOPE
			var z1v := seam_z + EDGE_SLOPE
			var x0v := float(x2 + 1) * SECTOR_SIZE
			var x1v := float(x2 + 2) * SECTOR_SIZE
			_append_horizontal_seam_strip(st2, x0v, x1v, z0v, seam_z, z1v, yT, yB, yLeftAvg, yRightAvg)

	# Commit groups and assign materials per pair
	for key_h in horiz.keys():
		var st_h: SurfaceTool = horiz[key_h]
		st_h.index(); st_h.generate_normals(); st_h.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _make_edge_blend_material(String(key_h), preloads, false))
	for key_v in vert.keys():
		var st_v: SurfaceTool = vert[key_v]
		st_v.index(); st_v.generate_normals(); st_v.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _make_edge_blend_material(String(key_v), preloads, true))
	return mesh

func _apply_edge_surface_materials(mesh: ArrayMesh, preloads, fallback_horiz_keys: Array, fallback_vert_keys: Array) -> void:
	if mesh == null:
		return
	var surface_idx := 0
	for key_h in fallback_horiz_keys:
		if surface_idx >= mesh.get_surface_count():
			return
		mesh.surface_set_material(surface_idx, _make_edge_blend_material(String(key_h), preloads, false))
		surface_idx += 1
	for key_v in fallback_vert_keys:
		if surface_idx >= mesh.get_surface_count():
			return
		mesh.surface_set_material(surface_idx, _make_edge_blend_material(String(key_v), preloads, true))
		surface_idx += 1

func _center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return _sample_hgt_height(hgt, w, h, sx, sy)

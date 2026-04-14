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
const RefreshCoordinator := preload("res://map/map_3d_refresh_coordinator.gd")
const ChunkRuntime := preload("res://map/map_3d_chunk_runtime.gd")
const EffectiveTypService := preload("res://map/map_3d_effective_typ_service.gd")
const OverlayProducers := preload("res://map/map_3d_overlay_descriptor_producers.gd")
const LegacyScriptParser := preload("res://map/map_3d_legacy_script_parser.gd")
const UnitOverlayController := preload("res://map/map_3d_unit_overlay_controller.gd")
const InvalidationRouter := preload("res://map/map_3d_invalidation_router.gd")
const StaticOverlayIndex := preload("res://map/map_3d_static_overlay_index.gd")

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
const UA_NORMAL_RENDER_SECTORS := 5
const UA_NORMAL_GEOMETRY_CULL_DISTANCE := float(UA_NORMAL_RENDER_SECTORS) * SECTOR_SIZE + SECTOR_SIZE * 0.5
const _ASYNC_APPLY_RESULTS_PER_FRAME := 4
const _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 48
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

# Preview top surfaces use world-space tiling with one repeat per sector.
func _compute_tile_scale() -> float:
	return 1.0 / SECTOR_SIZE

static func visibility_range_fade_start(viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> float:
	return ViewController.visibility_range_fade_start(viz_limit, fade_length)

static func visibility_range_config(viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> Dictionary:
	return ViewController.visibility_range_config(viz_limit, fade_length)

static func apply_visibility_range_to_environment(environment: Environment, enabled: bool, viz_limit: float = ViewController.UA_NORMAL_VIZ_LIMIT, fade_length: float = ViewController.UA_NORMAL_FADE_LENGTH) -> bool:
	return ViewController.apply_visibility_range_to_environment(environment, enabled, viz_limit, fade_length)

static func facade_contract() -> Dictionary:
	return {
		"runtime_fields": [
			"is_building_3d",
			"completed_chunks",
			"total_chunks",
			"status_text",
		],
		"instance_api": [
			"set_event_system_override",
			"set_current_map_data_override",
			"set_editor_state_override",
			"set_preloads_override",
			"get_build_state_snapshot",
			"has_pending_refresh",
			"get_last_build_metrics",
			"build_from_current_map",
			"clear",
			"mark_sector_dirty",
			"mark_sectors_dirty",
			"get_dirty_chunk_count",
			"is_using_chunked_terrain",
			"set_chunked_terrain_enabled",
		],
		"static_api": [
			"facade_contract",
			"visibility_range_fade_start",
			"visibility_range_config",
			"apply_visibility_range_to_environment",
			"build_mesh",
			"build_mesh_with_textures",
		],
		"compatibility_instance_api": [
			"_apply_pending_refresh",
			"_build_edge_overlay_result",
		],
		"compatibility_static_api": [
			"_building_definition_for_id_and_sec_type",
			"_visproto_base_names_for_set",
			"_base_name_from_visproto_index",
			"_building_attachment_base_name_for_vehicle",
			"_squad_base_name_for_vehicle",
			"_build_host_station_descriptors",
			"_build_squad_descriptors",
		],
	}

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

var _terrain_chunk_nodes: Dictionary = {}
var _edge_chunk_nodes: Dictionary = {}

var _geometry_distance_culling_enabled := false
var _geometry_cull_distance := UA_NORMAL_GEOMETRY_CULL_DISTANCE

# Material pooling: reuse identical ShaderMaterials across chunks.
var _sector_top_shader: Shader = null
var _edge_blend_shader: Shader = null
var _terrain_material_cache: Dictionary = {} # surface_type (int) -> ShaderMaterial
var _edge_material_cache: Dictionary = {} # "bucket_key:vertical_bool" -> ShaderMaterial

# Scheduling and async build coordination is delegated to the coordinator.
# Thread-safe state, chunk payload queues, generation IDs, and map-signature
# tracking live there; the renderer accesses them via `_coordinator`.
var _coordinator := RefreshCoordinator.new()

# Chunk-level state: dirty tracking, rebuild decisions, authored cache.
var _chunk_rt := ChunkRuntime.new()
var _effective_typ_service := EffectiveTypService.new()

var active_build_generation_id: int:
	get:
		return _coordinator.active_build_generation_id
	set(value):
		_coordinator.active_build_generation_id = value
var build_generation_id: int:
	get:
		return _coordinator.build_generation_id
	set(value):
		_coordinator.build_generation_id = value
var cancel_requested_generation_id: int:
	get:
		return _coordinator.cancel_requested_generation_id
	set(value):
		_coordinator.cancel_requested_generation_id = value

# Async initial-build state (exposed for UI loading indicator and cancellation).
var is_building_3d := false
var total_chunks := 0
var completed_chunks := 0
var status_text := ""

var _async_pending_reframe_camera := false
var _async_effective_typ: PackedByteArray = PackedByteArray()
var _async_blg: PackedByteArray = PackedByteArray()
var _async_w := 0
var _async_h := 0
var _async_level_set := 0
var _async_game_data_type := "original"
var _async_requested_restart := false
var _async_requested_reframe := false
var _async_overlay_apply_active := false
var _async_overlay_apply_state: Dictionary = {}
var _async_overlay_descriptors: Array = []
var _async_dynamic_overlay_descriptors: Array = []
var _async_overlay_metrics: Dictionary = {}
var _async_overlay_apply_started_usec := 0
var _overlay_only_refresh_requested := false
var _dynamic_overlay_refresh_requested := false
var _async_overlay_descriptor_dynamic_only := false
var _skip_next_map_changed_refresh := false
var _pending_unit_changes: Array = []
var _overlay_apply_manager := Map3DAuthoredOverlayManager.new()
var _static_overlay_index := StaticOverlayIndex.new()
var _localized_overlay_dirty_sectors: Dictionary = {}
var _localized_dynamic_overlay_dirty_sectors: Dictionary = {}

func set_event_system_override(event_system: Node) -> void:
	_event_system_override = event_system

func set_current_map_data_override(current_map_data: Node) -> void:
	_current_map_data_override = current_map_data

func set_editor_state_override(editor_state: Node) -> void:
	_editor_state_override = editor_state

func set_preloads_override(preloads: Node) -> void:
	_preloads_override = preloads
	_preloads_override_set = true

func get_build_state_snapshot() -> Dictionary:
	return {
		"is_building_3d": is_building_3d,
		"completed_chunks": completed_chunks,
		"total_chunks": total_chunks,
		"status_text": status_text,
	}

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
		"chunk_apply_ms": 0.0,
		"edge_slurp_build_ms": 0.0,
		"overlay_descriptor_generation_ms": 0.0,
		"overlay_node_creation_ms": 0.0,
		"static_overlay_descriptor_generation_ms": 0.0,
		"static_overlay_apply_ms": 0.0,
		"dynamic_overlay_descriptor_generation_ms": 0.0,
		"dynamic_overlay_apply_ms": 0.0,
		"support_height_query_ms": 0.0,
		"support_height_query_count": 0,
		"terrain_authored_descriptor_count": 0,
		"edge_authored_descriptor_count": 0,
		"overlay_descriptor_count": 0,
		"dirty_sector_count": 0,
		"dirty_chunk_count": 0,
		"localized_overlay_refresh": false,
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
	return _coordinator.is_async_build_active()

func _is_async_pipeline_active() -> bool:
	return _coordinator.is_async_pipeline_active(_async_overlay_apply_active)

func _is_async_overlay_descriptor_active() -> bool:
	return _coordinator.is_async_overlay_descriptor_active()

func _set_async_overlay_descriptor_state(done: bool, failed: bool, result, metrics: Dictionary) -> void:
	_coordinator.set_async_overlay_descriptor_state(done, failed, result, metrics)

func _set_async_overlay_descriptor_stage(stage: String) -> void:
	_coordinator.set_async_overlay_descriptor_stage(stage)

func _get_async_overlay_descriptor_stage() -> String:
	return _coordinator.get_async_overlay_descriptor_stage()

func _get_async_overlay_descriptor_state() -> Dictionary:
	return _coordinator.get_async_overlay_descriptor_state()

func _set_async_worker_state(done: bool, failed: bool, message: String) -> void:
	_coordinator.set_async_worker_state(done, failed, message)

func _get_async_worker_state() -> Dictionary:
	return _coordinator.get_async_worker_state()

func _is_async_cancel_requested(generation_id: int) -> bool:
	return _coordinator.is_async_cancel_requested(generation_id)

func _push_async_chunk_payload(payload: Dictionary) -> void:
	_coordinator.push_async_chunk_payload(payload)

func _pop_async_chunk_payload() -> Dictionary:
	return _coordinator.pop_async_chunk_payload()

func _clear_async_chunk_payloads() -> void:
	_coordinator.clear_async_chunk_payloads()

func _async_chunk_payload_count() -> int:
	return _coordinator.async_chunk_payload_count()


func _record_localized_overlay_sectors(sectors: Array) -> void:
	for sector_value in sectors:
		if sector_value is Vector2i:
			var sector := Vector2i(sector_value)
			_localized_overlay_dirty_sectors[sector] = true
			_localized_dynamic_overlay_dirty_sectors[sector] = true


func _localized_overlay_sector_list() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for key in _localized_overlay_dirty_sectors.keys():
		if key is Vector2i:
			sectors.append(Vector2i(key))
	return sectors


func _localized_dynamic_sector_list() -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	for key in _localized_dynamic_overlay_dirty_sectors.keys():
		if key is Vector2i:
			sectors.append(Vector2i(key))
	return sectors


func _clear_localized_overlay_scope() -> void:
	_localized_overlay_dirty_sectors.clear()
	_localized_dynamic_overlay_dirty_sectors.clear()

func _compute_effective_typ_for_map(
	cmd: Node,
	w: int,
	h: int,
	typ: PackedByteArray,
	blg: PackedByteArray,
	game_data_type: String
) -> PackedByteArray:
	return _effective_typ_service.compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)

static func _elapsed_ms_since(started_usec: int) -> float:
	if started_usec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_usec() - started_usec) / 1000.0, 0.0)

static func _checksum_packed_byte_array(data: PackedByteArray) -> int:
	return EffectiveTypService.checksum_packed_byte_array(data)

static func _profile_add_duration(profile, key: String, duration_ms: float) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = float(profile.get(key, 0.0)) + maxf(duration_ms, 0.0)

static func _profile_increment(profile, key: String, amount: int = 1) -> void:
	if typeof(profile) != TYPE_DICTIONARY:
		return
	profile[key] = int(profile.get(key, 0)) + amount

func _finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	metrics["build_total_ms"] = _elapsed_ms_since(build_started_usec)
	if _refresh_requested_at_usec > 0:
		metrics["refresh_end_to_end_ms"] = _elapsed_ms_since(_refresh_requested_at_usec)
		_refresh_requested_at_usec = 0
	_last_build_metrics = metrics.duplicate(true)

func _event_system() -> Node:
	if _event_system_override != null and is_instance_valid(_event_system_override):
		return _event_system_override
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("EventSystem")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("EventSystem")
	return null

func _current_map_data() -> Node:
	if _current_map_data_override != null and is_instance_valid(_current_map_data_override):
		return _current_map_data_override
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("CurrentMapData")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("CurrentMapData")
	return null

func _editor_state() -> Node:
	if _editor_state_override != null and is_instance_valid(_editor_state_override):
		return _editor_state_override
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.get_node_or_null("EditorState")
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree and main_loop.root != null:
		return main_loop.root.get_node_or_null("EditorState")
	return null

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
	# Allow in-progress async builds to continue even when the user switches
	# to 2D mode, so completed chunks are ready when they switch back.
	# New refreshes defer until 3D is visible to avoid wasting CPU on edits
	# the user hasn't asked to preview yet.
	if _is_async_pipeline_active():
		return true
	var editor_state := _editor_state()
	if editor_state != null:
		return bool(editor_state.get("view_mode_3d"))
	return true

func _is_3d_view_visible() -> bool:
	var editor_state := _editor_state()
	if editor_state != null:
		return bool(editor_state.get("view_mode_3d"))
	return true

func _apply_preview_activity_state() -> void:
	var in_3d := _is_3d_view_visible()
	set_physics_process(in_3d)
	set_process_unhandled_input(in_3d)

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
	# Pre-load shaders once to avoid repeated load() calls during chunk apply.
	_sector_top_shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	_edge_blend_shader = load(EDGE_BLEND_SHADER_PATH)

	var test_mesh := get_node_or_null("TestMesh")
	if test_mesh:
		_ensure_edge_node()

		test_mesh.visible = false
	# Ensure we have an active camera in the SubViewport
	if _camera:
		_camera.current = true
	# Listen for map events (guarded for test environment without autoloads)

	var _es = _event_system()
	if _es:
		_es.map_created.connect(_on_map_created)
		_es.map_updated.connect(_on_map_updated)
		_es.level_set_changed.connect(_on_level_set_changed)
		_es.map_view_updated.connect(_on_map_view_updated)
		if _es.has_signal("map_3d_focus_sector_requested"):
			_es.map_3d_focus_sector_requested.connect(_on_map_3d_focus_sector_requested)
		_es.map_3d_overlay_animations_changed.connect(_on_map_3d_overlay_animations_changed)
		if _es.has_signal("units_changed"):
			_es.units_changed.connect(_on_units_changed)
		if _es.has_signal("unit_position_committed"):
			_es.unit_position_committed.connect(_on_unit_position_committed)
		if _es.has_signal("unit_overlay_refresh_requested"):
			_es.unit_overlay_refresh_requested.connect(_on_unit_overlay_refresh_requested)
		if _es.has_signal("hgt_map_cells_edited"):
			_es.hgt_map_cells_edited.connect(_on_hgt_map_cells_edited)
		if _es.has_signal("typ_map_cells_edited"):
			_es.typ_map_cells_edited.connect(_on_typ_map_cells_edited)
		if _es.has_signal("blg_map_cells_edited"):
			_es.blg_map_cells_edited.connect(_on_blg_map_cells_edited)
	_apply_preview_activity_state()
	_apply_visibility_range_from_editor_state()
	var _cmd = _current_map_data()

	if _cmd:
		# Initial build if data already present
		if _cmd.horizontal_sectors > 0 and _cmd.vertical_sectors > 0 and not _cmd.hgt_map.is_empty():
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
	elif _preview_refresh_active():
		_flush_pending_unit_changes()

func _on_map_3d_overlay_animations_changed() -> void:
	if _preview_refresh_active():
		_request_overlay_only_refresh()

func _on_units_changed(changes: Array) -> void:
	var normalized := _normalize_unit_changes(changes)
	if normalized.is_empty():
		return
	if not _preview_refresh_active():
		_enqueue_pending_unit_changes(normalized)
		return
	if _is_async_pipeline_active():
		_enqueue_pending_unit_changes(normalized)
		return
	if normalized.size() > 16:
		_request_dynamic_overlay_refresh()
		return
	if _apply_unit_change_batch(normalized):
		return
	_request_dynamic_overlay_refresh()

func _on_unit_position_committed(unit_kind: String, unit_id: int) -> void:
	if unit_kind.is_empty() or unit_id <= 0:
		_request_dynamic_overlay_refresh()
		return
	_on_units_changed([{
		"kind": unit_kind,
		"unit_id": unit_id,
		"action": "moved",
	}])

func _on_unit_overlay_refresh_requested(unit_kind: String, unit_id: int) -> void:
	if not _preview_refresh_active():
		_request_dynamic_overlay_refresh()
		return
	_skip_next_map_changed_refresh = true
	_on_units_changed([{
		"kind": unit_kind,
		"unit_id": unit_id,
		"action": "visual",
	}])

func _request_overlay_only_refresh() -> void:
	_overlay_only_refresh_requested = true
	_request_refresh(false)

func _request_dynamic_overlay_refresh() -> void:
	_dynamic_overlay_refresh_requested = true
	_request_refresh(false)

func _can_use_overlay_only_refresh() -> bool:
	if _chunk_rt.initial_build_in_progress:
		return false
	if _chunk_rt.has_dirty_chunks():
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
	if Vector2i(w, h) != _chunk_rt.last_map_dimensions:
		return false
	if int(cmd.level_set) != _chunk_rt.last_level_set:
		return false
	return true

func _start_async_overlay_only_refresh(reframe_camera: bool) -> bool:
	if not _can_use_overlay_only_refresh():
		_overlay_only_refresh_requested = false
		return false
	if not _sync_async_overlay_state_from_current_map():
		_overlay_only_refresh_requested = false
		return false
	_sync_terrain_overlay_animation_mode_from_editor()
	_overlay_only_refresh_requested = false
	_coordinator.build_generation_id += 1
	_coordinator.active_build_generation_id = _coordinator.build_generation_id
	_coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_begin_build_state(1, "Preparing overlays...")
	_start_async_overlay_descriptor_build()
	return true

func _start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	if not _can_use_overlay_only_refresh():
		_dynamic_overlay_refresh_requested = false
		return false
	if not _sync_async_overlay_state_from_current_map():
		_dynamic_overlay_refresh_requested = false
		return false
	_sync_terrain_overlay_animation_mode_from_editor()
	_dynamic_overlay_refresh_requested = false
	_overlay_only_refresh_requested = false
	_coordinator.build_generation_id += 1
	_coordinator.active_build_generation_id = _coordinator.build_generation_id
	_coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_begin_build_state(1, "Updating vehicles...")
	_start_async_overlay_descriptor_build(true)
	return true

func _sync_async_overlay_state_from_current_map() -> bool:
	var cmd := _current_map_data()
	if cmd == null:
		return false
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return false
	var typ: PackedByteArray = cmd.typ_map
	var blg: PackedByteArray = cmd.blg_map
	if typ.size() != w * h:
		return false
	var game_data_type := _current_game_data_type()
	UATerrainPieceLibraryScript.set_piece_game_data_type(game_data_type)
	_async_effective_typ = _compute_effective_typ_for_map(cmd, w, h, typ, blg, game_data_type)
	_async_blg = blg
	_async_w = w
	_async_h = h
	_async_level_set = int(cmd.level_set)
	_async_game_data_type = game_data_type
	return true

func _try_start_async_initial_build(reframe_camera: bool) -> bool:
	if not _chunk_rt.initial_build_in_progress:
		return false
	if not _chunk_rt.has_dirty_chunks():
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
	_coordinator.build_generation_id += 1
	_coordinator.active_build_generation_id = _coordinator.build_generation_id
	_coordinator.cancel_requested_generation_id = 0
	_async_pending_reframe_camera = reframe_camera
	_async_effective_typ = effective_typ
	_async_blg = blg
	_async_w = w
	_async_h = h
	_async_level_set = level_set
	_async_game_data_type = game_data_type
	_coordinator._async_cancel_requested = false
	_async_requested_restart = false
	_async_requested_reframe = false
	_clear_async_chunk_payloads()
	_set_async_worker_state(false, false, "")
	var total := chunk_list.size()
	_begin_build_state(total, "Rendering map...")
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_initial_build_worker").bind(snapshot, _coordinator.active_build_generation_id))
	if err != OK:
		_end_build_state(false, "3D render worker could not start")
		return false
	_coordinator.set_async_initial_thread(thread)
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
		if int(payload.get("generation_id", -1)) != _coordinator.active_build_generation_id:
			continue
		if _coordinator._async_cancel_requested:
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
	_chunk_rt.erase_dirty_chunk(chunk_coord)
	var done := completed_chunks + 1
	_update_build_progress(done, total_chunks, "Rendering map... %d / %d" % [done, total_chunks])
	_bump_3d_viewport_rendering()

func _finish_async_initial_build() -> void:
	_join_async_thread()
	var cancelled := _coordinator._async_cancel_requested
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
	var support_descriptors: Array = _chunk_rt.get_support_descriptors()
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
		"generation_id": _coordinator.active_build_generation_id,
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
	_set_async_overlay_descriptor_stage("Preparing overlays: queued")
	_set_async_overlay_descriptor_state(false, false, {}, {})
	var thread := Thread.new()
	var err := thread.start(Callable(self, "_async_overlay_descriptor_worker").bind(payload))
	if err != OK:
		# Fallback to immediate apply of terrain-only descriptors if descriptor worker cannot start.
		_start_async_overlay_apply(support_descriptors, [], _make_empty_build_metrics())
		return
	_coordinator.set_async_overlay_descriptor_thread(thread)

func _async_overlay_descriptor_worker(payload: Dictionary) -> void:
	var generation_id := int(payload.get("generation_id", -1))
	var dynamic_only := bool(payload.get("dynamic_only", false))
	_set_async_overlay_descriptor_stage("Preparing overlays: starting")
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
	var static_started_usec := Time.get_ticks_usec()
	if not dynamic_only:
		_set_async_overlay_descriptor_stage("Preparing overlays: building attachments")
		static_descriptors.append_array(_build_blg_attachment_descriptors(blg, effective_typ, set_id, hgt, w, h, support_descriptors, game_data_type))
	metrics["static_overlay_descriptor_generation_ms"] = _elapsed_ms_since(static_started_usec)
	if _is_async_cancel_requested(generation_id):
		_set_async_overlay_descriptor_state(true, false, {}, {})
		return
	_set_async_overlay_descriptor_stage("Preparing overlays: host stations")
	var dynamic_started_usec := Time.get_ticks_usec()
	dynamic_descriptors.append_array(_build_host_station_descriptors_from_snapshot(host_station_snapshot, set_id, hgt, w, h, support_descriptors, metrics))
	if _is_async_cancel_requested(generation_id):
		_set_async_overlay_descriptor_state(true, false, {}, {})
		return
	_set_async_overlay_descriptor_stage("Preparing overlays: squads")
	dynamic_descriptors.append_array(_build_squad_descriptors_from_snapshot(squad_snapshot, set_id, hgt, w, h, support_descriptors, game_data_type, metrics))
	metrics["dynamic_overlay_descriptor_generation_ms"] = _elapsed_ms_since(dynamic_started_usec)
	metrics["overlay_descriptor_generation_ms"] = _elapsed_ms_since(started_usec)
	metrics["overlay_descriptor_count"] = static_descriptors.size() + dynamic_descriptors.size()
	_set_async_overlay_descriptor_stage("Preparing overlays: complete")
	_set_async_overlay_descriptor_state(true, false, {
		"static_descriptors": static_descriptors,
		"dynamic_descriptors": dynamic_descriptors,
	}, metrics)

func _pump_async_overlay_descriptor_build() -> void:
	if not _is_async_overlay_descriptor_active():
		return
	var stage := _get_async_overlay_descriptor_stage()
	if not stage.is_empty():
		_update_build_progress(total_chunks, total_chunks, stage)
	if _coordinator._async_cancel_requested:
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
	if _coordinator._async_cancel_requested:
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
		var dynamic_apply_started_usec := Time.get_ticks_usec()
		_apply_dynamic_overlay(dynamic_descriptors)
		metrics["dynamic_overlay_apply_ms"] = _elapsed_ms_since(dynamic_apply_started_usec)
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
		_flush_pending_unit_changes()
		return
	_start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)

func _join_async_overlay_descriptor_thread() -> void:
	_coordinator.join_async_overlay_descriptor_thread()

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

func _find_unit_by_instance_id(container: Node, unit_id: int) -> Node2D:
	return UnitOverlayController.find_unit_by_identity(container, unit_id)

func _normalize_unit_changes(changes: Array) -> Array:
	var normalized: Array = []
	var by_key := {}
	for change_any in changes:
		if typeof(change_any) != TYPE_DICTIONARY:
			continue
		var change := change_any as Dictionary
		var unit_kind := String(change.get("kind", ""))
		var unit_id := int(change.get("unit_id", 0))
		var action := String(change.get("action", ""))
		if unit_kind.is_empty() or unit_id <= 0 or action.is_empty():
			continue
		by_key["%s:%d" % [unit_kind, unit_id]] = {
			"kind": unit_kind,
			"unit_id": unit_id,
			"action": action,
		}
	for value in by_key.values():
		normalized.append(value)
	return normalized

func _enqueue_pending_unit_changes(changes: Array) -> void:
	if changes.is_empty():
		return
	var merged: Array = _pending_unit_changes.duplicate(true)
	merged.append_array(changes)
	_pending_unit_changes = _normalize_unit_changes(merged)

func _flush_pending_unit_changes() -> bool:
	if _pending_unit_changes.is_empty():
		return false
	if not _preview_refresh_active() or _is_async_pipeline_active():
		return false
	var pending := _normalize_unit_changes(_pending_unit_changes)
	_pending_unit_changes.clear()
	if pending.is_empty():
		return false
	if pending.size() > 16:
		_request_dynamic_overlay_refresh()
		return true
	if _apply_unit_change_batch(pending):
		return true
	_request_dynamic_overlay_refresh()
	return true

func _apply_unit_change_batch(changes: Array) -> bool:
	if changes.is_empty():
		return false
	if not _can_use_overlay_only_refresh():
		return false
	var cmd := _current_map_data()
	if cmd == null:
		return false
	var support_descriptors: Array = _chunk_rt.get_support_descriptors()
	_ensure_overlay_nodes()
	var game_data_type := _async_game_data_type if not _async_game_data_type.is_empty() else _current_game_data_type()
	var applied := UnitOverlayController.apply_unit_changes(_dynamic_overlay, changes, cmd, support_descriptors, game_data_type)
	if not applied:
		return false
	_apply_geometry_distance_culling_to_overlay()
	_bump_3d_viewport_rendering()
	return true

func _apply_single_unit_dynamic_refresh(unit_kind: String, unit_id: int) -> bool:
	return _apply_unit_change_batch([{
		"kind": unit_kind,
		"unit_id": unit_id,
		"action": "visual",
	}])

func _start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_ensure_overlay_nodes()
	_async_overlay_descriptors = static_descriptors
	_async_dynamic_overlay_descriptors = dynamic_descriptors
	_async_overlay_metrics = metrics.duplicate(true)
	_static_overlay_index.replace_all(static_descriptors)
	_async_overlay_apply_state = _overlay_apply_manager.begin_apply_overlay_node(_authored_overlay, _async_overlay_descriptors)
	_async_overlay_apply_started_usec = Time.get_ticks_usec()
	_async_overlay_apply_active = true
	UATerrainPieceLibraryScript.reset_piece_overlay_build_counters()
	_update_build_progress(total_chunks, total_chunks, "Applying 3D overlays... 0%")

func _pump_async_overlay_apply() -> void:
	if not _async_overlay_apply_active:
		return
	if _coordinator._async_cancel_requested:
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
	_update_build_progress(total_chunks, total_chunks, "Applying 3D overlays... %d%%" % clampi(pct, 0, 100))
	_bump_3d_viewport_rendering()
	if done:
		_finalize_async_overlay_apply()

func _finalize_async_overlay_apply() -> void:
	if _authored_overlay != null and is_instance_valid(_authored_overlay):
		_overlay_apply_manager.finalize_apply_overlay_node(_authored_overlay, _async_overlay_apply_state)
	var dynamic_apply_started_usec := Time.get_ticks_usec()
	_apply_dynamic_overlay(_async_dynamic_overlay_descriptors)
	_apply_geometry_distance_culling_to_overlay()
	var metrics := _async_overlay_metrics
	var pc: Dictionary = UATerrainPieceLibraryScript.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	metrics["overlay_node_creation_ms"] = _elapsed_ms_since(_async_overlay_apply_started_usec)
	metrics["static_overlay_apply_ms"] = metrics["overlay_node_creation_ms"]
	metrics["dynamic_overlay_apply_ms"] = _elapsed_ms_since(dynamic_apply_started_usec)
	_last_build_metrics = metrics
	_chunk_rt.initial_build_in_progress = false
	_chunk_rt.initial_build_accumulated_authored_descriptors.clear()
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
	else:
		_flush_pending_unit_changes()

func _cancel_async_initial_build() -> void:
	_coordinator.cancel_async_build(_async_overlay_apply_active)

func _join_async_thread() -> void:
	_coordinator.join_async_thread()

func _reset_async_build_state() -> void:
	_coordinator.reset_async_state()
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
	_async_overlay_descriptor_dynamic_only = false
	_overlay_only_refresh_requested = false
	_dynamic_overlay_refresh_requested = false
	_skip_next_map_changed_refresh = false

func _sync_terrain_overlay_animation_mode_from_editor() -> void:
	var es := _editor_state()
	var anims_on := true
	if es != null:
		var raw: Variant = es.get("map_3d_terrain_overlay_animations_enabled")
		if typeof(raw) == TYPE_BOOL:
			anims_on = raw
	UATerrainPieceLibraryScript.set_force_static_terrain_overlays(not anims_on)

func _apply_debug_mode_to_existing_materials() -> void:
	# Update cached terrain materials (shared across all chunks).
	for surface_type in _terrain_material_cache:
		var mat: ShaderMaterial = _terrain_material_cache[surface_type]
		mat.set_shader_parameter("debug_mode", _debug_shader_mode)
	# Also update any chunk-local materials not yet in cache (e.g. legacy path).
	for chunk_coord in _terrain_chunk_nodes:
		var node: MeshInstance3D = _terrain_chunk_nodes[chunk_coord]
		if node == null or node.mesh == null:
			continue
		for si in node.mesh.get_surface_count():
			var mat := node.mesh.surface_get_material(si)
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
			_camera.translate_object_local(Vector3(0, 0, -_wheel_step()))
			_update_geometry_distance_culling_visibility()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.translate_object_local(Vector3(0, 0, _wheel_step()))
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
	_framed = bool(frame_result.get("framed", false))
	_update_geometry_distance_culling_visibility()


func _on_map_3d_focus_sector_requested(sector_sx: int, sector_sy: int) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var cmd := _current_map_data()
	if cmd == null:
		return
	var w := int(cmd.horizontal_sectors)
	var h := int(cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	var frame_result := ViewController.frame_camera_to_sector(_camera, cmd, sector_sx, sector_sy, SECTOR_SIZE, HEIGHT_SCALE)
	if frame_result.is_empty():
		return
	_pitch = float(frame_result.get("pitch", _pitch))
	_yaw = float(frame_result.get("yaw", _yaw))
	_framed = bool(frame_result.get("framed", false))
	_update_geometry_distance_culling_visibility()
	if _preview_refresh_active():
		_bump_3d_viewport_rendering()

func _on_map_changed() -> void:
	if _skip_next_map_changed_refresh:
		_skip_next_map_changed_refresh = false
		return
	_cancel_async_initial_build()
	var has_localized_invalidation := _chunk_rt.take_localized_chunk_invalidation_pending()
	var _cmd = _current_map_data()

	if _cmd:
		var w := int(_cmd.horizontal_sectors)
		var h := int(_cmd.vertical_sectors)
		if w > 0 and h > 0:
			var hgt: PackedByteArray = _cmd.hgt_map
			var typ: PackedByteArray = _cmd.typ_map
			var blg: PackedByteArray = _cmd.blg_map
			var level_set := int(_cmd.level_set)
			var signature_changed := _is_map_signature_changed(w, h, level_set, hgt, typ, blg)
			_record_map_signature(w, h, level_set, hgt, typ, blg)
			if signature_changed and not has_localized_invalidation:
				# Any map-array checksum change means terrain content potentially changed.
				# Force dirty chunks so stale incremental chunk sets cannot miss distant sectors.
				_invalidate_all_chunks(w, h)
				_effective_typ_service.set_dirty(true)
				_clear_localized_overlay_scope()
		_request_refresh(false)

func _on_map_created() -> void:
	_cancel_async_initial_build()
	var _cmd = _current_map_data()
	if _cmd:
		_effective_typ_service.invalidate_cache()
		_effective_typ_service.set_dirty(true)
		# Seed dirty chunks for non-blocking initial terrain creation.
		# This enables the incremental chunk path immediately after map load.
		var w := int(_cmd.horizontal_sectors)
		var h := int(_cmd.vertical_sectors)
		var level_set := int(_cmd.level_set)
		_chunk_rt.last_map_dimensions = Vector2i(w, h)
		_chunk_rt.last_level_set = level_set
		_clear_chunk_nodes()
		_set_authored_overlay([])
		_clear_localized_overlay_scope()
		_chunk_rt.clear_dirty_chunks()
		_chunk_rt.clear_authored_caches()
		_chunk_rt.invalidate_all_chunks(w, h)
		_chunk_rt.initial_build_in_progress = true
		_chunk_rt.initial_build_accumulated_authored_descriptors.clear()
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
	_effective_typ_service.set_dirty(false)
	var invalidation := InvalidationRouter.invalidation_for_hgt_border_indices(border_indices, w, h)
	mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))

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
	_effective_typ_service.set_dirty(true)
	var invalidation := InvalidationRouter.invalidation_for_typ_indices(typ_indices, w, h)
	mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))

func _on_blg_map_cells_edited(blg_indices: Array) -> void:
	_cancel_async_initial_build()
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_effective_typ_service.set_dirty(true)
	var invalidation := InvalidationRouter.invalidation_for_blg_indices(blg_indices, w, h)
	mark_chunks_dirty(invalidation.get("dirty_chunks", []))
	_record_localized_overlay_sectors(invalidation.get("dirty_sectors", []))

func build_from_current_map() -> void:
	var build_started_usec := Time.get_ticks_usec()
	var metrics := _make_empty_build_metrics()
	_sync_terrain_overlay_animation_mode_from_editor()
	var _cmd = _current_map_data()
	if _cmd == null:
		clear()
		_finalize_build_metrics(metrics, build_started_usec)
		return
	var w: int = int(_cmd.horizontal_sectors)
	var h: int = int(_cmd.vertical_sectors)
	var hgt: PackedByteArray = _cmd.hgt_map
	var typ: PackedByteArray = _cmd.typ_map
	var blg: PackedByteArray = _cmd.blg_map
	var expected := (w + 2) * (h + 2)
	if w <= 0 or h <= 0 or hgt.size() != expected or typ.size() != w * h:
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
	var can_reuse_effective_typ := _effective_typ_service.is_valid_cache(w, h, game_data_type, typ_checksum, blg_checksum)
	if can_reuse_effective_typ:
		effective_typ = _effective_typ_service.get_effective_typ()
	else:
		effective_typ = _compute_effective_typ_for_map(_cmd, w, h, typ, blg, game_data_type)
	_async_effective_typ = effective_typ

	var pre = _preloads()
	if pre == null:
		var fallback_started_usec := Time.get_ticks_usec()
		var fallback_mesh := build_mesh(hgt, w, h)
		metrics["terrain_build_ms"] = _elapsed_ms_since(fallback_started_usec)
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
	var requires_full_rebuild := _needs_full_rebuild(w, h, level_set)
	if _chunk_rt.chunked_terrain_enabled and requires_full_rebuild:
		_clear_chunk_nodes()
		_chunk_rt.clear_authored_caches()
		_chunk_rt.prepare_chunked_full_rebuild(w, h, level_set)
		requires_full_rebuild = false
	var use_chunked := _chunk_rt.chunked_terrain_enabled and not requires_full_rebuild

	var terrain_started_usec := Time.get_ticks_usec()
	var authored_piece_descriptors: Array = []
	var support_descriptors: Array = []
	var overlay_descriptors: Array = []
	var processed_chunks: Array = []
	var localized_overlay_sectors := _localized_overlay_sector_list()
	var localized_dynamic_sectors := _localized_dynamic_sector_list()
	metrics["dirty_sector_count"] = localized_overlay_sectors.size()
	metrics["dirty_chunk_count"] = _chunk_rt.get_dirty_chunk_count()

	if use_chunked:
		if _chunk_rt.has_dirty_chunks():
			var terrain_cache_snapshot_descriptors: Array = _chunk_rt.get_support_descriptors()
			if _terrain_mesh:
				_terrain_mesh.mesh = null
			if _edge_mesh:
				_edge_mesh.mesh = null
			var max_chunks := -1
			var is_initial_batch := _chunk_rt.initial_build_in_progress
			if is_initial_batch:
				max_chunks = _chunk_rt.initial_build_batch_size
			var rebuild_result := _rebuild_dirty_chunks(hgt, effective_typ, w, h, pre, level_set, metrics, max_chunks)
			var batch_authored_descriptors: Array = rebuild_result.get("descriptors", [])
			processed_chunks = rebuild_result.get("processed_chunks", [])
			metrics["terrain_build_ms"] = _elapsed_ms_since(terrain_started_usec)
			metrics["incremental_rebuild"] = true

			if is_initial_batch:
				_chunk_rt.initial_build_accumulated_authored_descriptors.append_array(batch_authored_descriptors)
				metrics["terrain_authored_descriptor_count"] = _chunk_rt.initial_build_accumulated_authored_descriptors.size()
				if _chunk_rt.has_dirty_chunks():
					_finalize_build_metrics(metrics, build_started_usec)
					_request_refresh(false)
					return
				authored_piece_descriptors = _chunk_rt.initial_build_accumulated_authored_descriptors
				_chunk_rt.initial_build_in_progress = false
				_chunk_rt.initial_build_accumulated_authored_descriptors.clear()
			else:
				authored_piece_descriptors = batch_authored_descriptors
				metrics["terrain_authored_descriptor_count"] = authored_piece_descriptors.size()

			var cached_terrain_descriptors: Array = _chunk_rt.get_support_descriptors()
			if cached_terrain_descriptors.is_empty():
				if not terrain_cache_snapshot_descriptors.is_empty():
					cached_terrain_descriptors = terrain_cache_snapshot_descriptors.duplicate()
				else:
					cached_terrain_descriptors = authored_piece_descriptors.duplicate()
			else:
				cached_terrain_descriptors = cached_terrain_descriptors.duplicate()
			support_descriptors = cached_terrain_descriptors
			overlay_descriptors = cached_terrain_descriptors.duplicate()
			metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
		else:
			support_descriptors = _chunk_rt.get_support_descriptors().duplicate()
			overlay_descriptors = support_descriptors.duplicate()
			metrics["terrain_authored_descriptor_count"] = support_descriptors.size()
	else:
		_clear_chunk_nodes()
		_invalidate_all_chunks(w, h)
		_chunk_rt.last_map_dimensions = Vector2i(w, h)
		_chunk_rt.last_level_set = level_set

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
		if _terrain_mesh:
			_terrain_mesh.mesh = mesh
			_apply_sector_top_materials(mesh, pre, surface_to_surface_type)

		var edge_started_usec := Time.get_ticks_usec()
		if _edge_overlay_enabled and effective_typ.size() == w * h:
			var edge_result := _build_edge_overlay_result(hgt, w, h, effective_typ, pre.surface_type_map, level_set, pre)
			var edge_authored_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
			metrics["edge_authored_descriptor_count"] = edge_authored_descriptors.size()
			support_descriptors.append_array(edge_authored_descriptors)
			overlay_descriptors.append_array(edge_authored_descriptors)
			_ensure_edge_node()
			_edge_mesh.mesh = edge_result.get("mesh", null)
		else:
			if _edge_mesh:
				_edge_mesh.mesh = null
		metrics["edge_slurp_build_ms"] = _elapsed_ms_since(edge_started_usec)
		_chunk_rt.clear_dirty_chunks()
		_reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)

	var can_use_localized_overlay_refresh := use_chunked and not _chunk_rt.initial_build_in_progress and not processed_chunks.is_empty() and not localized_overlay_sectors.is_empty()
	var overlay_descriptor_started_usec := Time.get_ticks_usec()
	if can_use_localized_overlay_refresh:
		var localized_static_descriptors: Array = authored_piece_descriptors.duplicate()
		localized_static_descriptors.append_array(OverlayProducers.build_blg_attachment_descriptors_for_sectors(
			blg,
			effective_typ,
			int(_cmd.level_set),
			hgt,
			w,
			h,
			localized_overlay_sectors,
			game_data_type
		))
		metrics["static_overlay_descriptor_generation_ms"] = _elapsed_ms_since(overlay_descriptor_started_usec)
		metrics["overlay_descriptor_generation_ms"] = metrics["static_overlay_descriptor_generation_ms"]
		metrics["overlay_descriptor_count"] = localized_static_descriptors.size()
		var overlay_node_started_usec := Time.get_ticks_usec()
		_apply_localized_static_overlay_refresh(localized_static_descriptors, processed_chunks, localized_overlay_sectors, int(_cmd.level_set), w, h)
		metrics["static_overlay_apply_ms"] = _elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]
		var dynamic_descriptor_started_usec := Time.get_ticks_usec()
		_apply_localized_dynamic_overlay_refresh(_cmd, int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type, localized_dynamic_sectors, metrics)
		metrics["dynamic_overlay_descriptor_generation_ms"] = _elapsed_ms_since(dynamic_descriptor_started_usec)
		metrics["dynamic_overlay_apply_ms"] = 0.0
		metrics["localized_overlay_refresh"] = true
	else:
		overlay_descriptors.append_array(_build_blg_attachment_descriptors(blg, effective_typ, int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type))
		if _cmd.host_stations != null and is_instance_valid(_cmd.host_stations):
			overlay_descriptors.append_array(_build_host_station_descriptors(_cmd.host_stations.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors, metrics))
		if _cmd.squads != null and is_instance_valid(_cmd.squads):
			overlay_descriptors.append_array(_build_squad_descriptors(_cmd.squads.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type, metrics))
		metrics["overlay_descriptor_generation_ms"] = _elapsed_ms_since(overlay_descriptor_started_usec)
		metrics["static_overlay_descriptor_generation_ms"] = metrics["overlay_descriptor_generation_ms"]
		metrics["overlay_descriptor_count"] = overlay_descriptors.size()
		var overlay_node_started_usec := Time.get_ticks_usec()
		_set_authored_overlay(overlay_descriptors)
		metrics["static_overlay_apply_ms"] = _elapsed_ms_since(overlay_node_started_usec)
		metrics["overlay_node_creation_ms"] = metrics["static_overlay_apply_ms"]
	var pc: Dictionary = UATerrainPieceLibraryScript.get_piece_overlay_build_counters()
	metrics["piece_overlay_fast_path"] = int(pc.get("piece_overlay_fast_path", 0))
	metrics["piece_overlay_slow_path"] = int(pc.get("piece_overlay_slow_path", 0))
	_clear_localized_overlay_scope()
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
	_terrain_material_cache.clear()
	_edge_material_cache.clear()
	if _terrain_mesh:
		_terrain_mesh.mesh = null
	if _edge_mesh:
		_edge_mesh.mesh = null
	_clear_chunk_nodes()
	_set_authored_overlay([])
	_clear_localized_overlay_scope()

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
	_chunk_rt.clear_dirty_chunks()

func _invalidate_all_chunks(w: int, h: int) -> void:
	_chunk_rt.invalidate_all_chunks(w, h)

func _is_map_signature_changed(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> bool:
	return _coordinator.is_map_signature_changed(w, h, level_set, hgt, typ, blg)

func _record_map_signature(w: int, h: int, level_set: int, hgt: PackedByteArray, typ: PackedByteArray, blg: PackedByteArray) -> void:
	_coordinator.record_map_signature(w, h, level_set, hgt, typ, blg)

func _invalidate_chunks_for_sector_edit(sx: int, sy: int, w: int, h: int, edit_type: String) -> void:
	_chunk_rt.invalidate_chunks_for_sector_edit(sx, sy, w, h, edit_type)

func mark_chunks_dirty(chunk_coords: Array) -> void:
	if chunk_coords.is_empty():
		return
	_chunk_rt.explicit_chunk_invalidation_pending = true
	_chunk_rt.localized_chunk_invalidation_pending = true
	for chunk_value in chunk_coords:
		if chunk_value is Vector2i:
			_chunk_rt.mark_chunk_dirty(Vector2i(chunk_value))

func mark_sector_dirty(sx: int, sy: int, edit_type: String = "hgt") -> void:
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_chunk_rt.explicit_chunk_invalidation_pending = true
	_invalidate_chunks_for_sector_edit(sx, sy, w, h, edit_type)
	_record_localized_overlay_sectors([Vector2i(sx, sy)])

func mark_sectors_dirty(sectors: Array, edit_type: String = "hgt") -> void:
	var _cmd = _current_map_data()
	if _cmd == null:
		return
	var w := int(_cmd.horizontal_sectors)
	var h := int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	_chunk_rt.explicit_chunk_invalidation_pending = true
	for sector in sectors:
		if sector is Vector2i:
			_invalidate_chunks_for_sector_edit(sector.x, sector.y, w, h, edit_type)
			_record_localized_overlay_sectors([Vector2i(sector)])
		elif sector is Vector2:
			_invalidate_chunks_for_sector_edit(int(sector.x), int(sector.y), w, h, edit_type)
			_record_localized_overlay_sectors([Vector2i(int(sector.x), int(sector.y))])

func get_dirty_chunk_count() -> int:
	return _chunk_rt.get_dirty_chunk_count()

func is_using_chunked_terrain() -> bool:
	return _chunk_rt.chunked_terrain_enabled

func set_chunked_terrain_enabled(enabled: bool) -> void:
	_chunk_rt.chunked_terrain_enabled = enabled

func _needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	var has_chunk_nodes := not _terrain_chunk_nodes.is_empty()
	return _chunk_rt.needs_full_rebuild(w, h, level_set, has_chunk_nodes)

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
	_chunk_rt.update_terrain_authored_cache_for_chunk(chunk_coord, chunk_descriptors)

func _reset_terrain_authored_cache_from_descriptors(support_descriptors: Array, w: int, h: int) -> void:
	_chunk_rt.reset_terrain_authored_cache_from_descriptors(support_descriptors, w, h)

func _rebuild_dirty_chunks(
	hgt: PackedByteArray,
	effective_typ: PackedByteArray,
	w: int,
	h: int,
	pre: Node,
	level_set: int,
	metrics: Dictionary,
	max_chunks: int = -1
) -> Dictionary:
	var all_authored_descriptors: Array = []
	var chunks_rebuilt := 0
	var processed: Array[Vector2i] = []
	var apply_started_usec := Time.get_ticks_usec()
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
		_chunk_rt.erase_dirty_chunk(chunk_coord)
	metrics["chunks_rebuilt"] = chunks_rebuilt
	metrics["chunk_apply_ms"] = _elapsed_ms_since(apply_started_usec)
	return {
		"descriptors": all_authored_descriptors,
		"processed_chunks": processed,
	}

static func _chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy

func _dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	var focus_chunk := _chunk_focus_coord(w, h)
	return _chunk_rt.dirty_chunks_sorted_by_priority(focus_chunk)

func _chunk_focus_coord(w: int, h: int) -> Vector2i:
	if _camera != null and is_instance_valid(_camera):
		var world_pos := _camera.global_position if _camera.is_inside_tree() else _camera.position
		var sx := clampi(_world_to_sector_index(world_pos.x), 0, maxi(w - 1, 0))
		var sy := clampi(_world_to_sector_index(world_pos.z), 0, maxi(h - 1, 0))
		return TerrainBuilder.sector_to_chunk(sx, sy)
	var center_sx := maxi(w / 2, 0)
	var center_sy := maxi(h / 2, 0)
	return TerrainBuilder.sector_to_chunk(center_sx, center_sy)

func _apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	if _authored_overlay == null or not is_instance_valid(_authored_overlay):
		return
	var prefixes := StaticOverlayIndex.terrain_prefixes_for_chunks(set_id, affected_chunks, w, h)
	prefixes.append_array(StaticOverlayIndex.building_attachment_prefixes_for_sectors(set_id, affected_sectors))
	if prefixes.is_empty():
		return
	_static_overlay_index.replace_matching_prefixes(prefixes, replacement_descriptors)
	AuthoredOverlayManager.apply_overlay_for_prefixes(_authored_overlay, prefixes, replacement_descriptors)


func _apply_localized_dynamic_overlay_refresh(cmd: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	if affected_sectors.is_empty():
		return
	_ensure_overlay_nodes()
	var descriptors: Array = []
	if cmd.host_stations != null and is_instance_valid(cmd.host_stations):
		descriptors.append_array(OverlayProducers.build_host_station_descriptors_for_sectors(
			cmd.host_stations.get_children(),
			set_id,
			hgt,
			w,
			h,
			affected_sectors,
			support_descriptors,
			metrics
		))
	if cmd.squads != null and is_instance_valid(cmd.squads):
		descriptors.append_array(OverlayProducers.build_squad_descriptors_for_sectors(
			cmd.squads.get_children(),
			set_id,
			hgt,
			w,
			h,
			affected_sectors,
			support_descriptors,
			game_data_type,
			metrics
		))
	var prefixes := StaticOverlayIndex.exact_instance_key_prefixes(descriptors)
	if prefixes.is_empty():
		return
	AuthoredOverlayManager.apply_overlay_for_prefixes(_dynamic_overlay, prefixes, descriptors)
	_apply_geometry_distance_culling_to_overlay()


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
	_static_overlay_index.replace_all(static_descriptors)
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
	var w := maxi(_chunk_rt.last_map_dimensions.x, 0)
	var h := maxi(_chunk_rt.last_map_dimensions.y, 0)
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
	return OverlayProducers.snapshot_host_station_nodes(host_stations)

static func _build_host_station_descriptors_from_snapshot(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return OverlayProducers.build_host_station_descriptors_from_snapshot(host_stations, set_id, hgt, w, h, support_descriptors, profile)

static func _build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = [], profile = null) -> Array:
	return OverlayProducers.build_host_station_descriptors(host_stations, set_id, hgt, w, h, support_descriptors, profile)

static func _clear_runtime_lookup_caches_for_tests() -> void:
	EffectiveTypService.clear_runtime_lookup_caches_for_tests()

static func _blg_typ_overrides_for_game_data_type(game_data_type: String) -> Dictionary:
	return EffectiveTypService.blg_typ_overrides_for_game_data_type(game_data_type)

static func _building_sec_type_overrides_for_script_names(set_id: int, game_data_type: String, script_names: Array[String]) -> Dictionary:
	return EffectiveTypService.building_sec_type_overrides_for_script_names(set_id, game_data_type, script_names)

static func _tech_upgrade_typ_overrides_for_3d(set_id: int, game_data_type: String) -> Dictionary:
	return EffectiveTypService.tech_upgrade_typ_overrides_for_3d(set_id, game_data_type)

static func _entity_property(entity: Variant, property_names: Array[String], default_value: Variant = null) -> Variant:
	return EffectiveTypService.entity_property(entity, property_names, default_value)

static func _entity_int_property(entity: Variant, property_names: Array[String], default_value := -1) -> int:
	return EffectiveTypService.entity_int_property(entity, property_names, default_value)

static func _apply_sector_building_overrides_from_entities(
		effective: PackedByteArray,
		w: int,
		h: int,
		entities: Array,
		building_property_names: Array[String],
		building_sec_type_overrides: Dictionary
	) -> void:
	EffectiveTypService.apply_sector_building_overrides_from_entities(effective, w, h, entities, building_property_names, building_sec_type_overrides)

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
	return EffectiveTypService.effective_typ_map_for_3d(typ, blg, game_data_type, w, h, beam_gates, tech_upgrades, stoudson_bombs, set_id)

static func _parse_building_definitions(script_path: String) -> Array:
	return LegacyScriptParser.parse_building_definitions(script_path)

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
	return OverlayProducers.build_blg_attachment_descriptors(blg, effective_typ, set_id, hgt, w, h, _support_descriptors, game_data_type)

static func _parse_vehicle_visual_entries(script_path: String) -> Dictionary:
	return LegacyScriptParser.parse_vehicle_visual_entries(script_path)

static func _vehicle_visual_entries_for_game_data_type(set_id: int, game_data_type: String) -> Dictionary:
	return VisualLookupService._vehicle_visual_entries_for_game_data_type(set_id, game_data_type)

static func _parse_vehicle_visual_pairs(script_path: String) -> Dictionary:
	return LegacyScriptParser.parse_vehicle_visual_pairs(script_path)

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
	return OverlayProducers.squad_formation_offsets(quantity)

static func _snapshot_squad_nodes(squads: Array) -> Array:
	return OverlayProducers.snapshot_squad_nodes(squads)


static func _build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors_from_snapshot(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)


static func _build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)

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
								0
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
						0
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
	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type, "authored_piece_descriptors": authored_piece_descriptors}

func _apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	if mesh == null:
		return
	if preloads == null:
		_apply_untextured_materials(mesh)
		return

	if _sector_top_shader == null:
		_sector_top_shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	if _sector_top_shader == null:
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

		if _terrain_material_cache.has(surface_type):
			mesh.surface_set_material(surface_idx, _terrain_material_cache[surface_type])
			continue

		var mat := ShaderMaterial.new()
		mat.shader = _sector_top_shader
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
		_terrain_material_cache[surface_type] = mat
		mesh.surface_set_material(surface_idx, mat)

# ---- UA edge-based strip rendering ----
func _on_level_set_changed() -> void:
	# A set switch can change sector pattern topology and authored overlay descriptors.
	# Reset chunk/runtime caches so we never keep mixed old/new set chunk outputs.
	_terrain_material_cache.clear()
	_edge_material_cache.clear()
	_cancel_async_initial_build()
	_effective_typ_service.invalidate_cache()
	_effective_typ_service.set_dirty(true)
	var cmd := _current_map_data()
	if cmd != null:
		var w := int(cmd.horizontal_sectors)
		var h := int(cmd.vertical_sectors)
		if w > 0 and h > 0:
			_clear_chunk_nodes()
			_set_authored_overlay([])
			_chunk_rt.clear_dirty_chunks()
			_chunk_rt.clear_authored_caches()
			_chunk_rt.last_map_dimensions = Vector2i(w, h)
			_chunk_rt.last_level_set = int(cmd.level_set)
			_chunk_rt.invalidate_all_chunks(w, h)
			_chunk_rt.initial_build_in_progress = true
			_chunk_rt.initial_build_accumulated_authored_descriptors.clear()
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
	if preloads == null and is_inside_tree():
		preloads = _preloads()

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
			_append_vertical_fallback_group(fallback_horiz, _retail_slurp_bucket_key(sa, sb, 1, 0), float(x + 2) * SECTOR_SIZE, float(y + 1) * SECTOR_SIZE, float(y + 2) * SECTOR_SIZE, yL, yR, yTopAvg, yBottomAvg)

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
	if _edge_blend_shader == null:
		_edge_blend_shader = load(EDGE_BLEND_SHADER_PATH)
	if _edge_blend_shader == null:
		push_warning("[Map3D] Could not load edge_blend.gdshader")
		return _make_preview_material(EDGE_PREVIEW_COLOR)

	var cache_key := "%s:%s" % [bucket_key, use_uv_y_for_blend]
	if _edge_material_cache.has(cache_key):
		return _edge_material_cache[cache_key]

	var mat := ShaderMaterial.new()
	mat.shader = _edge_blend_shader
	mat.set_shader_parameter("texture_a", preloads.get_ground_texture(int(pair["surface_a"])))
	mat.set_shader_parameter("texture_b", preloads.get_ground_texture(int(pair["surface_b"])))
	mat.set_shader_parameter("vertical_seam", use_uv_y_for_blend)
	mat.set_shader_parameter("tile_scale", _compute_tile_scale())
	mat.set_shader_parameter("atlas_grid", Vector2(1.0, 1.0))
	mat.set_shader_parameter("variant_a", 0)
	mat.set_shader_parameter("variant_b", 0)
	_edge_material_cache[cache_key] = mat
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

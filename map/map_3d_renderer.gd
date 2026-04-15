extends Node3D
class_name Map3DRenderer

signal build_state_changed(is_building: bool, completed: int, total: int, status: String)
signal build_finished(success: bool)

const VisualLookupService := preload("res://map/3d/services/map_3d_visual_lookup_service.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const SlurpBuilder := preload("res://map/3d/terrain/map_3d_slurp_builder.gd")
const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const ViewController := preload("res://map/3d/controllers/map_3d_view_controller.gd")
const RendererEventController := preload("res://map/3d/controllers/map_3d_renderer_event_controller.gd")
const AsyncRefreshDriver := preload("res://map/3d/runtime/map_3d_async_refresh_driver.gd")
const CameraController := preload("res://map/3d/runtime/map_3d_camera_controller.gd")
const SceneGraph := preload("res://map/3d/runtime/map_3d_scene_graph.gd")
const RenderContextPort := preload("res://map/3d/runtime/map_3d_render_context_port.gd")
const ScenePort := preload("res://map/3d/runtime/map_3d_scene_port.gd")
const BuildStatePort := preload("res://map/3d/runtime/map_3d_build_state_port.gd")
const AsyncMapSnapshot := preload("res://map/3d/runtime/map_3d_async_map_snapshot.gd")
const OverlayRefreshScope := preload("res://map/3d/runtime/map_3d_overlay_refresh_scope.gd")
const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")
const RuntimeState := preload("res://map/3d/runtime/map_3d_runtime_state.gd")
const RuntimeContext := preload("res://map/3d/runtime/map_3d_runtime_context.gd")
const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const VisualCatalog := preload("res://map/3d/config/map_3d_visual_catalog.gd")
const PreviewGeometry := preload("res://map/3d/terrain/map_3d_preview_geometry.gd")
const OverlayPositioning := preload("res://map/3d/overlays/map_3d_overlay_positioning.gd")
const RefreshCoordinator := preload("res://map/3d/services/map_3d_refresh_coordinator.gd")
const ChunkRuntime := preload("res://map/3d/services/map_3d_chunk_runtime.gd")
const EffectiveTypService := preload("res://map/3d/services/map_3d_effective_typ_service.gd")
const OverlayProducers := preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const LegacyScriptParser := preload("res://map/3d/parsers/map_3d_legacy_script_parser.gd")
const UnitOverlayController := preload("res://map/3d/overlays/map_3d_unit_overlay_controller.gd")
const InvalidationRouter := preload("res://map/3d/services/map_3d_invalidation_router.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")
const UnitRuntimeIndex := preload("res://map/3d/services/map_3d_unit_runtime_index.gd")
const BuildPipeline := preload("res://map/3d/services/map_3d_build_pipeline.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE
# The 2D editor / UA coordinate system uses a 1200-unit sector span.
# The 3D preview + authored-piece sampling operates in scaled-world units
# where that span is 1.0. This constant is used to convert UA->scaled.
const WORLD_SCALE := SharedConstants.WORLD_SCALE
const EDGE_SLOPE := SharedConstants.EDGE_SLOPE # Per-side width; UA fillers span ~300 across seam (~150 into each sector)
const BORDER_TYP_TOP_LEFT := SharedConstants.BORDER_TYP_TOP_LEFT
const BORDER_TYP_TOP := SharedConstants.BORDER_TYP_TOP
const BORDER_TYP_TOP_RIGHT := SharedConstants.BORDER_TYP_TOP_RIGHT
const BORDER_TYP_LEFT := SharedConstants.BORDER_TYP_LEFT
const BORDER_TYP_RIGHT := SharedConstants.BORDER_TYP_RIGHT
const BORDER_TYP_BOTTOM_LEFT := SharedConstants.BORDER_TYP_BOTTOM_LEFT
const BORDER_TYP_BOTTOM := SharedConstants.BORDER_TYP_BOTTOM
const BORDER_TYP_BOTTOM_RIGHT := SharedConstants.BORDER_TYP_BOTTOM_RIGHT
const TERRAIN_PREVIEW_COLOR := Color(0.62, 0.66, 0.58, 1.0)
const EDGE_PREVIEW_COLOR := Color(0.82, 0.48, 0.24, 0.55)
const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"
const SUBQUAD_UV_INSET := 0.002 # Prevent internal 1/3 and 2/3 seam sampling bleed
const UA_NORMAL_RENDER_SECTORS := 5
const UA_NORMAL_GEOMETRY_CULL_DISTANCE := float(UA_NORMAL_RENDER_SECTORS) * SECTOR_SIZE + SECTOR_SIZE * 0.5
const _ASYNC_APPLY_RESULTS_PER_FRAME := 4
const _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 48
const _MAX_INCREMENTAL_UNIT_BATCH := 64
const HOST_STATION_BASE_NAMES := VisualCatalog.HOST_STATION_BASE_NAMES
const HOST_STATION_VISIBLE_GUN_BASE_NAMES := VisualCatalog.HOST_STATION_VISIBLE_GUN_BASE_NAMES
const HOST_STATION_GUN_ATTACHMENTS := VisualCatalog.HOST_STATION_GUN_ATTACHMENTS
const TECH_UPGRADE_EDITOR_TYP_OVERRIDES := VisualCatalog.TECH_UPGRADE_EDITOR_TYP_OVERRIDES
const SQUAD_FORMATION_SPACING := SharedConstants.SQUAD_FORMATION_SPACING
const SQUAD_EXTRA_Y_OFFSET := SharedConstants.SQUAD_EXTRA_Y_OFFSET

func _init() -> void:
	_runtime_context.bind(self)
	_render_context_port.bind(self)
	_scene_port.bind(self)
	_build_state_port.bind(self)
	_async_refresh_driver.bind(self, _render_context_port, _scene_port, _build_state_port)
	_camera_controller.bind(self, _render_context_port, _scene_port)
	_scene_graph.bind(_scene_port, _render_context_port, _runtime_state, _chunk_rt, _overlay_refresh_scope)
	_renderer_event_controller.bind(
		self,
		_render_context_port,
		_scene_port,
		_async_refresh_driver,
		_chunk_rt,
		_effective_typ_service,
		_overlay_refresh_scope,
		_runtime_state
	)
	_build_pipeline.bind(
		self,
		_render_context_port,
		_scene_port,
		_async_map_snapshot,
		_overlay_refresh_scope,
		_chunk_rt,
		_effective_typ_service,
		_unit_runtime_index,
		_static_overlay_index
	)
	_geometry_cull_distance = UA_NORMAL_GEOMETRY_CULL_DISTANCE


func _retain_collaborator_owned_state() -> void:
	# These fields intentionally stay reachable on the renderer facade for
	# compatibility while the real mutable storage lives in shared runtime state.
	var retained_state := [
		_runtime_state,
		_runtime_context,
		_terrain_mesh,
		_authored_overlay,
		_dynamic_overlay,
		_edge_overlay_enabled,
		_edge_chunk_nodes,
		_geometry_distance_culling_enabled,
		_geometry_cull_distance,
		_sector_top_shader,
		_edge_blend_shader,
		_async_pending_reframe_camera,
		_async_map_snapshot,
		_overlay_refresh_scope,
		_async_requested_restart,
		_async_requested_reframe,
		_async_overlay_apply_state,
		_async_overlay_descriptors,
		_async_dynamic_overlay_descriptors,
		_async_overlay_metrics,
		_async_build_started_usec,
		_async_overlay_apply_started_usec,
		_async_overlay_descriptor_dynamic_only,
		_async_overlay_apply_active,
		_overlay_only_refresh_requested,
		_dynamic_overlay_refresh_requested,
		_pending_unit_changes,
		_overlay_apply_manager,
	]
	if retained_state.size() < 0:
		push_error("unreachable collaborator state marker")

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

@onready var _camera: Camera3D = $Camera3D
@onready var _world_environment: WorldEnvironment = $WorldEnvironment if has_node("WorldEnvironment") else null

var _runtime_state := RuntimeState.new()
var _runtime_context := RuntimeContext.new()
var _render_context_port := RenderContextPort.new()
var _scene_port := ScenePort.new()
var _build_state_port := BuildStatePort.new()
var _async_map_snapshot := AsyncMapSnapshot.new()
var _overlay_refresh_scope := OverlayRefreshScope.new()

var _debug_shader_mode: int:
	get:
		return _runtime_state.debug_shader_mode
	set(value):
		_runtime_state.debug_shader_mode = int(value)

var _last_build_metrics: Dictionary:
	get:
		return _runtime_state.last_build_metrics
	set(value):
		_runtime_state.last_build_metrics = Dictionary(value)

var _terrain_chunk_nodes: Dictionary:
	get:
		return _runtime_state.terrain_chunk_nodes
	set(value):
		_runtime_state.terrain_chunk_nodes = Dictionary(value)

var _edge_chunk_nodes: Dictionary:
	get:
		return _runtime_state.edge_chunk_nodes
	set(value):
		_runtime_state.edge_chunk_nodes = Dictionary(value)

var _geometry_distance_culling_enabled:
	get:
		return _runtime_state.geometry_distance_culling_enabled
	set(value):
		_runtime_state.geometry_distance_culling_enabled = bool(value)

var _geometry_cull_distance:
	get:
		return _runtime_state.geometry_cull_distance
	set(value):
		_runtime_state.geometry_cull_distance = float(value)

var _sector_top_shader: Shader:
	get:
		return _runtime_state.sector_top_shader
	set(value):
		_runtime_state.sector_top_shader = value

var _edge_blend_shader: Shader:
	get:
		return _runtime_state.edge_blend_shader
	set(value):
		_runtime_state.edge_blend_shader = value

var _terrain_material_cache: Dictionary:
	get:
		return _runtime_state.terrain_material_cache
	set(value):
		_runtime_state.terrain_material_cache = Dictionary(value)

var _edge_material_cache: Dictionary:
	get:
		return _runtime_state.edge_material_cache
	set(value):
		_runtime_state.edge_material_cache = Dictionary(value)

# Keep seam/slurp strips visible in the live preview; redundant flat/same-surface
# seams are filtered out in the builder to avoid needless overdraw.
var _edge_overlay_enabled:
	get:
		return _runtime_state.edge_overlay_enabled
	set(value):
		_runtime_state.edge_overlay_enabled = bool(value)

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
var is_building_3d:
	get:
		return _async_refresh_driver.is_building_3d
	set(value):
		_async_refresh_driver.is_building_3d = bool(value)
var total_chunks:
	get:
		return _async_refresh_driver.total_chunks
	set(value):
		_async_refresh_driver.total_chunks = int(value)
var completed_chunks:
	get:
		return _async_refresh_driver.completed_chunks
	set(value):
		_async_refresh_driver.completed_chunks = int(value)
var status_text:
	get:
		return _async_refresh_driver.status_text
	set(value):
		_async_refresh_driver.status_text = String(value)

var _async_pending_reframe_camera:
	get:
		return _async_refresh_driver._async_pending_reframe_camera
	set(value):
		_async_refresh_driver._async_pending_reframe_camera = bool(value)
var _async_effective_typ: PackedByteArray:
	get:
		return _async_map_snapshot.effective_typ
	set(value):
		_async_map_snapshot.effective_typ = value
var _async_blg: PackedByteArray:
	get:
		return _async_map_snapshot.blg
	set(value):
		_async_map_snapshot.blg = value
var _async_w:
	get:
		return _async_map_snapshot.w
	set(value):
		_async_map_snapshot.w = int(value)
var _async_h:
	get:
		return _async_map_snapshot.h
	set(value):
		_async_map_snapshot.h = int(value)
var _async_level_set:
	get:
		return _async_map_snapshot.level_set
	set(value):
		_async_map_snapshot.level_set = int(value)
var _async_game_data_type:
	get:
		return _async_map_snapshot.game_data_type
	set(value):
		_async_map_snapshot.game_data_type = String(value)
var _async_requested_restart:
	get:
		return _async_refresh_driver._async_requested_restart
	set(value):
		_async_refresh_driver._async_requested_restart = bool(value)
var _async_requested_reframe:
	get:
		return _async_refresh_driver._async_requested_reframe
	set(value):
		_async_refresh_driver._async_requested_reframe = bool(value)
var _async_overlay_apply_active:
	get:
		return _async_refresh_driver.is_async_overlay_apply_active()
	set(value):
		_async_refresh_driver._async_overlay_apply_active = bool(value)
var _async_overlay_apply_state: Dictionary:
	get:
		return _async_refresh_driver._async_overlay_apply_state
	set(value):
		_async_refresh_driver._async_overlay_apply_state = Dictionary(value)
var _async_overlay_descriptors: Array:
	get:
		return _async_refresh_driver._async_overlay_descriptors
	set(value):
		_async_refresh_driver._async_overlay_descriptors = Array(value)
var _async_dynamic_overlay_descriptors: Array:
	get:
		return _async_refresh_driver._async_dynamic_overlay_descriptors
	set(value):
		_async_refresh_driver._async_dynamic_overlay_descriptors = Array(value)
var _async_overlay_metrics: Dictionary:
	get:
		return _async_refresh_driver._async_overlay_metrics
	set(value):
		_async_refresh_driver._async_overlay_metrics = Dictionary(value)
var _async_build_started_usec:
	get:
		return _async_refresh_driver._async_build_started_usec
	set(value):
		_async_refresh_driver._async_build_started_usec = int(value)
var _async_overlay_apply_started_usec:
	get:
		return _async_refresh_driver._async_overlay_apply_started_usec
	set(value):
		_async_refresh_driver._async_overlay_apply_started_usec = int(value)
var _overlay_only_refresh_requested:
	get:
		return _async_refresh_driver._overlay_only_refresh_requested
	set(value):
		_async_refresh_driver._overlay_only_refresh_requested = bool(value)
var _dynamic_overlay_refresh_requested:
	get:
		return _async_refresh_driver._dynamic_overlay_refresh_requested
	set(value):
		_async_refresh_driver._dynamic_overlay_refresh_requested = bool(value)
var _async_overlay_descriptor_dynamic_only:
	get:
		return _async_refresh_driver._async_overlay_descriptor_dynamic_only
	set(value):
		_async_refresh_driver._async_overlay_descriptor_dynamic_only = bool(value)
var _skip_next_map_changed_refresh:
	get:
		return _runtime_state.skip_next_map_changed_refresh
	set(value):
		_runtime_state.skip_next_map_changed_refresh = bool(value)
var _pending_unit_changes:
	get:
		return _async_refresh_driver._pending_unit_changes
	set(value):
		_async_refresh_driver._pending_unit_changes = Array(value)
var _overlay_apply_manager:
	get:
		return _runtime_state.overlay_apply_manager
var _static_overlay_index:
	get:
		return _runtime_state.static_overlay_index
var _unit_runtime_index:
	get:
		return _runtime_state.unit_runtime_index
var _renderer_event_controller := RendererEventController.new()
var _build_pipeline := BuildPipeline.new()
var _async_refresh_driver := AsyncRefreshDriver.new()
var _camera_controller := CameraController.new()
var _scene_graph := SceneGraph.new()

func set_event_system_override(event_system: Node) -> void:
	_runtime_context.set_event_system_override(event_system)

func set_current_map_data_override(current_map_data: Node) -> void:
	_runtime_context.set_current_map_data_override(current_map_data)

func set_editor_state_override(editor_state: Node) -> void:
	_runtime_context.set_editor_state_override(editor_state)

func set_preloads_override(preloads: Node) -> void:
	_runtime_context.set_preloads_override(preloads)

func get_build_state_snapshot() -> Dictionary:
	return _async_refresh_driver.get_build_state_snapshot()

func has_pending_refresh() -> bool:
	return _async_refresh_driver.has_pending_refresh()

func get_last_build_metrics() -> Dictionary:
	if _last_build_metrics.is_empty():
		return _make_empty_build_metrics()
	return _last_build_metrics.duplicate(true)

func _make_empty_build_metrics() -> Dictionary:
	return BuildMetrics.empty_metrics()

func _emit_build_state(building: bool, completed: int, total: int, status: String) -> void:
	_async_refresh_driver.emit_build_state(building, completed, total, status)

func _begin_build_state(total_chunk_count: int, status: String) -> void:
	_async_refresh_driver.begin_build_state(total_chunk_count, status)

func _update_build_progress(completed: int, total: int, status: String = "") -> void:
	_async_refresh_driver.update_build_progress(completed, total, status)

func _end_build_state(success: bool, status: String = "") -> void:
	_async_refresh_driver.end_build_state(success, status)

func _is_async_build_active() -> bool:
	return _coordinator.is_async_build_active()

func _is_async_pipeline_active() -> bool:
	return _coordinator.is_async_pipeline_active(_async_refresh_driver.is_async_overlay_apply_active())

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
	_overlay_refresh_scope.record_sectors(sectors)


func _localized_overlay_sector_list() -> Array[Vector2i]:
	return _overlay_refresh_scope.overlay_sector_list()


func _localized_dynamic_sector_list() -> Array[Vector2i]:
	return _overlay_refresh_scope.dynamic_sector_list()


func _clear_localized_overlay_scope() -> void:
	_overlay_refresh_scope.clear()

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
	return BuildMetrics.elapsed_ms_since(started_usec)

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
	if _async_refresh_driver.get_refresh_requested_at_usec() > 0:
		metrics["refresh_end_to_end_ms"] = _elapsed_ms_since(_async_refresh_driver.get_refresh_requested_at_usec())
		_async_refresh_driver.clear_refresh_requested_at_usec()
	_last_build_metrics = metrics.duplicate(true)

func _event_system() -> Node:
	return _runtime_context.event_system()

func _current_map_data() -> Node:
	return _runtime_context.current_map_data()

func _editor_state() -> Node:
	return _runtime_context.editor_state()

func _preloads() -> Node:
	return _runtime_context.preloads()

func _preview_refresh_active() -> bool:
	return _runtime_context.preview_refresh_active(_is_async_pipeline_active())

func _is_3d_view_visible() -> bool:
	return _runtime_context.is_3d_view_visible()

func _apply_preview_activity_state() -> void:
	var in_3d := _runtime_context.is_3d_view_visible()
	set_physics_process(in_3d)
	set_process_unhandled_input(in_3d)

func _request_refresh(reframe_camera: bool) -> void:
	_async_refresh_driver.request_refresh(reframe_camera)

func _apply_pending_refresh() -> void:
	_async_refresh_driver.apply_pending_refresh()

func _ready() -> void:
	_retain_collaborator_owned_state()
	_sector_top_shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	_edge_blend_shader = load(EDGE_BLEND_SHADER_PATH)
	_renderer_event_controller.ready()

func _apply_visibility_range_from_editor_state() -> void:
	var enabled := _runtime_context.visibility_range_enabled()
	if _world_environment != null and _world_environment.environment != null:
		apply_visibility_range_to_environment(_world_environment.environment, enabled)
	_apply_geometry_distance_culling_state(enabled)

func _on_map_view_updated() -> void:
	_renderer_event_controller.on_map_view_updated()

func _on_map_3d_overlay_animations_changed() -> void:
	_renderer_event_controller.on_map_overlay_animations_changed()

func _on_units_changed(changes: Array) -> void:
	_async_refresh_driver.on_units_changed(changes)

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
	_async_refresh_driver.request_overlay_only_refresh()

func _request_dynamic_overlay_refresh() -> void:
	_async_refresh_driver.request_dynamic_overlay_refresh()

func _can_use_overlay_only_refresh() -> bool:
	return _async_refresh_driver.can_use_overlay_only_refresh()

func _start_async_overlay_only_refresh(reframe_camera: bool) -> bool:
	return _async_refresh_driver.start_async_overlay_only_refresh(reframe_camera)

func _start_async_dynamic_overlay_refresh(reframe_camera: bool) -> bool:
	return _async_refresh_driver.start_async_dynamic_overlay_refresh(reframe_camera)

func _sync_async_overlay_state_from_current_map() -> bool:
	return _async_refresh_driver.sync_async_overlay_state_from_current_map()

func _try_start_async_initial_build(reframe_camera: bool) -> bool:
	return _async_refresh_driver.try_start_async_initial_build(reframe_camera)

func _async_initial_build_worker(snapshot: Dictionary, generation_id: int) -> void:
	_async_refresh_driver._async_initial_build_worker(snapshot, generation_id)

func _pump_async_initial_build() -> void:
	_async_refresh_driver.pump_async_initial_build()

func _apply_async_chunk_payload(payload: Dictionary) -> void:
	_async_refresh_driver.apply_async_chunk_payload(payload)

func _finish_async_initial_build() -> void:
	_async_refresh_driver.finish_async_initial_build()

func _start_async_overlay_descriptor_build(dynamic_only: bool = false) -> void:
	_async_refresh_driver.start_async_overlay_descriptor_build(dynamic_only)

func _async_overlay_descriptor_worker(payload: Dictionary) -> void:
	_async_refresh_driver._async_overlay_descriptor_worker(payload)

func _pump_async_overlay_descriptor_build() -> void:
	_async_refresh_driver.pump_async_overlay_descriptor_build()

func _join_async_overlay_descriptor_thread() -> void:
	_coordinator.join_async_overlay_descriptor_thread()

func _ensure_overlay_nodes() -> void:
	_scene_graph.ensure_overlay_nodes()

func _apply_dynamic_overlay(dynamic_descriptors: Array) -> void:
	_scene_graph.apply_dynamic_overlay(dynamic_descriptors)

func _find_unit_by_instance_id(container: Node, unit_id: int) -> Node2D:
	return UnitOverlayController.find_unit_by_identity(container, unit_id)

func _normalize_unit_changes(changes: Array) -> Array:
	return _async_refresh_driver.normalize_unit_changes(changes)

func _enqueue_pending_unit_changes(changes: Array) -> void:
	_async_refresh_driver.enqueue_pending_unit_changes(changes)

func _flush_pending_unit_changes() -> bool:
	return _async_refresh_driver.flush_pending_unit_changes()

func _apply_unit_change_batch(changes: Array) -> bool:
	return _async_refresh_driver.apply_unit_change_batch(changes)

func _apply_single_unit_dynamic_refresh(unit_kind: String, unit_id: int) -> bool:
	return _apply_unit_change_batch([{
		"kind": unit_kind,
		"unit_id": unit_id,
		"action": "visual",
	}])

func _start_async_overlay_apply(static_descriptors: Array, dynamic_descriptors: Array, metrics: Dictionary) -> void:
	_async_refresh_driver.start_async_overlay_apply(static_descriptors, dynamic_descriptors, metrics)

func _pump_async_overlay_apply() -> void:
	_async_refresh_driver.pump_async_overlay_apply()

func _finalize_async_overlay_apply() -> void:
	_async_refresh_driver.finalize_async_overlay_apply()

func _cancel_async_initial_build() -> void:
	_coordinator.cancel_async_build(_async_refresh_driver.is_async_overlay_apply_active())

func _join_async_thread() -> void:
	_coordinator.join_async_thread()

func _reset_async_build_state() -> void:
	_async_refresh_driver.reset_async_build_state()
	_async_effective_typ = PackedByteArray()
	_async_blg = PackedByteArray()
	_async_w = 0
	_async_h = 0
	_async_level_set = 0
	_async_game_data_type = "original"
	_skip_next_map_changed_refresh = false

func _sync_terrain_overlay_animation_mode_from_editor() -> void:
	UATerrainPieceLibrary.set_force_static_terrain_overlays(not _runtime_context.terrain_overlay_animations_enabled())

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
	_camera_controller.process_frame()
	_async_refresh_driver.process_frame()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _preview_refresh_active():
		_bump_3d_viewport_rendering()

func _exit_tree() -> void:
	if _is_async_pipeline_active():
		_cancel_async_initial_build()
		_join_async_thread()
		_join_async_overlay_descriptor_thread()

func _get_map_subviewport() -> SubViewport:
	return _scene_graph.get_map_subviewport()

func _bump_3d_viewport_rendering() -> void:
	_scene_graph.bump_3d_viewport_rendering()

func _physics_process(delta: float) -> void:
	_camera_controller.physics_process(delta)

func _unhandled_input(event: InputEvent) -> void:
	_camera_controller.unhandled_input(event)

func _wheel_step() -> float:
	return _camera_controller.wheel_step()

func _update_camera_rotation() -> void:
	_camera_controller.update_camera_rotation()

func _frame_if_needed() -> void:
	_camera_controller.frame_if_needed()


func _on_map_3d_focus_sector_requested(sector_sx: int, sector_sy: int) -> void:
	_camera_controller.focus_sector(sector_sx, sector_sy)

func _on_map_changed() -> void:
	_renderer_event_controller.on_map_changed()

func _on_map_created() -> void:
	_renderer_event_controller.on_map_created()

func _on_map_updated() -> void:
	_on_map_changed()

func _on_hgt_map_cells_edited(border_indices: Array) -> void:
	_renderer_event_controller.on_hgt_map_cells_edited(border_indices)

func _on_typ_map_cells_edited(typ_indices: Array) -> void:
	_renderer_event_controller.on_typ_map_cells_edited(typ_indices)

func _on_blg_map_cells_edited(blg_indices: Array) -> void:
	_renderer_event_controller.on_blg_map_cells_edited(blg_indices)

func build_from_current_map() -> void:
	_build_pipeline.build_from_current_map()

func _current_game_data_type() -> String:
	return _runtime_context.current_game_data_type()

func clear() -> void:
	_scene_graph.clear()

func _clear_chunk_nodes() -> void:
	_scene_graph.clear_chunk_nodes()

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
	return _scene_graph.get_or_create_terrain_chunk_node(chunk_coord)

func _get_or_create_edge_chunk_node(chunk_coord: Vector2i) -> MeshInstance3D:
	return _scene_graph.get_or_create_edge_chunk_node(chunk_coord)

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
	return _build_pipeline.rebuild_dirty_chunks(hgt, effective_typ, w, h, pre, level_set, metrics, max_chunks)

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
	var center_sx := maxi(w >> 1, 0)
	var center_sy := maxi(h >> 1, 0)
	return TerrainBuilder.sector_to_chunk(center_sx, center_sy)

func _apply_localized_static_overlay_refresh(replacement_descriptors: Array, affected_chunks: Array, affected_sectors: Array, set_id: int, w: int, h: int) -> void:
	_build_pipeline.apply_localized_static_overlay_refresh(replacement_descriptors, affected_chunks, affected_sectors, set_id, w, h)


func _apply_localized_dynamic_overlay_refresh(cmd: Node, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, affected_sectors: Array, metrics: Dictionary) -> void:
	_build_pipeline.apply_localized_dynamic_overlay_refresh(cmd, set_id, hgt, w, h, support_descriptors, game_data_type, affected_sectors, metrics)


func _set_authored_overlay(descriptors: Array) -> void:
	_scene_graph.set_authored_overlay(descriptors)

func _apply_geometry_distance_culling_state(enabled: bool) -> void:
	_scene_graph.apply_geometry_distance_culling_state(enabled)

func _set_all_distance_culled_nodes_visible(make_visible: bool) -> void:
	_scene_graph.set_all_distance_culled_nodes_visible(make_visible)

func _update_geometry_distance_culling_visibility() -> void:
	_scene_graph.update_geometry_distance_culling_visibility()

func _apply_geometry_distance_culling_to_chunk_node(chunk_node: MeshInstance3D, chunk_coord: Vector2i) -> void:
	_scene_graph.apply_geometry_distance_culling_to_chunk_node(chunk_node, chunk_coord)

func _apply_geometry_distance_culling_to_overlay() -> void:
	_scene_graph.apply_geometry_distance_culling_to_overlay()

func _chunk_center_world_xz(chunk_coord: Vector2i) -> Vector2:
	return _scene_graph.chunk_center_world_xz(chunk_coord)

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
	return TerrainBuilder.build_mesh(hgt, w, h)

static func _sample_hgt_height(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return PreviewGeometry.sample_hgt_height(hgt, w, h, sx, sy)

static func _implicit_border_typ_value(w: int, h: int, sx: int, sy: int) -> int:
	return PreviewGeometry.implicit_border_typ_value(w, h, sx, sy)

static func _typ_value_with_implicit_border(typ: PackedByteArray, w: int, h: int, sx: int, sy: int) -> int:
	return PreviewGeometry.typ_value_with_implicit_border(typ, w, h, sx, sy)

static func _corner_average_h(hgt: PackedByteArray, w: int, h: int, corner_x: int, corner_y: int) -> float:
	return PreviewGeometry.corner_average_h(hgt, w, h, corner_x, corner_y)

static func _draw_flat_sector_geometry(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	PreviewGeometry.draw_flat_sector_geometry(st, x0, x1, z0, z1, y)

static func _preview_surface_type_for_typ(mapping: Dictionary, typ_value: int) -> int:
	return PreviewGeometry.preview_surface_type_for_typ(mapping, typ_value)

static func _retail_slurp_bucket_key(surface_a: int, surface_b: int, neighbor_dx: int, neighbor_dy: int) -> String:
	return PreviewGeometry.retail_slurp_bucket_key(surface_a, surface_b, neighbor_dx, neighbor_dy)

static func _surface_pair_from_slurp_bucket_key(bucket_key: String) -> Dictionary:
	return PreviewGeometry.surface_pair_from_slurp_bucket_key(bucket_key)

static func _authored_slurp_base_name(surface_a: int, surface_b: int, vertical: bool) -> String:
	return PreviewGeometry.authored_slurp_base_name(surface_a, surface_b, vertical)

static func _sector_center_origin(sx: int, sy: int, sector_y: float) -> Vector3:
	return OverlayPositioning.sector_center_origin(sx, sy, sector_y)

static func _sector_center_origin_scaled(sx: int, sy: int, sector_y: float) -> Vector3:
	return OverlayPositioning.sector_center_origin_scaled(sx, sy, sector_y)

static func _host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return OverlayPositioning.host_station_base_name_for_vehicle(vehicle_id)

static func _host_station_gun_base_name_for_type(gun_type: int) -> String:
	return OverlayPositioning.host_station_gun_base_name_for_type(gun_type)

static func _vector3_from_variant(value) -> Vector3:
	return OverlayPositioning.vector3_from_variant(value)

static func _host_station_godot_offset_from_ua(ua_offset: Vector3) -> Vector3:
	return OverlayPositioning.host_station_godot_offset_from_ua(ua_offset)

static func _host_station_godot_direction_from_ua(ua_direction: Vector3) -> Vector3:
	return OverlayPositioning.host_station_godot_direction_from_ua(ua_direction)

static func _world_to_sector_index(world_coord: float) -> int:
	return OverlayPositioning.world_to_sector_index(world_coord)

static func _ground_height_at_world_position(hgt: PackedByteArray, w: int, h: int, world_x: float, world_z: float) -> float:
	return OverlayPositioning.ground_height_at_world_position(hgt, w, h, world_x, world_z)

static func _support_height_at_world_position(hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, world_x: float, world_z: float, profile = null) -> float:
	return OverlayPositioning.support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z, profile)

static func _host_station_origin(host_station: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	return OverlayPositioning.host_station_origin(host_station, hgt, w, h, support_descriptors, profile)

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
	return VisualLookupService._base_name_from_visproto_index(visproto_base_names, visual_index)

static func _preferred_squad_visual_base_name(vehicle_visuals: Dictionary, visproto_base_names: Array) -> String:
	return VisualLookupService._preferred_squad_visual_base_name(vehicle_visuals, visproto_base_names)

static func _building_attachment_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._building_attachment_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func _squad_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	return VisualLookupService._squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)

static func _squad_quantity(squad: Object) -> int:
	return OverlayPositioning.squad_quantity(squad)

static func _squad_anchor_origin(squad: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, profile = null) -> Vector3:
	return OverlayPositioning.squad_anchor_origin(squad, hgt, w, h, support_descriptors, profile)

static func _squad_formation_offsets(quantity: int) -> Array:
	return OverlayProducers.squad_formation_offsets(quantity)

static func _snapshot_squad_nodes(squads: Array) -> Array:
	return OverlayProducers.snapshot_squad_nodes(squads)


static func _build_squad_descriptors_from_snapshot(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors_from_snapshot(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)


static func _build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String, profile = null) -> Array:
	return OverlayProducers.build_squad_descriptors(squads, set_id, hgt, w, h, support_descriptors, game_data_type, profile)

static func _draw_quad(st: SurfaceTool, xl: float, xr: float, zt: float, zb: float, y: float, f: int, cells: int, v: int, rot_deg: int = 0, u0: float = 0.0, vv0: float = 0.0, u1: float = 1.0, vv1: float = 1.0) -> void:
	PreviewGeometry.draw_quad(st, xl, xr, zt, zb, y, f, cells, v, rot_deg, u0, vv0, u1, vv1)

static func _decode_raw_to_fcv(raw_val: int, default_file: int) -> Array:
	return PreviewGeometry.decode_raw_to_fcv(raw_val, default_file)

static func _decode_raw_to_fcv_with_remap(raw_val: int, default_file: int, tile_remap: Dictionary) -> Array:
	return PreviewGeometry.decode_raw_to_fcv_with_remap(raw_val, default_file, tile_remap)

static func _remap_subsector_idx(subsector_idx: int, remap_table: Dictionary) -> int:
	return PreviewGeometry.remap_subsector_idx(subsector_idx, remap_table)

static func _tile_desc_for_subsector(tile_mapping: Dictionary, subsector_idx: int) -> Dictionary:
	return PreviewGeometry.tile_desc_for_subsector(tile_mapping, subsector_idx)

static func _sector_pattern_for_typ(subsector_patterns: Dictionary, typ_value: int, fallback_surface_type: int) -> Dictionary:
	return PreviewGeometry.sector_pattern_for_typ(subsector_patterns, typ_value, fallback_surface_type)

static func _default_file_variant_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Array:
	return PreviewGeometry.default_file_variant_for_subsector(surface_type, subsector_idx, tile_mapping, tile_remap, subsector_idx_remap)

static func _default_stage_slot_for_raw(raw_value: int) -> int:
	return PreviewGeometry.default_stage_slot_for_raw(raw_value)

static func _selected_raw_id_for_tile_desc(tile_desc: Dictionary) -> int:
	return PreviewGeometry.selected_raw_id_for_tile_desc(tile_desc)

static func _default_piece_selection_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Dictionary:
	return PreviewGeometry.default_piece_selection_for_subsector(surface_type, subsector_idx, tile_mapping, tile_remap, subsector_idx_remap)

static func _authored_origin_for_subsector(x0: float, z0: float, sector_y: float, sub_x: int, sub_y: int) -> Vector3:
	return PreviewGeometry.authored_origin_for_subsector(x0, z0, sector_y, sub_x, sub_y)

static func _append_vertical_seam_strip(st: SurfaceTool, x0: float, seam_x: float, x1: float, z0: float, z1: float, y_left: float, y_right: float, y_top_avg: float, y_bottom_avg: float) -> void:
	PreviewGeometry.append_vertical_seam_strip(st, x0, seam_x, x1, z0, z1, y_left, y_right, y_top_avg, y_bottom_avg)

static func _append_horizontal_seam_strip(st: SurfaceTool, x0: float, x1: float, z0: float, seam_z: float, z1: float, y_top: float, y_bottom: float, y_left_avg: float, y_right_avg: float) -> void:
	PreviewGeometry.append_horizontal_seam_strip(st, x0, x1, z0, seam_z, z1, y_top, y_bottom, y_left_avg, y_right_avg)

static func _should_emit_seam_strip(_surface_a: int, _surface_b: int, _outer_a: float, _outer_b: float, _seam_mid_a: float, _seam_mid_b: float) -> bool:
	return PreviewGeometry.should_emit_seam_strip(_surface_a, _surface_b, _outer_a, _outer_b, _seam_mid_a, _seam_mid_b)

static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, subsector_idx_remap: Dictionary = {}, lego_defs: Dictionary = {}, set_id: int = 1) -> Dictionary:
	return TerrainBuilder.build_mesh_with_textures(hgt, typ, w, h, mapping, subsector_patterns, tile_mapping, tile_remap, subsector_idx_remap, lego_defs, set_id)

func _apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	_scene_graph.apply_sector_top_materials(mesh, preloads, surface_to_surface_type)

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
	_scene_graph.ensure_edge_node()

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
	return _scene_graph.build_edge_overlay_result(hgt, w, h, typ, mapping, set_id, preloads)

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
	return _scene_graph.make_edge_blend_material(bucket_key, preloads, use_uv_y_for_blend)

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
	_scene_graph.apply_edge_surface_materials(mesh, preloads, fallback_horiz_keys, fallback_vert_keys)

func _center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return PreviewGeometry.sample_hgt_height(hgt, w, h, sx, sy)

extends Node3D
class_name Map3DRenderer

signal build_state_changed(is_building: bool, completed: int, total: int, status: String)
signal build_finished(success: bool)

const ViewController := preload("res://map/3d/controllers/map_3d_view_controller.gd")
const RendererEventController := preload("res://map/3d/controllers/map_3d_renderer_event_controller.gd")
const AsyncRefreshDriver := preload("res://map/3d/runtime/map_3d_async_refresh_driver.gd")
const CameraController := preload("res://map/3d/runtime/map_3d_camera_controller.gd")
const SceneGraph := preload("res://map/3d/runtime/map_3d_scene_graph.gd")
const RendererHostPort := preload("res://map/3d/runtime/map_3d_renderer_host_port.gd")
const RenderContextPort := preload("res://map/3d/runtime/map_3d_render_context_port.gd")
const ScenePort := preload("res://map/3d/runtime/map_3d_scene_port.gd")
const EventActionPort := preload("res://map/3d/runtime/map_3d_event_action_port.gd")
const AsyncStatePort := preload("res://map/3d/runtime/map_3d_async_state_port.gd")
const BuildRuntimePort := preload("res://map/3d/runtime/map_3d_build_runtime_port.gd")
const ViewActionPort := preload("res://map/3d/runtime/map_3d_view_action_port.gd")
const AsyncMapSnapshot := preload("res://map/3d/runtime/map_3d_async_map_snapshot.gd")
const OverlayRefreshScope := preload("res://map/3d/runtime/map_3d_overlay_refresh_scope.gd")
const BuildMetrics := preload("res://map/3d/runtime/map_3d_build_metrics.gd")
const RuntimeState := preload("res://map/3d/runtime/map_3d_runtime_state.gd")
const RuntimeContext := preload("res://map/3d/runtime/map_3d_runtime_context.gd")
const SharedConstants := preload("res://map/3d/config/map_3d_shared_constants.gd")
const RefreshCoordinator := preload("res://map/3d/services/map_3d_refresh_coordinator.gd")
const ChunkRuntime := preload("res://map/3d/services/map_3d_chunk_runtime.gd")
const EffectiveTypService := preload("res://map/3d/services/map_3d_effective_typ_service.gd")
const RebuildPolicy := preload("res://map/3d/services/map_3d_rebuild_policy.gd")
const UnitOverlayController := preload("res://map/3d/overlays/map_3d_unit_overlay_controller.gd")
const InvalidationRouter := preload("res://map/3d/services/map_3d_invalidation_router.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")
const UnitRuntimeIndex := preload("res://map/3d/services/map_3d_unit_runtime_index.gd")
const BuildPipeline := preload("res://map/3d/services/map_3d_build_pipeline.gd")
const MaterialService := preload("res://map/3d/runtime/map_3d_material_service.gd")

const SECTOR_SIZE := SharedConstants.SECTOR_SIZE
const HEIGHT_SCALE := SharedConstants.HEIGHT_SCALE
# The 2D editor / UA coordinate system uses a 1200-unit sector span.
# The 3D preview + authored-piece sampling operates in scaled-world units
# where that span is 1.0. This constant is used to convert UA->scaled.
const WORLD_SCALE := SharedConstants.WORLD_SCALE
const EDGE_SLOPE := SharedConstants.EDGE_SLOPE # Per-side width; UA fillers span ~300 across seam (~150 into each sector)
const UA_NORMAL_RENDER_SECTORS := 5
const UA_NORMAL_GEOMETRY_CULL_DISTANCE := float(UA_NORMAL_RENDER_SECTORS) * SECTOR_SIZE + SECTOR_SIZE * 0.5
const _ASYNC_APPLY_RESULTS_PER_FRAME := 4
const _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 48
const _INITIAL_LOAD_ASYNC_APPLY_RESULTS_PER_FRAME := 16
const _INITIAL_LOAD_ASYNC_OVERLAY_APPLY_OPS_PER_FRAME := 384
const _MAX_INCREMENTAL_UNIT_BATCH := 64

func _init() -> void:
	_runtime_context.bind(self)
	_host_port.bind(self)
	_render_context_port.bind(self)
	_scene_port.bind(self)
	_async_state_port.bind(_coordinator, _async_map_snapshot, _async_refresh_driver)
	_build_runtime_port.bind(
		self,
		_chunk_rt,
		_effective_typ_service,
		_unit_runtime_index,
		_static_overlay_index,
		_overlay_refresh_scope,
		_runtime_state,
		_build_pipeline,
		_rebuild_policy
	)
	_view_action_port.bind(self, _camera_controller)
	_event_action_port.bind(_view_action_port, _async_state_port)
	_rebuild_policy.bind(_render_context_port, _scene_port, _runtime_state, _chunk_rt, _effective_typ_service, _overlay_refresh_scope)
	_async_refresh_driver.bind(_host_port, _render_context_port, _scene_port, _async_state_port, _build_runtime_port, _view_action_port)
	_camera_controller.bind(_host_port, _render_context_port, _scene_port)
	_scene_graph.bind(_scene_port, _render_context_port, _runtime_state, _chunk_rt, _overlay_refresh_scope)
	_renderer_event_controller.bind(
		_event_action_port,
		_render_context_port,
		_scene_port,
		_async_refresh_driver,
		_rebuild_policy,
		_chunk_rt,
		_effective_typ_service,
		_overlay_refresh_scope,
		_runtime_state,
		_camera_controller
	)
	_build_pipeline.bind(
		_render_context_port,
		_scene_port,
		_async_map_snapshot,
		_overlay_refresh_scope,
		_chunk_rt,
		_effective_typ_service,
		_unit_runtime_index,
		_static_overlay_index,
		_rebuild_policy,
		self
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
		],
		"compatibility_instance_api": [
			"_apply_pending_refresh",
		],
		"compatibility_static_api": [],
	}

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _edge_mesh: MeshInstance3D = $EdgeMesh if has_node("EdgeMesh") else null
@onready var _authored_overlay: Node3D = $AuthoredOverlay if has_node("AuthoredOverlay") else null
@onready var _dynamic_overlay: Node3D = $DynamicOverlay if has_node("DynamicOverlay") else null

@onready var _camera: Camera3D = $Camera3D
@onready var _world_environment: WorldEnvironment = $WorldEnvironment if has_node("WorldEnvironment") else null

var _runtime_state := RuntimeState.new()
var _runtime_context := RuntimeContext.new()
var _host_port := RendererHostPort.new()
var _render_context_port := RenderContextPort.new()
var _scene_port := ScenePort.new()
var _event_action_port := EventActionPort.new()
var _async_state_port := AsyncStatePort.new()
var _build_runtime_port := BuildRuntimePort.new()
var _view_action_port := ViewActionPort.new()
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
var _rebuild_policy := RebuildPolicy.new()

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

func _finalize_build_metrics(metrics: Dictionary, build_started_usec: int) -> void:
	metrics["build_total_ms"] = BuildMetrics.elapsed_ms_since(build_started_usec)
	if _async_refresh_driver.get_refresh_requested_at_usec() > 0:
		metrics["refresh_end_to_end_ms"] = BuildMetrics.elapsed_ms_since(_async_refresh_driver.get_refresh_requested_at_usec())
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
	MaterialService.apply_debug_mode_to_existing_materials(_terrain_material_cache, _terrain_chunk_nodes, _debug_shader_mode)
	_frame_if_needed()

func _process(_delta: float) -> void:
	_camera_controller.process_frame()
	_async_refresh_driver.process_frame()

func _async_chunk_apply_budget() -> int:
	return _INITIAL_LOAD_ASYNC_APPLY_RESULTS_PER_FRAME if _chunk_rt.initial_build_in_progress else _ASYNC_APPLY_RESULTS_PER_FRAME

func _async_overlay_apply_budget(descriptor_count: int = 0) -> int:
	if not _chunk_rt.initial_build_in_progress:
		return _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME
	if descriptor_count >= 12000:
		return maxi(_INITIAL_LOAD_ASYNC_OVERLAY_APPLY_OPS_PER_FRAME * 2, _ASYNC_OVERLAY_APPLY_OPS_PER_FRAME)
	return _INITIAL_LOAD_ASYNC_OVERLAY_APPLY_OPS_PER_FRAME

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
	_rebuild_policy.mark_chunks_dirty(chunk_coords)

func mark_sector_dirty(sx: int, sy: int, edit_type: String = "hgt") -> void:
	_rebuild_policy.mark_sector_dirty(sx, sy, edit_type)

func mark_sectors_dirty(sectors: Array, edit_type: String = "hgt") -> void:
	_rebuild_policy.mark_sectors_dirty(sectors, edit_type)

func get_dirty_chunk_count() -> int:
	return _chunk_rt.get_dirty_chunk_count()

func is_using_chunked_terrain() -> bool:
	return _chunk_rt.chunked_terrain_enabled

func set_chunked_terrain_enabled(enabled: bool) -> void:
	_chunk_rt.chunked_terrain_enabled = enabled

func _needs_full_rebuild(w: int, h: int, level_set: int) -> bool:
	return _rebuild_policy.needs_full_rebuild(w, h, level_set)

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

func _dirty_chunks_sorted_by_priority(w: int, h: int) -> Array[Vector2i]:
	return _rebuild_policy.dirty_chunks_sorted_by_priority(w, h)

func _chunk_focus_coord(w: int, h: int) -> Vector2i:
	return _rebuild_policy.chunk_focus_coord(w, h)

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

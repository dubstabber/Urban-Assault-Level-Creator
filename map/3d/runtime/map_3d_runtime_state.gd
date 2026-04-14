extends RefCounted

const AuthoredOverlayManager := preload("res://map/3d/overlays/map_3d_authored_overlay_manager.gd")
const StaticOverlayIndex := preload("res://map/3d/services/map_3d_static_overlay_index.gd")
const UnitRuntimeIndex := preload("res://map/3d/services/map_3d_unit_runtime_index.gd")


var last_build_metrics: Dictionary = {}

var terrain_chunk_nodes: Dictionary = {}
var edge_chunk_nodes: Dictionary = {}

var geometry_distance_culling_enabled := false
var geometry_cull_distance := 0.0

var sector_top_shader: Shader = null
var edge_blend_shader: Shader = null
var terrain_material_cache: Dictionary = {}
var edge_material_cache: Dictionary = {}

var edge_overlay_enabled := true
var debug_shader_mode := 0

var async_pending_reframe_camera := false
var async_effective_typ: PackedByteArray = PackedByteArray()
var async_blg: PackedByteArray = PackedByteArray()
var async_w := 0
var async_h := 0
var async_level_set := 0
var async_game_data_type := "original"
var async_requested_restart := false
var async_requested_reframe := false
var async_overlay_apply_state: Dictionary = {}
var async_overlay_descriptors: Array = []
var async_dynamic_overlay_descriptors: Array = []
var async_overlay_metrics: Dictionary = {}
var async_build_started_usec := 0
var async_overlay_apply_started_usec := 0
var async_overlay_descriptor_dynamic_only := false
var overlay_only_refresh_requested := false
var dynamic_overlay_refresh_requested := false
var pending_unit_changes: Array = []

var skip_next_map_changed_refresh := false

var overlay_apply_manager := AuthoredOverlayManager.new()
var static_overlay_index := StaticOverlayIndex.new()
var unit_runtime_index := UnitRuntimeIndex.new()

var localized_overlay_dirty_sectors: Dictionary = {}
var localized_dynamic_overlay_dirty_sectors: Dictionary = {}


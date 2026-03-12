extends Node3D
class_name Map3DRenderer

const UATerrainPieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
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
const UA_NORMAL_VIZ_LIMIT := 2500.0
const UA_NORMAL_FADE_LENGTH := 1000.0
const UA_VISIBILITY_FOG_COLOR := Color.BLACK
const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"
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
const SQUAD_VEHICLE_SCRIPT_ROOTS := {
	"original": "res://.usor/openua/DATA/SCRIPTS",
	"metropolisDawn": "res://.usor/openua/dataxp/Scripts",
}
const SQUAD_VISPROTO_PATH_PATTERNS := {
	"original": "res://urban_assault_decompiled-master/assets/sets/set%d/scripts/visproto.lst",
	"metropolisDawn": "res://urban_assault_decompiled-master/assets/sets/set%d_xp/scripts/visproto.lst",
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

static var _squad_vehicle_visuals_cache: Dictionary = {}
static var _squad_visproto_base_name_cache: Dictionary = {}
static var _vehicle_visual_entries_cache: Dictionary = {}
static var _blg_typ_override_cache: Dictionary = {}
static var _building_definitions_cache: Dictionary = {}
static var _building_sec_type_override_cache: Dictionary = {}


# Preview top surfaces use world-space tiling with one repeat per sector.
func _compute_tile_scale() -> float:
	return 1.0 / SECTOR_SIZE

static func visibility_range_fade_start(viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> float:
	return maxf(maxf(viz_limit, 0.0) - maxf(fade_length, 0.0), 0.0)

static func visibility_range_config(viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> Dictionary:
	var clamped_viz_limit := maxf(viz_limit, 0.0)
	return {
		"fade_start": visibility_range_fade_start(clamped_viz_limit, fade_length),
		"fade_end": clamped_viz_limit,
	}

static func apply_visibility_range_to_environment(environment: Environment, enabled: bool, viz_limit: float = UA_NORMAL_VIZ_LIMIT, fade_length: float = UA_NORMAL_FADE_LENGTH) -> bool:
	if environment == null:
		return false
	var config := visibility_range_config(viz_limit, fade_length)
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = float(config["fade_start"])
	environment.fog_depth_end = float(config["fade_end"])
	environment.fog_depth_curve = 1.0
	environment.fog_density = 1.0
	environment.fog_light_color = UA_VISIBILITY_FOG_COLOR
	environment.fog_light_energy = 1.0
	environment.fog_aerial_perspective = 0.0
	environment.fog_height_density = 0.0
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = 0.0
	environment.fog_enabled = enabled
	return true

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _edge_mesh: MeshInstance3D = $EdgeMesh if has_node("EdgeMesh") else null
@onready var _authored_overlay: Node3D = $AuthoredOverlay if has_node("AuthoredOverlay") else null
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

	var _es = get_node_or_null("/root/EventSystem")
	if _es:
		_es.map_created.connect(_on_map_changed)
		_es.map_updated.connect(_on_map_changed)
		_es.level_set_changed.connect(_on_level_set_changed)
		_es.map_view_updated.connect(_on_map_view_updated)
	_apply_visibility_range_from_editor_state()
	var _cmd = get_node_or_null("/root/CurrentMapData")

	if _cmd:
		print("[Map3D] _ready: initial dims w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt=", _cmd.hgt_map.size())
		# Initial build if data already present
		if _cmd.horizontal_sectors > 0 and _cmd.vertical_sectors > 0 and not _cmd.hgt_map.is_empty():
			print("[Map3D] _ready: building from current map")
			build_from_current_map()

func _apply_visibility_range_from_editor_state() -> void:
	if _world_environment == null or _world_environment.environment == null:
		return
	var editor_state = get_node_or_null("/root/EditorState")
	var enabled := false
	if editor_state != null:
		enabled = bool(editor_state.get("map_3d_visibility_range_enabled"))
	apply_visibility_range_to_environment(_world_environment.environment, enabled)

func _on_map_view_updated() -> void:
	_apply_visibility_range_from_editor_state()

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
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.translate_local(Vector3(0, 0, _wheel_step()))
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

func _wheel_step() -> float:
	var _cmd = get_node_or_null("/root/CurrentMapData")
	var max_dim: int = int(max(_cmd.horizontal_sectors, _cmd.vertical_sectors)) if _cmd else 1
	return max(200.0, float(max_dim) * SECTOR_SIZE * 0.02)

func _update_camera_rotation() -> void:
	var rot := Basis()
	rot = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	_camera.global_transform.basis = rot.orthonormalized()

func _frame_if_needed() -> void:
	if _framed:
		return
	var _cmd = get_node_or_null("/root/CurrentMapData")
	if _cmd == null:
		return
	var w: int = int(_cmd.horizontal_sectors)
	var h: int = int(_cmd.vertical_sectors)
	if w <= 0 or h <= 0:
		return
	# Compute map center (XZ) over the playable area, but offset by the rendered border ring.
	# Use +Z downward to match 2D map (0,0) at top-left.
	# Border sectors occupy [0 .. SECTOR_SIZE] on each side, so playable terrain starts at +1 sector.
	var center := Vector3((1.0 + w * 0.5) * SECTOR_SIZE, 0.0, (1.0 + h * 0.5) * SECTOR_SIZE)
	var dist: float = float(max(w + 2, h + 2)) * SECTOR_SIZE * 1.6
	# Estimate terrain base height from hgt_map (use max for safety)
	var hgt: PackedByteArray = _cmd.hgt_map
	var mn: int = 255
	var mx: int = 0
	var sum: int = 0
	var count: int = hgt.size()
	for i in count:
		var v: int = int(hgt[i])
		sum += v
		if v < mn:
			mn = v
		if v > mx:
			mx = v
	var avg_h: float = float(sum) / float(count) if count > 0 else 0.0
	var terrain_base_y: float = float(mx) * HEIGHT_SCALE
	center.y = terrain_base_y
	# Camera orientation preset
	_pitch = deg_to_rad(-35.0)
	_yaw = deg_to_rad(45.0)
	_update_camera_rotation()
	# Place camera above terrain and back along +Z
	var y_offset: float = max(dist * 0.35, 300.0)
	var desired_pos := Vector3(center.x, terrain_base_y + y_offset, center.z + dist)
	_camera.global_transform.origin = desired_pos
	# Expand far clip to encompass large maps
	var far_dist: float = max(dist * 4.0, 50000.0)
	_camera.near = 0.1
	_camera.far = min(far_dist, 1.0e7)
	print("[Map3D] frame_if_needed: w=", w, " h=", h, " dist=", dist,
		" near=", _camera.near, " far=", _camera.far,
		" center=", center, " y_offset=", y_offset, " min_h=", mn, " max_h=", mx, " avg_h=", avg_h)
	_camera.look_at(center, Vector3.UP)
	_framed = true

func _on_map_changed() -> void:
	var _cmd = get_node_or_null("/root/CurrentMapData")
	if _cmd:
		print("[Map3D] map_changed signal: w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt_size=", _cmd.hgt_map.size())
		build_from_current_map()
		# Force reframe on each map change to ensure camera is valid for new bounds
		_framed = false
		_frame_if_needed()

func build_from_current_map() -> void:
	var _cmd = get_node_or_null("/root/CurrentMapData")
	if _cmd == null:
		print("[Map3D] build_from_current_map: no CurrentMapData autoload, clearing mesh")
		clear()
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
		clear()
		return

	var game_data_type := _current_game_data_type()
	var effective_typ := _effective_typ_map_for_3d(
		typ,
		blg,
		game_data_type,
		w,
		h,
		_cmd.beam_gates,
		_cmd.tech_upgrades,
		_cmd.stoudson_bombs
	)

	var pre = get_node_or_null("/root/Preloads")
	if pre == null:
		var fallback_mesh := build_mesh(hgt, w, h)
		print("[Map3D] build_from_current_map: Preloads unavailable, using untextured mesh with surfaces=", fallback_mesh.get_surface_count())
		if _terrain_mesh:
			_terrain_mesh.mesh = fallback_mesh
			_apply_untextured_materials(fallback_mesh)
		_set_authored_overlay([])
		if _edge_mesh:
			_edge_mesh.mesh = null
		return

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
		int(_cmd.level_set)
	)
	var mesh: ArrayMesh = result["mesh"]
	var surface_to_surface_type: Dictionary = result["surface_to_surface_type"]
	var authored_piece_descriptors: Array = result.get("authored_piece_descriptors", [])
	var support_descriptors := authored_piece_descriptors.duplicate()
	var overlay_descriptors := authored_piece_descriptors.duplicate()
	print("[Map3D] build_from_current_map: built textured mesh with surfaces=", mesh.get_surface_count())
	if _terrain_mesh:
		_terrain_mesh.mesh = mesh
		print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")
		_apply_sector_top_materials(mesh, pre, surface_to_surface_type)

	# Edge overlay now prefers authored retail slurp pieces (`SxyV` / `SxyH`) and only
	# falls back to the older blended strip approximation when a slurp asset is unavailable.
	if _edge_overlay_enabled and effective_typ.size() == w * h:
		var edge_result := _build_edge_overlay_result(hgt, w, h, effective_typ, pre.surface_type_map, int(_cmd.level_set), pre)
		var edge_authored_descriptors: Array = edge_result.get("authored_piece_descriptors", [])
		support_descriptors.append_array(edge_authored_descriptors)
		overlay_descriptors.append_array(edge_authored_descriptors)
		_ensure_edge_node()
		_edge_mesh.mesh = edge_result.get("mesh", null)
	else:
		if _edge_mesh:
			_edge_mesh.mesh = null
	overlay_descriptors.append_array(_build_blg_attachment_descriptors(blg, effective_typ, int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type))
	if _cmd.host_stations != null and is_instance_valid(_cmd.host_stations):
		overlay_descriptors.append_array(_build_host_station_descriptors(_cmd.host_stations.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors))
	if _cmd.squads != null and is_instance_valid(_cmd.squads):
		overlay_descriptors.append_array(_build_squad_descriptors(_cmd.squads.get_children(), int(_cmd.level_set), hgt, w, h, support_descriptors, game_data_type))
	_set_authored_overlay(overlay_descriptors)

func _current_game_data_type() -> String:
	var editor_state = get_node_or_null("/root/EditorState")
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
	_set_authored_overlay([])

func _set_authored_overlay(descriptors: Array) -> void:
	if _authored_overlay:
		remove_child(_authored_overlay)
		_authored_overlay.free()
		_authored_overlay = null
	if descriptors.is_empty():
		return
	_authored_overlay = UATerrainPieceLibraryScript.build_overlay_node(descriptors)
	add_child(_authored_overlay)

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
	return Vector3((float(sx) + 1.5) * SECTOR_SIZE, sector_y, (float(sy) + 1.5) * SECTOR_SIZE)

static func _host_station_base_name_for_vehicle(vehicle_id: int) -> String:
	return String(HOST_STATION_BASE_NAMES.get(vehicle_id, ""))

static func _host_station_gun_base_name_for_type(gun_type: int) -> String:
	return String(HOST_STATION_VISIBLE_GUN_BASE_NAMES.get(gun_type, ""))

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

static func _support_height_at_world_position(hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, world_x: float, world_z: float) -> float:
	var terrain_height := _ground_height_at_world_position(hgt, w, h, world_x, world_z)
	var authored_support = UATerrainPieceLibraryScript.support_height_at_world_position(support_descriptors, world_x, world_z)
	if authored_support != null:
		return max(float(authored_support), terrain_height)
	return terrain_height

static func _host_station_origin(host_station: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array) -> Vector3:
	var pos_y_value = host_station.get("pos_y")
	var ua_x := float(host_station.position.x)
	var world_z := absf(float(host_station.position.y))
	var ua_y := float(pos_y_value if pos_y_value != null else 0.0)
	var support_y := _support_height_at_world_position(hgt, w, h, support_descriptors, ua_x, world_z)
	return Vector3(ua_x, support_y - ua_y, world_z)

static func _build_host_station_descriptors(host_stations: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array = []) -> Array:
	var descriptors: Array = []
	for host_station in host_stations:
		if host_station == null or not is_instance_valid(host_station):
			continue
		if not (host_station is Node2D):
			continue
		var vehicle_value = host_station.get("vehicle")
		if vehicle_value == null:
			continue
		var base_name := _host_station_base_name_for_vehicle(int(vehicle_value))
		if base_name.is_empty():
			continue
		if not UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
			continue
		var origin := _host_station_origin(host_station as Node2D, hgt, w, h, support_descriptors)
		descriptors.append({
			"set_id": set_id,
			"raw_id": -1,
			"base_name": base_name,
			"origin": origin,
		})
		var gun_attachments_value = HOST_STATION_GUN_ATTACHMENTS.get(int(vehicle_value), [])
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
				var ua_offset: Vector3 = attachment.get("ua_offset", Vector3.ZERO)
				var gun_descriptor := {
					"set_id": set_id,
					"raw_id": -1,
					"base_name": gun_base_name,
					"origin": origin + _host_station_godot_offset_from_ua(ua_offset),
				}
				var ua_direction: Vector3 = attachment.get("ua_direction", Vector3.ZERO)
				var godot_direction := _host_station_godot_direction_from_ua(ua_direction)
				if godot_direction.length_squared() > 0.000001:
					gun_descriptor["forward"] = godot_direction
				descriptors.append(gun_descriptor)
	return descriptors

static func _normalized_game_data_type(game_data_type: String) -> String:
	return "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"

static func _script_root_for_game_data_type(game_data_type: String) -> String:
	return String(SQUAD_VEHICLE_SCRIPT_ROOTS.get(_normalized_game_data_type(game_data_type), SQUAD_VEHICLE_SCRIPT_ROOTS["original"]))

static func _visproto_path_for_set(set_id: int, game_data_type: String) -> String:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var pattern := String(SQUAD_VISPROTO_PATH_PATTERNS.get(normalized_game_data_type, SQUAD_VISPROTO_PATH_PATTERNS["original"]))
	return pattern % max(set_id, 1)

static func _script_paths_for_game_data_type(game_data_type: String) -> Array:
	var script_root := _script_root_for_game_data_type(game_data_type)
	var result: Array = []
	var dir := DirAccess.open(script_root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "scr":
			result.append("%s/%s" % [script_root, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

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

static func _building_sec_type_overrides_from_script_path(script_path: String) -> Dictionary:
	var result := {}
	var ambiguous_building_ids := {}
	for definition_value in _parse_building_definitions(script_path):
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

static func _building_sec_type_overrides_for_script_names(game_data_type: String, script_names: Array[String]) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := normalized_game_data_type
	for script_name in script_names:
		cache_key += ":%s" % script_name
	if _building_sec_type_override_cache.has(cache_key):
		return _building_sec_type_override_cache[cache_key]
	var result := {}
	var script_root := _script_root_for_game_data_type(game_data_type)
	for script_name in script_names:
		var script_path := script_root.path_join(script_name)
		var script_overrides := _building_sec_type_overrides_from_script_path(script_path)
		for building_id in script_overrides.keys():
			if result.has(building_id):
				continue
			result[building_id] = int(script_overrides[building_id])
	_building_sec_type_override_cache[cache_key] = result
	return result

static func _tech_upgrade_typ_overrides_for_3d(game_data_type: String) -> Dictionary:
	var overrides := _building_sec_type_overrides_for_script_names(game_data_type, ["NET_BLDG.SCR", "BUILD.SCR"]).duplicate()
	# Tech upgrades are a special preview case: the editor already applies an
	# explicit building_id -> visible typ_map mapping for the small finite set of
	# selectable upgrade buildings, and some of those visuals intentionally differ
	# from the raw script sec_type (for example 60 -> typ 106, not sec_type 1).
	# Mirror that editor-facing visual contract first, then keep the script data as
	# fallback for anything else.
	for building_id in TECH_UPGRADE_EDITOR_TYP_OVERRIDES.keys():
		overrides[int(building_id)] = int(TECH_UPGRADE_EDITOR_TYP_OVERRIDES[building_id])
	return overrides

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
		stoudson_bombs: Array = []
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
	var build_script_overrides := _building_sec_type_overrides_for_script_names(game_data_type, ["BUILD.SCR"])
	var tech_upgrade_overrides := _tech_upgrade_typ_overrides_for_3d(game_data_type)
	_apply_sector_building_overrides_from_entities(effective, w, h, beam_gates, ["closed_bp"], build_script_overrides)
	_apply_sector_building_overrides_from_entities(effective, w, h, tech_upgrades, ["building_id", "building"], tech_upgrade_overrides)
	_apply_sector_building_overrides_from_entities(effective, w, h, stoudson_bombs, ["inactive_bp"], build_script_overrides)
	return effective

static func _script_assignment_text(raw_line: String, prefix: String) -> String:
	var equals_index := raw_line.find("=")
	if equals_index >= 0:
		return raw_line.substr(equals_index + 1).strip_edges()
	return raw_line.replacen(prefix, "").strip_edges()

static func _empty_building_attachment() -> Dictionary:
	return {
		"act": -1,
		"vehicle_id": -1,
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

static func _parse_building_definitions(script_path: String) -> Array:
	var result: Array = []
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return result
	var current_building := {}
	var current_attachment := {}
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges().to_lower()
		if line.is_empty():
			continue
		if line.begins_with("new_building"):
			_append_building_attachment(current_building, current_attachment)
			_append_building_definition(result, current_building)
			current_building = {
				"building_id": int(_script_assignment_text(line, "new_building")),
				"sec_type": -1,
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
			var ua_offset_x := Vector3(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_x.x = float(_script_assignment_text(line, "sbact_pos_x"))
			current_attachment["ua_offset"] = ua_offset_x
		elif line.begins_with("sbact_pos_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_y := Vector3(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_y.y = float(_script_assignment_text(line, "sbact_pos_y"))
			current_attachment["ua_offset"] = ua_offset_y
		elif line.begins_with("sbact_pos_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_offset_z := Vector3(current_attachment.get("ua_offset", Vector3.ZERO))
			ua_offset_z.z = float(_script_assignment_text(line, "sbact_pos_z"))
			current_attachment["ua_offset"] = ua_offset_z
		elif line.begins_with("sbact_dir_x"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_x := Vector3(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_x.x = float(_script_assignment_text(line, "sbact_dir_x"))
			current_attachment["ua_direction"] = ua_direction_x
		elif line.begins_with("sbact_dir_y"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_y := Vector3(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_y.y = float(_script_assignment_text(line, "sbact_dir_y"))
			current_attachment["ua_direction"] = ua_direction_y
		elif line.begins_with("sbact_dir_z"):
			if current_attachment.is_empty():
				current_attachment = _empty_building_attachment()
			var ua_direction_z := Vector3(current_attachment.get("ua_direction", Vector3.ZERO))
			ua_direction_z.z = float(_script_assignment_text(line, "sbact_dir_z"))
			current_attachment["ua_direction"] = ua_direction_z
	_append_building_attachment(current_building, current_attachment)
	_append_building_definition(result, current_building)
	return result

static func _building_definitions_for_game_data_type(game_data_type: String) -> Array:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if _building_definitions_cache.has(normalized_game_data_type):
		return _building_definitions_cache[normalized_game_data_type]
	var result: Array = []
	for script_path in _script_paths_for_game_data_type(normalized_game_data_type):
		result.append_array(_parse_building_definitions(String(script_path)))
	_building_definitions_cache[normalized_game_data_type] = result
	return result

static func _building_definition_for_id_and_sec_type(building_id: int, sec_type: int, game_data_type: String) -> Dictionary:
	for definition in _building_definitions_for_game_data_type(game_data_type):
		if typeof(definition) != TYPE_DICTIONARY:
			continue
		var building := definition as Dictionary
		if int(building.get("building_id", -1)) == building_id and int(building.get("sec_type", -1)) == sec_type:
			return building
	return {}

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
			var definition := _building_definition_for_id_and_sec_type(building_id, int(effective_typ[idx]), game_data_type)
			if definition.is_empty():
				continue
			var world_x := (float(sx) + 1.5) * SECTOR_SIZE
			var world_z := (float(sy) + 1.5) * SECTOR_SIZE
			var sector_origin := _sector_center_origin(sx, sy, _ground_height_at_world_position(hgt, w, h, world_x, world_z))
			var attachments: Array = definition.get("attachments", [])
			for attachment_value in attachments:
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
					"raw_id": -1,
					"base_name": base_name,
					"origin": sector_origin + _host_station_godot_offset_from_ua(Vector3(attachment.get("ua_offset", Vector3.ZERO))),
				}
				var godot_direction := _host_station_godot_direction_from_ua(Vector3(attachment.get("ua_direction", Vector3.ZERO)))
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
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return result
	var current_vehicle_id := -1
	var current_entry: Dictionary = {}
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges().to_lower()
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

static func _vehicle_visual_entries_for_game_data_type(game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if _vehicle_visual_entries_cache.has(normalized_game_data_type):
		return _vehicle_visual_entries_cache[normalized_game_data_type]
	var merged := {}
	for script_path in _script_paths_for_game_data_type(normalized_game_data_type):
		var parsed: Dictionary = _parse_vehicle_visual_entries(String(script_path))
		for vehicle_id in parsed.keys():
			var entries: Array = merged.get(int(vehicle_id), [])
			entries.append_array(Array(parsed.get(vehicle_id, [])))
			merged[int(vehicle_id)] = entries
	_vehicle_visual_entries_cache[normalized_game_data_type] = merged
	return merged

static func _parse_vehicle_visual_pairs(script_path: String) -> Dictionary:
	var result := {}
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return result
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return result
	var current_vehicle_id := -1
	while not file.eof_reached():
		var line := file.get_line().get_slice(";", 0).strip_edges().to_lower()
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

static func _squad_vehicle_visuals_for_game_data_type(game_data_type: String) -> Dictionary:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	if _squad_vehicle_visuals_cache.has(normalized_game_data_type):
		return _squad_vehicle_visuals_cache[normalized_game_data_type]
	var merged := {}
	for script_path in _script_paths_for_game_data_type(normalized_game_data_type):
		var parsed: Dictionary = _parse_vehicle_visual_pairs(String(script_path))
		for vehicle_id in parsed.keys():
			merged[int(vehicle_id)] = Dictionary(parsed[vehicle_id]).duplicate(true)
	_squad_vehicle_visuals_cache[normalized_game_data_type] = merged
	return merged

static func _visproto_base_names_for_set(set_id: int, game_data_type: String) -> Array:
	var normalized_game_data_type := _normalized_game_data_type(game_data_type)
	var cache_key := "%s:%d" % [normalized_game_data_type, max(set_id, 1)]
	if _squad_visproto_base_name_cache.has(cache_key):
		return _squad_visproto_base_name_cache[cache_key]
	var result: Array = []
	var visproto_path := _visproto_path_for_set(set_id, normalized_game_data_type)
	if FileAccess.file_exists(visproto_path):
		var file := FileAccess.open(visproto_path, FileAccess.READ)
		if file != null:
			while not file.eof_reached():
				var line := file.get_line().get_slice(";", 0).strip_edges()
				if line.is_empty():
					continue
				result.append(line.get_basename())
	_squad_visproto_base_name_cache[cache_key] = result
	return result

static func _base_name_from_visproto_index(visproto_base_names: Array, visual_index: int) -> String:
	if visual_index < 0 or visual_index >= visproto_base_names.size():
		return ""
	var base_name := String(visproto_base_names[visual_index])
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
	var vehicle_entries: Dictionary = _vehicle_visual_entries_for_game_data_type(game_data_type)
	if not vehicle_entries.has(vehicle_id):
		return _squad_base_name_for_vehicle(vehicle_id, set_id, game_data_type)
	var visproto_base_names := _visproto_base_names_for_set(set_id, game_data_type)
	var fallback := ""
	for entry_value in Array(vehicle_entries[vehicle_id]):
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var vehicle_visuals := entry_value as Dictionary
		var base_name := _preferred_squad_visual_base_name(vehicle_visuals, visproto_base_names)
		if base_name.is_empty():
			continue
		var model_name := String(vehicle_visuals.get("model", "")).to_lower()
		if model_name != "plane" and model_name != "heli":
			return base_name
		if fallback.is_empty():
			fallback = base_name
	return fallback

static func _squad_base_name_for_vehicle(vehicle_id: int, set_id: int, game_data_type: String) -> String:
	var vehicle_visuals: Dictionary = _squad_vehicle_visuals_for_game_data_type(game_data_type)
	if not vehicle_visuals.has(vehicle_id):
		return ""
	var visproto_base_names := _visproto_base_names_for_set(set_id, game_data_type)
	return _preferred_squad_visual_base_name(Dictionary(vehicle_visuals[vehicle_id]), visproto_base_names)

static func _squad_quantity(squad: Object) -> int:
	var quantity_value = squad.get("quantity")
	if quantity_value == null:
		return 1
	return max(1, int(quantity_value))

static func _squad_anchor_origin(squad: Node2D, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array) -> Vector3:
	var world_x := float(squad.position.x)
	var world_z := absf(float(squad.position.y))
	return Vector3(world_x, _support_height_at_world_position(hgt, w, h, support_descriptors, world_x, world_z), world_z)

static func _squad_formation_offsets(quantity: int) -> Array:
	var offsets: Array = []
	var columns := int(sqrt(float(quantity))) + 2
	for unit_index in range(quantity):
		# Latest user-validated preview parity keeps the recovered spacing/column-count rule,
		# but fills each row left-to-right and advances subsequent rows upward in preview space
		# while preserving the same shared snapped anchor rules.
		var x_offset := SQUAD_FORMATION_SPACING * (float(unit_index % columns) - float(columns) / 2.0)
		var z_offset: float = -SQUAD_FORMATION_SPACING * floor(float(unit_index) / float(columns))
		offsets.append(Vector3(x_offset, 0.0, z_offset))
	return offsets

static func _build_squad_descriptors(squads: Array, set_id: int, hgt: PackedByteArray, w: int, h: int, support_descriptors: Array, game_data_type: String) -> Array:
	var descriptors: Array = []
	for squad in squads:
		if squad == null or not is_instance_valid(squad):
			continue
		if not (squad is Node2D):
			continue
		var vehicle_value = squad.get("vehicle")
		if vehicle_value == null:
			continue
		var base_name := _squad_base_name_for_vehicle(int(vehicle_value), set_id, game_data_type)
		if base_name.is_empty():
			continue
		if not UATerrainPieceLibraryScript.has_piece_source(set_id, base_name):
			continue
		var squad_anchor_origin := _squad_anchor_origin(squad as Node2D, hgt, w, h, support_descriptors)
		for formation_offset in _squad_formation_offsets(_squad_quantity(squad)):
			descriptors.append({
				"set_id": set_id,
				"raw_id": -1,
				"base_name": base_name,
				"origin": squad_anchor_origin + Vector3(formation_offset),
				"y_offset": SQUAD_EXTRA_Y_OFFSET,
			})
	return descriptors

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
		return {"raw_id": -1, "piece": [default_file, (16 if default_file == 4 else 4), 0]}
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

static func _should_emit_seam_strip(surface_a: int, surface_b: int, outer_a: float, outer_b: float, seam_mid_a: float, seam_mid_b: float) -> bool:
	# Retail slurps are selected from the ordered neighboring SurfaceType pair for every
	# rendered sector adjacency. The preview also needs that behavior for flat/coplanar
	# neighbors so sectors stay visually joined instead of leaving seams open.
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
							int(piece[2])
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
					authored_piece_descriptors.append(authored)

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
	build_from_current_map()

func _ensure_edge_node() -> void:
	if _edge_mesh == null:
		var mi := MeshInstance3D.new()
		mi.name = "EdgeMesh"
		add_child(mi)
		_edge_mesh = mi

func _build_edges_from_current_map() -> void:
	var cmd = get_node_or_null("/root/CurrentMapData")
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
	var pre = get_node_or_null("/root/Preloads")
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
		preloads = get_node_or_null("/root/Preloads")

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
					"raw_id": -1,
					"base_name": base_name,
					"origin": _sector_center_origin(x + 1, y, yR),
					"warp_mode": "vside",
					"anchor_height": yR,
					"left_height": yL,
					"right_height": yR,
					"top_avg": yTopAvg,
					"bottom_avg": yBottomAvg,
				})
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
					"raw_id": -1,
					"base_name": base_name_h,
					"origin": _sector_center_origin(x2, y2 + 1, yB),
					"warp_mode": "hside",
					"anchor_height": yB,
					"top_height": yT,
					"bottom_height": yB,
					"left_avg": yLeftAvg,
					"right_avg": yRightAvg,
				})
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
		preloads = get_node_or_null("/root/Preloads")
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

func _center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	return _sample_hgt_height(hgt, w, h, sx, sy)

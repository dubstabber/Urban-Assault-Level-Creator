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
const EDGE_BLEND_SHADER_PATH := "res://resources/terrain/shaders/edge_blend.gdshader"


# Preview top surfaces use world-space tiling with one repeat per sector.
func _compute_tile_scale() -> float:
	return 1.0 / SECTOR_SIZE

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _edge_mesh: MeshInstance3D = $EdgeMesh if has_node("EdgeMesh") else null
@onready var _authored_overlay: Node3D = $AuthoredOverlay if has_node("AuthoredOverlay") else null
var _edge_overlay_enabled := false

@onready var _camera: Camera3D = $Camera3D

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
	var _cmd = get_node_or_null("/root/CurrentMapData")

	if _cmd:
		print("[Map3D] _ready: initial dims w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt=", _cmd.hgt_map.size())
		# Initial build if data already present
		if _cmd.horizontal_sectors > 0 and _cmd.vertical_sectors > 0 and not _cmd.hgt_map.is_empty():
			print("[Map3D] _ready: building from current map")
			build_from_current_map()

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
	var expected := (w + 2) * (h + 2)
	print("[Map3D] build_from_current_map: w=", w, " h=", h, " hgt_size=", hgt.size(), " expected=", expected)
	if w <= 0 or h <= 0 or hgt.size() != expected or typ.size() != w * h:
		print("[Map3D] build_from_current_map: invalid data, clearing mesh")
		clear()
		return

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
		typ,
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
	print("[Map3D] build_from_current_map: built textured mesh with surfaces=", mesh.get_surface_count())
	if _terrain_mesh:
		_terrain_mesh.mesh = mesh
		print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")
		_apply_sector_top_materials(mesh, pre, surface_to_surface_type)
	_set_authored_overlay(authored_piece_descriptors)

	# Optional edge overlay approximates retail `vside` / `hside` slurps with
	# ordered-pair texture blends. Exact authored filler payloads are still unresolved.
	if _edge_overlay_enabled and typ.size() == w * h:
		_build_edges_from_current_map()
	else:
		if _edge_mesh:
			_edge_mesh.mesh = null

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

static func _selected_raw_id_for_tile_desc(tile_desc: Dictionary) -> int:
	var start_health := 255 if int(tile_desc.get("flag", 0)) != 0 else 0
	return int(tile_desc.get("val0", 0)) if start_health >= 201 else int(tile_desc.get("val3", 0))

static func _default_piece_selection_for_subsector(surface_type: int, subsector_idx: int, tile_mapping: Dictionary, tile_remap: Dictionary, subsector_idx_remap: Dictionary) -> Dictionary:
	var default_file := clampi(surface_type, 0, 5)
	var remapped_idx := _remap_subsector_idx(subsector_idx, subsector_idx_remap)
	var tile_desc := _tile_desc_for_subsector(tile_mapping, remapped_idx)
	if tile_desc.is_empty():
		return {"raw_id": -1, "piece": [default_file, (16 if default_file == 4 else 4), 0]}
	var raw_val := _selected_raw_id_for_tile_desc(tile_desc)
	return {"raw_id": raw_val, "piece": _decode_raw_to_fcv_with_remap(raw_val, default_file, tile_remap)}

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
							Vector3((piece_x0 + piece_x1) * 0.5, sector_y, (piece_z0 + piece_z1) * 0.5)
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
	if w <= 0 or h <= 0 or hgt.size() != (w + 2) * (h + 2) or typ.size() != w * h:
		if _edge_mesh: _edge_mesh.mesh = null
		return
	var pre = get_node_or_null("/root/Preloads")
	var mapping: Dictionary = pre.surface_type_map if pre else {}
	var mesh := _build_edges_mesh(hgt, w, h, typ, mapping, pre)
	_ensure_edge_node()
	_edge_mesh.mesh = mesh

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

	# Retail `vside` slurps apply to left/right neighboring sector pairs.
	for y in h:
		for x in (w - 1):
			var a := int(typ[y * w + x])
			var b := int(typ[y * w + x + 1])
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
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
			var yL := _center_h(hgt, w, h, x, y)
			var yR := _center_h(hgt, w, h, x + 1, y)
			var yTopAvg := _corner_average_h(hgt, w, h, x + 1, y)
			var yBottomAvg := _corner_average_h(hgt, w, h, x + 1, y + 1)
			_append_vertical_seam_strip(st, x0, seam_x, x1, z0, z1, yL, yR, yTopAvg, yBottomAvg)

	# Retail `hside` slurps apply to top/bottom neighboring sector pairs.
	for y in (h - 1):
		for x in w:
			var a2 := int(typ[y * w + x])
			var b2 := int(typ[(y + 1) * w + x])
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var key2 := _retail_slurp_bucket_key(sa2, sb2, 0, 1)
			if key2.is_empty():
				continue
			var st2: SurfaceTool = vert.get(key2)
			if st2 == null:
				st2 = SurfaceTool.new()
				st2.begin(Mesh.PRIMITIVE_TRIANGLES)
				vert[key2] = st2
			var seam_z := float(y + 2) * SECTOR_SIZE
			var z0v := seam_z - EDGE_SLOPE
			var z1v := seam_z + EDGE_SLOPE
			var x0v := float(x + 1) * SECTOR_SIZE
			var x1v := float(x + 2) * SECTOR_SIZE
			var yT := _center_h(hgt, w, h, x, y)
			var yB := _center_h(hgt, w, h, x, y + 1)
			var yLeftAvg := _corner_average_h(hgt, w, h, x, y + 1)
			var yRightAvg := _corner_average_h(hgt, w, h, x + 1, y + 1)
			_append_horizontal_seam_strip(st2, x0v, x1v, z0v, seam_z, z1v, yT, yB, yLeftAvg, yRightAvg)

	# --- Border seams: connect border ring to inner playable area ---
	# North border (between border row and y=0)
	for x in w:
		var border_typ_top := _typ_value_with_implicit_border(typ, w, h, x, -1)
		var inner_typ_top := _typ_value_with_implicit_border(typ, w, h, x, 0)
		if not mapping.has(border_typ_top) or not mapping.has(inner_typ_top):
			continue
		var sa_top := int(mapping.get(border_typ_top, 0))
		var sb_top := int(mapping.get(inner_typ_top, 0))
		var key_top := _retail_slurp_bucket_key(sa_top, sb_top, 0, 1)
		if key_top.is_empty():
			continue
		var st_top: SurfaceTool = vert.get(key_top)
		if st_top == null:
			st_top = SurfaceTool.new()
			st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
			vert[key_top] = st_top
		var seam_zn := SECTOR_SIZE
		var z0n := seam_zn - EDGE_SLOPE
		var z1n := seam_zn + EDGE_SLOPE
		var x0n := float(x + 1) * SECTOR_SIZE
		var x1n := float(x + 2) * SECTOR_SIZE
		var yTn := _center_h(hgt, w, h, x, -1)
		var yBn := _center_h(hgt, w, h, x, 0)
		var yLeftAvgn := _corner_average_h(hgt, w, h, x, 0)
		var yRightAvgn := _corner_average_h(hgt, w, h, x + 1, 0)
		_append_horizontal_seam_strip(st_top, x0n, x1n, z0n, seam_zn, z1n, yTn, yBn, yLeftAvgn, yRightAvgn)

	# South border (between y=h-1 and border row)
	for x in w:
		var inner_typ_bottom := _typ_value_with_implicit_border(typ, w, h, x, h - 1)
		var border_typ_bottom := _typ_value_with_implicit_border(typ, w, h, x, h)
		if not mapping.has(inner_typ_bottom) or not mapping.has(border_typ_bottom):
			continue
		var sa_bottom := int(mapping.get(inner_typ_bottom, 0))
		var sb_bottom := int(mapping.get(border_typ_bottom, 0))
		var key_bottom := _retail_slurp_bucket_key(sa_bottom, sb_bottom, 0, 1)
		if key_bottom.is_empty():
			continue
		var st_bottom: SurfaceTool = vert.get(key_bottom)
		if st_bottom == null:
			st_bottom = SurfaceTool.new()
			st_bottom.begin(Mesh.PRIMITIVE_TRIANGLES)
			vert[key_bottom] = st_bottom
		var seam_zs := float(h + 1) * SECTOR_SIZE
		var z0s := seam_zs - EDGE_SLOPE
		var z1s := seam_zs + EDGE_SLOPE
		var x0s := float(x + 1) * SECTOR_SIZE
		var x1s := float(x + 2) * SECTOR_SIZE
		var yTs := _center_h(hgt, w, h, x, h - 1)
		var yBs := _center_h(hgt, w, h, x, h)
		var yLeftAvgs := _corner_average_h(hgt, w, h, x, h)
		var yRightAvgs := _corner_average_h(hgt, w, h, x + 1, h)
		_append_horizontal_seam_strip(st_bottom, x0s, x1s, z0s, seam_zs, z1s, yTs, yBs, yLeftAvgs, yRightAvgs)

	# West border (between border column and x=0)
	for yy in h:
		var border_typ_left := _typ_value_with_implicit_border(typ, w, h, -1, yy)
		var inner_typ_left := _typ_value_with_implicit_border(typ, w, h, 0, yy)
		if not mapping.has(border_typ_left) or not mapping.has(inner_typ_left):
			continue
		var sa_left := int(mapping.get(border_typ_left, 0))
		var sb_left := int(mapping.get(inner_typ_left, 0))
		var key_left := _retail_slurp_bucket_key(sa_left, sb_left, 1, 0)
		if key_left.is_empty():
			continue
		var st_left: SurfaceTool = horiz.get(key_left)
		if st_left == null:
			st_left = SurfaceTool.new()
			st_left.begin(Mesh.PRIMITIVE_TRIANGLES)
			horiz[key_left] = st_left
		var seam_xw := SECTOR_SIZE
		var x0w := seam_xw - EDGE_SLOPE
		var x1w := seam_xw + EDGE_SLOPE
		var z0w := float(yy + 1) * SECTOR_SIZE
		var z1w := float(yy + 2) * SECTOR_SIZE
		var yLw := _center_h(hgt, w, h, -1, yy)
		var yRw := _center_h(hgt, w, h, 0, yy)
		var yTopAvgw := _corner_average_h(hgt, w, h, 0, yy)
		var yBottomAvgw := _corner_average_h(hgt, w, h, 0, yy + 1)
		_append_vertical_seam_strip(st_left, x0w, seam_xw, x1w, z0w, z1w, yLw, yRw, yTopAvgw, yBottomAvgw)

	# East border (between x=w-1 and border column)
	for yy2 in h:
		var inner_typ_right := _typ_value_with_implicit_border(typ, w, h, w - 1, yy2)
		var border_typ_right := _typ_value_with_implicit_border(typ, w, h, w, yy2)
		if not mapping.has(inner_typ_right) or not mapping.has(border_typ_right):
			continue
		var sa_right := int(mapping.get(inner_typ_right, 0))
		var sb_right := int(mapping.get(border_typ_right, 0))
		var key_right := _retail_slurp_bucket_key(sa_right, sb_right, 1, 0)
		if key_right.is_empty():
			continue
		var st_right: SurfaceTool = horiz.get(key_right)
		if st_right == null:
			st_right = SurfaceTool.new()
			st_right.begin(Mesh.PRIMITIVE_TRIANGLES)
			horiz[key_right] = st_right
		var seam_xe := float(w + 1) * SECTOR_SIZE
		var x0e := seam_xe - EDGE_SLOPE
		var x1e := seam_xe + EDGE_SLOPE
		var z0e := float(yy2 + 1) * SECTOR_SIZE
		var z1e := float(yy2 + 2) * SECTOR_SIZE
		var yLe := _center_h(hgt, w, h, w - 1, yy2)
		var yRe := _center_h(hgt, w, h, w, yy2)
		var yTopAvge := _corner_average_h(hgt, w, h, w, yy2)
		var yBottomAvge := _corner_average_h(hgt, w, h, w, yy2 + 1)
		_append_vertical_seam_strip(st_right, x0e, seam_xe, x1e, z0e, z1e, yLe, yRe, yTopAvge, yBottomAvge)

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

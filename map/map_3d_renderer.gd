extends Node3D
class_name Map3DRenderer

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
const EDGE_SLOPE := 150.0 # Per-side width; UA fillers span ~300 across seam (~150 into each sector)


@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _camera: Camera3D = $Camera3D

var _mouselook := false
var _yaw := 0.0
var _pitch := -0.6
var _move_speed := 1200.0
var _sprint_mult := 2.0
var _look_sens := 0.0025
var _framed := false

func _ready() -> void:
	var test_mesh := get_node_or_null("TestMesh")
	if test_mesh:
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
	var _cmd = get_node_or_null("/root/CurrentMapData")
	if _cmd:
		print("[Map3D] _ready: initial dims w=", _cmd.horizontal_sectors, " h=", _cmd.vertical_sectors, " hgt=", _cmd.hgt_map.size())
		# Initial build if data already present
		if _cmd.horizontal_sectors > 0 and _cmd.vertical_sectors > 0 and not _cmd.hgt_map.is_empty():
			print("[Map3D] _ready: building from current map")
			build_from_current_map()
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
	# Compute map center (XZ) first
	# Use +Z downward to match 2D map (0,0) at top-left
	var center := Vector3(((w + 2) as float) * SECTOR_SIZE * 0.5, 0.0, ((h + 2) as float) * SECTOR_SIZE * 0.5)
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
	var expected := (w + 2) * (h + 2)
	print("[Map3D] build_from_current_map: w=", w, " h=", h, " hgt_size=", hgt.size(), " expected=", expected)
	if w <= 0 or h <= 0 or hgt.size() != expected:
		print("[Map3D] build_from_current_map: invalid data, clearing mesh")
		clear()
		return
	var mesh := build_mesh(hgt, w, h)
	var surf_count := mesh.get_surface_count()
	print("[Map3D] build_from_current_map: built mesh with surfaces=", surf_count)
	if _terrain_mesh:
		_terrain_mesh.mesh = mesh
		print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")
		# Simple lit material for MVP
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.roughness = 1.0
		mat.metallic = 0.0
		mat.albedo_color = Color(0.35, 0.48, 0.35)
		# Avoid disappearing mesh if triangle winding is inverted
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_terrain_mesh.material_override = mat

func clear() -> void:
	if _terrain_mesh:
		_terrain_mesh.mesh = null

# Static, pure builder (useful for tests)
# Rewritten to build a shared-vertex grid with alternating diagonals.
# This avoids per-sector center splits (which cause T-junctions and seams)
# and ensures consistent connectivity between adjacent sectors.
static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or w <= 0 or h <= 0:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var EDGE: float = float(min(EDGE_SLOPE, SECTOR_SIZE * 0.49))
	for y in bh:
		for x in bw:
			var bx := x
			var by := y
			# Heights: hgt values are sector centers; scale to world Y
			var y_c := float(hgt[by * bw + bx]) * HEIGHT_SCALE
			var bx0: int = max(0, bx - 1)
			var bx1: int = min(bw - 1, bx + 1)
			var by0: int = max(0, by - 1)
			var by1: int = min(bh - 1, by + 1)
			var y_w := float(hgt[by * bw + bx0]) * HEIGHT_SCALE
			var y_e := float(hgt[by * bw + bx1]) * HEIGHT_SCALE
			var y_n := float(hgt[by0 * bw + bx]) * HEIGHT_SCALE
			var y_s := float(hgt[by1 * bw + bx]) * HEIGHT_SCALE
			# Diagonal corner averaged heights (UA-style), clamped at borders
			var y_nw := ((float(hgt[by0 * bw + bx0]) + float(hgt[by0 * bw + bx]) + float(hgt[by * bw + bx0]) + float(hgt[by * bw + bx])) * 0.25) * HEIGHT_SCALE
			var y_ne := ((float(hgt[by0 * bw + bx1]) + float(hgt[by0 * bw + bx]) + float(hgt[by * bw + bx1]) + float(hgt[by * bw + bx])) * 0.25) * HEIGHT_SCALE
			var y_sw := ((float(hgt[by1 * bw + bx0]) + float(hgt[by1 * bw + bx]) + float(hgt[by * bw + bx0]) + float(hgt[by * bw + bx])) * 0.25) * HEIGHT_SCALE
			var y_se := ((float(hgt[by1 * bw + bx1]) + float(hgt[by1 * bw + bx]) + float(hgt[by * bw + bx1]) + float(hgt[by * bw + bx])) * 0.25) * HEIGHT_SCALE
			# Sector outer/inner rects
			var x0 := x * SECTOR_SIZE
			var x1 := (x + 1) * SECTOR_SIZE
			# Use +Z downward to match 2D map (row y increases downward)
			var z0 := y * SECTOR_SIZE
			var z1 := (y + 1) * SECTOR_SIZE
			var ix0: float = x0 + EDGE
			var ix1: float = x1 - EDGE
			# Inner offsets: move inward from top (z0) by +EDGE, and from bottom (z1) by -EDGE
			var iz0: float = z0 + EDGE
			var iz1: float = z1 - EDGE
			# Edge target heights at the shared boundary (symmetric midpoint; only cardinal neighbors)
			var y_n_edge := (y_c + y_n) * 0.5
			var y_s_edge := (y_c + y_s) * 0.5
			var y_w_edge := (y_c + y_w) * 0.5
			var y_e_edge := (y_c + y_e) * 0.5
			# 1) Center plateau (flat at sector height)
			var p_nw := Vector3(ix0, y_c, iz0)
			var p_ne := Vector3(ix1, y_c, iz0)
			var p_se := Vector3(ix1, y_c, iz1)
			var p_sw := Vector3(ix0, y_c, iz1)
			st.add_vertex(p_nw); st.add_vertex(p_ne); st.add_vertex(p_se)
			st.add_vertex(p_nw); st.add_vertex(p_se); st.add_vertex(p_sw)
			# 2) Edge strips: north, south, west, east (meet neighbors at the midpoint height; only cardinal neighbors)
			# North strip: [ix0..ix1] x [z0..iz0] from y_n_edge at z0 to y_c at iz0
			st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			# South strip: [ix0..ix1] x [iz1..z1] from y_c at iz1 to y_s_edge at z1
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix1, y_s_edge, z1)); st.add_vertex(Vector3(ix0, y_s_edge, z1))
			# West strip: [x0..ix0] x [iz1..iz0] from y_w_edge at x0 to y_c at ix0
			st.add_vertex(Vector3(x0, y_w_edge, iz0)); st.add_vertex(Vector3(ix0, y_c, iz0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.add_vertex(Vector3(x0, y_w_edge, iz0)); st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(x0, y_w_edge, iz1))
			# East strip: [ix1..x1] x [iz1..iz0] from y_c at ix1 to y_e_edge at x1
			st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz1))
			st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz1)); st.add_vertex(Vector3(ix1, y_c, iz1))
			# 3) Corner patches: use diagonal average only at the single corner vertex; edge boundaries use midpoint heights
			# NW corner: [x0..ix0] x [z0..iz0]
			st.add_vertex(Vector3(x0, y_nw, z0)); st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.add_vertex(Vector3(x0, y_nw, z0)); st.add_vertex(Vector3(ix0, y_c, iz0)); st.add_vertex(Vector3(x0, y_w_edge, iz0))
			# NE corner: [ix1..x1] x [z0..iz0]
			st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(x1, y_ne, z0)); st.add_vertex(Vector3(x1, y_e_edge, iz0))
			st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(x1, y_e_edge, iz0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			# SE corner: [ix1..x1] x [iz1..z1]
			st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(x1, y_e_edge, iz1)); st.add_vertex(Vector3(x1, y_se, z1))
			st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(x1, y_se, z1)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			# SW corner: [x0..ix0] x [iz1..z1]
			st.add_vertex(Vector3(x0, y_w_edge, iz1)); st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix0, y_s_edge, z1))
			st.add_vertex(Vector3(x0, y_w_edge, iz1)); st.add_vertex(Vector3(ix0, y_s_edge, z1)); st.add_vertex(Vector3(x0, y_sw, z1))
	# Index and generate normals
	st.index()
	st.generate_normals()
	return st.commit()

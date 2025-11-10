extends Node3D
class_name Map3DRenderer

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _camera: Camera3D = $Camera3D

var _mouselook := false
var _yaw := 0.0
var _pitch := -0.6
var _move_speed := 2100.0
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
	# Listen for map events
	EventSystem.map_created.connect(_on_map_changed)
	EventSystem.map_updated.connect(_on_map_changed)
	print("[Map3D] _ready: initial dims w=", CurrentMapData.horizontal_sectors, " h=", CurrentMapData.vertical_sectors, " hgt=", CurrentMapData.hgt_map.size())
	# Initial build if data already present
	if CurrentMapData.horizontal_sectors > 0 and CurrentMapData.vertical_sectors > 0 and not CurrentMapData.hgt_map.is_empty():
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
	var max_dim: int = int(max(CurrentMapData.horizontal_sectors, CurrentMapData.vertical_sectors))
	return max(200.0, float(max_dim) * SECTOR_SIZE * 0.02)

func _update_camera_rotation() -> void:
	var rot := Basis()
	rot = Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch)
	_camera.global_transform.basis = rot.orthonormalized()

func _frame_if_needed() -> void:
	if _framed:
		return
	var w := CurrentMapData.horizontal_sectors
	var h := CurrentMapData.vertical_sectors
	if w <= 0 or h <= 0:
		return
	# Compute map center (XZ) first
	var center := Vector3((w as float) * SECTOR_SIZE * 0.5, 0.0, - (h as float) * SECTOR_SIZE * 0.5)
	var dist: float = float(max(w, h)) * SECTOR_SIZE * 1.6
	# Estimate terrain base height from hgt_map (use max for safety)
	var hgt := CurrentMapData.hgt_map
	var mn := 255
	var mx := 0
	var sum := 0
	var count := hgt.size()
	for i in count:
		var v := int(hgt[i])
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
	print("[Map3D] map_changed signal: w=", CurrentMapData.horizontal_sectors, " h=", CurrentMapData.vertical_sectors, " hgt_size=", CurrentMapData.hgt_map.size())
	build_from_current_map()
	# Force reframe on each map change to ensure camera is valid for new bounds
	_framed = false
	_frame_if_needed()

func build_from_current_map() -> void:
	var w := CurrentMapData.horizontal_sectors
	var h := CurrentMapData.vertical_sectors
	var hgt := CurrentMapData.hgt_map
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
static func build_mesh(hgt: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or w <= 0 or h <= 0:
		return ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in h:
		for x in w:
			# Border indices for the four corners (offset by +1 to skip the outer border)
			var bx := x + 1
			var by := y + 1
			var i_nw := by * bw + bx
			var i_ne := by * bw + (bx + 1)
			var i_se := (by + 1) * bw + (bx + 1)
			var i_sw := (by + 1) * bw + bx
			var y_nw := float(hgt[i_nw]) * HEIGHT_SCALE
			var y_ne := float(hgt[i_ne]) * HEIGHT_SCALE
			var y_se := float(hgt[i_se]) * HEIGHT_SCALE
			var y_sw := float(hgt[i_sw]) * HEIGHT_SCALE
			var x0 := x * SECTOR_SIZE
			var x1 := (x + 1) * SECTOR_SIZE
			var z0 := -y * SECTOR_SIZE
			var z1 := -(y + 1) * SECTOR_SIZE
			var nw := Vector3(x0, y_nw, z0)
			var ne := Vector3(x1, y_ne, z0)
			var se := Vector3(x1, y_se, z1)
			var sw := Vector3(x0, y_sw, z1)
			var center_y := (y_nw + y_ne + y_se + y_sw) * 0.25
			var c := Vector3((x0 + x1) * 0.5, center_y, (z0 + z1) * 0.5)
			# Emit four center-split triangles (CCW from top)
			st.add_vertex(nw); st.add_vertex(ne); st.add_vertex(c)
			st.add_vertex(ne); st.add_vertex(se); st.add_vertex(c)
			st.add_vertex(se); st.add_vertex(sw); st.add_vertex(c)
			st.add_vertex(sw); st.add_vertex(nw); st.add_vertex(c)
	st.generate_normals()
	return st.commit()

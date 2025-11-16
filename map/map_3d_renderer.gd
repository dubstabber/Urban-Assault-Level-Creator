extends Node3D
class_name Map3DRenderer

const SECTOR_SIZE := 1200.0
const HEIGHT_SCALE := 100.0
const EDGE_SLOPE := 150.0 # Per-side width; UA fillers span ~300 across seam (~150 into each sector)


# Compute a world-space tile scale so a single texture tile spans ~3 sectors.
# This reduces visible repetition within a single sector and keeps seamless tiling across sectors.
func _compute_tile_scale() -> float:
	return 1.0 / (SECTOR_SIZE * 3.0)

@onready var _terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var _edge_mesh: MeshInstance3D = $EdgeMesh if has_node("EdgeMesh") else null

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
	# Compute map center (XZ) - center on playable area, not including borders
	# Use +Z downward to match 2D map (0,0) at top-left
	# Playable area starts at SECTOR_SIZE and extends for w*SECTOR_SIZE (same for Z)
	# So center is at (1 + w/2) * SECTOR_SIZE for X, and (1 + h/2) * SECTOR_SIZE for Z
	var center := Vector3((1.0 + w * 0.5) * SECTOR_SIZE, 0.0, (1.0 + h * 0.5) * SECTOR_SIZE)
	var dist: float = float(max(w, h)) * SECTOR_SIZE * 1.6
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
	var mapping: Dictionary = pre.surface_type_map if pre else {}
	var result := build_mesh_with_textures(hgt, typ, w, h, mapping)
	var mesh: ArrayMesh = result["mesh"]
	var surface_to_surface_type: Dictionary = result["surface_to_surface_type"]
	var surf_count: int = mesh.get_surface_count()
	print("[Map3D] build_from_current_map: built mesh with surfaces=", surf_count)
	if _terrain_mesh:
		_terrain_mesh.mesh = mesh
		print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")

		# Apply sector top textures per surface (using ground_textures based on SurfaceType)
		_apply_sector_top_materials(mesh, pre, surface_to_surface_type)

		# Build UA-style edge strips with texture blending
		_build_edges_from_current_map()

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
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix0, y_s_edge, z1)); st.add_vertex(Vector3(x0, y_sw, z1))
			st.add_vertex(Vector3(x0, y_w_edge, iz1)); st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(x0, y_sw, z1))


	# Index and generate normals
	st.index()
	st.generate_normals()
	var mesh2: ArrayMesh = st.commit()
	return mesh2

# Compute a per-sector atlas variant from a typ_map value.
# This is a placeholder until we have a UA-faithful typ->variant mapping table.
static func _variant_from_typ(typ_value: int) -> int:
	# Simple baseline: use the low two bits of typ_value so 0..3 map
	# to the four cells of a 2x2 atlas. This ensures that different
	# typ ids sharing a SurfaceType can still pick different quadrants.
	return typ_value & 3

# Build mesh with per-sector texturing support
# Creates separate surfaces for each SurfaceType (0-5) to enable different ground textures
# Returns: Dictionary with keys "mesh" (ArrayMesh) and "surface_to_surface_type" (Dictionary mapping surface_index -> SurfaceType)
static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary) -> Dictionary:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or typ.size() != w * h or w <= 0 or h <= 0:
		return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}}

	# Group sectors by SurfaceType (0-5) to create separate surfaces
	# This allows each SurfaceType to have its own ground texture
	var surface_tools := {}  # SurfaceType -> SurfaceTool
	var surface_type_order: Array[int] = []  # Track order of SurfaceTypes for surface index mapping

	# Pre-create SurfaceTools for all 6 SurfaceTypes
	for i in 6:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface_tools[i] = st
		surface_type_order.append(i)
	# Add one extra surface for invalid/unmapped typ values (-1)
	var st_invalid := SurfaceTool.new()
	st_invalid.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tools[-1] = st_invalid
	surface_type_order.append(-1)
	# Add one extra surface for border sectors (no typ_map) (-2)
	var st_border := SurfaceTool.new()
	st_border.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tools[-2] = st_border
	surface_type_order.append(-2)

	var EDGE: float = float(min(EDGE_SLOPE, SECTOR_SIZE * 0.49))

	# Build geometry per sector, adding to appropriate SurfaceTool based on typ_map
	for y in bh:
		for x in bw:
			var bx := x
			var by := y

			# Determine surface type. Border sectors use a fallback surface (-2).
			var is_border := (bx == 0 or by == 0 or bx == bw - 1 or by == bh - 1)
			var surface_type: int = -2 if is_border else 0
			var typ_value := 0
			if not is_border:
				# Get typ_map value for this sector and map to SurfaceType
				var sector_x := bx - 1  # Convert from bordered coords to typ_map coords
				var sector_y := by - 1
				var typ_idx := sector_y * w + sector_x
				typ_value = int(typ[typ_idx])
				var has_map := mapping.has(typ_value)
				surface_type = int(mapping.get(typ_value, 0))
				surface_type = clampi(surface_type, 0, 5)
				if not has_map:
					surface_type = -1

			# Get SurfaceTool for this SurfaceType (already created)
			var st: SurfaceTool = surface_tools[surface_type]

			# Encode a per-sector atlas variant into the vertex color so the shader
			# can pick different 2x2 atlas quadrants for different typ ids sharing
			# the same SurfaceType. Border sectors keep the default variant 0.
			var variant_index := 0
			if not is_border:
				variant_index = _variant_from_typ(typ_value)
			# Pack variant (0..3) into COLOR.r in the 0..1 range as (cell+0.5)/4.
			var packed_variant := clampi(variant_index, 0, 3)
			st.set_color(Color((float(packed_variant) + 0.5) / 4.0, 0.0, 0.0))

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
			var z0 := y * SECTOR_SIZE
			var z1 := (y + 1) * SECTOR_SIZE
			var ix0: float = x0 + EDGE
			var ix1: float = x1 - EDGE
			var iz0: float = z0 + EDGE
			var iz1: float = z1 - EDGE

			# Edge target heights at the shared boundary
			var y_n_edge := (y_c + y_n) * 0.5
			var y_s_edge := (y_c + y_s) * 0.5
			var y_w_edge := (y_c + y_w) * 0.5
			var y_e_edge := (y_c + y_e) * 0.5

			# 1) Center plateau (flat at sector height) - this is what gets textured
			var p_nw := Vector3(ix0, y_c, iz0)
			var p_ne := Vector3(ix1, y_c, iz0)
			var p_se := Vector3(ix1, y_c, iz1)
			var p_sw := Vector3(ix0, y_c, iz1)
			st.add_vertex(p_nw); st.add_vertex(p_ne); st.add_vertex(p_se)
			st.add_vertex(p_nw); st.add_vertex(p_se); st.add_vertex(p_sw)

			# 2) Edge strips: north, south, west, east
			st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix1, y_s_edge, z1)); st.add_vertex(Vector3(ix0, y_s_edge, z1))
			st.add_vertex(Vector3(x0, y_w_edge, iz0)); st.add_vertex(Vector3(ix0, y_c, iz0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.add_vertex(Vector3(x0, y_w_edge, iz0)); st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(x0, y_w_edge, iz1))
			st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz1))
			st.add_vertex(Vector3(ix1, y_c, iz0)); st.add_vertex(Vector3(x1, y_e_edge, iz1)); st.add_vertex(Vector3(ix1, y_c, iz1))

			# 3) Corner patches
			st.add_vertex(Vector3(x0, y_nw, z0)); st.add_vertex(Vector3(ix0, y_n_edge, z0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.add_vertex(Vector3(x0, y_nw, z0)); st.add_vertex(Vector3(ix0, y_c, iz0)); st.add_vertex(Vector3(x0, y_w_edge, iz0))
			st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(x1, y_ne, z0)); st.add_vertex(Vector3(x1, y_e_edge, iz0))
			st.add_vertex(Vector3(ix1, y_n_edge, z0)); st.add_vertex(Vector3(x1, y_e_edge, iz0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(x1, y_e_edge, iz1)); st.add_vertex(Vector3(x1, y_se, z1))
			st.add_vertex(Vector3(ix1, y_c, iz1)); st.add_vertex(Vector3(x1, y_se, z1)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(ix0, y_s_edge, z1)); st.add_vertex(Vector3(x0, y_sw, z1))
			st.add_vertex(Vector3(x0, y_w_edge, iz1)); st.add_vertex(Vector3(ix0, y_c, iz1)); st.add_vertex(Vector3(x0, y_sw, z1))

	# Commit all non-empty surfaces to mesh and record actual indices
	var mesh := ArrayMesh.new()
	var surface_to_surface_type := {}
	for i in surface_type_order.size():
		var surface_type: int = surface_type_order[i]
		var st: SurfaceTool = surface_tools[surface_type]
		# Index and normals even if empty; commit will no-op if there are no vertices
		var before := mesh.get_surface_count()
		st.index()
		st.generate_normals()
		st.commit(mesh)
		var after := mesh.get_surface_count()
		# Only map when a new surface was actually added
		if after > before:
			surface_to_surface_type[before] = surface_type

	return {"mesh": mesh, "surface_to_surface_type": surface_to_surface_type}

# Apply sector top materials with ground textures based on SurfaceType
# surface_to_surface_type: Dictionary mapping surface_index -> SurfaceType (0-5)
func _apply_sector_top_materials(mesh: ArrayMesh, preloads, surface_to_surface_type: Dictionary) -> void:
	if not preloads:
		return

	var shader: Shader = load("res://resources/terrain/shaders/sector_top.gdshader")
	if not shader:
		push_warning("[Map3D] Could not load sector_top.gdshader")
		return

	# Apply material for each surface using the surface_to_surface_type mapping
	for surface_idx in surface_to_surface_type.keys():
		var surface_type: int = surface_to_surface_type[surface_idx]
		# Unmapped/invalid typ values: assign translucent debug material
		if surface_type == -1:
			var dbg := StandardMaterial3D.new()
			dbg.albedo_color = Color(1.0, 0.0, 1.0, 0.45)
			dbg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.surface_set_material(surface_idx, dbg)
			continue
		# Border sectors: use neutral set texture 0 with the sector_top shader
		elif surface_type == -2:
			var border_mat := ShaderMaterial.new()
			border_mat.shader = shader
			if preloads:
				border_mat.set_shader_parameter("ground_texture", preloads.get_ground_texture(0))
				border_mat.set_shader_parameter("tile_scale", _compute_tile_scale())
				# Use the 2x2 atlas layout but keep a neutral, fixed quadrant for borders.
				border_mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
				border_mat.set_shader_parameter("use_vertex_variant", false)
				border_mat.set_shader_parameter("variant", 0)
			mesh.surface_set_material(surface_idx, border_mat)
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		# Get the ground texture for this SurfaceType (0-5)
		var texture: Texture2D = preloads.get_ground_texture(surface_type)
		if texture:
			mat.set_shader_parameter("ground_texture", texture)
			mat.set_shader_parameter("tile_scale", _compute_tile_scale())
			# UA ground textures are 2x2 atlases; pick the quadrant per typ_map via vertex COLOR.
			mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
			mat.set_shader_parameter("use_vertex_variant", true)
			mat.set_shader_parameter("variant", 0)
			mesh.surface_set_material(surface_idx, mat)

# ---- UA edge-based strip rendering ----
func _on_level_set_changed() -> void:
	# Rebuild the full terrain to refresh top materials and edge strips when set changes
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
	var mesh := _build_edges_mesh(hgt, w, h, typ, mapping)
	_ensure_edge_node()
	_edge_mesh.mesh = mesh

func _build_edges_mesh(hgt: PackedByteArray, w: int, h: int, typ: PackedByteArray, mapping: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var shader: Shader = load("res://resources/terrain/shaders/edge_blend.gdshader")
	var pre = null
	if is_inside_tree():
		pre = get_node_or_null("/root/Preloads")
	# Collect per (surfaceA, surfaceB) pair to minimize materials
	var horiz := {}
	var vert := {}
	# Horizontal seams between (x,y) and (x+1,y)
	# typ_map coordinates need to be offset by 1 sector to account for the border in hgt_map
	for y in h:
		for x in (w - 1):
			var a := int(typ[y * w + x])
			var b := int(typ[y * w + x + 1])
			# Skip seams touching invalid/unmapped typ values
			if not mapping.has(a) or not mapping.has(b):
				continue
			var sa := int(mapping.get(a, 0))
			var sb := int(mapping.get(b, 0))
			var key := "h_%d_%d" % [sa, sb]
			var st: SurfaceTool = horiz.get(key)
			if st == null:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				horiz[key] = st
			# geometry - offset by SECTOR_SIZE to account for border
			var seam_x := float(x + 1 + 1) * SECTOR_SIZE  # +1 for seam, +1 for border offset
			var x0 := seam_x - EDGE_SLOPE
			var x1 := seam_x + EDGE_SLOPE
			var z0 := float(y + 1) * SECTOR_SIZE  # +1 for border offset
			var z1 := float(y + 1 + 1) * SECTOR_SIZE  # +1 for next sector, +1 for border offset
			var yL := _center_h(hgt, w, h, x, y)
			var yR := _center_h(hgt, w, h, x + 1, y)
			var yN_L := _center_h(hgt, w, h, x, y - 1)
			var yN_R := _center_h(hgt, w, h, x + 1, y - 1)
			var yS_L := _center_h(hgt, w, h, x, y + 1)
			var yS_R := _center_h(hgt, w, h, x + 1, y + 1)
			var yLT := (yL + yN_L) * 0.5
			var yRT := (yR + yN_R) * 0.5
			var yLB := (yL + yS_L) * 0.5
			var yRB := (yR + yS_R) * 0.5
			# two triangles with UV across seam (x 0..1) and along length (z 0..1)
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, yLT, z0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(x1, yRT, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, yRB, z1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, yLT, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, yRB, z1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(x0, yLB, z1))
	# Vertical seams between (x,y) and (x,y+1)
	# typ_map coordinates need to be offset by 1 sector to account for the border in hgt_map
	for y in (h - 1):
		for x in w:
			var a2 := int(typ[y * w + x])
			var b2 := int(typ[(y + 1) * w + x])
			# Skip seams touching invalid/unmapped typ values
			if not mapping.has(a2) or not mapping.has(b2):
				continue
			var sa2 := int(mapping.get(a2, 0))
			var sb2 := int(mapping.get(b2, 0))
			var key2 := "v_%d_%d" % [sa2, sb2]
			var st2: SurfaceTool = vert.get(key2)
			if st2 == null:
				st2 = SurfaceTool.new()
				st2.begin(Mesh.PRIMITIVE_TRIANGLES)
				vert[key2] = st2
			# geometry - offset by SECTOR_SIZE to account for border
			var seam_z := float(y + 1 + 1) * SECTOR_SIZE  # +1 for seam, +1 for border offset
			var z0v := seam_z - EDGE_SLOPE
			var z1v := seam_z + EDGE_SLOPE
			var x0v := float(x + 1) * SECTOR_SIZE  # +1 for border offset
			var x1v := float(x + 1 + 1) * SECTOR_SIZE  # +1 for next sector, +1 for border offset
			var yT := _center_h(hgt, w, h, x, y)
			var yB := _center_h(hgt, w, h, x, y + 1)
			var yW_T := _center_h(hgt, w, h, x - 1, y)
			var yE_T := _center_h(hgt, w, h, x + 1, y)
			var yW_B := _center_h(hgt, w, h, x - 1, y + 1)
			var yE_B := _center_h(hgt, w, h, x + 1, y + 1)
			var yTL := (yT + yW_T) * 0.5
			var yTR := (yT + yE_T) * 0.5
			var yBL := (yB + yW_B) * 0.5
			var yBR := (yB + yE_B) * 0.5
			# two triangles with UV across seam (x 0..1) and along length (z 0..1)
			st2.set_uv(Vector2(0.0, 0.0)); st2.add_vertex(Vector3(x0v, yTL, z0v))
			st2.set_uv(Vector2(1.0, 0.0)); st2.add_vertex(Vector3(x1v, yTR, z0v))
			st2.set_uv(Vector2(1.0, 1.0)); st2.add_vertex(Vector3(x1v, yBR, z1v))
			st2.set_uv(Vector2(0.0, 0.0)); st2.add_vertex(Vector3(x0v, yTL, z0v))
			st2.set_uv(Vector2(1.0, 1.0)); st2.add_vertex(Vector3(x1v, yBR, z1v))
			st2.set_uv(Vector2(0.0, 1.0)); st2.add_vertex(Vector3(x0v, yBL, z1v))

		# --- Border seams: connect border ring to inner playable area ---
		# North border (between border row and y=0)
		for x in w:
			var inner_typ_top := int(typ[0 * w + x])
			if not mapping.has(inner_typ_top):
				continue
			var sa_top := 0
			var sb_top := int(mapping.get(inner_typ_top, 0))
			var key_top := "v_%d_%d" % [sa_top, sb_top]
			var st_top: SurfaceTool = vert.get(key_top)
			if st_top == null:
				st_top = SurfaceTool.new()
				st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
				vert[key_top] = st_top
			var seam_zn := float(1) * SECTOR_SIZE
			var z0n := seam_zn - EDGE_SLOPE
			var z1n := seam_zn + EDGE_SLOPE
			var x0n := float(x + 1) * SECTOR_SIZE
			var x1n := float(x + 2) * SECTOR_SIZE
			var yTn := _center_h(hgt, w, h, x, -1)
			var yBn := _center_h(hgt, w, h, x, 0)
			var yW_Tn := _center_h(hgt, w, h, x - 1, -1)
			var yE_Tn := _center_h(hgt, w, h, x + 1, -1)
			var yW_Bn := _center_h(hgt, w, h, x - 1, 0)
			var yE_Bn := _center_h(hgt, w, h, x + 1, 0)
			var yTLn := (yTn + yW_Tn) * 0.5
			var yTRn := (yTn + yE_Tn) * 0.5
			var yBLn := (yBn + yW_Bn) * 0.5
			var yBRn := (yBn + yE_Bn) * 0.5
			st_top.set_uv(Vector2(0.0, 0.0)); st_top.add_vertex(Vector3(x0n, yTLn, z0n))
			st_top.set_uv(Vector2(1.0, 0.0)); st_top.add_vertex(Vector3(x1n, yTRn, z0n))
			st_top.set_uv(Vector2(1.0, 1.0)); st_top.add_vertex(Vector3(x1n, yBRn, z1n))
			st_top.set_uv(Vector2(0.0, 0.0)); st_top.add_vertex(Vector3(x0n, yTLn, z0n))
			st_top.set_uv(Vector2(1.0, 1.0)); st_top.add_vertex(Vector3(x1n, yBRn, z1n))
			st_top.set_uv(Vector2(0.0, 1.0)); st_top.add_vertex(Vector3(x0n, yBLn, z1n))
		# South border (between y=h-1 and border row)
		for x in w:
			var inner_typ_bottom := int(typ[(h - 1) * w + x])
			if not mapping.has(inner_typ_bottom):
				continue
			var sa_bottom := int(mapping.get(inner_typ_bottom, 0))
			var sb_bottom := 0
			var key_bottom := "v_%d_%d" % [sa_bottom, sb_bottom]
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
			var yW_Ts := _center_h(hgt, w, h, x - 1, h - 1)
			var yE_Ts := _center_h(hgt, w, h, x + 1, h - 1)
			var yW_Bs := _center_h(hgt, w, h, x - 1, h)
			var yE_Bs := _center_h(hgt, w, h, x + 1, h)
			var yTLs := (yTs + yW_Ts) * 0.5
			var yTRs := (yTs + yE_Ts) * 0.5
			var yBLs := (yBs + yW_Bs) * 0.5
			var yBRs := (yBs + yE_Bs) * 0.5
			st_bottom.set_uv(Vector2(0.0, 0.0)); st_bottom.add_vertex(Vector3(x0s, yTLs, z0s))
			st_bottom.set_uv(Vector2(1.0, 0.0)); st_bottom.add_vertex(Vector3(x1s, yTRs, z0s))
			st_bottom.set_uv(Vector2(1.0, 1.0)); st_bottom.add_vertex(Vector3(x1s, yBRs, z1s))
			st_bottom.set_uv(Vector2(0.0, 0.0)); st_bottom.add_vertex(Vector3(x0s, yTLs, z0s))
			st_bottom.set_uv(Vector2(1.0, 1.0)); st_bottom.add_vertex(Vector3(x1s, yBRs, z1s))
			st_bottom.set_uv(Vector2(0.0, 1.0)); st_bottom.add_vertex(Vector3(x0s, yBLs, z1s))
		# West border (between border column and x=0)
		for yy in h:
			var inner_typ_left := int(typ[yy * w + 0])
			if not mapping.has(inner_typ_left):
				continue
			var sa_left := 0
			var sb_left := int(mapping.get(inner_typ_left, 0))
			var key_left := "h_%d_%d" % [sa_left, sb_left]
			var st_left: SurfaceTool = horiz.get(key_left)
			if st_left == null:
				st_left = SurfaceTool.new()
				st_left.begin(Mesh.PRIMITIVE_TRIANGLES)
				horiz[key_left] = st_left
			var seam_xw := float(1) * SECTOR_SIZE
			var x0w := seam_xw - EDGE_SLOPE
			var x1w := seam_xw + EDGE_SLOPE
			var z0w := float(yy + 1) * SECTOR_SIZE
			var z1w := float(yy + 2) * SECTOR_SIZE
			var yLw := _center_h(hgt, w, h, -1, yy)
			var yRw := _center_h(hgt, w, h, 0, yy)
			var yN_Lw := _center_h(hgt, w, h, -1, yy - 1)
			var yN_Rw := _center_h(hgt, w, h, 0, yy - 1)
			var yS_Lw := _center_h(hgt, w, h, -1, yy + 1)
			var yS_Rw := _center_h(hgt, w, h, 0, yy + 1)
			var yLTw := (yLw + yN_Lw) * 0.5
			var yRTw := (yRw + yN_Rw) * 0.5
			var yLBw := (yLw + yS_Lw) * 0.5
			var yRBw := (yRw + yS_Rw) * 0.5
			st_left.set_uv(Vector2(0.0, 0.0)); st_left.add_vertex(Vector3(x0w, yLTw, z0w))
			st_left.set_uv(Vector2(1.0, 0.0)); st_left.add_vertex(Vector3(x1w, yRTw, z0w))
			st_left.set_uv(Vector2(1.0, 1.0)); st_left.add_vertex(Vector3(x1w, yRBw, z1w))
			st_left.set_uv(Vector2(0.0, 0.0)); st_left.add_vertex(Vector3(x0w, yLTw, z0w))
			st_left.set_uv(Vector2(1.0, 1.0)); st_left.add_vertex(Vector3(x1w, yRBw, z1w))
			st_left.set_uv(Vector2(0.0, 1.0)); st_left.add_vertex(Vector3(x0w, yLBw, z1w))
		# East border (between x=w-1 and border column)
		for yy2 in h:
			var inner_typ_right := int(typ[yy2 * w + (w - 1)])
			if not mapping.has(inner_typ_right):
				continue
			var sa_right := int(mapping.get(inner_typ_right, 0))
			var sb_right := 0
			var key_right := "h_%d_%d" % [sa_right, sb_right]
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
			var yN_Le := _center_h(hgt, w, h, w - 1, yy2 - 1)
			var yN_Re := _center_h(hgt, w, h, w, yy2 - 1)
			var yS_Le := _center_h(hgt, w, h, w - 1, yy2 + 1)
			var yS_Re := _center_h(hgt, w, h, w, yy2 + 1)
			var yLTe := (yLe + yN_Le) * 0.5
			var yRTe := (yRe + yN_Re) * 0.5
			var yLBe := (yLe + yS_Le) * 0.5
			var yRBe := (yRe + yS_Re) * 0.5
			st_right.set_uv(Vector2(0.0, 0.0)); st_right.add_vertex(Vector3(x0e, yLTe, z0e))
			st_right.set_uv(Vector2(1.0, 0.0)); st_right.add_vertex(Vector3(x1e, yRTe, z0e))
			st_right.set_uv(Vector2(1.0, 1.0)); st_right.add_vertex(Vector3(x1e, yRBe, z1e))
			st_right.set_uv(Vector2(0.0, 0.0)); st_right.add_vertex(Vector3(x0e, yLTe, z0e))
			st_right.set_uv(Vector2(1.0, 1.0)); st_right.add_vertex(Vector3(x1e, yRBe, z1e))
			st_right.set_uv(Vector2(0.0, 1.0)); st_right.add_vertex(Vector3(x0e, yLBe, z1e))
	# Commit groups and assign materials per pair
	for key_h in horiz.keys():
		var st_h: SurfaceTool = horiz[key_h]
		st_h.index(); st_h.generate_normals(); st_h.commit(mesh)
		var parts_h: Array = key_h.split("_")
		var a_h := int(parts_h[1])
		var b_h := int(parts_h[2])
		var sm := ShaderMaterial.new()
		sm.shader = shader
		if pre:
			sm.set_shader_parameter("texture_a", pre.get_ground_texture(a_h))
			sm.set_shader_parameter("texture_b", pre.get_ground_texture(b_h))
		sm.set_shader_parameter("vertical_seam", false)
		sm.set_shader_parameter("tile_scale", _compute_tile_scale())
		# Use full textures for edges as well; no atlas subdivision.
		sm.set_shader_parameter("atlas_grid", Vector2(1.0, 1.0))
		sm.set_shader_parameter("variant_a", 0)
		sm.set_shader_parameter("variant_b", 0)
		mesh.surface_set_material(mesh.get_surface_count() - 1, sm)
	for key_v in vert.keys():
		var st_v: SurfaceTool = vert[key_v]
		st_v.index(); st_v.generate_normals(); st_v.commit(mesh)
		var parts_v: Array = key_v.split("_")
		var a_v := int(parts_v[1])
		var b_v := int(parts_v[2])
		var sm2 := ShaderMaterial.new()
		sm2.shader = shader
		if pre:
			sm2.set_shader_parameter("texture_a", pre.get_ground_texture(a_v))
			sm2.set_shader_parameter("texture_b", pre.get_ground_texture(b_v))
		sm2.set_shader_parameter("vertical_seam", true)
		sm2.set_shader_parameter("tile_scale", _compute_tile_scale())
		# Match top surfaces: full texture, no atlas subdivision.
		sm2.set_shader_parameter("atlas_grid", Vector2(1.0, 1.0))
		sm2.set_shader_parameter("variant_a", 0)
		sm2.set_shader_parameter("variant_b", 0)
		mesh.surface_set_material(mesh.get_surface_count() - 1, sm2)
	return mesh

func _center_h(hgt: PackedByteArray, w: int, h: int, sx: int, sy: int) -> float:
	var bw := w + 2
	var bh := h + 2
	sx = clampi(sx + 1, 0, bw - 1)
	sy = clampi(sy + 1, 0, bh - 1)
	return float(hgt[sy * bw + sx]) * HEIGHT_SCALE

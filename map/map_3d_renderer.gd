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
var _edge_overlay_enabled := false

@onready var _camera: Camera3D = $Camera3D

var _mouselook := false
var _yaw := 0.0
var _pitch := -0.6
var _move_speed := 1200.0
var _sprint_mult := 2.0
var _look_sens := 0.0025
var _framed := false
var _debug_shader_mode: int = 0 # 0=normal, 1=file index colors, 2=variant grayscale

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
	var subsector_patterns: Dictionary = pre.subsector_patterns if pre else {}
	var tile_mapping: Dictionary = pre.tile_mapping if pre else {}
	var current_set = 1
	if _cmd:
		current_set = int(_cmd.level_set)
	var result := build_mesh_with_textures(hgt, typ, w, h, mapping, subsector_patterns, tile_mapping, pre.tile_remap if pre else {}, current_set)
	var mesh: ArrayMesh = result["mesh"]
	var surface_to_surface_type: Dictionary = result["surface_to_surface_type"]
	var surf_count: int = mesh.get_surface_count()
	print("[Map3D] build_from_current_map: built mesh with surfaces=", surf_count)
	if _terrain_mesh:
		_terrain_mesh.mesh = mesh
		print("[Map3D] build_from_current_map: mesh assigned to TerrainMesh")

		# Apply sector top materials per surface (using ground_textures based on SurfaceType)
		_apply_sector_top_materials(mesh, pre, surface_to_surface_type)

		# Optionally build overlay edge strips; disabled to avoid z-fighting
		if _edge_overlay_enabled:
			_build_edges_from_current_map()
		else:
			if _edge_mesh:
				_edge_mesh.mesh = null

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

# Compute a per-sector atlas variant from a typ_map value using subsector patterns.
# Returns the average/center subsector index from the 3x3 grid for simple cases,
# or encodes full pattern information for faithful rendering.
static func _variant_from_typ(typ_value: int, subsector_patterns: Dictionary) -> int:
	if subsector_patterns.has(typ_value):
		var pattern = subsector_patterns[typ_value]
		var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
		# Use center subsector (index 4 in 3x3 grid) as representative variant
		# This provides better variety than just typ_value & 3
		if subsectors.size() >= 5:
			# Map subsector index to 0-3 range for 2x2 atlas compatibility
			return subsectors[4] & 3
	# Fallback to simple variant
	return typ_value & 3
# This function maps subsector tile indices to ground texture files using UA's original logic
static func _decode_raw_to_fcv(raw_val: int, default_file: int) -> Array:
	var f: int
	var cells: int
	var v: int
	# Map raw tile id by repeating 36-entry buckets. UA encodes files/variants in groups of 36.
	var n := raw_val % 36
	if n >= 0 and n < 4:
		# 0-3: sector surface type, 2x2
		f = default_file
		cells = (16 if f == 4 else 4)
		v = n
	elif n < 8:
		# 4-7: file 1, 2x2
		f = 1
		cells = 4
		v = n - 4
	elif n < 12:
		# 8-11: file 2, 2x2
		f = 2
		cells = 4
		v = n - 8
	elif n < 16:
		# 12-15: file 3, 2x2
		f = 3
		cells = 4
		v = n - 12
	elif n < 32:
		# 16-31: file 4, 4x4 (16 variants)
		f = 4
		cells = 16
		v = n - 16
	else:
		# 32-35: file 5, 2x2
		f = 5
		cells = 4
		v = n - 32
	return [f, cells, v]

# Same as above, but first consults an optional per-set remap (raw tile id -> file/variant)
static func _decode_raw_to_fcv_with_remap(raw_val: int, default_file: int, tile_remap: Dictionary) -> Array:
	if tile_remap and tile_remap.has(str(raw_val)):
		var m: Dictionary = tile_remap[str(raw_val)]
		var file_idx: int = int(m.get("file", default_file))
		var cells: int = (16 if file_idx == 4 else 4)
		var variant_idx: int = clampi(int(m.get("variant", 0)), 0, cells - 1)
		return [file_idx, cells, variant_idx]
	return _decode_raw_to_fcv(raw_val, default_file)

# Debug helper to understand subsector-to-texture mapping
static func debug_subsector_mapping(typ_value: int, subsector_patterns: Dictionary, tile_mapping: Dictionary) -> void:
	if not subsector_patterns.has(typ_value):
		print("DEBUG: typ %d has no subsector pattern" % typ_value)
		return
	
	var pattern = subsector_patterns[typ_value]
	var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
	var surface_type: int = int(pattern.get("surface_type", 0))
	
	print("DEBUG: typ %d -> surface_type %d, subsectors: %s" % [typ_value, surface_type, subsectors])
	
	for i in range(min(subsectors.size(), 9)):
		var sub_idx = subsectors[i]
		if tile_mapping.has(sub_idx):
			var tile_data = tile_mapping[sub_idx]
			var raw_vals = [tile_data.get("val0", 0), tile_data.get("val1", 0), tile_data.get("val2", 0), tile_data.get("val3", 0)]
			print("  subsector[%d] = %d -> tile_mapping vals: %s" % [i, sub_idx, raw_vals])
		else:
			print("  subsector[%d] = %d -> NO TILE MAPPING!" % [i, sub_idx])

# Build mesh with per-sector texturing support
# Creates separate surfaces for each SurfaceType (0-5) to enable different ground textures
# Returns: Dictionary with keys "mesh" (ArrayMesh) and "surface_to_surface_type" (Dictionary mapping surface_index -> SurfaceType)
static func build_mesh_with_textures(hgt: PackedByteArray, typ: PackedByteArray, w: int, h: int, mapping: Dictionary, subsector_patterns: Dictionary = {}, tile_mapping: Dictionary = {}, tile_remap: Dictionary = {}, set_id: int = 1) -> Dictionary:
	var bw := w + 2
	var bh := h + 2
	if hgt.size() != bw * bh or typ.size() != w * h or w <= 0 or h <= 0:
		return {"mesh": ArrayMesh.new(), "surface_to_surface_type": {}}

	# Group sectors by SurfaceType (0-5) to create separate surfaces
	# This allows each SurfaceType to have its own ground texture
	var surface_tools := {} # SurfaceType -> SurfaceTool
	var surface_type_order: Array[int] = [] # Track order of SurfaceTypes for surface index mapping

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
				var sector_x := bx - 1 # Convert from bordered coords to typ_map coords
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
			var total_cells := 4
			var variant_index := 0
			if not is_border:
				total_cells = (16 if surface_type == 4 else 4)
				if subsector_patterns.has(typ_value):
					var pattern2 = subsector_patterns[typ_value]
					var subs2: PackedInt32Array = pattern2.get("subsectors", PackedInt32Array())
					if subs2.size() >= 5:
						variant_index = subs2[4] & (total_cells - 1)
					else:
						variant_index = typ_value & (total_cells - 1)
				else:
					variant_index = typ_value & (total_cells - 1)
			# Pack variant (0..3) into COLOR.r in the 0..1 range as (cell+0.5)/4.
			var packed_variant := clampi(variant_index, 0, total_cells - 1)
			st.set_color(Color((float(packed_variant) + 0.5) / float(total_cells), 0.0, 0.0))

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

			# 1) Center plateau (flat at sector height)
			# 3x3 mosaic from subsector patterns when sector type is SECTYPE_3X3 (0)
			var composed := false
			# Special-case: set 1 typ 0 is 3x3 of ground_2 top-left (2x2 atlas, cell 0)
			var override_typ0 := (set_id == 1 and not is_border and typ_value == 0)
			if override_typ0:
				var step_x_o: float = (ix1 - ix0) / 3.0
				var step_z_o: float = (iz1 - iz0) / 3.0
				for cy_o in 3:
					for cx_o in 3:
						var xl_o: float = ix0 + float(cx_o) * step_x_o
						var xr_o: float = xl_o + step_x_o
						var zt_o: float = iz0 + float(cy_o) * step_z_o
						var zb_o: float = zt_o + step_z_o
						var f_override := 2
						var cells_override := 4
						var v_override := 0
						st.set_color(Color((float(v_override) + 0.5) / float(cells_override), (float(f_override) + 0.5) / 6.0, 0.0))
						# Single quad filling the subcell with atlas cell 0 of ground_2
						st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl_o, y_c, zt_o))
						st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(xr_o, y_c, zt_o))
						st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr_o, y_c, zb_o))
						st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl_o, y_c, zt_o))
						st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr_o, y_c, zb_o))
						st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(xl_o, y_c, zb_o))
				composed = true
			if not composed and not is_border and subsector_patterns.has(typ_value):
				var pat = subsector_patterns[typ_value]
				var sector_t: int = int(pat.get("sector_type", -1))
				var subs: PackedInt32Array = pat.get("subsectors", PackedInt32Array())
				if sector_t == 0 and subs.size() >= 9:
					var step_x: float = (ix1 - ix0) / 3.0
					var step_z: float = (iz1 - iz0) / 3.0
					for cy in 3:
						for cx in 3:
							# Sector coords in typ space for world-subcell addressing
							var _sx := bx - 1
							var _sy := by - 1
							var si: int = subs[cy * 3 + cx]
							var td: Dictionary = tile_mapping.get(si, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
							var vals := [int(td.get("val0", 0)), int(td.get("val1", 0)), int(td.get("val2", 0)), int(td.get("val3", 0))]
							var flg: int = int(td.get("flag", 0))
							# Selection rule inferred from UA:
							# - If flag != 0: pick one of the four values pseudo-randomly but deterministically by world subcell
							# - Else: use a 2x2 tiling pattern across the world: NW,NE,SW,SE
							var world_cx := (_sx * 3) + cx
							var world_cy := (_sy * 3) + cy
							var sel_idx: int
							if flg != 0:
								var sel_seed := (world_cx * 73856093) ^ (world_cy * 19349663) ^ (typ_value * 83492791)
								sel_idx = sel_seed & 3
							else:
								sel_idx = ((world_cy & 1) << 1) | (world_cx & 1)
							var raw: int = int(vals[sel_idx])
							if raw == 0:
								# Fallback: first non-zero among the group
								for vtry in vals:
									if int(vtry) != 0:
										raw = int(vtry)
										break
							var dec := _decode_raw_to_fcv_with_remap(raw, surface_type, tile_remap)
							var f: int = dec[0]
							var cells: int = dec[1]
							var v: int = dec[2]
							var xl: float = ix0 + float(cx) * step_x
							var xr: float = xl + step_x
							var zt: float = iz0 + float(cy) * step_z
							var zb: float = zt + step_z
							st.set_color(Color((float(v) + 0.5) / float(cells), (float(f) + 0.5) / 6.0, 0.0))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl, y_c, zt))
							st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(xr, y_c, zt))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr, y_c, zb))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl, y_c, zt))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr, y_c, zb))
							st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(xl, y_c, zb))
						# end mosaic cell
						composed = true
				elif subs.size() == 1:
					# Uniform sector: replicate a single subsector across a 3x3 grid
					var step_x1: float = (ix1 - ix0) / 3.0
					var step_z1: float = (iz1 - iz0) / 3.0
					var _sx1 := bx - 1
					var _sy1 := by - 1
					for cy1 in 3:
						for cx1 in 3:
							var si1: int = subs[0]
							var td1: Dictionary = tile_mapping.get(si1, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
							var vals1 := [int(td1.get("val0", 0)), int(td1.get("val1", 0)), int(td1.get("val2", 0)), int(td1.get("val3", 0))]
							var flg1: int = int(td1.get("flag", 0))
							var wcx1 := (_sx1 * 3) + cx1
							var wcy1 := (_sy1 * 3) + cy1
							var sel1: int
							if flg1 != 0:
								var sel_seed1 := (wcx1 * 73856093) ^ (wcy1 * 19349663) ^ (typ_value * 83492791)
								sel1 = sel_seed1 & 3
							else:
								sel1 = ((wcy1 & 1) << 1) | (wcx1 & 1)
							var raw1: int = int(vals1[sel1])
							if raw1 == 0:
								for vtry1 in vals1:
									if int(vtry1) != 0:
										raw1 = int(vtry1)
										break
							var dec1 := _decode_raw_to_fcv_with_remap(raw1, surface_type, tile_remap)
							var f1: int = dec1[0]
							var cells1: int = dec1[1]
							var v1: int = dec1[2]
							var xl1: float = ix0 + float(cx1) * step_x1
							var xr1: float = xl1 + step_x1
							var zt1: float = iz0 + float(cy1) * step_z1
							var zb1: float = zt1 + step_z1
							st.set_color(Color((float(v1) + 0.5) / float(cells1), (float(f1) + 0.5) / 6.0, 0.0))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl1, y_c, zt1))
							st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(xr1, y_c, zt1))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr1, y_c, zb1))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl1, y_c, zt1))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr1, y_c, zb1))
							st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(xl1, y_c, zb1))
					composed = true
				elif subs.size() == 4:
					# 2x2 pattern
					var step_x2: float = (ix1 - ix0) / 2.0
					var step_z2: float = (iz1 - iz0) / 2.0
					var _sx3 := bx - 1
					var _sy3 := by - 1
					for cy2 in 2:
						for cx2 in 2:
							var si2: int = subs[cy2 * 2 + cx2]
							var td2: Dictionary = tile_mapping.get(si2, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
							var vals2 := [int(td2.get("val0", 0)), int(td2.get("val1", 0)), int(td2.get("val2", 0)), int(td2.get("val3", 0))]
							var flg2: int = int(td2.get("flag", 0))
							var wcx2 := (_sx3 * 2) + cx2
							var wcy2 := (_sy3 * 2) + cy2
							var sel2: int
							if flg2 != 0:
								var sel_seed2 := (wcx2 * 73856093) ^ (wcy2 * 19349663) ^ (typ_value * 83492791)
								sel2 = sel_seed2 & 3
							else:
								sel2 = ((wcy2 & 1) << 1) | (wcx2 & 1)
							var raw2: int = int(vals2[sel2])
							if raw2 == 0:
								for vtry2 in vals2:
									if int(vtry2) != 0:
										raw2 = int(vtry2)
										break
							var dec2 := _decode_raw_to_fcv_with_remap(raw2, surface_type, tile_remap)
							var f2: int = dec2[0]
							var cells2: int = dec2[1]
							var v2: int = dec2[2]
							var xl2: float = ix0 + float(cx2) * step_x2
							var xr2: float = xl2 + step_x2
							var zt2: float = iz0 + float(cy2) * step_z2
							var zb2: float = zt2 + step_z2
							st.set_color(Color((float(v2) + 0.5) / float(cells2), (float(f2) + 0.5) / 6.0, 0.0))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl2, y_c, zt2))
							st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(xr2, y_c, zt2))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr2, y_c, zb2))
							st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(xl2, y_c, zt2))
							st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(xr2, y_c, zb2))
							st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(xl2, y_c, zb2))
					composed = true
			if not composed:
				var p_nw := Vector3(ix0, y_c, iz0)
				var p_ne := Vector3(ix1, y_c, iz0)
				var p_se := Vector3(ix1, y_c, iz1)
				var p_sw := Vector3(ix0, y_c, iz1)
				# Temporary: choose atlas cell from a hash of typ and sector coords to reduce tiling
				var cells_fallback: int = (16 if surface_type == 4 else 4)
				var seed_f: int = (typ_value ^ (bx * 73856093) ^ (by * 19349663))
				var vcell: int = (seed_f & 0x7fffffff) % cells_fallback
				st.set_color(Color((float(vcell) + 0.5) / float(cells_fallback), (float(surface_type) + 0.5) / 6.0, 0.0))
				st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p_nw)
				st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p_ne)
				st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p_se)
				st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p_nw)
				st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p_se)
				st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p_sw)

			# 2) Edge strips: pick file/variant from side mosaic cells when available
			var north_f := surface_type; var north_cells := (16 if north_f == 4 else 4); var north_v := packed_variant
			var south_f := north_f; var south_cells := north_cells; var south_v := packed_variant
			var west_f := north_f; var west_cells := north_cells; var west_v := packed_variant
			var east_f := north_f; var east_cells := north_cells; var east_v := packed_variant
			if override_typ0:
				north_f = 2; south_f = 2; west_f = 2; east_f = 2
				north_cells = 4; south_cells = 4; west_cells = 4; east_cells = 4
				north_v = 0; south_v = 0; west_v = 0; east_v = 0
			elif subsector_patterns.has(typ_value):
				var patE = subsector_patterns[typ_value]
				if int(patE.get("sector_type", -1)) == 0:
					var subsE: PackedInt32Array = patE.get("subsectors", PackedInt32Array())
					if subsE.size() >= 9:
						# Select raw from N, S, W, E mid cells; prefer first non-zero
						var _sx2 := bx - 1
						var _sy2 := by - 1
						var idxN := subsE[0 * 3 + 1]
						var tN: Dictionary = tile_mapping.get(idxN, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
						var valsN := [int(tN.get("val0", 0)), int(tN.get("val1", 0)), int(tN.get("val2", 0)), int(tN.get("val3", 0))]
						var flgN: int = int(tN.get("flag", 0))
						var selN: int = ((((_sy2 * 3 + 0) & 1) << 1) | (((_sx2 * 3 + 1) & 1)))
						if flgN != 0:
							var sel_seedN := (((_sx2 * 3 + 1) * 73856093) ^ ((_sy2 * 3 + 0) * 19349663) ^ (typ_value * 83492791))
							selN = sel_seedN & 3
						var rawN: int = int(valsN[selN]); if rawN == 0: for vtry in valsN: if int(vtry) != 0: rawN = int(vtry); break
						var dN := _decode_raw_to_fcv_with_remap(rawN, surface_type, tile_remap); north_f = dN[0]; north_cells = dN[1]; north_v = dN[2]
						var idxS := subsE[2 * 3 + 1]
						var tS: Dictionary = tile_mapping.get(idxS, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
						var valsS := [int(tS.get("val0", 0)), int(tS.get("val1", 0)), int(tS.get("val2", 0)), int(tS.get("val3", 0))]
						var flgS: int = int(tS.get("flag", 0))
						var selS: int = ((((_sy2 * 3 + 2) & 1) << 1) | (((_sx2 * 3 + 1) & 1)))
						if flgS != 0:
							var sel_seedS := (((_sx2 * 3 + 1) * 73856093) ^ ((_sy2 * 3 + 2) * 19349663) ^ (typ_value * 83492791))
							selS = sel_seedS & 3
						var rawS: int = int(valsS[selS]); if rawS == 0: for vtry in valsS: if int(vtry) != 0: rawS = int(vtry); break
						var dS := _decode_raw_to_fcv_with_remap(rawS, surface_type, tile_remap); south_f = dS[0]; south_cells = dS[1]; south_v = dS[2]
						var idxW := subsE[1 * 3 + 0]
						var tW: Dictionary = tile_mapping.get(idxW, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
						var valsW := [int(tW.get("val0", 0)), int(tW.get("val1", 0)), int(tW.get("val2", 0)), int(tW.get("val3", 0))]
						var flgW: int = int(tW.get("flag", 0))
						var selW: int = ((((_sy2 * 3 + 1) & 1) << 1) | (((_sx2 * 3 + 0) & 1)))
						if flgW != 0:
							var sel_seedW := (((_sx2 * 3 + 0) * 73856093) ^ ((_sy2 * 3 + 1) * 19349663) ^ (typ_value * 83492791))
							selW = sel_seedW & 3
						var rawW: int = int(valsW[selW]); if rawW == 0: for vtry in valsW: if int(vtry) != 0: rawW = int(vtry); break
						var dW := _decode_raw_to_fcv_with_remap(rawW, surface_type, tile_remap); west_f = dW[0]; west_cells = dW[1]; west_v = dW[2]
						var idxE := subsE[1 * 3 + 2]
						var tE: Dictionary = tile_mapping.get(idxE, {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 0})
						var valsE := [int(tE.get("val0", 0)), int(tE.get("val1", 0)), int(tE.get("val2", 0)), int(tE.get("val3", 0))]
						var flgE: int = int(tE.get("flag", 0))
						var selE: int = ((((_sy2 * 3 + 1) & 1) << 1) | (((_sx2 * 3 + 2) & 1)))
						if flgE != 0:
							var sel_seedE := (((_sx2 * 3 + 2) * 73856093) ^ ((_sy2 * 3 + 1) * 19349663) ^ (typ_value * 83492791))
							selE = sel_seedE & 3
						var rawE: int = int(valsE[selE]); if rawE == 0: for vtry in valsE: if int(vtry) != 0: rawE = int(vtry); break
						var dE := _decode_raw_to_fcv_with_remap(rawE, surface_type, tile_remap); east_f = dE[0]; east_cells = dE[1]; east_v = dE[2]

			# North strip
			st.set_color(Color((float(north_v) + 0.5) / float(north_cells), (float(north_f) + 0.5) / 6.0, 0.0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix0, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(ix1, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix0, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			# South strip
			st.set_color(Color((float(south_v) + 0.5) / float(south_cells), (float(south_f) + 0.5) / 6.0, 0.0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(ix1, y_c, iz1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(ix0, y_s_edge, z1))
			# West strip
			st.set_color(Color((float(west_v) + 0.5) / float(west_cells), (float(west_f) + 0.5) / 6.0, 0.0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, y_w_edge, iz0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, y_w_edge, iz0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(x0, y_w_edge, iz1))
			# East strip
			st.set_color(Color((float(east_v) + 0.5) / float(east_cells), (float(east_f) + 0.5) / 6.0, 0.0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(x1, y_e_edge, iz0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_e_edge, iz1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_e_edge, iz1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(ix1, y_c, iz1))

			# 3) Corner patches (mesh-local UVs)
			# NW corner
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, y_nw, z0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(ix0, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, y_nw, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz0))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(x0, y_w_edge, iz0))
			# NE corner
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(x1, y_ne, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_e_edge, iz0))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_n_edge, z0))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_e_edge, iz0))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(ix1, y_c, iz0))
			# SE corner
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_c, iz1))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(x1, y_e_edge, iz1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_se, z1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix1, y_c, iz1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x1, y_se, z1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(ix1, y_s_edge, z1))
			# SW corner
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(ix0, y_s_edge, z1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(x0, y_sw, z1))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(x0, y_w_edge, iz1))
			st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(ix0, y_c, iz1))
			st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(x0, y_sw, z1))

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
				# bind multi-textures for selection via COLOR.g
				for i in 6:
					border_mat.set_shader_parameter("ground%d" % i, preloads.get_ground_texture(i))
				border_mat.set_shader_parameter("tile_scale", _compute_tile_scale())
				# Use mesh UVs for center composition and allow per-vertex selection
				border_mat.set_shader_parameter("use_mesh_uv", true)
				border_mat.set_shader_parameter("use_multi_textures", true)
				# Borders: fixed atlas layout 2x2
				border_mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
				border_mat.set_shader_parameter("use_vertex_variant", true)
				border_mat.set_shader_parameter("variant", 0)
				border_mat.set_shader_parameter("debug_mode", _debug_shader_mode)
			mesh.surface_set_material(surface_idx, border_mat)
			continue
		var mat := ShaderMaterial.new()
		mat.shader = shader
		# Get the ground texture for this SurfaceType (0-5)
		var texture: Texture2D = preloads.get_ground_texture(surface_type)
		if texture:
			mat.set_shader_parameter("ground_texture", texture)
			# bind all ground textures for per-vertex file selection
			for i in 6:
				mat.set_shader_parameter("ground%d" % i, preloads.get_ground_texture(i))
			mat.set_shader_parameter("tile_scale", _compute_tile_scale())
			mat.set_shader_parameter("use_mesh_uv", true)
			mat.set_shader_parameter("use_multi_textures", true)
			# UA: 4x4 for file 4 handled in shader; default atlas grid here is a fallback only
			mat.set_shader_parameter("atlas_grid", Vector2(2.0, 2.0))
			mat.set_shader_parameter("use_vertex_variant", true)
			mat.set_shader_parameter("variant", 0)
			mat.set_shader_parameter("debug_mode", _debug_shader_mode)
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
			var seam_x := float(x + 1 + 1) * SECTOR_SIZE # +1 for seam, +1 for border offset
			var x0 := seam_x - EDGE_SLOPE
			var x1 := seam_x + EDGE_SLOPE
			var z0 := float(y + 1) * SECTOR_SIZE # +1 for border offset
			var z1 := float(y + 1 + 1) * SECTOR_SIZE # +1 for next sector, +1 for border offset
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
			var seam_z := float(y + 1 + 1) * SECTOR_SIZE # +1 for seam, +1 for border offset
			var z0v := seam_z - EDGE_SLOPE
			var z1v := seam_z + EDGE_SLOPE
			var x0v := float(x + 1) * SECTOR_SIZE # +1 for border offset
			var x1v := float(x + 1 + 1) * SECTOR_SIZE # +1 for next sector, +1 for border offset
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

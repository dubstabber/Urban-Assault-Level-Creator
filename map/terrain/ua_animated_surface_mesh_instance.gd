extends MeshInstance3D

var _frames: Array = []
var _frame_index := 0
var _elapsed := 0.0
@export var serialized_frame_meshes: Array[Mesh] = []
@export var serialized_frame_durations := PackedFloat32Array()
@export var serialized_frame_payload := ""
@export var serialized_anim_name := ""
@export var serialized_transparency_mode := ""
@export var serialized_tracy_val := 0
@export var serialized_shade_value := 0

func _ready() -> void:
	if _frames.is_empty() and not serialized_frame_meshes.is_empty():
		_restore_serialized_animation()

func setup_animation(frames: Array) -> void:
	_frames.clear()
	for frame in frames:
		var prepared := {}
		prepared["duration_sec"] = float(frame.get("duration_sec", 0.04))
		prepared["mesh"] = _mesh_from_triangles(frame.get("triangles", []), frame.get("material", null))
		_frames.append(prepared)
	_frame_index = 0
	_elapsed = 0.0
	_apply_current_frame()
	set_process(_frames.size() > 1)

func _restore_serialized_animation() -> void:
	_frames.clear()
	for i in serialized_frame_meshes.size():
		var mesh_resource := serialized_frame_meshes[i]
		if mesh_resource == null:
			continue
		var duration_sec := 0.04
		if i < serialized_frame_durations.size():
			duration_sec = max(float(serialized_frame_durations[i]), 0.01)
		_frames.append({
			"duration_sec": duration_sec,
			"mesh": mesh_resource,
		})
	_frame_index = 0
	_elapsed = 0.0
	_apply_current_frame()
	set_meta("ua_authored_animated", true)
	set_process(_frames.size() > 1)

func _process(delta: float) -> void:
	if _frames.size() <= 1:
		return
	_elapsed += delta
	var frame_time := _current_frame_time()
	while _elapsed >= frame_time:
		_elapsed -= frame_time
		_frame_index = (_frame_index + 1) % _frames.size()
		_apply_current_frame()
		frame_time = _current_frame_time()

func _current_frame_time() -> float:
	if _frames.is_empty():
		return 0.04
	return max(float(_frames[_frame_index].get("duration_sec", 0.04)), 0.01)

func _apply_current_frame() -> void:
	if _frames.is_empty():
		mesh = null
		return
	var frame: Dictionary = _frames[_frame_index]
	mesh = frame.get("mesh", null)

func _mesh_from_triangles(triangles: Array, material: Material) -> ArrayMesh:
	var built_mesh := ArrayMesh.new()
	if triangles.is_empty():
		return built_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in triangles:
		var verts: Array = tri.get("verts", [])
		var uvs: Array = tri.get("uvs", [])
		if verts.size() != 3 or uvs.size() != 3:
			continue
		for i in 3:
			st.set_uv(uvs[i])
			st.add_vertex(verts[i])
	st.index()
	st.generate_normals()
	st.commit(built_mesh)
	if built_mesh.get_surface_count() > 0:
		built_mesh.surface_set_material(0, material)
	return built_mesh
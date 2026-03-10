extends MeshInstance3D

var _frames: Array = []
var _frame_index := 0
var _elapsed := 0.0

func setup_animation(frames: Array) -> void:
	_frames = frames.duplicate(true)
	_frame_index = 0
	_elapsed = 0.0
	_apply_current_frame()
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
	mesh = _mesh_from_triangles(frame.get("triangles", []), frame.get("material", null))

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
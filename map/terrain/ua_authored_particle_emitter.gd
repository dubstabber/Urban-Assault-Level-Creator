extends Node3D
class_name UAAuthoredParticleEmitter

const MAX_PARTICLES := 96

var _stages: Array = []
var _particles: Array = []
var _node_pool: Array = []
var _current_stage_meshes: Array = []
var _global_time_sec := 0.0
var _emitter_age_ms := 0.0
var _spawn_accumulator_ms := 0.0
var _cycle_length_ms := 1000.0
var _context_life_time_ms := 1000.0
var _context_start_gen_ms := 0.0
var _context_stop_gen_ms := 0.0
var _particle_life_time_ms := 1000.0
var _gen_pause_ms := 0.0
var _start_speed := 0.0
var _start_size := 1.0
var _end_size := 1.0
var _noise := 0.0
var _accel_start := Vector3.ZERO
var _accel_delta := Vector3.ZERO
var _magnify_start := Vector3.ZERO
var _magnify_delta := Vector3.ZERO
var _life_per_stage_ms := 1000.0
var _random_state := 1

func setup_emitter(definition: Dictionary) -> void:
	position = Vector3(definition.get("anchor", Vector3.ZERO))
	_context_life_time_ms = max(float(definition.get("context_life_time_ms", 1000.0)), 1.0)
	_context_start_gen_ms = max(float(definition.get("context_start_gen_ms", 0.0)), 0.0)
	_context_stop_gen_ms = max(float(definition.get("context_stop_gen_ms", _context_life_time_ms)), _context_start_gen_ms)
	_particle_life_time_ms = max(float(definition.get("lifetime_ms", 1000.0)), 1.0)
	_cycle_length_ms = max(_context_life_time_ms, _context_stop_gen_ms, 1.0)
	var gen_rate: float = max(float(definition.get("gen_rate", 0.0)), 0.0)
	_gen_pause_ms = 1024.0 / gen_rate if gen_rate > 0.0 else 0.0
	_start_speed = float(definition.get("start_speed", 0.0))
	_start_size = float(definition.get("start_size", 1.0))
	_end_size = float(definition.get("end_size", _start_size))
	_noise = float(definition.get("noise", 0.0))
	_accel_start = Vector3(definition.get("accel_start", Vector3.ZERO))
	_magnify_start = Vector3(definition.get("magnify_start", Vector3.ZERO))
	_accel_delta = (Vector3(definition.get("accel_end", _accel_start)) - _accel_start) / _context_life_time_ms
	_magnify_delta = (Vector3(definition.get("magnify_end", _magnify_start)) - _magnify_start) / _context_life_time_ms
	_random_state = _seed_from_definition(definition)
	_stages.clear()
	for stage in definition.get("stages", []):
		if typeof(stage) != TYPE_DICTIONARY:
			continue
		var built_frames: Array = []
		for frame in stage.get("frames", []):
			if typeof(frame) != TYPE_DICTIONARY:
				continue
			var mesh := _mesh_from_triangles(frame.get("triangles", []), frame.get("material", null))
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			built_frames.append({
				"mesh": mesh,
				"duration_sec": max(float(frame.get("duration_sec", 0.04)), 0.01),
			})
		if not built_frames.is_empty():
			_stages.append(built_frames)
	_life_per_stage_ms = _particle_life_time_ms / max(_stages.size(), 1)
	set_meta("ua_authored_particle_emitter", true)
	set_process(not _stages.is_empty() and _gen_pause_ms > 0.0)

func _process(delta: float) -> void:
	if _stages.is_empty():
		return
	var delta_ms := delta * 1000.0
	_global_time_sec += delta
	_current_stage_meshes.resize(_stages.size())
	for stage_idx in _stages.size():
		_current_stage_meshes[stage_idx] = _mesh_for_stage(stage_idx)
	_emitter_age_ms += delta_ms
	if _emitter_age_ms >= _cycle_length_ms:
		_emitter_age_ms = fposmod(_emitter_age_ms, _cycle_length_ms)
		_spawn_accumulator_ms = 0.0
	if _gen_pause_ms > 0.0 and _emitter_age_ms >= _context_start_gen_ms and _emitter_age_ms < _context_stop_gen_ms:
		_spawn_accumulator_ms += delta_ms
		while _spawn_accumulator_ms >= _gen_pause_ms:
			_spawn_accumulator_ms -= _gen_pause_ms
			_spawn_particle(_spawn_accumulator_ms)
	_update_particles(delta, delta_ms)

func _spawn_particle(initial_age_ms: float) -> void:
	if _particles.size() >= MAX_PARTICLES:
		return
	var magnify: Vector3 = _magnify_start + _magnify_delta * min(_emitter_age_ms, _context_life_time_ms)
	var direction: Vector3 = magnify + _rand_vec()
	if direction.length_squared() <= 0.000001:
		direction = Vector3.UP
	var particle_node: MeshInstance3D
	if not _node_pool.is_empty():
		particle_node = _node_pool.pop_back()
		particle_node.visible = true
	else:
		particle_node = MeshInstance3D.new()
		particle_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(particle_node)
	var initial_stage := mini(int(floor(initial_age_ms / max(_life_per_stage_ms, 1.0))), _stages.size() - 1) if not _stages.is_empty() else -1
	if initial_stage >= 0 and initial_stage < _current_stage_meshes.size():
		particle_node.mesh = _current_stage_meshes[initial_stage]
	_particles.append({
		"node": particle_node,
		"age_ms": initial_age_ms,
		"position": Vector3.ZERO,
		"velocity": direction.normalized() * _start_speed,
		"stage_index": initial_stage,
	})

func _update_particles(delta_sec: float, delta_ms: float) -> void:
	for idx in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[idx]
		var age_ms := float(particle.get("age_ms", 0.0)) + delta_ms
		if age_ms >= _particle_life_time_ms:
			var node: MeshInstance3D = particle.get("node", null) as MeshInstance3D
			if node != null:
				node.visible = false
				node.position = Vector3.ZERO
				node.mesh = null
				_node_pool.append(node)
			_particles.remove_at(idx)
			continue
		var velocity := Vector3(particle.get("velocity", Vector3.ZERO))
		velocity += (_accel_start + _accel_delta * min(age_ms, _context_life_time_ms)) * delta_sec
		var position_local := Vector3(particle.get("position", Vector3.ZERO)) + velocity * delta_sec
		if not is_zero_approx(_noise):
			position_local += _rand_vec() * (_noise * delta_sec)
		var particle_node: MeshInstance3D = particle.get("node", null) as MeshInstance3D
		var new_stage_index := mini(int(floor(age_ms / max(_life_per_stage_ms, 1.0))), _stages.size() - 1)
		var old_stage_index: int = int(particle.get("stage_index", -1))
		if particle_node != null:
			particle_node.position = position_local
			particle_node.scale = Vector3.ONE * max(lerpf(_start_size, _end_size, age_ms / _particle_life_time_ms), 0.01)
			if new_stage_index != old_stage_index:
				particle_node.mesh = _current_stage_meshes[new_stage_index] if new_stage_index < _current_stage_meshes.size() else null
		particle["age_ms"] = age_ms
		particle["velocity"] = velocity
		particle["position"] = position_local
		particle["stage_index"] = new_stage_index
		_particles[idx] = particle

func _mesh_for_stage(stage_index: int) -> ArrayMesh:
	if stage_index < 0 or stage_index >= _stages.size():
		return null
	var frames: Array = _stages[stage_index]
	if frames.is_empty():
		return null
	if frames.size() == 1:
		return frames[0].get("mesh", null)
	var total_duration := 0.0
	for frame in frames:
		total_duration += max(float(frame.get("duration_sec", 0.04)), 0.01)
	var local_time := fposmod(_global_time_sec, max(total_duration, 0.01))
	for frame in frames:
		local_time -= max(float(frame.get("duration_sec", 0.04)), 0.01)
		if local_time <= 0.0:
			return frame.get("mesh", null)
	return frames[frames.size() - 1].get("mesh", null)

func _mesh_from_triangles(triangles: Array, material: Material) -> ArrayMesh:
	if triangles.is_empty() or material == null:
		return null
	var built_mesh := ArrayMesh.new()
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

func _seed_from_definition(definition: Dictionary) -> int:
	var anchor := Vector3(definition.get("anchor", Vector3.ZERO))
	var seed_value: int = int(abs(anchor.x) + abs(anchor.y) * 3.0 + abs(anchor.z) * 7.0)
	seed_value += int(definition.get("point_id", 0)) * 97
	seed_value += int(definition.get("context_start_gen_ms", 0.0)) * 13
	return maxi(seed_value & 0x7fffffff, 1)

func _rand_vec() -> Vector3:
	return Vector3(_rand_signed(), _rand_signed(), _rand_signed())

func _rand_signed() -> float:
	_random_state = int((1103515245 * _random_state + 12345) & 0x7fffffff)
	return (float(_random_state % 20001) / 10000.0) - 1.0
extends RefCounted
class_name UAAuthoredParticleBuilder

const ParticleEmitterScript = preload("res://map/terrain/ua_authored_particle_emitter.gd")

static func extract_particle_emitters(node, points: Array, set_id: int, emitter_from_ptcl: Callable) -> Array:
	var result: Array = []
	collect_particle_emitters(node, result, points, set_id, emitter_from_ptcl)
	return result

static func collect_particle_emitters(node, out: Array, points: Array, set_id: int, emitter_from_ptcl: Callable) -> void:
	if not emitter_from_ptcl.is_valid():
		return
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("PTCL"):
			var emitter_value = emitter_from_ptcl.call(node["PTCL"], points, set_id)
			if typeof(emitter_value) == TYPE_DICTIONARY:
				var emitter := emitter_value as Dictionary
				if not emitter.is_empty():
					out.append(emitter)
			return
		for value in node.values():
			collect_particle_emitters(value, out, points, set_id, emitter_from_ptcl)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			collect_particle_emitters(item, out, points, set_id, emitter_from_ptcl)

static func particle_emitter_from_ptcl(ptcl_data: Array, points: Array, set_id: int, external_source_loading_enabled: bool, ade_point_finder: Callable, point_position_resolver: Callable, particle_atts_finder: Callable, stages_builder: Callable, vector3_components: Callable) -> Dictionary:
	if not external_source_loading_enabled:
		return {}
	if not ade_point_finder.is_valid() or not point_position_resolver.is_valid() or not particle_atts_finder.is_valid() or not stages_builder.is_valid() or not vector3_components.is_valid():
		return {}
	var point_id := int(ade_point_finder.call(ptcl_data))
	var anchor = point_position_resolver.call(points, point_id)
	if anchor == null:
		return {}
	var atts_value = particle_atts_finder.call(ptcl_data)
	if typeof(atts_value) != TYPE_DICTIONARY:
		return {}
	var atts := atts_value as Dictionary
	if atts.is_empty():
		return {}
	var stages_value = stages_builder.call(ptcl_data, set_id)
	if typeof(stages_value) != TYPE_ARRAY:
		return {}
	var stages := Array(stages_value)
	if stages.is_empty():
		return {}
	return {
		"point_id": point_id,
		"anchor": anchor,
		"context_life_time_ms": max(int(atts.get("context_life_time", 0)), 1),
		"context_start_gen_ms": max(int(atts.get("context_start_gen", 0)), 0),
		"context_stop_gen_ms": max(int(atts.get("context_stop_gen", 0)), 0),
		"gen_rate": max(int(atts.get("gen_rate", 0)), 0),
		"lifetime_ms": max(int(atts.get("lifetime", 0)), 1),
		"start_speed": float(atts.get("start_speed", 0.0)),
		"start_size": float(atts.get("start_size", 1.0)),
		"end_size": float(atts.get("end_size", atts.get("start_size", 1.0))),
		"noise": float(atts.get("noise", 0.0)),
		"accel_start": vector3_components.call(atts, "accel_start"),
		"accel_end": vector3_components.call(atts, "accel_end"),
		"magnify_start": vector3_components.call(atts, "magnify_start"),
		"magnify_end": vector3_components.call(atts, "magnify_end"),
		"stages": stages,
	}

static func particle_stages_from_ptcl(ptcl_data: Array, set_id: int, stage_from_area: Callable) -> Array:
	var area_stages: Array = []
	collect_ptcl_stage_areas(ptcl_data, area_stages)
	var stages: Array = []
	for area_data in area_stages:
		if not stage_from_area.is_valid():
			continue
		var stage_value = stage_from_area.call(area_data, set_id)
		if typeof(stage_value) != TYPE_DICTIONARY:
			continue
		var stage := stage_value as Dictionary
		if not stage.is_empty():
			stages.append(stage)
	return stages

static func collect_ptcl_stage_areas(node, out: Array) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("AREA"):
			out.append(node["AREA"])
			return
		for value in node.values():
			collect_ptcl_stage_areas(value, out)
	elif typeof(node) == TYPE_ARRAY:
		for item in node:
			collect_ptcl_stage_areas(item, out)

static func particle_stage_from_area(area_data: Array, set_id: int, load_anim_frames: Callable, billboard_material_resolver: Callable, render_hints_from_area: Callable, first_anim_name_finder: Callable, first_name_finder: Callable, triangulator: Callable, coerce_uvs: Callable, first_points_finder: Callable, unit_billboard_polygon_builder: Callable) -> Dictionary:
	if not render_hints_from_area.is_valid() or not first_anim_name_finder.is_valid() or not billboard_material_resolver.is_valid() or not load_anim_frames.is_valid() or not first_name_finder.is_valid() or not triangulator.is_valid() or not coerce_uvs.is_valid() or not first_points_finder.is_valid() or not unit_billboard_polygon_builder.is_valid():
		return {}
	var polygon_value = unit_billboard_polygon_builder.call()
	if typeof(polygon_value) != TYPE_ARRAY:
		return {}
	var polygon := Array(polygon_value)
	var render_hints_value = render_hints_from_area.call(area_data)
	var render_hints: Dictionary = render_hints_value if typeof(render_hints_value) == TYPE_DICTIONARY else {}
	var frames: Array = []
	var anim_name := String(first_anim_name_finder.call(area_data))
	if not anim_name.is_empty():
		var anim_frames_value = load_anim_frames.call(set_id, anim_name, polygon)
		if typeof(anim_frames_value) != TYPE_ARRAY:
			return {}
		for frame_value in Array(anim_frames_value):
			if typeof(frame_value) != TYPE_DICTIONARY:
				continue
			var frame := frame_value as Dictionary
			var material = billboard_material_resolver.call(set_id, String(frame.get("texture_name", "")), render_hints)
			if material == null:
				continue
			frames.append({
				"triangles": frame.get("triangles", []),
				"material": material,
				"duration_sec": float(frame.get("duration_sec", 0.04)),
			})
	else:
		var texture_name := String(first_name_finder.call(area_data, "NAM2"))
		var material = billboard_material_resolver.call(set_id, texture_name, render_hints)
		if material == null:
			return {}
		var uv_points_value = first_points_finder.call(area_data, "OTL2")
		if typeof(uv_points_value) != TYPE_ARRAY:
			return {}
		var uvs_value = coerce_uvs.call(Array(uv_points_value), polygon, set_id, texture_name)
		if typeof(uvs_value) != TYPE_ARRAY:
			return {}
		var triangles_value = triangulator.call(polygon, Array(uvs_value))
		if typeof(triangles_value) != TYPE_ARRAY:
			return {}
		frames.append({
			"triangles": Array(triangles_value),
			"material": material,
			"duration_sec": 0.04,
		})
	return {"frames": frames} if not frames.is_empty() else {}

static func particle_node_from_definition(definition: Dictionary) -> Node3D:
	if definition.is_empty():
		return null
	var emitter: Node3D = ParticleEmitterScript.new()
	emitter.setup_emitter(definition)
	return emitter if emitter.has_meta("ua_authored_particle_emitter") else null

static func unit_billboard_polygon() -> Array:
	return [
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0),
	]

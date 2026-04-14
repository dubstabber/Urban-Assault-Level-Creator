extends RefCounted

const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")
const MaterialFactory = preload("res://map/terrain/ua_authored_material_factory.gd")
const AnimationBuilder = preload("res://map/terrain/ua_authored_animation_builder.gd")
const ParticleBuilder = preload("res://map/terrain/ua_authored_particle_builder.gd")
const LEGACY_SET_ROOT := "res://resources/ua/bundled/sets"

var _errors: Array[String] = []


func _reset_errors() -> void:
	_errors.clear()
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)


func _load_test_anim_frames() -> Array:
	var polygon := [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var anim_path_finder := func(set_id: int, anim_name: String) -> String:
		return AuthoredPieceLibrary._find_anim_json_path(set_id, anim_name)
	var json_loader := func(path: String) -> Dictionary:
		return AuthoredPieceLibrary._load_json(path)
	var triangulator := func(poly: Array, uvs: Array) -> Array:
		return AuthoredPieceLibrary._triangulate(poly, uvs)
	var bmpanim_uv_coercer := func(raw_uvs: Array, poly: Array) -> Array:
		return AuthoredPieceLibrary._coerce_bmpanim_uvs(raw_uvs, poly)
	return AnimationBuilder.load_anim_frames(
		1,
		"05079601.ANM",
		polygon,
		"original",
		true,
		anim_path_finder,
		json_loader,
		triangulator,
		bmpanim_uv_coercer
	)


func test_material_factory_luminous_fx2_resolves_retail_hi_alpha_override() -> bool:
	_reset_errors()
	var raw_path := MaterialFactory.raw_texture_override_path(1, "FX2.ILBM", {"transparency_mode": "lumtracy", "tracy_val": 128}, "original", LEGACY_SET_ROOT)
	_check(not raw_path.is_empty(), "Luminous FX2 should resolve a retail hi/alpha raw texture override when it exists in the set assets")
	_check(raw_path.to_lower().ends_with("/set1/hi/alpha/fx2.ilb"), "Luminous FX2 should prefer the set-local hi/alpha override used by retail UA on normal blended hardware")
	var non_luminous_raw_path := MaterialFactory.raw_texture_override_path(1, "FX2.ILBM", {}, "original", LEGACY_SET_ROOT)
	_check(non_luminous_raw_path.is_empty(), "Non-luminous FX2 should keep the existing keyed BMP path instead of always forcing the raw hi/alpha override")
	return _errors.is_empty()


func test_animation_builder_loads_area_animation_frames_from_anm() -> bool:
	_reset_errors()
	var frames := _load_test_anim_frames()
	_check(frames.size() == 4, "05079601.ANM should resolve to its 4 exported animation frames")
	if frames.size() == 4:
		_check(String(frames[0].get("texture_name", "")) == "FX2.ILBM", "05079601.ANM should reference FX2.ILBM frames")
		_check(frames[0].get("triangles", []).size() == 2, "Quad ANM frames should triangulate into two triangles")
		_check(is_equal_approx(float(frames[0].get("duration_sec", 0.0)), 0.04), "ANM frame_time 40 should map to 0.04 seconds")
	return _errors.is_empty()


func test_animation_builder_uses_bmpanim_u8_uv_scale() -> bool:
	_reset_errors()
	var frames := _load_test_anim_frames()
	_check(frames.size() == 4, "05079601.ANM should still resolve during bmpanim UV regression coverage")
	if frames.size() == 4:
		var triangles: Array = frames[2].get("triangles", [])
		_check(triangles.size() == 2, "Edge-heavy ANM frame should still triangulate into two triangles")
		if triangles.size() == 2:
			var uvs: Array = triangles[0].get("uvs", [])
			_check(uvs.size() == 3, "Triangulated ANM frame should preserve UVs per triangle vertex")
			if uvs.size() == 3:
				_check(is_equal_approx(uvs[0].x, 154.0 / 256.0), "ANM U coordinates should follow retail bmpanim's u8/256 normalization")
				_check(is_equal_approx(uvs[0].y, 254.0 / 256.0), "ANM V coordinates should follow retail bmpanim's u8/256 normalization")
				_check(float(uvs[0].y) < 1.0, "Edge-heavy ANM UVs should stay inside the atlas instead of landing on the outermost border")
	return _errors.is_empty()


func test_particle_builder_extracts_nested_ptcl_emitters() -> bool:
	_reset_errors()
	var emitters := ParticleBuilder.extract_particle_emitters({
		"children": [
			{"PTCL": [{"id": 1}]},
			{"nested": {"PTCL": [{"id": 2}]}}
		]
	}, [], 7, func(ptcl_data: Array, _points: Array, set_id: int) -> Dictionary:
		return {"set_id": set_id, "stage_count": ptcl_data.size()}
	)
	_check(emitters.size() == 2, "Nested PTCL nodes should be collected into dedicated emitter definitions")
	if emitters.size() == 2:
		_check(int(emitters[0].get("set_id", -1)) == 7, "Emitter extraction should pass through the resolved set id")
	return _errors.is_empty()


func test_particle_builder_skips_invalid_anchor_point() -> bool:
	_reset_errors()
	var emitter := ParticleBuilder.particle_emitter_from_ptcl(
		[],
		[],
		1,
		true,
		func(_ptcl_data: Array) -> int:
			return 99,
		func(_points: Array, _point_id: int):
			return null,
		func(_ptcl_data: Array) -> Dictionary:
			return {"context_life_time": 1000, "context_start_gen": 0, "context_stop_gen": 500, "gen_rate": 10, "lifetime": 1000, "start_size": 10, "end_size": 5, "start_speed": 10},
		func(_ptcl_data: Array, _set_id: int) -> Array:
			return [{"frames": [{"duration_sec": 0.04}]}],
		func(_atts: Dictionary, _prefix: String) -> Vector3:
			return Vector3.ZERO
	)
	_check(emitter.is_empty(), "Particle emitters with invalid skeleton anchors should be skipped safely")
	return _errors.is_empty()


func test_particle_builder_skips_when_no_renderable_stages_exist() -> bool:
	_reset_errors()
	var emitter := ParticleBuilder.particle_emitter_from_ptcl(
		[],
		[{"x": 0.0, "y": 0.0, "z": 0.0}],
		1,
		true,
		func(_ptcl_data: Array) -> int:
			return 0,
		func(_points: Array, _point_id: int):
			return Vector3.ZERO,
		func(_ptcl_data: Array) -> Dictionary:
			return {"context_life_time": 1000, "context_start_gen": 0, "context_stop_gen": 500, "gen_rate": 10, "lifetime": 1000, "start_size": 10, "end_size": 5, "start_speed": 10},
		func(_ptcl_data: Array, _set_id: int) -> Array:
			return [],
		func(_atts: Dictionary, _prefix: String) -> Vector3:
			return Vector3.ZERO
	)
	_check(emitter.is_empty(), "Particle emitters without any renderable PTCL stages should be skipped safely instead of creating incomplete runtime emitters")
	return _errors.is_empty()


func run() -> int:
	var tests: Array[String] = [
		"test_material_factory_luminous_fx2_resolves_retail_hi_alpha_override",
		"test_animation_builder_loads_area_animation_frames_from_anm",
		"test_animation_builder_uses_bmpanim_u8_uv_scale",
		"test_particle_builder_extracts_nested_ptcl_emitters",
		"test_particle_builder_skips_invalid_anchor_point",
		"test_particle_builder_skips_when_no_renderable_stages_exist",
	]
	var failures := 0
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

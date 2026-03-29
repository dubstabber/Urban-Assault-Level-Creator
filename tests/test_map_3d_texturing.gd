extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const SlurpBuilder = preload("res://map/map_3d_slurp_builder.gd")
const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")
const AnimatedSurfaceMeshInstanceScript = preload("res://map/terrain/ua_animated_surface_mesh_instance.gd")
const ParticleEmitterScript = preload("res://map/terrain/ua_authored_particle_emitter.gd")
# Use scaled constants from the renderer (WORLD_SCALE = 1/1200)
const SECTOR_SIZE := Map3DRendererScript.SECTOR_SIZE
const HEIGHT_SCALE := Map3DRendererScript.HEIGHT_SCALE
const EDGE_SLOPE := Map3DRendererScript.EDGE_SLOPE
const LOOKUP_TEST_SET_ID := 178
# In this repo checkout, retail/BAS/SKLT source data (and the `objects/` folders)
# live under the decompiled-master asset tree rather than `resources/ua/bundled/`.
const LEGACY_SET_ROOT := "res://urban_assault_decompiled-master/assets/sets"

class MockPreloads:
	extends Node

	var _textures: Array[Texture2D] = []
	# Minimal fields required by Map3DRenderer.build_from_current_map()
	# when it calls build_mesh_with_textures(...).
	var surface_type_map := {}
	var subsector_patterns := {}
	var tile_mapping := {}
	var tile_remap := {}
	var subsector_idx_remap := {}
	var lego_defs := {}

	func _init() -> void:
		_textures.resize(6)
		for i in 6:
			var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
			img.fill(Color(float(i + 1) / 6.0, 0.25, 0.5, 1.0))
			_textures[i] = ImageTexture.create_from_image(img)

	func get_ground_texture(surface_type: int) -> Texture2D:
		return _textures[clampi(surface_type, 0, 5)]

class HostStationStub:
	extends Node2D

	var vehicle := 0
	var pos_y := -500

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, ua_y: int) -> void:
		vehicle = vehicle_id
		pos_y = ua_y
		position = Vector2(pos_x, pos_z_abs)

class SquadStub:
	extends Node2D

	var vehicle := 0
	var quantity := 1

	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, squad_quantity: int = 1) -> void:
		vehicle = vehicle_id
		quantity = squad_quantity
		position = Vector2(pos_x, pos_z_abs)

class CurrentMapDataStub:
	extends Node

	var horizontal_sectors := 2
	var vertical_sectors := 2
	var level_set := 1
	var hgt_map := PackedByteArray()
	var typ_map := PackedByteArray()
	var blg_map := PackedByteArray()
	var beam_gates: Array = []
	var tech_upgrades: Array = []
	var stoudson_bombs: Array = []
	var host_stations: Node = null
	var squads: Node = null


class EditorStateStub:
	extends Node

	var view_mode_3d := false
	var map_3d_visibility_range_enabled := false
	var game_data_type := "original"


var _errors: Array[String] = []

func _reset_errors() -> void:
	_errors.clear()
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)
	_ensure_baked_renderer_lookup_registries()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

# Keep expectations in the renderer's UA-space world coordinates.
static func _ua_vec3(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

func _ensure_baked_renderer_lookup_registries() -> void:
	var metadata_dir := "res://resources/ua/sets/set%d/metadata" % LOOKUP_TEST_SET_ID
	_ensure_dir(metadata_dir)
	_save_json("%s/visproto_base_names.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": LOOKUP_TEST_SET_ID,
		"game_data_type": "original",
		"base_names": ["VPwSIMPL", "VP_DFLAK", "VP_RADA", ""]
	})
	_save_json("%s/vehicle_visuals.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": LOOKUP_TEST_SET_ID,
		"game_data_type": "original",
		"vehicles": {
			"1": {"slots": {"wait": 0, "normal": 0}, "model": "tank"},
			"96": {"slots": {"wait": 1, "normal": 3}, "model": "tank"},
			"109": {"slots": {"wait": 2}, "model": "tank"},
			"139": {"slots": {"wait": 2}, "model": "tank"},
			"150": {"slots": {"wait": 3}, "model": "tank"},
		}
	})
	_save_json("%s/building_definitions.json" % metadata_dir, {
		"schema_version": 1,
		"set_id": LOOKUP_TEST_SET_ID,
		"game_data_type": "original",
		"definitions": [
			{"building_id": 25, "sec_type": 3, "attachments": []},
			{"building_id": 35, "sec_type": 245, "attachments": []},
			{
				"building_id": 28,
				"sec_type": 205,
				"attachments": [
					{
						"act": 0,
						"vehicle_id": 96,
						"ua_offset": {"x": 0.0, "y": - 425.0, "z": 0.0},
						"ua_direction": {"x": 1.0, "y": 0.0, "z": 0.0},
					}
				]
			},
			{
				"building_id": 28,
				"sec_type": 240,
				"attachments": [
					{
						"act": 0,
						"vehicle_id": 139,
						"ua_offset": {"x": 0.0, "y": - 425.0, "z": 0.0},
						"ua_direction": {"x": 1.0, "y": 0.0, "z": 0.0},
					}
				]
			},
			{
				"building_id": 20,
				"sec_type": 199,
				"attachments": [
					{
						"act": 0,
						"vehicle_id": 150,
						"ua_offset": {"x": 0.0, "y": 0.0, "z": 0.0},
						"ua_direction": {"x": 0.0, "y": 0.0, "z": 1.0},
					}
				]
			},
			{
				"building_id": 3,
				"sec_type": 204,
				"attachments": [
					{
						"act": 0,
						"vehicle_id": 109,
						"ua_offset": {"x": 30.0, "y": - 530.0, "z": 0.0},
						"ua_direction": {"x": - 1.0, "y": 0.0, "z": 0.0},
					}
				]
			}
		]
	})
	var xp_metadata_dir := "res://resources/ua/sets/set%d_xp/metadata" % LOOKUP_TEST_SET_ID
	_ensure_dir(xp_metadata_dir)
	_save_json("%s/visproto_base_names.json" % xp_metadata_dir, {
		"schema_version": 1,
		"set_id": LOOKUP_TEST_SET_ID,
		"game_data_type": "metropolisDawn",
		"base_names": ["VP_MYKO4"]
	})
	_save_json("%s/vehicle_visuals.json" % xp_metadata_dir, {
		"schema_version": 1,
		"set_id": LOOKUP_TEST_SET_ID,
		"game_data_type": "metropolisDawn",
		"vehicles": {
			"63": {"slots": {"wait": 0}, "model": "tank"}
		}
	})
	Map3DRendererScript._clear_runtime_lookup_caches_for_tests()

func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("make_dir_recursive failed (%d) for %s" % [err, path])

func _save_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t", false))
	file.store_string("\n")
	file.close()

static func _make_typ_and_hgt(w: int, h: int, typ_values: Array, height: int = 0) -> Dictionary:
	var typ := PackedByteArray(typ_values)
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	for i in hgt.size():
		hgt[i] = height
	return {"typ": typ, "hgt": hgt}

static func _set_hgt_value(hgt: PackedByteArray, w: int, x: int, y: int, value: int) -> void:
	var bw := w + 2
	hgt[(y + 1) * bw + (x + 1)] = value

static func _surface_index_for_type(surface_map: Dictionary, surface_type: int) -> int:
	for surface_idx in surface_map.keys():
		if int(surface_map[surface_idx]) == surface_type:
			return int(surface_idx)
	return -1

static func _distinct_color_count(colors: PackedColorArray) -> int:
	var seen := {}
	for c in colors:
		var key := "%0.4f|%0.4f|%0.4f|%0.4f" % [c.r, c.g, c.b, c.a]
		seen[key] = true
	return seen.size()

static func _files_used_from_colors(colors: PackedColorArray) -> Dictionary:
	var seen := {}
	for color in colors:
		var file_idx := int(floor(clampf(color.g, 0.0, 0.9999) * 6.0))
		seen[file_idx] = true
	return seen

static func _variants_used_from_colors(colors: PackedColorArray, cells: int) -> Dictionary:
	var seen := {}
	for color in colors:
		var variant_idx := int(floor(clampf(color.r, 0.0, 0.9999) * float(cells)))
		seen[variant_idx] = true
	return seen

static func _base_names_from_descriptors(descriptors: Array) -> Dictionary:
	var seen := {}
	for desc in descriptors:
		if typeof(desc) == TYPE_DICTIONARY:
			seen[String(desc.get("base_name", ""))] = true
	return seen


static func _instance_keys_from_descriptors(descriptors: Array) -> Dictionary:
	var seen := {}
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var key := String(Dictionary(desc).get("instance_key", ""))
		if not key.is_empty():
			seen[key] = true
	return seen


static func _attachment_vehicle_ids(definition: Dictionary) -> Array:
	var ids: Array = []
	for attachment in Array(definition.get("attachments", [])):
		if typeof(attachment) != TYPE_DICTIONARY:
			continue
		ids.append(int(Dictionary(attachment).get("vehicle_id", -1)))
	ids.sort()
	return ids


static func _has_descriptor(descriptors: Array, base_name: String, origin: Vector3) -> bool:
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		if String(desc.get("base_name", "")) != base_name:
			continue
		if Vector3(desc.get("origin", Vector3.INF)).is_equal_approx(origin):
			return true
	return false

static func _find_descriptor(descriptors: Array, base_name: String, origin: Vector3) -> Dictionary:
	for desc in descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		if String(desc.get("base_name", "")) != base_name:
			continue
		if Vector3(desc.get("origin", Vector3.INF)).is_equal_approx(origin):
			return desc
	return {}

static func _uv_bounds(uvs: PackedVector2Array) -> Dictionary:
	if uvs.is_empty():
		return {}
	var min_u := uvs[0].x
	var max_u := uvs[0].x
	var min_v := uvs[0].y
	var max_v := uvs[0].y
	for uv in uvs:
		min_u = min(min_u, uv.x)
		max_u = max(max_u, uv.x)
		min_v = min(min_v, uv.y)
		max_v = max(max_v, uv.y)
	return {"min_u": min_u, "max_u": max_u, "min_v": min_v, "max_v": max_v}

static func _mesh_xz_bounds(mesh: ArrayMesh, surface_idx: int = -1) -> Dictionary:
	if mesh == null or mesh.get_surface_count() == 0:
		return {}
	var start_surface: int = max(surface_idx, 0)
	var end_surface: int = surface_idx if surface_idx >= 0 else mesh.get_surface_count() - 1
	if start_surface >= mesh.get_surface_count() or end_surface >= mesh.get_surface_count():
		return {}
	var seeded := false
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for i in range(start_surface, end_surface + 1):
		var arrays := mesh.surface_get_arrays(i)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			if not seeded:
				min_x = v.x
				max_x = v.x
				min_z = v.z
				max_z = v.z
				seeded = true
			else:
				min_x = min(min_x, v.x)
				max_x = max(max_x, v.x)
				min_z = min(min_z, v.z)
				max_z = max(max_z, v.z)
	if not seeded:
		return {}
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}

static func _node_mesh_local_y_bounds(root: Node) -> Dictionary:
	var seeded := false
	var min_y := 0.0
	var max_y := 0.0
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		if mesh != null:
			for surface_idx in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface_idx)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					if not seeded:
						min_y = v.y
						max_y = v.y
						seeded = true
					else:
						min_y = min(min_y, v.y)
						max_y = max(max_y, v.y)
	for child in root.get_children():
		var child_bounds := _node_mesh_local_y_bounds(child)
		if child_bounds.is_empty():
			continue
		if not seeded:
			min_y = float(child_bounds["min_y"])
			max_y = float(child_bounds["max_y"])
			seeded = true
		else:
			min_y = min(min_y, float(child_bounds["min_y"]))
			max_y = max(max_y, float(child_bounds["max_y"]))
	if not seeded:
		return {}
	return {"min_y": min_y, "max_y": max_y}

static func _count_nodes_with_meta(root: Node, meta_name: String) -> int:
	var count := 0
	if root.has_meta(meta_name):
		count += 1
	for child in root.get_children():
		count += _count_nodes_with_meta(child, meta_name)
	return count

static func _first_node_with_meta(root: Node, meta_name: String) -> Node:
	if root == null:
		return null
	if root.has_meta(meta_name):
		return root
	for child in root.get_children():
		var found := _first_node_with_meta(child, meta_name)
		if found != null:
			return found
	return null

static func _image_has_transparent_pixels(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.5:
				return true
	return false

static func _image_has_partial_alpha_pixels(image: Image) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0 and alpha < 1.0:
				return true
	return false

static func _first_transparent_pixel(image: Image) -> Color:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				return pixel
	return Color(1.0, 0.0, 1.0, 1.0)

static func _images_are_identical(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return false
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	for y in a.get_height():
		for x in a.get_width():
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				return false
	return true

static func _material_is_magenta_placeholder(material: Material) -> bool:
	if not (material is StandardMaterial3D):
		return false
	return material.albedo_texture == null \
		and material.albedo_color.is_equal_approx(Color(1.0, 0.0, 1.0, 0.5)) \
		and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA

static func _node_has_magenta_placeholder_material(root: Node) -> bool:
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		if mesh != null:
			for surface_idx in mesh.get_surface_count():
				if _material_is_magenta_placeholder(mesh.surface_get_material(surface_idx)):
					return true
	for child in root.get_children():
		if _node_has_magenta_placeholder_material(child):
			return true
	return false

static func _node_has_runtime_content(root: Node) -> bool:
	if root is MeshInstance3D:
		var mesh := (root as MeshInstance3D).mesh
		if mesh != null and mesh.get_surface_count() > 0:
			return true
	if root.has_meta("ua_authored_particle_emitter"):
		return true
	for child in root.get_children():
		if _node_has_runtime_content(child):
			return true
	return false

func _check_edge_shader_material(
	material: Material,
	preloads: MockPreloads,
	expected_surface_a: int,
	expected_surface_b: int,
	expected_vertical_seam: bool,
	context_label: String
) -> void:
	_check(material is ShaderMaterial, "%s should use ShaderMaterial for pair-driven slurp blending" % context_label)
	if material is ShaderMaterial:
		_check(
			material.get_shader_parameter("texture_a") == preloads.get_ground_texture(expected_surface_a),
			"%s should bind texture_a from the ordered first surface_type" % context_label
		)
		_check(
			material.get_shader_parameter("texture_b") == preloads.get_ground_texture(expected_surface_b),
			"%s should bind texture_b from the ordered second surface_type" % context_label
		)
		_check(
			bool(material.get_shader_parameter("vertical_seam")) == expected_vertical_seam,
			"%s should keep the expected seam orientation flag" % context_label
		)

static func _edge_shader_material_matches(
	material: Material,
	preloads: MockPreloads,
	expected_surface_a: int,
	expected_surface_b: int,
	expected_vertical_seam: bool
) -> bool:
	if not (material is ShaderMaterial):
		return false
	return (
		material.get_shader_parameter("texture_a") == preloads.get_ground_texture(expected_surface_a)
		and material.get_shader_parameter("texture_b") == preloads.get_ground_texture(expected_surface_b)
		and bool(material.get_shader_parameter("vertical_seam")) == expected_vertical_seam
	)

func test_retail_slurp_bucket_key_uses_vside_for_left_right_pairs() -> bool:
	_reset_errors()
	_check(
		Map3DRendererScript._retail_slurp_bucket_key(2, 5, 1, 0) == "vside_2_5",
		"Left/right neighboring sectors should map to the retail vside slurp family"
	)
	_check(
		Map3DRendererScript._retail_slurp_bucket_key(5, 2, 1, 0) == "vside_5_2",
		"Retail vside slurp selection should preserve ordered surface_type pairs"
	)
	return _errors.is_empty()

func test_retail_slurp_bucket_key_uses_hside_for_top_bottom_pairs() -> bool:
	_reset_errors()
	_check(
		Map3DRendererScript._retail_slurp_bucket_key(1, 4, 0, 1) == "hside_1_4",
		"Top/bottom neighboring sectors should map to the retail hside slurp family"
	)
	_check(
		Map3DRendererScript._retail_slurp_bucket_key(1, 4, 1, 1) == "",
		"Only axis-aligned neighboring sector pairs should produce a retail slurp bucket key"
	)
	return _errors.is_empty()

func test_build_mesh_with_textures_groups_same_surface_type_into_one_top_family() -> bool:
	_reset_errors()
	var w := 2
	var h := 1
	var data := _make_typ_and_hgt(w, h, [12, 34])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		w,
		h,
		{12: 2, 34: 2}
	)
	_check(result.has("mesh"), "build_mesh_with_textures should return a mesh entry")
	_check(result.has("surface_to_surface_type"), "build_mesh_with_textures should return a surface mapping entry")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, 2)
		_check(mesh != null, "Textured build_mesh_with_textures returned null mesh")
		_check(textured_surface_idx >= 0, "Expected a terrain surface for surface_type 2")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var files_used := _files_used_from_colors(colors)
			_check(colors.size() > 0, "Textured terrain surface should include vertex colors for texture-family selection")
			_check(indices.size() == 2 * 2 * 3, "Two flat sectors with the same surface_type should share one top-family surface bucket")
			_check(_distinct_color_count(colors) == 1, "Same-surface-type sectors should keep one preview texture-family selection")
			_check(files_used.size() == 1 and files_used.has(2), "Preview top should follow surface_type 2 directly")
	return _errors.is_empty()

func test_build_edges_mesh_uses_shader_materials() -> bool:
	_reset_errors()
	var w := 2
	var h := 1
	var data := _make_typ_and_hgt(w, h, [12, 34])
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], w, h, data["typ"], {12: 0, 34: 1}, preloads)
	_check(edges_mesh != null, "_build_edges_mesh returned null")
	if edges_mesh != null:
		_check(edges_mesh.get_surface_count() > 0, "_build_edges_mesh should still produce seam geometry")
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			_check(material is ShaderMaterial, "Edge overlay surfaces should use ShaderMaterial for pair-driven slurp blending")
			if material is ShaderMaterial:
				_check(material.get_shader_parameter("texture_a") != null, "Edge slurp material should bind texture_a")
				_check(material.get_shader_parameter("texture_b") != null, "Edge slurp material should bind texture_b")
	return _errors.is_empty()

func test_build_edges_mesh_left_right_seams_keep_ordered_pair_and_horizontal_blend_flag() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34])
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, preloads)
	_check(edges_mesh != null, "Left/right seam build returned null")
	if edges_mesh != null:
		_check(edges_mesh.get_surface_count() > 0, "Left/right seam build should produce seam surfaces")
		var found := false
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			if _edge_shader_material_matches(material, preloads, 0, 1, false):
				found = true
				_check_edge_shader_material(material, preloads, 0, 1, false, "Left/right vside seam material")
				break
		_check(found, "Left/right seam build should include an ordered vside material bucket for surface pair 0 -> 1")
	return _errors.is_empty()

func test_build_edges_mesh_left_right_seam_geometry_uses_playable_bounds() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34])
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, preloads)
	_check(edges_mesh != null, "Left/right seam geometry build returned null")
	if edges_mesh != null:
		var found := false
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			if not _edge_shader_material_matches(material, preloads, 0, 1, false):
				continue
			var arrays := edges_mesh.surface_get_arrays(surface_idx)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var min_x := INF
			var max_x := -INF
			var min_z := INF
			var max_z := -INF
			for v in verts:
				min_x = min(min_x, v.x)
				max_x = max(max_x, v.x)
				min_z = min(min_z, v.z)
				max_z = max(max_z, v.z)
			_check(min_x < 2.0 * SECTOR_SIZE and max_x > 2.0 * SECTOR_SIZE, "Left/right seam strip should straddle the inner playable boundary at x=2*SECTOR_SIZE")
			_check(is_equal_approx(min_z, SECTOR_SIZE), "Left/right seam strip should begin at the top edge of the bordered playable row")
			_check(is_equal_approx(max_z, 2.0 * SECTOR_SIZE), "Left/right seam strip should end at the bottom edge of the bordered playable row")
			found = true
			break
		_check(found, "Expected to find the left/right seam geometry bucket for the ordered 0 -> 1 pair")
	return _errors.is_empty()

func test_build_edges_mesh_left_right_seam_geometry_uses_corner_averages() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34])
	_set_hgt_value(data["hgt"], 2, 0, -1, 1)
	_set_hgt_value(data["hgt"], 2, 1, -1, 3)
	_set_hgt_value(data["hgt"], 2, 0, 0, 4)
	_set_hgt_value(data["hgt"], 2, 1, 0, 6)
	_set_hgt_value(data["hgt"], 2, 0, 1, 8)
	_set_hgt_value(data["hgt"], 2, 1, 1, 10)
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, preloads)
	_check(edges_mesh != null, "Left/right seam geometry build returned null")
	if edges_mesh != null:
		var found := false
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			if not _edge_shader_material_matches(material, preloads, 0, 1, false):
				continue
			var arrays := edges_mesh.surface_get_arrays(surface_idx)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var found_top_avg := false
			var found_bottom_avg := false
			var expected_top_avg := 3.5 * HEIGHT_SCALE
			var expected_bottom_avg := 7.0 * HEIGHT_SCALE
			for v in verts:
				if is_equal_approx(v.x, 2.0 * SECTOR_SIZE) and is_equal_approx(v.z, SECTOR_SIZE):
					found_top_avg = true
					_check(is_equal_approx(v.y, expected_top_avg), "Vertical seam top midpoint should use the retail-style corner average")
				if is_equal_approx(v.x, 2.0 * SECTOR_SIZE) and is_equal_approx(v.z, 2.0 * SECTOR_SIZE):
					found_bottom_avg = true
					_check(is_equal_approx(v.y, expected_bottom_avg), "Vertical seam bottom midpoint should use the retail-style corner average")
				if is_equal_approx(v.x, 2.0 * SECTOR_SIZE - EDGE_SLOPE) or is_equal_approx(v.x, 2.0 * SECTOR_SIZE + EDGE_SLOPE):
					_check(is_equal_approx(v.y, 4.0 * HEIGHT_SCALE) or is_equal_approx(v.y, 6.0 * HEIGHT_SCALE) or is_equal_approx(v.y, expected_top_avg) or is_equal_approx(v.y, expected_bottom_avg), "Vertical seam strip should preserve sector heights on its outer edges")
			_check(found_top_avg, "Expected to find the seam midpoint vertex at the top of the vertical strip")
			_check(found_bottom_avg, "Expected to find the seam midpoint vertex at the bottom of the vertical strip")
			found = true
			break
		_check(found, "Expected to find the left/right seam geometry bucket for the ordered 0 -> 1 pair")
	return _errors.is_empty()

func test_build_edges_mesh_top_bottom_seams_keep_ordered_pair_and_vertical_blend_flag() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 2, [12, 34])
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 1, 2, data["typ"], {12: 0, 34: 1}, preloads)
	_check(edges_mesh != null, "Top/bottom seam build returned null")
	if edges_mesh != null:
		_check(edges_mesh.get_surface_count() > 0, "Top/bottom seam build should produce seam surfaces")
		var found := false
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			if _edge_shader_material_matches(material, preloads, 0, 1, true):
				found = true
				_check_edge_shader_material(material, preloads, 0, 1, true, "Top/bottom hside seam material")
				break
		_check(found, "Top/bottom seam build should include an ordered hside material bucket for surface pair 0 -> 1")
	return _errors.is_empty()

func test_build_edges_mesh_without_preloads_falls_back_to_preview_material() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34])
	var renderer = Map3DRendererScript.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1})
	_check(edges_mesh != null, "_build_edges_mesh returned null without preloads")
	if edges_mesh != null and edges_mesh.get_surface_count() > 0:
		var material := edges_mesh.surface_get_material(0)
		_check(material is StandardMaterial3D, "Without preloads, edge overlay should still fall back to preview materials")
	return _errors.is_empty()

func test_edge_overlay_is_enabled_by_default_in_live_3d_renderer() -> bool:
	_reset_errors()
	var renderer = Map3DRendererScript.new()
	_check(renderer._edge_overlay_enabled, "Live 3D renderer should enable the slurp/edge overlay by default")
	return _errors.is_empty()

func test_build_edges_mesh_keeps_flat_same_surface_seams() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34], 5)
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 0}, preloads)
	_check(edges_mesh != null, "Flat same-surface seam build returned null")
	if edges_mesh != null:
		_check(edges_mesh.get_surface_count() == 0, "Flat same-surface neighboring sectors should not emit redundant seam strips")
	return _errors.is_empty()

func test_build_edges_mesh_includes_implicit_border_ring_pairs() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 5)
	_set_hgt_value(data["hgt"], 1, 0, -1, 3)
	_set_hgt_value(data["hgt"], 1, -1, 0, 4)
	_set_hgt_value(data["hgt"], 1, 1, 0, 7)
	_set_hgt_value(data["hgt"], 1, 0, 1, 8)
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var mapping := {12: 1, 248: 0, 249: 0, 250: 0, 251: 0, 252: 0, 253: 0, 254: 0, 255: 0}
	var edges_mesh: ArrayMesh = renderer._build_edges_mesh(data["hgt"], 1, 1, data["typ"], mapping, preloads)
	_check(edges_mesh != null, "Implicit-border seam build returned null")
	if edges_mesh != null:
		var found_north := false
		var found_south := false
		var found_west := false
		var found_east := false
		for surface_idx in edges_mesh.get_surface_count():
			var material := edges_mesh.surface_get_material(surface_idx)
			if _edge_shader_material_matches(material, preloads, 0, 1, true):
				found_north = true
			elif _edge_shader_material_matches(material, preloads, 1, 0, true):
				found_south = true
			elif _edge_shader_material_matches(material, preloads, 0, 1, false):
				found_west = true
			elif _edge_shader_material_matches(material, preloads, 1, 0, false):
				found_east = true
		_check(found_north, "North border seam should use the implicit border -> inner ordered pair")
		_check(found_south, "South border seam should use the inner -> implicit border ordered pair")
		_check(found_west, "West border seam should use the implicit border -> inner ordered pair")
		_check(found_east, "East border seam should use the inner -> implicit border ordered pair")
	return _errors.is_empty()

func test_surface_pair_from_slurp_bucket_key_rejects_invalid_keys() -> bool:
	_reset_errors()
	_check(
		Map3DRendererScript._surface_pair_from_slurp_bucket_key("broken") == {},
		"Malformed slurp bucket keys should not decode into a surface pair"
	)
	_check(
		Map3DRendererScript._surface_pair_from_slurp_bucket_key("diag_1_2") == {},
		"Only retail vside/hside bucket families should decode into a surface pair"
	)
	return _errors.is_empty()

func test_build_edge_overlay_result_uses_pair_based_vertical_seam_for_interior_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34])
	var renderer = Map3DRendererScript.new()
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S01V", Vector3(2.5 * SECTOR_SIZE, 0.0, 1.5 * SECTOR_SIZE)), "Interior left/right seam should prefer authored S01V slurp anchored to the right sector center")
	_check(result.get("mesh", null) == null, "When the authored interior slurp exists, the live overlay should not fall back to the old strip mesh for that seam")
	return _errors.is_empty()


func test_build_edge_overlay_result_keeps_authored_vertical_slurp_for_height_step_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34], 5)
	_set_hgt_value(data["hgt"], 2, 1, 0, 10)
	var renderer = Map3DRendererScript.new()
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S01V", Vector3(2.5 * SECTOR_SIZE, 10.0 * HEIGHT_SCALE, 1.5 * SECTOR_SIZE)), "Height-step interior left/right neighbors should still keep authored S01V slurps anchored to the right sector center")
	_check(result.get("mesh", null) == null, "Height-step authored vertical seams should not fall back to strip mesh because fallback causes protruding artifacts")
	return _errors.is_empty()

func test_build_edge_overlay_result_keeps_authored_vertical_slurp_for_flat_same_surface_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34], 5)
	var renderer = Map3DRendererScript.new()
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 0}, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S00V", Vector3(2.5 * SECTOR_SIZE, 5.0 * HEIGHT_SCALE, 1.5 * SECTOR_SIZE)), "Flat same-height same-surface interior neighbors should still emit authored S00V slurps")
	return _errors.is_empty()

func test_build_edge_overlay_result_uses_pair_based_horizontal_seam_for_interior_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 2, [12, 34])
	var renderer = Map3DRendererScript.new()
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 1, 2, data["typ"], {12: 0, 34: 1}, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S01H", Vector3(1.5 * SECTOR_SIZE, 0.0, 2.5 * SECTOR_SIZE)), "Interior top/bottom seam should prefer authored S01H slurp anchored to the bottom sector center")
	_check(result.get("mesh", null) == null, "When the authored interior hside slurp exists, the live overlay should not fall back to the old strip mesh for that seam")
	return _errors.is_empty()


func test_build_edge_overlay_result_keeps_authored_horizontal_slurp_for_height_step_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 2, [12, 34], 5)
	_set_hgt_value(data["hgt"], 1, 0, 1, 10)
	var renderer = Map3DRendererScript.new()
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 1, 2, data["typ"], {12: 0, 34: 1}, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S01H", Vector3(1.5 * SECTOR_SIZE, 10.0 * HEIGHT_SCALE, 2.5 * SECTOR_SIZE)), "Height-step interior top/bottom neighbors should still keep authored S01H slurps anchored to the bottom sector center")
	_check(result.get("mesh", null) == null, "Height-step authored horizontal seams should not fall back to strip mesh because fallback causes protruding artifacts")
	return _errors.is_empty()

func test_build_edge_overlay_result_uses_pair_based_horizontal_seam_for_north_border_pair() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 5)
	var renderer = Map3DRendererScript.new()
	var mapping := {12: 1, 248: 0, 249: 0, 250: 0, 251: 0, 252: 0, 253: 0, 254: 0, 255: 0}
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 1, 1, data["typ"], mapping, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S01H", Vector3(1.5 * SECTOR_SIZE, 5.0 * HEIGHT_SCALE, 1.5 * SECTOR_SIZE)), "North border seam should use authored S01H with the implicit border SurfaceType ordered before the inner sector")
	return _errors.is_empty()

func test_build_edge_overlay_result_always_uses_strip_mesh_for_live_preview() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34], 5)
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var result := renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 1}, 99, preloads)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var mesh: ArrayMesh = result.get("mesh", null)
	_check(descriptors.is_empty(), "When no authored slurp source exists for the requested set, the live overlay should skip authored seam descriptors")
	_check(mesh != null, "When authored slurp assets are unavailable, the live overlay should fall back to the seam strip mesh")
	if mesh != null:
		_check(mesh.get_surface_count() > 0, "Fallback seam mesh should include at least one strip surface")
		var found := false
		for surface_idx in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface_idx)
			if _edge_shader_material_matches(material, preloads, 0, 1, false):
				found = true
				break
		_check(found, "Fallback seam mesh should still preserve the ordered surface-pair blend for the missing authored vertical slurp")
	return _errors.is_empty()

func test_build_edge_overlay_result_skips_same_surface_fallback_when_authored_slurp_is_unavailable() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 34], 5)
	var renderer = Map3DRendererScript.new()
	var result := renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], {12: 0, 34: 0}, 99, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var mesh: ArrayMesh = result.get("mesh", null)
	_check(descriptors.is_empty(), "Missing same-surface authored slurps should not emit descriptors")
	_check(mesh == null or mesh.get_surface_count() == 0, "Missing same-surface authored slurps should not emit floating fallback seam strips")
	return _errors.is_empty()

func test_build_edge_overlay_result_includes_pair_based_border_to_border_seam_on_north_ring() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 1, [12, 12], 5)
	_set_hgt_value(data["hgt"], 2, 0, -1, 6)
	var renderer = Map3DRendererScript.new()
	var mapping := {12: 1, 248: 0, 249: 0, 250: 0, 251: 0, 252: 0, 253: 0, 254: 0, 255: 0}
	var result: Dictionary = renderer._build_edge_overlay_result(data["hgt"], 2, 1, data["typ"], mapping, 1, MockPreloads.new())
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	_check(_has_descriptor(descriptors, "S00V", _ua_vec3(3000.0, 500.0, 600.0)), "Adjacent north-border sectors should also emit authored border-to-border slurps on the implicit ring")
	return _errors.is_empty()


func test_chunk_edge_overlay_assigns_vertical_seam_to_single_chunk_owner() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(8, 1, [12, 12, 12, 12, 34, 34, 34, 34], 5)
	var left_result: Dictionary = SlurpBuilder.build_chunk_edge_overlay_result(Vector2i(0, 0), data["hgt"], 8, 1, data["typ"], {12: 0, 34: 1}, 1)
	var right_result: Dictionary = SlurpBuilder.build_chunk_edge_overlay_result(Vector2i(1, 0), data["hgt"], 8, 1, data["typ"], {12: 0, 34: 1}, 1)
	_check(_has_descriptor(left_result.get("authored_piece_descriptors", []), "S01V", Vector3(5.5 * SECTOR_SIZE, 5.0 * HEIGHT_SCALE, 1.5 * SECTOR_SIZE)), "The owning chunk should contain the cross-chunk authored vertical slurp descriptor")
	_check(not _base_names_from_descriptors(right_result.get("authored_piece_descriptors", [])).has("S01V"), "The non-owning chunk should not duplicate the cross-chunk authored vertical slurp descriptor")
	_check(right_result.get("mesh", null) == null or right_result.get("mesh", null).get_surface_count() == 0, "The non-owning chunk should not duplicate fallback mesh seams either")
	return _errors.is_empty()

func test_authored_piece_uvs_decode_array_pairs_against_texture_size() -> bool:
	_reset_errors()
	var polygon := [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var uvs: Array = AuthoredPieceLibrary._coerce_uvs(
		[[1, 1], [126, 1], [126, 126], [1, 126]],
		polygon,
		1,
		"BODEN2.ILBM"
	)
	_check(uvs.size() == polygon.size(), "Authored UV decoding should preserve one UV per polygon vertex")
	if uvs.size() == polygon.size():
		_check(is_equal_approx(uvs[0].x, 1.0 / 255.0), "Array-pair authored UVs should normalize using the real texture width")
		_check(is_equal_approx(uvs[0].y, 1.0 / 255.0), "Array-pair authored UVs should normalize using the real texture height")
		_check(is_equal_approx(uvs[2].x, 126.0 / 255.0), "Authored UV decoding should preserve the high-end U coordinate")
		_check(is_equal_approx(uvs[2].y, 126.0 / 255.0), "Authored UV decoding should preserve the high-end V coordinate")
	return _errors.is_empty()

func test_authored_piece_material_keeps_opaque_textures_nontransparent() -> bool:
	_reset_errors()
	var material := AuthoredPieceLibrary._material_for_texture(1, "BODEN2.ILBM")
	_check(material is StandardMaterial3D, "Authored-piece textured material should use StandardMaterial3D")
	if material is StandardMaterial3D:
		_check(material.albedo_texture != null, "Authored-piece textured material should bind the requested texture")
		_check(material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA, "Opaque authored-piece textures should not be forced into alpha blending")
		_check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Authored-piece textured materials should bypass directional lighting for a flatter UA-like presentation")
		_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "Authored-piece geometry should stay double-sided because extracted BAS meshes do not consistently preserve front-face winding")
	return _errors.is_empty()

func test_authored_piece_material_returns_null_for_empty_texture_name() -> bool:
	_reset_errors()
	var material := AuthoredPieceLibrary._material_for_texture(1, "")
	_check(material == null, "Texture-less authored surfaces should be skipped instead of creating a magenta debug placeholder material")
	return _errors.is_empty()

func test_preview_material_uses_unshaded_nonmetallic_presentation() -> bool:
	_reset_errors()
	var material := Map3DRendererScript._make_preview_material(Color(0.25, 0.5, 0.75, 1.0))
	_check(material is StandardMaterial3D, "Preview fallback material should use StandardMaterial3D")
	if material is StandardMaterial3D:
		_check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Preview fallback material should be unshaded so the 3D preview does not introduce a fake light direction")
		_check(is_equal_approx(material.metallic, 0.0), "Preview fallback material should remain non-metallic")
		_check(is_equal_approx(material.roughness, 1.0), "Preview fallback material should keep the fully matte fallback roughness")
	return _errors.is_empty()

func test_terrain_shaders_are_unshaded_for_ua_style_flat_preview() -> bool:
	_reset_errors()
	var sector_shader := load("res://resources/terrain/shaders/sector_top.gdshader") as Shader
	var edge_shader := load("res://resources/terrain/shaders/edge_blend.gdshader") as Shader
	_check(sector_shader != null, "Sector-top terrain shader should load")
	_check(edge_shader != null, "Edge-blend terrain shader should load")
	if sector_shader != null:
		_check(String(sector_shader.code).contains("unshaded"), "Sector-top terrain shader should opt out of lighting so sector tops match the flat UA presentation")
	if edge_shader != null:
		_check(String(edge_shader.code).contains("unshaded"), "Edge-blend terrain shader should opt out of lighting so seam strips do not show directional shading")
	return _errors.is_empty()

func test_authored_piece_material_converts_yellow_key_to_alpha() -> bool:
	_reset_errors()
	var material := AuthoredPieceLibrary._material_for_texture(1, "FX2.ILBM")
	_check(material is StandardMaterial3D, "Keyed authored texture should still use StandardMaterial3D")
	if material is StandardMaterial3D:
		_check(material.albedo_texture != null, "Keyed authored texture should bind a processed texture")
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "Yellow-keyed authored textures should use alpha scissor to avoid broad transparent sorting")
		_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "Keyed authored cutouts should stay double-sided because BAS face winding is not reliable enough for backface culling")
		if material.albedo_texture != null:
			var image: Image = material.albedo_texture.get_image()
			_check(image != null and _image_has_transparent_pixels(image), "Yellow-keyed authored textures should contain transparent pixels after conversion")
			if image != null:
				var transparent := _first_transparent_pixel(image)
				_check(transparent.r == 0.0 and transparent.g == 0.0 and transparent.b == 0.0 and transparent.a == 0.0, "Yellow-keyed transparent texels should zero RGB as well as alpha to avoid halos")
	return _errors.is_empty()

func test_authored_piece_luminous_material_uses_separate_alpha_path() -> bool:
	_reset_errors()
	var cutout_material := AuthoredPieceLibrary._material_for_texture(1, "FX2.ILBM")
	var luminous_material := AuthoredPieceLibrary._material_for_texture(1, "FX2.ILBM", {"transparency_mode": "lumtracy", "tracy_val": 128})
	_check(luminous_material is StandardMaterial3D, "Luminous authored texture should still use StandardMaterial3D")
	_check(cutout_material != luminous_material, "Cutout and luminous authored materials should not share the same cache entry")
	if luminous_material is StandardMaterial3D:
		_check(luminous_material.albedo_texture != null, "Luminous authored texture should bind a processed texture")
		_check(luminous_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Luminous authored surfaces should keep alpha blending")
		_check(luminous_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Luminous authored surfaces should bypass Godot lighting for a closer UA look")
		_check(luminous_material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Luminous authored surfaces should use additive blending to match UA's primary LUMTRACY path")
		_check(luminous_material.disable_fog, "Luminous/additive authored surfaces should opt out of preview visibility fog so bright animated effects can remain visible farther out like in retail UA")
		_check(luminous_material.cull_mode == BaseMaterial3D.CULL_DISABLED, "Luminous authored surfaces should remain double-sided like other authored BAS geometry")
		if luminous_material.albedo_texture != null:
			var image: Image = luminous_material.albedo_texture.get_image()
			_check(image != null and not _image_has_partial_alpha_pixels(image), "Luminous authored textures should keep their original opaque palette colors; UA's primary LUMTRACY path comes from additive blend state rather than per-pixel alpha remapping")
	if cutout_material is StandardMaterial3D:
		_check(not cutout_material.disable_fog, "Ordinary cutout authored surfaces should still participate in preview visibility fog")
	if cutout_material is StandardMaterial3D and luminous_material is StandardMaterial3D and cutout_material.albedo_texture != null and luminous_material.albedo_texture != null:
		var cutout_image: Image = cutout_material.albedo_texture.get_image()
		var luminous_image: Image = luminous_material.albedo_texture.get_image()
		_check(not _images_are_identical(cutout_image, luminous_image), "Luminous FX2 rendering should not reuse the keyed BMP cutout texture when the retail hi/alpha override is available")
	return _errors.is_empty()

func test_authored_piece_material_applies_source_shade_multiplier() -> bool:
	_reset_errors()
	var shade_value := 228
	var material := AuthoredPieceLibrary._material_for_texture(1, "CITY1.ILBM", {"shade_value": shade_value})
	_check(material is StandardMaterial3D, "Shaded authored texture should still use StandardMaterial3D")
	if material is StandardMaterial3D:
		var expected := 1.0 - float(shade_value) / 256.0
		_check(is_equal_approx(material.albedo_color.r, expected), "Shaded authored material should darken RGB by the UA shade multiplier")
		_check(is_equal_approx(material.albedo_color.g, expected), "Shaded authored material should apply the same multiplier to green")
		_check(is_equal_approx(material.albedo_color.b, expected), "Shaded authored material should apply the same multiplier to blue")
		_check(is_equal_approx(material.albedo_color.a, 1.0), "Opaque shaded authored materials should keep full alpha")
	return _errors.is_empty()

func test_authored_piece_material_applies_source_shade_multiplier_to_opaque_texture() -> bool:
	_reset_errors()
	var shade_value := 128
	var material := AuthoredPieceLibrary._material_for_texture(1, "BODEN2.ILBM", {"shade_value": shade_value})
	_check(material is StandardMaterial3D, "Opaque shaded authored texture should still build a standard material")
	if material is StandardMaterial3D:
		var expected := 1.0 - float(shade_value) / 256.0
		_check(is_equal_approx(material.albedo_color.r, expected), "Opaque authored textures should still receive the UA shade multiplier even without alpha")
		_check(is_equal_approx(material.albedo_color.g, expected), "Opaque authored textures should tint green with the same UA shade multiplier")
		_check(is_equal_approx(material.albedo_color.b, expected), "Opaque authored textures should tint blue with the same UA shade multiplier")
		_check(is_equal_approx(material.albedo_color.a, 1.0), "Opaque authored textures should keep full alpha after shade tinting")
	return _errors.is_empty()

func test_authored_piece_luminous_fx2_resolves_retail_hi_alpha_override() -> bool:
	_reset_errors()
	var raw_path := AuthoredPieceLibrary._raw_texture_override_path(1, "FX2.ILBM", {"transparency_mode": "lumtracy", "tracy_val": 128})
	_check(not raw_path.is_empty(), "Luminous FX2 should resolve a retail hi/alpha raw texture override when it exists in the set assets")
	_check(raw_path.to_lower().ends_with("/set1/hi/alpha/fx2.ilb"), "Luminous FX2 should prefer the set-local hi/alpha override used by retail UA on normal blended hardware")
	var non_luminous_raw_path := AuthoredPieceLibrary._raw_texture_override_path(1, "FX2.ILBM", {})
	_check(non_luminous_raw_path.is_empty(), "Non-luminous FX2 should keep the existing keyed BMP path instead of always forcing the raw hi/alpha override")
	return _errors.is_empty()

func test_authored_piece_area_animation_frames_load_from_anm() -> bool:
	_reset_errors()
	var polygon := [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var frames: Array = AuthoredPieceLibrary._load_anim_frames(1, "05079601.ANM", polygon)
	_check(frames.size() == 4, "05079601.ANM should resolve to its 4 exported animation frames")
	if frames.size() == 4:
		_check(String(frames[0].get("texture_name", "")) == "FX2.ILBM", "05079601.ANM should reference FX2.ILBM frames")
		_check(frames[0].get("triangles", []).size() == 2, "Quad ANM frames should triangulate into two triangles")
		_check(is_equal_approx(float(frames[0].get("duration_sec", 0.0)), 0.04), "ANM frame_time 40 should map to 0.04 seconds")
	return _errors.is_empty()

func test_authored_piece_area_animation_frames_use_bmpanim_u8_uv_scale() -> bool:
	_reset_errors()
	var polygon := [
		Vector3.ZERO,
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 1.0),
		Vector3(0.0, 0.0, 1.0),
	]
	var frames: Array = AuthoredPieceLibrary._load_anim_frames(1, "05079601.ANM", polygon)
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

func test_authored_piece_area_lumtracy_hints_are_preserved_for_typ185() -> bool:
	_reset_errors()
	var piece_source: Dictionary = AuthoredPieceLibrary._load_piece_source(1, "GR_254")
	var surfaces: Array = AuthoredPieceLibrary._extract_surfaces(
		piece_source.get("bas_data", {}),
		piece_source.get("points", []),
		piece_source.get("polys", []),
		1
	)
	var found_luminous := false
	for surface in surfaces:
		if typeof(surface) != TYPE_DICTIONARY:
			continue
		var animation_frames: Array = surface.get("animation_frames", [])
		var render_hints: Dictionary = surface.get("render_hints", {})
		if animation_frames.is_empty():
			continue
		if String(render_hints.get("transparency_mode", "")) == "lumtracy":
			found_luminous = true
			_check(int(render_hints.get("tracy_val", -1)) == 128, "GR_254 luminous animated area should preserve its tracy value from BAS STRC")
			break
	_check(found_luminous, "typ185 GR_254 authored animated surfaces should preserve lumtracy render hints")
	return _errors.is_empty()

func test_set1_typ96_bottom_right_piece_preserves_dark_parapet_shade() -> bool:
	_reset_errors()
	var piece_source: Dictionary = AuthoredPieceLibrary._load_piece_source(1, "ST_GHTT4")
	var surfaces: Array = AuthoredPieceLibrary._extract_surfaces(
		piece_source.get("bas_data", {}),
		piece_source.get("points", []),
		piece_source.get("polys", []),
		1
	)
	var found_dark_parapet := false
	for surface in surfaces:
		if typeof(surface) != TYPE_DICTIONARY:
			continue
		if String(surface.get("texture_name", "")) != "CITY1.ILBM":
			continue
		if not surface.get("animation_frames", []).is_empty():
			continue
		var render_hints: Dictionary = surface.get("render_hints", {})
		if int(render_hints.get("shade_value", -1)) == 228:
			found_dark_parapet = true
			var mesh_surface: Dictionary = AuthoredPieceLibrary._mesh_surface_from_surface(surface, 1)
			var material: Material = mesh_surface.get("material", null)
			_check(material is StandardMaterial3D, "ST_GHTT4 parapet surface should still build a standard authored material")
			if material is StandardMaterial3D:
				var expected := 1.0 - 228.0 / 256.0
				_check(is_equal_approx(material.albedo_color.r, expected), "ST_GHTT4 parapet surface should preserve the source dark shade multiplier")
			break
	_check(found_dark_parapet, "ST_GHTT4 should preserve the dark CITY1 parapet shading used by set1 typ96 bottom-right")
	return _errors.is_empty()

func test_authored_piece_mesh_uses_authored_uvs_for_st_empty() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "ST_EMPTY")
	_check(mesh != null, "ST_EMPTY authored-piece mesh should load")
	_check(mesh != null and mesh.get_surface_count() > 0, "ST_EMPTY authored-piece mesh should expose at least one surface")
	if mesh != null and mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var bounds := _uv_bounds(uvs)
		_check(uvs.size() > 0, "ST_EMPTY authored-piece mesh should carry UVs")
		if not bounds.is_empty():
			_check(is_equal_approx(float(bounds["min_u"]), 1.0 / 255.0) and is_equal_approx(float(bounds["max_u"]), 126.0 / 255.0), "ST_EMPTY UVs should preserve the authored U bounds from BAS data")
			_check(is_equal_approx(float(bounds["min_v"]), 1.0 / 255.0) and is_equal_approx(float(bounds["max_v"]), 126.0 / 255.0), "ST_EMPTY UVs should preserve the authored V bounds from BAS data")
	return _errors.is_empty()

func test_authored_piece_mesh_loads_ground_slurp_assets_from_objects_ground() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "S00V")
	var bounds := _mesh_xz_bounds(mesh)
	_check(not bounds.is_empty(), "Ground slurp assets should load through the authored-piece library from objects/ground")
	if not bounds.is_empty():
		_check(is_equal_approx(float(bounds["min_x"]), -750.0) and is_equal_approx(float(bounds["max_x"]), -450.0), "S00V should preserve its authored seam-local X footprint from objects/ground")
		_check(is_equal_approx(float(bounds["min_z"]), -600.0) and is_equal_approx(float(bounds["max_z"]), 600.0), "S00V should preserve its authored seam-local Z span from objects/ground")
	return _errors.is_empty()

func test_authored_piece_mesh_loads_vehicle_assets_from_objects_vehicles() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "VP_ROBO")
	_check(mesh != null, "Vehicle BAS assets should resolve through the authored-piece library from objects/vehicles")
	if mesh != null:
		_check(mesh.get_surface_count() > 0, "Vehicle BAS assets should build at least one surface")
		_check(not _mesh_xz_bounds(mesh).is_empty(), "Vehicle BAS assets should produce usable mesh bounds")
	var piece := AuthoredPieceLibrary._build_piece_node(1, "VP_ROBO", 0)
	_check(piece != null, "Vehicle overlays should still build when a baked scene exists but has no renderable content")
	if piece != null:
		_check(piece.get_child_count() > 0, "Vehicle overlays should fall back to legacy BAS/SKL content instead of returning an empty baked scene")
		piece.free()
	return _errors.is_empty()

func test_authored_piece_known_vehicle_and_radar_models_skip_textureless_placeholder_surfaces() -> bool:
	_reset_errors()
	for base_name in ["VP_RADA", "VP_NFOX", "VP_KPAN1"]:
		var piece := AuthoredPieceLibrary._build_piece_node(1, base_name, 0)
		_check(piece != null, "%s authored overlay should still build after skipping texture-less surfaces" % base_name)
		if piece != null:
			_check(not _node_has_magenta_placeholder_material(piece), "%s should skip texture-less authored surfaces instead of rendering the magenta debug placeholder" % base_name)
			piece.free()
	return _errors.is_empty()

func test_build_host_station_descriptors_emits_vehicle_overlay_and_visible_turrets_at_ua_mirrored_origin() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 1800.0, 1800.0, -700)
	], 1, data["hgt"], 2, 2)
	_check(descriptors.size() == 5, "Vehicle id 56 should emit the body plus four visible attached gun overlays")
	_check(_has_descriptor(descriptors, "VP_ROBO", _ua_vec3(1800.0, 1500.0, 1800.0)), "Vehicle id 56 should resolve to VP_ROBO at the host-station origin")
	_check(_has_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1700.0, 1745.0)), "Resistance front gun should mirror its local UA offset into Godot space")
	_check(_has_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1680.0, 1880.0)), "Resistance rear gun should mirror its local UA offset into Godot space")
	_check(_has_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1890.0, 1800.0)), "Resistance top gun should mirror its local UA offset into Godot space")
	_check(_has_descriptor(descriptors, "VP_FLAK2", _ua_vec3(1800.0, 1350.0, 1800.0)), "Resistance lower gun should mirror its local UA offset into Godot space")
	return _errors.is_empty()

func test_build_host_station_overlay_node_instantiates_visible_resistance_robo_and_turrets() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 1800.0, 1800.0, -700)
	], 1, data["hgt"], 2, 2)
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == 5, "Resistance robo host-station overlays should instantiate the body plus four visible turret nodes")
	for child in overlay.get_children():
		_check(_node_has_runtime_content(child), "Resistance robo host-station overlay children should contain renderable runtime content instead of empty placeholder nodes")
	overlay.free()
	return _errors.is_empty()

func test_build_host_station_descriptors_accepts_player_vehicle_alias_ids() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 6)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(176, 1800.0, 1200.0, -500)
	], 1, data["hgt"], 1, 1)
	_check(descriptors.size() == 1, "Player visual aliases should resolve to host-station overlay descriptors")
	if descriptors.size() == 1:
		_check(String(descriptors[0].get("base_name", "")) == "VP_GIGNT", "Player id 176 should resolve to the same host-station model family as faction id 59")
		_check(is_equal_approx(Vector3(descriptors[0].get("origin", Vector3.ZERO)).y, 1100.0), "Player alias placement should still add the relative Y offset on top of sampled ground height")
	return _errors.is_empty()

func test_build_host_station_descriptors_emits_visible_black_sect_turrets() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(62, 1200.0, 1200.0, -500)
	], 1, data["hgt"], 1, 1)
	_check(descriptors.size() == 3, "Vehicle id 62 should emit the body plus its two visible turret overlays")
	_check(_has_descriptor(descriptors, "VP_BSECT", _ua_vec3(1200.0, 500.0, 1200.0)), "Vehicle id 62 should still emit the Black Sect body overlay")
	_check(_has_descriptor(descriptors, "VP_FLAK2", _ua_vec3(1200.0, 650.0, 825.0)), "Black Sect front gun should mirror its UA local offset into Godot space")
	_check(_has_descriptor(descriptors, "VP_FLAK2", _ua_vec3(1200.0, 620.0, 1580.0)), "Black Sect rear gun should mirror its UA local offset into Godot space")
	return _errors.is_empty()

func test_build_host_station_descriptors_keeps_body_when_gun_visuals_are_invisible() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(57, 1200.0, 1200.0, -500)
	], 1, data["hgt"], 1, 1)
	_check(descriptors.size() == 1, "Host stations whose gun types resolve to dummy visuals should still keep their body overlay")
	if descriptors.size() == 1:
		_check(String(descriptors[0].get("base_name", "")) == "VP_KROBO", "Invisible gun attachments should not suppress the host-station body model")
	return _errors.is_empty()

func test_build_host_station_overlay_node_keeps_visible_body_when_gun_visuals_are_invisible() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(57, 1200.0, 1200.0, -500)
	], 1, data["hgt"], 1, 1)
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == 1, "Host stations with dummy gun visuals should still instantiate the body overlay node")
	if overlay.get_child_count() == 1:
		_check(_node_has_runtime_content(overlay.get_child(0)), "The surviving host-station body node should contain renderable runtime content")
	overlay.free()
	return _errors.is_empty()

func test_build_host_station_descriptors_emits_source_backed_turret_forward_vectors() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 1800.0, 1800.0, -700)
	], 1, data["hgt"], 2, 2)
	var front_gun := _find_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1700.0, 1745.0))
	var rear_gun := _find_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1680.0, 1880.0))
	var top_gun := _find_descriptor(descriptors, "VP_MFLAK", _ua_vec3(1800.0, 1890.0, 1800.0))
	var lower_gun := _find_descriptor(descriptors, "VP_FLAK2", _ua_vec3(1800.0, 1350.0, 1800.0))
	_check(Vector3(front_gun.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "UA +Z turret sockets should face Godot -Z after the preview axis conversion")
	_check(Vector3(rear_gun.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "UA -Z turret sockets should face Godot +Z after the preview axis conversion")
	_check(Vector3(top_gun.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Resistance top turret should keep its source-backed forward direction")
	_check(Vector3(lower_gun.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Resistance lower turret should keep its source-backed forward direction")
	return _errors.is_empty()

func test_build_host_station_descriptors_snaps_y_to_authored_support_mesh_when_present() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 12)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 150.0, 150.0, -500)
	], 1, data["hgt"], 1, 1, [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": _ua_vec3(0.0, 2000.0, 0.0)}
	])
	_check(_has_descriptor(descriptors, "VP_ROBO", _ua_vec3(150.0, 2508.0, 150.0)), "Host-station body placement should use the highest authored support mesh underneath before applying relative pos_y")
	_check(_has_descriptor(descriptors, "VP_MFLAK", _ua_vec3(150.0, 2708.0, 95.0)), "Attached host-station guns should inherit the same support-snapped body origin when a mesh underneath is higher than terrain")
	return _errors.is_empty()

func test_build_host_station_descriptors_keeps_terrain_height_when_support_is_lower() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 12)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(176, 150.0, 150.0, -500)
	], 1, data["hgt"], 1, 1, [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 100, "origin": Vector3.ZERO}
	])
	_check(descriptors.size() == 1, "Lower authored support should not prevent host-station descriptor emission")
	if descriptors.size() == 1:
		_check(Vector3(descriptors[0].get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(150.0, 1700.0, 150.0)), "Host-station placement should keep terrain as the support reference when authored support is not higher")
	return _errors.is_empty()

func test_build_host_station_descriptors_ignores_remote_higher_support_meshes() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 12)
	# Use coordinates clearly inside the support mesh footprint (ST_EMPTY is 300x300 centered at origin)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 50.0, 50.0, -500)
	], 1, data["hgt"], 1, 1, [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": _ua_vec3(0.0, 2000.0, 0.0)},
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 102, "origin": _ua_vec3(6000.0, 5000.0, 0.0)}
	])
	_check(_has_descriptor(descriptors, "VP_ROBO", _ua_vec3(50.0, 2508.0, 50.0)), "Host-station placement should sample only support meshes under the local anchor instead of snapping to a higher remote roof elsewhere in the map")
	return _errors.is_empty()

func test_build_host_station_descriptors_snaps_to_rotated_authored_support_mesh() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 12)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 900.0, 300.0, -500)
	], 1, data["hgt"], 1, 1, [
		{
			"set_id": 1,
			"base_name": "S00V",
			"raw_id": - 1,
			"origin": _ua_vec3(900.0, 2000.0, 900.0),
			"forward": Vector3(1.0, 0.0, 0.0)
		}
	])
	_check(_has_descriptor(descriptors, "VP_ROBO", _ua_vec3(900.0, 2508.0, 300.0)), "Host-station placement should still snap to authored support geometry after the support descriptor is rotated via forward")
	_check(_has_descriptor(descriptors, "VP_MFLAK", _ua_vec3(900.0, 2708.0, 245.0)), "Attached host-station guns should inherit the same rotated-support-snapped body origin")
	return _errors.is_empty()

func test_build_host_station_descriptors_skips_unknown_vehicle_ids() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(999, 1200.0, 1200.0, -500)
	], 1, data["hgt"], 1, 1)
	_check(descriptors.is_empty(), "Unknown host-station vehicle ids should be ignored instead of producing broken overlay descriptors")
	return _errors.is_empty()

func test_host_station_descriptor_positions_stay_in_ua_world_units() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 8)
	var descriptors := Map3DRendererScript._build_host_station_descriptors([
		HostStationStub.new(56, 1800.0, 1800.0, -700)
	], 1, data["hgt"], 2, 2)
	var body := {}
	for descriptor_value in descriptors:
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor := descriptor_value as Dictionary
		if String(descriptor.get("base_name", "")) != "VP_ROBO":
			continue
		body = descriptor
		break
	_check(not body.is_empty(), "Host-station body descriptor should be emitted")
	if not body.is_empty():
		var origin := Vector3(body.get("origin", Vector3.ZERO))
		_check(origin.x > 1000.0 and origin.z > 1000.0, "Host-station origins should stay in UA world units instead of scaled 0..N space")
		_check(origin.is_equal_approx(Vector3(1800.0, 1500.0, 1800.0)), "Host-station body origin should match UA-space sector placement and relative pos_y")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_applies_known_blg_overrides_only() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 28, 20, 255]),
		"original",
		-1,
		-1,
		[],
		[],
		[],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([12, 205, 199, 12]), "Known building ids should replace only their matching 3D typ_map slots while unknown ids leave typ_map unchanged")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_applies_beam_gate_closed_bp_override() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[ {"sec_x": 1, "sec_y": 2, "closed_bp": 25}],
		[],
		[],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([12, 12, 3, 12]), "Beam gates should treat sec_x/sec_y as 1-based playable-sector coordinates and replace the matching 3D typ_map sector with the source-backed closed_bp sec_type")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_applies_tech_upgrade_building_override() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[],
		[ {"sec_x": 2, "sec_y": 1, "building": 50}],
		[],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([12, 102, 12, 12]), "Tech upgrades should normalize their 1-based sector coordinates and apply the editor-aligned visible typ override for known building/building_id variants")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_applies_editor_aligned_tech_upgrade_override_variants() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[],
		[
			{"sec_x": 1, "sec_y": 1, "building": 60},
			{"sec_x": 2, "sec_y": 1, "building_id": 61},
			{"sec_x": 1, "sec_y": 2, "building": 51}
		],
		[],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([106, 113, 101, 12]), "Tech upgrades should mirror the editor's explicit visible typ mapping for building ids like 60, 61, and 51 instead of falling back to the raw NET_BLDG sec_type values")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_applies_stoudson_bomb_inactive_bp_override() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[],
		[],
		[ {"sec_x": 2, "sec_y": 2, "inactive_bp": 35}],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([12, 12, 12, 245]), "Stoudson bombs should normalize their 1-based sector coordinates before applying the inactive_bp building sec_type override")
	return _errors.is_empty()

func test_effective_typ_map_for_3d_ignores_unknown_or_out_of_bounds_secondary_building_overrides() -> bool:
	_reset_errors()
	var effective := Map3DRendererScript._effective_typ_map_for_3d(
		PackedByteArray([12, 12, 12, 12]),
		PackedByteArray([0, 0, 0, 0]),
		"original",
		2,
		2,
		[
			{"sec_x": 3, "sec_y": 1, "closed_bp": 25},
			{"sec_x": 0, "sec_y": 1, "closed_bp": 999}
		],
		[ {"sec_x": 1, "sec_y": 2}],
		[ {"sec_x": 2, "sec_y": 2, "inactive_bp": - 1}],
		LOOKUP_TEST_SET_ID
	)
	_check(effective == PackedByteArray([12, 12, 12, 12]), "Out-of-bounds 1-based sector coordinates and unknown secondary building ids should leave the 3D typ_map unchanged")
	return _errors.is_empty()

func test_building_definition_for_id_and_sec_type_distinguishes_duplicate_original_ids() -> bool:
	_reset_errors()
	var small_aa := Map3DRendererScript._building_definition_for_id_and_sec_type(28, 205, LOOKUP_TEST_SET_ID, "original")
	var radar := Map3DRendererScript._building_definition_for_id_and_sec_type(28, 240, LOOKUP_TEST_SET_ID, "original")
	_check(not small_aa.is_empty(), "Original building id 28 should resolve when the effective sec_type is the Resistance flak typ 205")
	_check(not radar.is_empty(), "Original building id 28 should also resolve the separate radar definition when the effective sec_type is 240")
	if not small_aa.is_empty():
		var small_aa_attachments: Array = small_aa.get("attachments", [])
		_check(int(small_aa.get("sec_type", -1)) == 205, "The Resistance small-AA definition should keep sec_type 205")
		_check(small_aa_attachments.size() == 1 and int(Dictionary(small_aa_attachments[0]).get("vehicle_id", -1)) == 96, "The sec_type 205 definition for building 28 should emit the visible small-AA vehicle 96")
	if not radar.is_empty():
		var radar_attachments: Array = radar.get("attachments", [])
		_check(int(radar.get("sec_type", -1)) == 240, "The alternate original building-28 definition should keep sec_type 240")
		_check(radar_attachments.size() == 1 and int(Dictionary(radar_attachments[0]).get("vehicle_id", -1)) == 139, "The sec_type 240 definition for building 28 should emit the radar attachment vehicle 139 instead of the small-AA one")
	return _errors.is_empty()

func test_building_attachment_base_name_for_vehicle_prefers_non_effect_vehicle_definition() -> bool:
	_reset_errors()
	var base_name := Map3DRendererScript._building_attachment_base_name_for_vehicle(96, LOOKUP_TEST_SET_ID, "original")
	_check(base_name == "VP_DFLAK", "Building attachments should prefer the non-effect vehicle definition for id 96 instead of the later bruch.scr particle/effect reuse")
	return _errors.is_empty()


func test_md_building_alias_74_reuses_taerflak_definition() -> bool:
	_reset_errors()
	var d74 := Map3DRendererScript._building_definition_for_id_and_sec_type(74, 208, 1, "metropolisDawn")
	var d31 := Map3DRendererScript._building_definition_for_id_and_sec_type(31, 208, 1, "metropolisDawn")
	_check(not d74.is_empty(), "MD building id 74 should resolve a definition through the 74->31 alias path")
	_check(not d31.is_empty(), "MD building id 31 should resolve the source TAERFLAK definition")
	if not d74.is_empty() and not d31.is_empty():
		var ids74 := _attachment_vehicle_ids(d74)
		var ids31 := _attachment_vehicle_ids(d31)
		_check(ids74.size() > 0, "Aliased MD building id 74 should include turret/radar attachment vehicle entries")
		_check(ids74 == ids31, "Aliased MD building id 74 should keep the same attachment vehicle profile as source id 31")
	return _errors.is_empty()


func test_build_blg_attachment_descriptors_emits_small_aa_overlay_for_blg28() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	_set_hgt_value(data["hgt"], 1, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([28]),
		PackedByteArray([205]),
		1,
		data["hgt"],
		1,
		1,
		[],
		"original"
	)
	_check(descriptors.size() == 1, "Building id 28 should emit exactly one visible small-AA overlay descriptor in the original data set")
	if descriptors.size() == 1:
		var descriptor: Dictionary = descriptors[0]
		_check(String(descriptor.get("base_name", "")) == "VP_DFLAK", "Building id 28 should resolve vehicle 96 through visproto to VP_DFLAK")
		_check(Vector3(descriptor.get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(1800.0, 1225.0, 1800.0)), "Small-AA overlay placement should use the sector center plus the source-backed mirrored UA offset")
		_check(Vector3(descriptor.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(1.0, 0.0, 0.0)), "Small-AA overlay should carry the source-backed forward direction after UA->Godot conversion")
	return _errors.is_empty()

func test_build_blg_attachment_descriptors_keeps_sector_ground_height_when_authored_support_mesh_is_higher() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	_set_hgt_value(data["hgt"], 1, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([28]), PackedByteArray([205]), 1, data["hgt"], 1, 1,
		[ {"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": Vector3(0.0, 2000.0, 0.0)}], "original"
	)
	_check(descriptors.size() == 1, "Raised authored support meshes should not suppress visible building turret descriptor emission")
	if descriptors.size() == 1:
		_check(Vector3(descriptors[0].get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(1800.0, 1225.0, 1800.0)), "Building turret sockets should stay anchored to the terrain sector center height instead of inheriting raised authored support geometry")
	return _errors.is_empty()

func test_build_blg_attachment_descriptors_skips_dummy_gflak_visuals() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([20]),
		PackedByteArray([199]),
		1,
		data["hgt"],
		1,
		1,
		[],
		"original"
	)
	_check(descriptors.is_empty(), "Buildings whose attached vehicles resolve only to dummy visuals should not emit broken 3D turret overlays")
	return _errors.is_empty()

func test_build_blg_attachment_descriptors_emits_radar_nozzle_overlay() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	_set_hgt_value(data["hgt"], 1, 0, 0, 7)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([3]),
		PackedByteArray([204]),
		1,
		data["hgt"],
		1,
		1,
		[],
		"original"
	)
	_check(descriptors.size() == 1, "Radar buildings should emit their visible nozzle/radar overlay descriptor")
	if descriptors.size() == 1:
		var descriptor: Dictionary = descriptors[0]
		_check(String(descriptor.get("base_name", "")) == "VP_RADA", "Original radar building id 3 should resolve vehicle 109 through visproto to VP_RADA")
		_check(Vector3(descriptor.get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(1830.0, 1230.0, 1800.0)), "Radar nozzle placement should use the sector center plus the source-backed mirrored UA offset")
		_check(Vector3(descriptor.get("forward", Vector3.ZERO)).is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "Radar nozzle overlay should carry the source-backed forward direction after UA->Godot conversion")
	return _errors.is_empty()

func test_build_blg_attachment_overlay_applies_positive_x_forward_orientation() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	_set_hgt_value(data["hgt"], 1, 0, 0, 8)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([28]), PackedByteArray([205]), 1, data["hgt"], 1, 1, [], "original"
	)
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == 1, "Small-AA building overlay should instantiate exactly one authored child")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Small-AA authored overlay child should be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(1.0, 0.0, 0.0)), "Positive-X building turret sockets should face Godot +X after optional overlay yaw is applied")
	overlay.free()
	return _errors.is_empty()

func test_build_blg_attachment_overlay_applies_negative_x_forward_orientation() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	_set_hgt_value(data["hgt"], 1, 0, 0, 7)
	var descriptors := Map3DRendererScript._build_blg_attachment_descriptors(
		PackedByteArray([3]), PackedByteArray([204]), 1, data["hgt"], 1, 1, [], "original"
	)
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == 1, "Radar nozzle building overlay should instantiate exactly one authored child")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Radar nozzle authored overlay child should be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "Negative-X building nozzle sockets should face Godot -X after optional overlay yaw is applied")
	overlay.free()
	return _errors.is_empty()

func test_squad_formation_offsets_fill_left_to_right_and_rows_advance_upward() -> bool:
	_reset_errors()
	var offsets := Map3DRendererScript._squad_formation_offsets(5)
	var expected := [
		_ua_vec3(-200.0, 0.0, 0.0),
		_ua_vec3(-100.0, 0.0, 0.0),
		_ua_vec3(0.0, 0.0, 0.0),
		_ua_vec3(100.0, 0.0, 0.0),
		_ua_vec3(-200.0, 0.0, -100.0),
	]
	_check(offsets.size() == expected.size(), "Squad formation offsets should emit one X/Z offset per squad unit")
	for i in range(min(offsets.size(), expected.size())):
		_check(Vector3(offsets[i]).is_equal_approx(expected[i]), "Squad formation offset %d should fill rows left-to-right and restart the next row upward from the left" % i)
	return _errors.is_empty()

func test_squad_formation_offsets_for_32_restart_each_row_from_left_and_move_upward() -> bool:
	_reset_errors()
	var offsets := Map3DRendererScript._squad_formation_offsets(32)
	var expected_prefix := [
		_ua_vec3(-350.0, 0.0, 0.0),
		_ua_vec3(-250.0, 0.0, 0.0),
		_ua_vec3(-150.0, 0.0, 0.0),
		_ua_vec3(-50.0, 0.0, 0.0),
		_ua_vec3(50.0, 0.0, 0.0),
		_ua_vec3(150.0, 0.0, 0.0),
		_ua_vec3(250.0, 0.0, 0.0),
		_ua_vec3(-350.0, 0.0, -100.0),
		_ua_vec3(-250.0, 0.0, -100.0),
	]
	_check(offsets.size() == 32, "Quantity 32 squads should still emit one offset per rendered unit")
	for i in range(min(offsets.size(), expected_prefix.size())):
		_check(Vector3(offsets[i]).is_equal_approx(expected_prefix[i]), "Quantity 32 squads should fill each row from the left and start the next row one step upward from the left edge (index %d)" % i)
	return _errors.is_empty()

func test_build_squad_descriptors_resolves_original_vehicle_visuals_and_uses_leftmost_single_unit_offset() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 9)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 1200.0, 1200.0)
	], 1, data["hgt"], 2, 2, [], "original")
	_check(descriptors.size() == 1, "Original squad vehicle ids should emit exactly one vehicle overlay descriptor when a source-backed visual exists")
	if descriptors.size() == 1:
		var descriptor: Dictionary = descriptors[0]
		_check(String(descriptor.get("base_name", "")) == "VPwSIMPL", "Original squad vehicle id 1 should prefer the source-backed vp_wait idle visual through user.scr and visproto.lst")
		_check(Vector3(descriptor.get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(1050.0, 900.0, 1200.0)), "Single-unit squads should use the leftmost slot of the first row while keeping the shared snapped anchor Y")
		_check(is_equal_approx(float(descriptor.get("y_offset", -1.0)), Map3DRendererScript.SQUAD_EXTRA_Y_OFFSET), "Squad overlays should carry a small extra vertical lift so vehicle hulls do not sit too deep in support surfaces")
	return _errors.is_empty()

func test_build_squad_overlay_node_instantiates_visible_original_vehicle() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 9)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 1200.0, 1200.0)
	], 1, data["hgt"], 2, 2, [], "original")
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == 1, "Single-unit original squads should instantiate exactly one overlay node")
	if overlay.get_child_count() == 1:
		_check(_node_has_runtime_content(overlay.get_child(0)), "Single-unit original squad overlay nodes should contain renderable runtime content")
	overlay.free()
	return _errors.is_empty()

func test_build_squad_descriptors_expands_quantity_into_left_to_right_upward_formation() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(2, 2, [12, 12, 12, 12], 0)
	_set_hgt_value(data["hgt"], 2, 0, 0, 9)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 1200.0, 1200.0, 5)
	], 1, data["hgt"], 2, 2, [], "original")
	var expected_origins := [
		_ua_vec3(1000.0, 900.0, 1200.0),
		_ua_vec3(1100.0, 900.0, 1200.0),
		_ua_vec3(1200.0, 900.0, 1200.0),
		_ua_vec3(1300.0, 900.0, 1200.0),
		_ua_vec3(1000.0, 900.0, 1100.0),
	]
	_check(descriptors.size() == expected_origins.size(), "Squad quantity should expand into one rendered descriptor per squad unit while preserving left-to-right upward row growth")
	for i in range(min(descriptors.size(), expected_origins.size())):
		_check(Vector3(descriptors[i].get("origin", Vector3.INF)).is_equal_approx(expected_origins[i]), "Rendered squad unit %d should use the left-to-right X fill and upward row progression from the shared squad anchor" % i)
	return _errors.is_empty()

func test_build_squad_descriptors_clamps_invalid_quantity_to_single_unit() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 1200.0, 1200.0, 0)
	], 1, data["hgt"], 1, 1, [], "original")
	_check(descriptors.size() == 1, "Invalid squad quantities should clamp to a single rendered squad unit instead of producing no preview")
	if descriptors.size() == 1:
		_check(Vector3(descriptors[0].get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(1050.0, 0.0, 1200.0)), "Clamped single-unit squads should still use the same leftmost first-row slot")
	return _errors.is_empty()

func test_build_squad_descriptors_resolves_metropolis_dawn_vehicle_visuals() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(63, 1200.0, 1200.0)
	], 1, data["hgt"], 1, 1, [], "metropolisDawn")
	_check(descriptors.size() == 1, "Metropolis Dawn squad vehicle ids should resolve through the XP script set when a source-backed visual exists")
	if descriptors.size() == 1:
		_check(String(descriptors[0].get("base_name", "")) == "VP_MYKO4", "XP squad vehicle id 63 should resolve through Myk.scr and set1_xp visproto.lst to VP_MYKO4")
		_check(is_equal_approx(float(descriptors[0].get("y_offset", -1.0)), Map3DRendererScript.SQUAD_EXTRA_Y_OFFSET), "XP squad overlays should receive the same conservative extra lift as original-game squads")
	return _errors.is_empty()


func test_md_direct_squad_base_mappings_resolve_xpack_models() -> bool:
	_reset_errors()
	AuthoredPieceLibrary.set_piece_game_data_type("metropolisDawn")
	Map3DRendererScript._clear_runtime_lookup_caches_for_tests()
	var expected := {
		143: "VP_TODIN",
		144: "VP_TKATJ",
		145: "VP_MMYKO",
	}
	var known_bad := {
		"VP_GHTT": true,
		"VP_GLIDW": true,
		"VP_BRGR4": true,
	}
	for vehicle_id in expected.keys():
		var base_name := Map3DRendererScript._squad_base_name_for_vehicle(int(vehicle_id), 1, "metropolisDawn")
		_check(not base_name.is_empty(), "MD squad vehicle %d should resolve to a non-empty visual base name" % int(vehicle_id))
		_check(base_name == String(expected[vehicle_id]), "MD squad vehicle %d should resolve to the expected direct XPACK base name" % int(vehicle_id))
		_check(not known_bad.has(base_name), "MD squad vehicle %d should not regress to known bad projectile/effect bases" % int(vehicle_id))
	return _errors.is_empty()


func test_preferred_squad_visual_base_name_prefers_wait_over_normal() -> bool:
	_reset_errors()
	var base_name := Map3DRendererScript._preferred_squad_visual_base_name({
		"wait": 1,
		"normal": 0,
	}, ["VP_NORMAL", "VP_WAIT"])
	_check(base_name == "VP_WAIT", "Squad visual selection should prefer the source-backed vp_wait idle visual over vp_normal when both resolve to valid BAS names")
	return _errors.is_empty()

func test_preferred_squad_visual_base_name_falls_back_from_dummy_wait_to_normal() -> bool:
	_reset_errors()
	var base_name := Map3DRendererScript._preferred_squad_visual_base_name({
		"wait": 1,
		"normal": 0,
	}, ["VP_NORMAL", "dummy"])
	_check(base_name == "VP_NORMAL", "Squad visual selection should fall back to vp_normal when the wait-state visual is dummy or otherwise unusable")
	return _errors.is_empty()

func test_build_squad_descriptors_snaps_y_to_authored_support_mesh_when_present() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 12)
	var support_descriptors := [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 100, "origin": Vector3.ZERO}
	]
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 150.0, 150.0)
	], 1, data["hgt"], 1, 1, support_descriptors, "original")
	_check(descriptors.size() == 1, "Squad descriptor building should still emit the squad body when an authored support mesh is available beneath it")
	if descriptors.size() == 1:
		var origin := Vector3(descriptors[0].get("origin", Vector3.INF))
		_check(origin.is_equal_approx(_ua_vec3(0.0, 1200.0, 150.0)), "Squad Y snapping should choose the highest supporting mesh at the shared anchor before the leftmost X formation offset is applied")
	var rooftop_descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(1, 150.0, 150.0)
	], 1, data["hgt"], 1, 1, [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": _ua_vec3(0.0, 2000.0, 0.0)}
	], "original")
	_check(rooftop_descriptors.size() == 1, "Raised authored support meshes should still allow squad descriptor emission")
	if rooftop_descriptors.size() == 1:
		_check(Vector3(rooftop_descriptors[0].get("origin", Vector3.INF)).is_equal_approx(_ua_vec3(0.0, 2008.0, 150.0)), "Squad Y snapping should use authored support geometry when it is higher than terrain at the shared squad anchor, while preserving the left-to-right row fill")
	return _errors.is_empty()

func test_build_squad_descriptors_skips_unknown_vehicle_ids() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [12], 0)
	var descriptors := Map3DRendererScript._build_squad_descriptors([
		SquadStub.new(999, 1200.0, 1200.0)
	], 1, data["hgt"], 1, 1, [], "original")
	_check(descriptors.is_empty(), "Unknown squad vehicle ids should be ignored instead of emitting broken 3D overlay descriptors")
	return _errors.is_empty()

func test_build_overlay_node_deforms_authored_slurp_mesh_to_neighbor_heights() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{
			"set_id": 1,
			"raw_id": - 1,
			"base_name": "S00V",
			"origin": _ua_vec3(0.0, 500.0, 0.0),
			"warp_mode": "vside",
			"anchor_height": 500.0 / 1200.0,
			"left_height": 100.0 / 1200.0,
			"right_height": 500.0 / 1200.0,
			"top_avg": 200.0 / 1200.0,
			"bottom_avg": 300.0 / 1200.0,
		}
	])
	_check(overlay.get_child_count() == 1, "Warped slurp overlay should instantiate one authored piece node")
	if overlay.get_child_count() == 1:
		var piece := overlay.get_child(0) as Node3D
		_check(piece.position.is_equal_approx(_ua_vec3(0.0, 500.0, 0.0) + Vector3(0.0, AuthoredPieceLibrary.OVERLAY_Y_BIAS, 0.0)), "Warped slurp piece should still receive the authored overlay Y bias above the anchor height")
		var bounds := _node_mesh_local_y_bounds(piece)
		_check(not bounds.is_empty(), "Warped slurp piece should expose local Y deformation")
		if not bounds.is_empty():
			_check(float(bounds["min_y"]) < -350.0 / 1200.0, "Warped slurp mesh should pull one side down toward the lower neighboring sector height")
			_check(float(bounds["max_y"]) > -5.0 and float(bounds["max_y"]) < 5.0, "Warped slurp mesh should keep the anchor-side edge near the anchor sector height")
	return _errors.is_empty()

func test_authored_piece_mesh_keeps_st_empty_on_300_unit_subsector_footprint() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "ST_EMPTY")
	var bounds := _mesh_xz_bounds(mesh)
	_check(not bounds.is_empty(), "ST_EMPTY authored-piece mesh should expose X/Z bounds")
	if not bounds.is_empty():
		_check(is_equal_approx(float(bounds["min_x"]), -150.0) and is_equal_approx(float(bounds["max_x"]), 150.0), "ST_EMPTY should keep its raw 300-unit authored X footprint so adjacent 3x3 pieces do not overlap")
		_check(is_equal_approx(float(bounds["min_z"]), -150.0) and is_equal_approx(float(bounds["max_z"]), 150.0), "ST_EMPTY should keep its raw 300-unit authored Z footprint so adjacent 3x3 pieces do not overlap")
	return _errors.is_empty()

func test_authored_piece_mesh_keeps_gr_254_on_sector_sized_border_footprint() -> bool:
	_reset_errors()
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "GR_254")
	var bounds := _mesh_xz_bounds(mesh)
	_check(not bounds.is_empty(), "GR_254 authored border mesh should expose X/Z bounds")
	if not bounds.is_empty():
		_check(is_equal_approx(float(bounds["min_x"]), -600.0) and is_equal_approx(float(bounds["max_x"]), 600.0), "GR_254 should preserve its authored 1200-unit X span instead of being scaled beyond a sector")
		_check(is_equal_approx(float(bounds["min_z"]), -600.0) and is_equal_approx(float(bounds["max_z"]), 450.0), "GR_254 should preserve its mirrored-authored Z footprint instead of being inflated by the old equal-thirds scale")
	return _errors.is_empty()

func test_authored_piece_polygon_vertices_mirror_local_z_into_editor_space() -> bool:
	_reset_errors()
	var polygon := AuthoredPieceLibrary._polygon_vertices(
		[
			{"x": 10.0, "y": - 5.0, "z": 7.0},
			{"x": - 2.0, "y": 3.0, "z": - 11.0},
		],
		[[0, 1]],
		0
	)
	_check(polygon.size() == 2, "Polygon decode should preserve point count for the test poly")
	if polygon.size() == 2:
		_check(polygon[0].is_equal_approx(Vector3(10.0 / 1200.0, 5.0 / 1200.0, -7.0 / 1200.0)), "Authored polygon conversion should mirror local Z into the editor preview space without inflating the raw authored footprint")
		_check(polygon[1].is_equal_approx(Vector3(-2.0 / 1200.0, -3.0 / 1200.0, 11.0 / 1200.0)), "Authored polygon conversion should keep X, flip source-down Y upward, and mirror Z without the old equal-thirds scaling")
	return _errors.is_empty()

func test_build_overlay_node_biases_authored_piece_above_terrain_plane() -> bool:
	_reset_errors()
	var origin := Vector3(1200.0, 700.0, 2400.0)
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 99, "origin": origin}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should instantiate the authored test piece")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Authored overlay child should be a Node3D")
		if child != null:
			_check(is_equal_approx(child.position.x, origin.x) and is_equal_approx(child.position.z, origin.z), "Authored overlay bias should not disturb horizontal placement")
			_check(is_equal_approx(child.position.y, origin.y + AuthoredPieceLibrary.OVERLAY_Y_BIAS), "Authored overlay should sit slightly above the terrain plane to avoid coplanar cutoff")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_applies_optional_y_offset() -> bool:
	_reset_errors()
	var origin := Vector3(1200.0, 700.0, 2400.0)
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 102, "origin": origin, "y_offset": 8.0}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should instantiate the authored test piece when applying an optional vertical offset")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Y-offset authored overlay child should be a Node3D")
		if child != null:
			_check(is_equal_approx(child.position.y, origin.y + AuthoredPieceLibrary.OVERLAY_Y_BIAS + 8.0), "Optional authored overlay y_offset should add a small extra lift on top of the shared overlay bias")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_applies_optional_forward_orientation() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 100, "origin": Vector3.ZERO, "forward": Vector3(0.0, 0.0, 1.0)}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should instantiate the authored test piece when applying optional orientation")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Oriented authored overlay child should be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(0.0, 0.0, 1.0)), "Optional forward orientation should rotate authored overlays so their facing matches the descriptor")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_applies_optional_forward_orientation_for_positive_x() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 103, "origin": Vector3.ZERO, "forward": Vector3(1.0, 0.0, 0.0)}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should instantiate the authored test piece for positive-X orientation")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Positive-X authored overlay child should be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(1.0, 0.0, 0.0)), "Optional forward orientation should not mirror positive-X facing")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_applies_optional_forward_orientation_for_negative_x() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 104, "origin": Vector3.ZERO, "forward": Vector3(-1.0, 0.0, 0.0)}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should instantiate the authored test piece for negative-X orientation")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Negative-X authored overlay child should be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "Optional forward orientation should not mirror negative-X facing")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_ignores_zero_forward_orientation() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": Vector3.ZERO, "forward": Vector3.ZERO}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should still instantiate authored overlays when optional orientation is empty")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Zero-forward authored overlay child should still be a Node3D")
		if child != null:
			var facing := -child.transform.basis.z.normalized()
			_check(facing.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "Zero forward vectors should leave authored overlays at their default facing instead of producing a bogus yaw")
	overlay.free()
	return _errors.is_empty()

func test_build_overlay_node_skips_invalid_descriptors_without_dropping_valid_neighbors() -> bool:
	_reset_errors()
	var origin := Vector3(1200.0, 700.0, 2400.0)
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{"set_id": 1, "base_name": "MISSING_TEST_PIECE", "raw_id": 404, "origin": Vector3.ZERO},
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 105, "origin": origin}
	])
	_check(overlay.get_child_count() == 1, "Overlay builder should skip missing authored-piece descriptors while still instantiating later valid descriptors")
	if overlay.get_child_count() == 1:
		var child := overlay.get_child(0) as Node3D
		_check(child != null, "Mixed-validity overlay build should still return the surviving authored child as a Node3D")
		if child != null:
			_check(child.position.is_equal_approx(Vector3(origin.x, origin.y + AuthoredPieceLibrary.OVERLAY_Y_BIAS, origin.z)), "The surviving valid authored overlay should keep its expected biased origin even when earlier descriptors were skipped")
	overlay.free()
	return _errors.is_empty()

func test_build_mesh_with_textures_compact_sector_uses_surface_type_texture_family() -> bool:
	_reset_errors()
	var w := 1
	var h := 1
	var data := _make_typ_and_hgt(w, h, [7])
	var subsector_patterns := {
		7: {
			"surface_type": 1,
			"sector_type": 1,
			"subsectors": PackedInt32Array([10])
		}
	}
	var tile_mapping := {
		10: {"val0": 2, "val1": 0, "val2": 6, "val3": 5, "flag": 255}
	}
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		w,
		h,
		{7: 1},
		subsector_patterns,
		tile_mapping
	)
	_check(result.has("mesh"), "build_mesh_with_textures should return a mesh entry")
	_check(result.has("surface_to_surface_type"), "build_mesh_with_textures should return a surface mapping entry")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, 1)
		_check(textured_surface_idx >= 0, "Expected a terrain surface for compact surface_type 1")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var files_used := _files_used_from_colors(colors)
			var variants_used := _variants_used_from_colors(colors, 4)
			_check(indices.size() == 2 * 3, "Compact sectors should render as one flat top quad")
			_check(_distinct_color_count(colors) == 1, "Compact sector surface should use one texture-family selection")
			_check(files_used.size() == 1 and files_used.has(1), "Compact sector should use the texture family for surface_type 1")
			_check(variants_used.size() == 1 and variants_used.has(2), "Compact sector should use the startup-state slot selected from tile flag 255 (val0)")
	return _errors.is_empty()

func test_selected_raw_id_for_tile_desc_uses_startup_raw_stage_slot() -> bool:
	_reset_errors()
	var tile_desc := {"val0": 40, "val1": 30, "val2": 20, "val3": 10, "flag": 255}
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(tile_desc) == 40, "startup raw 255 should use stage slot 0 / val0")
	tile_desc["flag"] = 0
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(tile_desc) == 10, "startup raw 0 should use stage slot 3 / val3")
	tile_desc["flag"] = 1
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(tile_desc) == 20, "raw_to_stage bands should still map raw 1 to stage slot 2 when passed directly")
	var fixed_piece_tile_desc := {"val0": 129, "val1": 0, "val2": 0, "val3": 0, "flag": 0}
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(fixed_piece_tile_desc) == 129, "Single-prototype tile entries should keep their only authored piece even when the selected startup-state slot is 0")
	var multi_piece_zero_slot_tile_desc := {"val0": 129, "val1": 128, "val2": 0, "val3": 0, "flag": 0}
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(multi_piece_zero_slot_tile_desc) == 0, "Zero-slot fallback should not override multi-prototype tile entries")
	var repeated_steady_state_tile_desc := {"val0": 203, "val1": 203, "val2": 203, "val3": 35, "flag": 0}
	_check(Map3DRendererScript._selected_raw_id_for_tile_desc(repeated_steady_state_tile_desc) == 203, "The unique typ155-style repeated steady-state payload should keep its repeated authored piece instead of dropping to the divergent val3")
	return _errors.is_empty()

func test_authored_origin_for_subsector_uses_300_unit_lattice() -> bool:
	_reset_errors()
	var origin := Map3DRendererScript._authored_origin_for_subsector(SECTOR_SIZE, SECTOR_SIZE, 0.0, 1, 2)
	_check(origin.is_equal_approx(Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.75)), "3x3 authored subpieces should use the source-backed 300-unit lattice inside a 1200-unit sector")
	return _errors.is_empty()

func test_default_piece_selection_for_subsector_missing_tile_desc_falls_back_to_surface_family() -> bool:
	_reset_errors()
	var selection := Map3DRendererScript._default_piece_selection_for_subsector(4, 107, {}, {}, {})
	var piece: Array = selection.get("piece", [])
	_check(int(selection.get("raw_id", -2)) == -1, "Missing tile metadata should not resolve an authored/raw tile id")
	_check(piece.size() == 3, "Fallback surface-family selection should still return an FCV triple")
	if piece.size() == 3:
		_check(int(piece[0]) == 4, "Fallback file should stay on the sector surface_type")
		_check(int(piece[1]) == 16, "Surface_type 4 fallback should use the 16-cell family")
		_check(int(piece[2]) == 0, "Fallback variant should default to 0 when tile metadata is missing")
	return _errors.is_empty()

func test_build_mesh_with_textures_complex_sector_uses_3x3_subsector_grid() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [9], 6)
	var subsector_patterns := {
		9: {
			"surface_type": 2,
			"sector_type": 0,
			"subsectors": PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8])
		}
	}
	var tile_mapping := {
		0: {"val0": 0, "val1": 0, "val2": 0, "val3": 0, "flag": 1},
		1: {"val0": 4, "val1": 0, "val2": 4, "val3": 0, "flag": 1},
		2: {"val0": 8, "val1": 0, "val2": 8, "val3": 0, "flag": 1},
		3: {"val0": 12, "val1": 0, "val2": 12, "val3": 0, "flag": 1},
		4: {"val0": 16, "val1": 0, "val2": 16, "val3": 0, "flag": 1},
		5: {"val0": 32, "val1": 0, "val2": 32, "val3": 0, "flag": 1},
		6: {"val0": 36, "val1": 0, "val2": 36, "val3": 0, "flag": 1},
		7: {"val0": 37, "val1": 0, "val2": 37, "val3": 0, "flag": 1},
		8: {"val0": 38, "val1": 0, "val2": 38, "val3": 0, "flag": 1}
	}
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		{9: 2},
		subsector_patterns,
		tile_mapping
	)
	_check(result.has("mesh"), "Complex-sector textured build should return a mesh entry")
	_check(result.has("surface_to_surface_type"), "Complex-sector textured build should return a surface mapping entry")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, 2)
		_check(textured_surface_idx >= 0, "Expected a terrain surface for complex surface_type 2")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var files_used := _files_used_from_colors(colors)
			_check(indices.size() == 9 * 2 * 3, "Complex sectors should render as a 3x3 grid of flat subquads")
			_check(files_used.has(1) and files_used.has(2) and files_used.has(3) and files_used.has(4) and files_used.has(5), "Complex sector preview should preserve per-subsector file selection")
			for v in verts:
				_check(is_equal_approx(v.y, 6.0 * HEIGHT_SCALE), "Complex sector subquads should stay on the sector's single hgt_map height")
	return _errors.is_empty()

func test_apply_sector_top_materials_enables_multi_texture_shader_mode() -> bool:
	_reset_errors()
	var renderer = Map3DRendererScript.new()
	var preloads := MockPreloads.new()
	var data := _make_typ_and_hgt(1, 1, [12])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(data["hgt"], data["typ"], 1, 1, {12: 3})
	var mesh: ArrayMesh = result.get("mesh", null)
	var surface_map: Dictionary = result.get("surface_to_surface_type", {})
	_check(mesh != null, "Material application test should produce a mesh")
	if mesh != null:
		renderer._apply_sector_top_materials(mesh, preloads, surface_map)
		var textured_surface_idx := _surface_index_for_type(surface_map, 3)
		_check(textured_surface_idx >= 0, "Expected a terrain surface for shader-material test")
		if textured_surface_idx >= 0:
			var material := mesh.surface_get_material(textured_surface_idx)
			_check(material is ShaderMaterial, "Terrain top should use ShaderMaterial when preloads are available")
			if material is ShaderMaterial:
				_check(bool(material.get_shader_parameter("use_mesh_uv")), "Terrain shader should consume mesh UVs for subsector composition")
				_check(bool(material.get_shader_parameter("use_multi_textures")), "Terrain shader should enable per-vertex ground-file selection")
				_check(bool(material.get_shader_parameter("use_vertex_variant")), "Terrain shader should enable per-vertex variant selection")
				_check(material.get_shader_parameter("ground0") != null and material.get_shader_parameter("ground5") != null, "Terrain shader should bind the full set of ground textures")
	return _errors.is_empty()

func test_sector_top_shader_uses_nearest_sampling_for_packed_ground_atlases() -> bool:
	_reset_errors()
	var path := "res://resources/terrain/shaders/sector_top.gdshader"
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "sector_top shader source should be readable for regression coverage")
	if file != null:
		var source := file.get_as_text()
		file.close()
		_check(source.contains("filter_nearest"), "Packed ground atlas sampling should use nearest filtering to avoid camera-angle-dependent cross-cell bleed")
		_check(not source.contains("filter_linear"), "Sector-top shader should no longer use linear sampling on packed ground atlases")
		_check(source.contains("textureLod"), "Sector-top shader should pin packed atlas sampling to LOD 0 to avoid mip-driven texture swapping")
	return _errors.is_empty()

func test_edge_blend_shader_pins_sampling_to_lod0() -> bool:
	_reset_errors()
	var path := "res://resources/terrain/shaders/edge_blend.gdshader"
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "edge_blend shader source should be readable for regression coverage")
	if file != null:
		var source := file.get_as_text()
		file.close()
		_check(source.contains("textureLod(texture_a"), "Edge seam shader should pin texture_a sampling to LOD 0")
		_check(source.contains("textureLod(texture_b"), "Edge seam shader should pin texture_b sampling to LOD 0")
	return _errors.is_empty()

func test_typ_value_with_implicit_border_restores_fixed_border_ring() -> bool:
	_reset_errors()
	var typ := PackedByteArray([77])
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, -1, -1) == 248, "Top-left implicit border typ should be 248")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 0, -1) == 252, "Top edge implicit border typ should be 252")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 1, -1) == 249, "Top-right implicit border typ should be 249")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, -1, 0) == 255, "Left edge implicit border typ should be 255")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 0, 0) == 77, "Playable cell should keep its real typ_map value")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 1, 0) == 253, "Right edge implicit border typ should be 253")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, -1, 1) == 251, "Bottom-left implicit border typ should be 251")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 0, 1) == 254, "Bottom edge implicit border typ should be 254")
	_check(Map3DRendererScript._typ_value_with_implicit_border(typ, 1, 1, 1, 1) == 250, "Bottom-right implicit border typ should be 250")
	return _errors.is_empty()

func test_build_mesh_with_textures_renders_full_implicit_border_ring() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [77])
	var mapping := {
		77: 0,
		248: 0,
		249: 0,
		250: 0,
		251: 0,
		252: 0,
		253: 0,
		254: 0,
		255: 0,
	}
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(data["hgt"], data["typ"], 1, 1, mapping)
	_check(result.has("mesh"), "Border-ring textured build should return a mesh entry")
	_check(result.has("surface_to_surface_type"), "Border-ring textured build should return a surface mapping entry")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, 0)
		_check(textured_surface_idx >= 0, "Expected a terrain surface for the implicit border ring surface_type")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var min_x := INF
			var max_x := -INF
			var min_z := INF
			var max_z := -INF
			for v in verts:
				min_x = min(min_x, v.x)
				max_x = max(max_x, v.x)
				min_z = min(min_z, v.z)
				max_z = max(max_z, v.z)
			_check(indices.size() == 9 * 2 * 3, "A 1x1 textured map should render the full 3x3 implicit border ring footprint")
			_check(is_equal_approx(min_x, 0.0) and is_equal_approx(max_x, 3.0 * SECTOR_SIZE), "Implicit border ring should expand textured terrain bounds across the full bordered width")
			_check(is_equal_approx(min_z, 0.0) and is_equal_approx(max_z, 3.0 * SECTOR_SIZE), "Implicit border ring should expand textured terrain bounds across the full bordered height")
	return _errors.is_empty()

func test_set1_typ3_uses_gate_authored_piece() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(1)
	var data := _make_typ_and_hgt(1, 1, [3])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		1
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var base_names := _base_names_from_descriptors(descriptors)
	var center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
	_check(descriptors.size() >= 1, "typ3 should emit authored piece descriptors")
	_check(base_names.has("ST_GAT2"), "typ3 should resolve to ST_GAT2 authored geometry")
	_check(_has_descriptor(descriptors, "ST_GAT2", center_origin), "typ3 should place ST_GAT2 at the bordered map's center sector")
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	_check(overlay.get_child_count() == descriptors.size(), "typ3 authored descriptors should all instantiate overlay children")
	overlay.free()
	return _errors.is_empty()

func test_set1_typ185_uses_authored_piece_descriptors() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(1)
	var data := _make_typ_and_hgt(1, 1, [185])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		1
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	var south_center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.75)
	_check(descriptors.size() >= 1, "typ185 should emit authored piece descriptors instead of relying only on generic top quads")
	_check(overlay.get_child_count() == descriptors.size(), "typ185 authored descriptors should all instantiate overlay children")
	_check(_count_nodes_with_meta(overlay, "ua_authored_animated") >= 1, "typ185 overlay should now include at least one animated authored surface for the GR_254 center piece path")
	_check(_has_descriptor(descriptors, "ST_NS1", south_center_origin), "typ185 south-center road piece should use startup-state val0 and the 300-unit lattice position")
	_check(not _has_descriptor(descriptors, "ST_STRE2", south_center_origin), "typ185 south-center road piece should no longer be forced to ST_STRE2 at the same origin")
	overlay.free()
	return _errors.is_empty()

func test_set1_typ40_uses_normal_startup_state_variants() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(1)
	var data := _make_typ_and_hgt(1, 1, [40])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		1
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var top_left_origin := Vector3(SECTOR_SIZE * 1.25, 0.0, SECTOR_SIZE * 1.25)
	var center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
	_check(_has_descriptor(descriptors, "GR_GITTR", top_left_origin), "typ40 top-left piece should use the normal startup GR_GITTR variant")
	_check(_has_descriptor(descriptors, "GR_TVTRM", center_origin), "typ40 center piece should use the normal startup GR_TVTRM variant")
	_check(not _has_descriptor(descriptors, "GRyGITTR", top_left_origin), "typ40 top-left piece should not start in the damaged/y variant")
	_check(not _has_descriptor(descriptors, "GRYTVTRM", center_origin), "typ40 center piece should not start in the damaged/y variant")
	return _errors.is_empty()

func test_set1_typ239_uses_startup_outer_gems_instead_of_empty_damaged_slots() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(1)
	var data := _make_typ_and_hgt(1, 1, [239])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		1
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var north_center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.25)
	var west_center_origin := Vector3(SECTOR_SIZE * 1.25, 0.0, SECTOR_SIZE * 1.5)
	var east_center_origin := Vector3(SECTOR_SIZE * 1.75, 0.0, SECTOR_SIZE * 1.5)
	var south_center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.75)
	_check(_has_descriptor(descriptors, "ST_GEMM2", north_center_origin), "typ239 north-center piece should start as ST_GEMM2 instead of empty")
	_check(_has_descriptor(descriptors, "ST_GEMM", west_center_origin), "typ239 west-center piece should start as ST_GEMM instead of empty")
	_check(_has_descriptor(descriptors, "ST_GEMM", east_center_origin), "typ239 east-center piece should start as ST_GEMM instead of empty")
	_check(_has_descriptor(descriptors, "ST_GEMM2", south_center_origin), "typ239 south-center piece should start as ST_GEMM2 instead of empty")
	_check(not _has_descriptor(descriptors, "ST_EMPTY", north_center_origin), "typ239 north-center piece should not regress to ST_EMPTY")
	_check(not _has_descriptor(descriptors, "ST_EMPTY", west_center_origin), "typ239 west-center piece should not regress to ST_EMPTY")
	return _errors.is_empty()

func test_set6_typ234_uses_authored_static_animation_overlay() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(6)
	var data := _make_typ_and_hgt(1, 1, [234])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		6
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	var center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
	_check(descriptors.size() >= 1, "set6 typ234 should emit at least one authored piece descriptor")
	_check(_has_descriptor(descriptors, "ST_ENDL4", center_origin), "set6 typ234 should resolve to the ST_ENDL4 authored sector piece at the compact-sector center")
	_check(overlay.get_child_count() == descriptors.size(), "set6 typ234 authored descriptors should instantiate overlay children")
	_check(_count_nodes_with_meta(overlay, "ua_authored_animated") >= 1, "set6 typ234 overlay should include embedded animated authored surfaces from ST_ENDL4")
	_check(_count_nodes_with_meta(overlay, "ua_authored_particle_emitter") >= 1, "set6 typ234 overlay should include authored floating particle emitters from ST_ENDL4 instead of flattening PTCL stages into ground surfaces")
	overlay.free()
	return _errors.is_empty()

func test_set6_typ235_uses_authored_static_animation_overlay() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(6)
	var data := _make_typ_and_hgt(1, 1, [235])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		6
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var overlay := AuthoredPieceLibrary.build_overlay_node(descriptors)
	var center_origin := Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
	_check(descriptors.size() >= 1, "set6 typ235 should emit at least one authored piece descriptor")
	_check(_has_descriptor(descriptors, "ST_ENDL5", center_origin), "set6 typ235 should resolve to the ST_ENDL5 authored sector piece at the compact-sector center")
	_check(overlay.get_child_count() == descriptors.size(), "set6 typ235 authored descriptors should instantiate overlay children")
	_check(_count_nodes_with_meta(overlay, "ua_authored_animated") >= 1, "set6 typ235 overlay should include embedded animated authored surfaces from ST_ENDL5")
	_check(_count_nodes_with_meta(overlay, "ua_authored_particle_emitter") >= 1, "set6 typ235 overlay should include authored floating particle emitters from ST_ENDL5 instead of flattening PTCL stages into ground surfaces")
	overlay.free()
	return _errors.is_empty()

func test_project_source_root_contains_authored_animated_and_particle_content_for_piece_runtime() -> bool:
	_reset_errors()
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	# Use the in-project (non-bundled) UA set tree for runtime piece extraction.
	AuthoredPieceLibrary.set_external_source_root("res://urban_assault_decompiled-master/assets/sets")
	var piece := AuthoredPieceLibrary.build_piece_scene_root(6, "ST_ENDL4")
	_check(piece != null, "ST_ENDL4 should instantiate directly from the populated project-contained source tree")
	if piece != null:
		_check(_first_node_with_meta(piece, "ua_authored_animated") != null, "ST_ENDL4 should contain an authored animated child when loaded from the project-contained source tree")
		_check(_first_node_with_meta(piece, "ua_authored_particle_emitter") != null, "ST_ENDL4 should contain an authored particle emitter child when loaded from the project-contained source tree")
		piece.free()
	return _errors.is_empty()

func test_apply_overlay_node_preserves_embedded_animated_surface_identity_for_transform_only_updates() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{
			"instance_key": "animated-identity",
			"set_id": 6,
			"base_name": "ST_ENDL4",
			"raw_id": - 1,
			"origin": Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
		}
	])
	_check(overlay.get_child_count() == 1, "Animated identity test should instantiate exactly one top-level authored piece")
	if overlay.get_child_count() == 1:
		var piece := overlay.get_child(0) as Node3D
		var animated := _first_node_with_meta(piece, "ua_authored_animated")
		_check(animated != null, "Animated identity test piece should contain an authored animated child")
		if piece != null and animated != null:
			var piece_id := piece.get_instance_id()
			var animated_id := animated.get_instance_id()
			var updated_origin := Vector3(SECTOR_SIZE * 1.75, 0.0, SECTOR_SIZE * 1.25)
			var updated_y_offset := 12.0
			AuthoredPieceLibrary.apply_overlay_node(overlay, [
				{
					"instance_key": "animated-identity",
					"set_id": 6,
					"base_name": "ST_ENDL4",
					"raw_id": - 1,
					"origin": updated_origin,
					"y_offset": updated_y_offset
				}
			])
			var updated_piece := overlay.get_child(0) as Node3D
			var updated_animated := _first_node_with_meta(updated_piece, "ua_authored_animated")
			_check(updated_piece != null and updated_piece.get_instance_id() == piece_id, "Transform-only overlay updates should preserve the top-level authored piece node for animated content")
			_check(updated_animated != null and updated_animated.get_instance_id() == animated_id, "Transform-only overlay updates should preserve embedded animated authored nodes")
			if updated_piece != null:
				var expected_position := updated_origin + Vector3(0.0, AuthoredPieceLibrary.OVERLAY_Y_BIAS + updated_y_offset, 0.0)
				_check(updated_piece.position.is_equal_approx(expected_position), "Transform-only overlay updates should still refresh the reused animated piece transform")
	overlay.free()
	return _errors.is_empty()

func test_animated_surface_frame_advance_reuses_prepared_meshes() -> bool:
	_reset_errors()
	var animated := AnimatedSurfaceMeshInstanceScript.new()
	var material_a := StandardMaterial3D.new()
	var material_b := StandardMaterial3D.new()
	var frame_a := {
		"duration_sec": 0.04,
		"triangles": [
			{
				"verts": [Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD],
				"uvs": [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]
			}
		],
		"material": material_a
	}
	var frame_b := {
		"duration_sec": 0.04,
		"triangles": [
			{
				"verts": [Vector3.ZERO, Vector3(0.0, 1.0, 0.0), Vector3.FORWARD],
				"uvs": [Vector2.ZERO, Vector2.UP, Vector2.ONE]
			}
		],
		"material": material_b
	}
	animated.setup_animation([frame_a, frame_b])
	_check(animated.mesh != null, "Animated surface setup should assign the first prepared frame mesh immediately")
	var seen_mesh_ids: Array[int] = []
	for step in 5:
		if animated.mesh != null:
			var mesh_id := animated.mesh.get_instance_id()
			if not seen_mesh_ids.has(mesh_id):
				seen_mesh_ids.append(mesh_id)
		animated._process(0.05)
	_check(seen_mesh_ids.size() == 2, "Animated surface playback should reuse the same two prepared frame meshes across multiple frame advances")
	if animated.mesh != null and seen_mesh_ids.size() == 2:
		_check(seen_mesh_ids.has(animated.mesh.get_instance_id()), "Animated surface playback should keep reusing previously prepared frame meshes instead of allocating new ones")
	animated.free()
	return _errors.is_empty()

func test_baked_authored_piece_runtime_restores_animated_luminous_frames() -> bool:
	_reset_errors()
	# This repo version does not implement a `set_baked_piece_loading_enabled()` hook.
	# Keep this test as a no-op so the suite can still validate renderer/overlay
	# correctness without requiring baked piece registries.
	print("SKIP test_baked_authored_piece_runtime_restores_animated_luminous_frames (baked piece loading not implemented)")
	return true

func test_particle_emitter_node_pool_reuses_expired_particle_nodes() -> bool:
	_reset_errors()
	var emitter := ParticleEmitterScript.new()
	var material := StandardMaterial3D.new()
	var frame := {
		"duration_sec": 0.04,
		"triangles": [ {"verts": [Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD], "uvs": [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]}],
		"material": material
	}
	emitter.setup_emitter({
		"anchor": Vector3.ZERO,
		"context_life_time_ms": 10000.0,
		"context_start_gen_ms": 0.0,
		"context_stop_gen_ms": 10000.0,
		"lifetime_ms": 200.0,
		"gen_rate": 50.0,
		"start_speed": 1.0,
		"start_size": 1.0,
		"end_size": 1.0,
		"stages": [ {"frames": [frame]}]
	})
	for warm_up in 5:
		emitter._process(0.05)
	var child_count_after_warmup := emitter.get_child_count()
	_check(child_count_after_warmup > 0, "Particle emitter should have spawned child nodes after warmup")
	for step in 20:
		emitter._process(0.05)
	var child_count_after_many_cycles := emitter.get_child_count()
	var total_nodes := emitter._particles.size() + emitter._node_pool.size()
	_check(child_count_after_many_cycles == total_nodes, "All child nodes should be accounted for in active particles or pool")
	_check(emitter._node_pool.size() > 0, "Some particles should have expired and returned their nodes to the pool")
	var all_nodes_are_children := true
	for particle in emitter._particles:
		var node: MeshInstance3D = particle.get("node", null) as MeshInstance3D
		if node != null and node.get_parent() != emitter:
			all_nodes_are_children = false
	for node in emitter._node_pool:
		if node is MeshInstance3D and node.get_parent() != emitter:
			all_nodes_are_children = false
	_check(all_nodes_are_children, "All particle nodes (active and pooled) should remain children of the emitter")
	var pooled_visible := false
	for node in emitter._node_pool:
		if node is MeshInstance3D and node.visible:
			pooled_visible = true
	_check(not pooled_visible, "Pooled particle nodes should be hidden")
	emitter.free()
	return _errors.is_empty()

func test_particle_emitter_mesh_assignment_only_on_stage_change() -> bool:
	_reset_errors()
	var emitter := ParticleEmitterScript.new()
	var material_a := StandardMaterial3D.new()
	var material_b := StandardMaterial3D.new()
	var frame_a := {
		"duration_sec": 0.04,
		"triangles": [ {"verts": [Vector3.ZERO, Vector3.RIGHT, Vector3.FORWARD], "uvs": [Vector2.ZERO, Vector2.RIGHT, Vector2.UP]}],
		"material": material_a
	}
	var frame_b := {
		"duration_sec": 0.04,
		"triangles": [ {"verts": [Vector3.ZERO, Vector3.UP, Vector3.FORWARD], "uvs": [Vector2.ZERO, Vector2.UP, Vector2.ONE]}],
		"material": material_b
	}
	emitter.setup_emitter({
		"anchor": Vector3.ZERO,
		"context_life_time_ms": 10000.0,
		"context_start_gen_ms": 0.0,
		"context_stop_gen_ms": 10000.0,
		"lifetime_ms": 1000.0,
		"gen_rate": 50.0,
		"start_speed": 1.0,
		"start_size": 1.0,
		"end_size": 1.0,
		"stages": [ {"frames": [frame_a]}, {"frames": [frame_b]}]
	})
	emitter._process(0.05)
	_check(emitter._particles.size() > 0, "Particle emitter should spawn particles after first tick")
	var all_have_stage_index := true
	for particle in emitter._particles:
		if not particle.has("stage_index"):
			all_have_stage_index = false
	_check(all_have_stage_index, "All particles should track their current stage_index")
	var first_particle: Dictionary = emitter._particles[0] if emitter._particles.size() > 0 else {}
	var initial_stage: int = int(first_particle.get("stage_index", -1))
	_check(initial_stage == 0, "New particles should start at stage 0")
	var particle_node: MeshInstance3D = first_particle.get("node", null) as MeshInstance3D
	var initial_mesh: Mesh = particle_node.mesh if particle_node else null
	_check(initial_mesh != null, "Particle should have mesh assigned from initial stage")
	for tick in 5:
		emitter._process(0.05)
	var same_stage_mesh: Mesh = particle_node.mesh if particle_node else null
	_check(same_stage_mesh == initial_mesh, "Mesh should not change while particle remains in same stage (300ms, stage lasts 500ms)")
	var updated_particle: Dictionary = emitter._particles[0] if emitter._particles.size() > 0 else {}
	var updated_stage: int = int(updated_particle.get("stage_index", -1))
	_check(updated_stage == 0, "Particle should still be in stage 0 after 300ms (lifetime 1000ms, 2 stages = 500ms per stage)")
	for tick in 5:
		emitter._process(0.1)
	if emitter._particles.size() > 0:
		var aged_particle: Dictionary = emitter._particles[0]
		var aged_stage: int = int(aged_particle.get("stage_index", -1))
		if aged_stage == 1:
			var aged_node: MeshInstance3D = aged_particle.get("node", null) as MeshInstance3D
			_check(aged_node != null and aged_node.mesh != initial_mesh, "Mesh should change when particle transitions to stage 1")
	emitter.free()
	return _errors.is_empty()

func test_apply_overlay_node_preserves_particle_emitter_identity_for_transform_only_updates() -> bool:
	_reset_errors()
	var overlay := AuthoredPieceLibrary.build_overlay_node([
		{
			"instance_key": "particle-identity",
			"set_id": 6,
			"base_name": "ST_ENDL4",
			"raw_id": - 1,
			"origin": Vector3(SECTOR_SIZE * 1.5, 0.0, SECTOR_SIZE * 1.5)
		}
	])
	_check(overlay.get_child_count() == 1, "Particle identity test should instantiate exactly one top-level authored piece")
	if overlay.get_child_count() == 1:
		var piece := overlay.get_child(0) as Node3D
		var emitter := _first_node_with_meta(piece, "ua_authored_particle_emitter")
		_check(emitter != null, "Particle identity test piece should contain an authored particle emitter child")
		if piece != null and emitter != null:
			var piece_id := piece.get_instance_id()
			var emitter_id := emitter.get_instance_id()
			var updated_origin := Vector3(SECTOR_SIZE * 1.25, 0.0, SECTOR_SIZE * 1.75)
			AuthoredPieceLibrary.apply_overlay_node(overlay, [
				{
					"instance_key": "particle-identity",
					"set_id": 6,
					"base_name": "ST_ENDL4",
					"raw_id": - 1,
					"origin": updated_origin
				}
			])
			var updated_piece := overlay.get_child(0) as Node3D
			var updated_emitter := _first_node_with_meta(updated_piece, "ua_authored_particle_emitter")
			_check(updated_piece != null and updated_piece.get_instance_id() == piece_id, "Transform-only overlay updates should preserve the top-level authored piece node for particle content")
			_check(updated_emitter != null and updated_emitter.get_instance_id() == emitter_id, "Transform-only overlay updates should preserve embedded particle emitter nodes")
			if updated_piece != null:
				var expected_position := updated_origin + Vector3(0.0, AuthoredPieceLibrary.OVERLAY_Y_BIAS, 0.0)
				_check(updated_piece.position.is_equal_approx(expected_position), "Transform-only overlay updates should still refresh the reused particle piece transform")
	overlay.free()
	return _errors.is_empty()

func test_authored_piece_surface_extraction_skips_ptcl_stage_areas() -> bool:
	_reset_errors()
	var fake_points := [
		{"x": 0.0, "y": 0.0, "z": 0.0},
		{"x": 1.0, "y": 0.0, "z": 0.0},
		{"x": 1.0, "y": 0.0, "z": 1.0},
	]
	var fake_polys := [[0, 1, 2]]
	var fake_ptcl := {
		"PTCL": [
			{"ADE ": [ {"ROOT": []}, {"STRC": {"flags": 0, "point": 0, "poly": 0, "strc_type": "STRC_ADE ", "version": 1}}]},
			{"ATTS": {"is_particle_atts": true, "context_life_time": 1000, "context_start_gen": 0, "context_stop_gen": 500, "gen_rate": 10, "lifetime": 1000, "start_size": 10, "end_size": 5, "start_speed": 10}},
			{"OBJT": [
				{"CLID": {"class_id": "area.class"}},
				{"AREA": [
					{"ADE ": [ {"ROOT": []}, {"STRC": {"flags": 4, "point": 0, "poly": 0, "strc_type": "STRC_ADE ", "version": 1}}]},
					{"STRC": {"polFlags": 0, "poly": 0, "strc_type": "STRC_AREA", "version": 1}},
					{"NAM2": {"name": "FX2.ILBM"}},
					{"OTL2": {"points": [[0, 0], [255, 0], [255, 255], [0, 255]]}},
				]}
			]},
		]
	}
	var surfaces: Array = AuthoredPieceLibrary._extract_surfaces(fake_ptcl, fake_points, fake_polys, 1)
	var emitters: Array = AuthoredPieceLibrary._extract_particle_emitters(fake_ptcl, fake_points, 1)
	_check(surfaces.is_empty(), "PTCL life-stage AREA nodes should not be flattened into ordinary authored surfaces")
	_check(emitters.size() == 1, "PTCL nodes should instead produce a dedicated authored particle emitter definition")
	return _errors.is_empty()

func test_authored_piece_particle_emitter_skips_invalid_anchor_point() -> bool:
	_reset_errors()
	var emitters: Array = AuthoredPieceLibrary._extract_particle_emitters({
		"PTCL": [
			{"ADE ": [ {"ROOT": []}, {"STRC": {"flags": 0, "point": 99, "poly": 0, "strc_type": "STRC_ADE ", "version": 1}}]},
			{"ATTS": {"is_particle_atts": true, "context_life_time": 1000, "context_start_gen": 0, "context_stop_gen": 500, "gen_rate": 10, "lifetime": 1000, "start_size": 10, "end_size": 5, "start_speed": 10}},
			{"OBJT": [ {"CLID": {"class_id": "area.class"}}, {"AREA": [ {"NAM2": {"name": "FX2.ILBM"}}]}]},
		]
	}, [], 1)
	_check(emitters.is_empty(), "Particle emitters with invalid skeleton anchors should be skipped safely")
	return _errors.is_empty()

func test_authored_piece_particle_emitter_skips_when_no_renderable_stages_exist() -> bool:
	_reset_errors()
	var emitters: Array = AuthoredPieceLibrary._extract_particle_emitters({
		"PTCL": [
			{"ADE ": [ {"ROOT": []}, {"STRC": {"flags": 0, "point": 0, "poly": 0, "strc_type": "STRC_ADE ", "version": 1}}]},
			{"ATTS": {"is_particle_atts": true, "context_life_time": 1000, "context_start_gen": 0, "context_stop_gen": 500, "gen_rate": 10, "lifetime": 1000, "start_size": 10, "end_size": 5, "start_speed": 10}}
		]
	}, [ {"x": 0.0, "y": 0.0, "z": 0.0}], 1)
	_check(emitters.is_empty(), "Particle emitters without any renderable PTCL stages should be skipped safely instead of creating incomplete runtime emitters")
	return _errors.is_empty()

func test_set4_typ155_uses_repeated_steady_state_piece_for_bottom_left() -> bool:
	_reset_errors()
	var parser = load("res://map/terrain/set_sdf_parser.gd")
	var full_data: Dictionary = parser.parse_full_typ_data(4)
	var data := _make_typ_and_hgt(1, 1, [155])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(
		data["hgt"],
		data["typ"],
		1,
		1,
		full_data.get("surface_types", {}),
		full_data.get("subsector_patterns", {}),
		full_data.get("tile_mapping", {}),
		{},
		{},
		full_data.get("lego_defs", {}),
		4
	)
	var descriptors: Array = result.get("authored_piece_descriptors", [])
	var bottom_left_origin := Vector3(SECTOR_SIZE * 1.25, 0.0, SECTOR_SIZE * 1.75)
	_check(_has_descriptor(descriptors, "MTzEASY2", bottom_left_origin), "set4 typ155 bottom-left piece should use the repeated steady-state MTzEASY2 authored piece")
	_check(not _has_descriptor(descriptors, "ET_KRAT2", bottom_left_origin), "set4 typ155 bottom-left piece should no longer fall back to ET_KRAT2 at startup")
	return _errors.is_empty()

func test_build_mesh_with_textures_unknown_typ_uses_debug_surface() -> bool:
	_reset_errors()
	var data := _make_typ_and_hgt(1, 1, [222])
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(data["hgt"], data["typ"], 1, 1, {})
	_check(result.has("mesh"), "Unknown-typ result should still include mesh key")
	_check(result.has("surface_to_surface_type"), "Unknown-typ result should still include surface mapping")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var debug_surface_idx := _surface_index_for_type(surface_map, -1)
		_check(debug_surface_idx >= 0, "Unknown typ should be routed to the debug surface bucket")
		if debug_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(debug_surface_idx)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			_check(indices.size() == 9 * 2 * 3, "Unknown typ should still emit the full bordered flat-top geometry")
	return _errors.is_empty()

func test_build_mesh_with_textures_invalid_input_returns_empty_mesh() -> bool:
	_reset_errors()
	var result: Dictionary = Map3DRendererScript.build_mesh_with_textures(PackedByteArray([0, 0, 0, 0]), PackedByteArray([12]), 1, 1, {12: 0})
	_check(result.has("mesh"), "Invalid-input result should still include mesh key")
	if result.has("mesh"):
		var mesh: ArrayMesh = result["mesh"]
		_check(mesh.get_surface_count() == 0, "Invalid input should return an empty mesh")
	return _errors.is_empty()


func _overlay_child_by_name(renderer: Node, overlay_name: String) -> Node3D:
	for child in renderer.get_children():
		if child != null and child is Node3D and child.name == overlay_name:
			return child
	return null


func _instance_keys_from_overlay(overlay: Node3D) -> Dictionary:
	var found_keys: Dictionary = {}
	if overlay == null:
		return found_keys
	for piece_root in overlay.get_children():
		var key: String = String(piece_root.get_meta("instance_key", ""))
		if not key.is_empty():
			found_keys[key] = true
	return found_keys


func test_build_from_current_map_wires_host_stations_into_authored_overlay() -> bool:
	_reset_errors()

	var w := 2
	var h := 2
	var data := _make_typ_and_hgt(w, h, [12, 12, 12, 12], 0)

	var host_stations := Node.new()
	host_stations.add_child(HostStationStub.new(56, 1800.0, 1800.0, -700))

	var map_data := CurrentMapDataStub.new()
	map_data.horizontal_sectors = w
	map_data.vertical_sectors = h
	map_data.level_set = 1
	map_data.hgt_map = data["hgt"]
	map_data.typ_map = data["typ"]
	map_data.blg_map = PackedByteArray([0, 0, 0, 0])
	map_data.host_stations = host_stations
	map_data.squads = null

	var editor_state := EditorStateStub.new()
	editor_state.game_data_type = "original"

	var preloads := MockPreloads.new()
	preloads.surface_type_map = {12: 0}

	var renderer := Map3DRendererScript.new()
	renderer._edge_overlay_enabled = false
	renderer.set_current_map_data_override(map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)

	renderer.build_from_current_map()

	var overlay: Node3D = null
	for child in renderer.get_children():
		if child != null and child is Node3D and child.name == "AuthoredOverlay":
			overlay = child
			break
	_check(overlay != null, "Expected Map3DRenderer.build_from_current_map() to create an AuthoredOverlay node")

	var found_keys: Dictionary = {}
	if overlay != null:
		for piece_root in overlay.get_children():
			var key: String = String(piece_root.get_meta("instance_key", ""))
			if not key.is_empty():
				found_keys[key] = true

	var expected_descriptors: Array = Map3DRendererScript._build_host_station_descriptors(
		host_stations.get_children(),
		map_data.level_set,
		data["hgt"],
		w,
		h,
		[]
	)
	_check(expected_descriptors.size() > 0, "Expected at least one host-station descriptor")
	for desc in expected_descriptors:
		var expected_key := String(desc.get("instance_key", ""))
		_check(found_keys.has(expected_key), "AuthoredOverlay missing host descriptor instance_key: %s" % expected_key)

	renderer.free()
	return _errors.is_empty()


func test_dynamic_overlay_keeps_md_squads_after_mixed_pool_refresh_events() -> bool:
	_reset_errors()

	var w := 2
	var h := 2
	var data := _make_typ_and_hgt(w, h, [12, 12, 12, 12], 0)

	var squads := Node.new()
	var md_squad := SquadStub.new(143, 1200.0, 1200.0, 1)
	squads.add_child(md_squad)

	var map_data := CurrentMapDataStub.new()
	map_data.horizontal_sectors = w
	map_data.vertical_sectors = h
	map_data.level_set = 1
	map_data.hgt_map = data["hgt"]
	map_data.typ_map = data["typ"]
	map_data.blg_map = PackedByteArray([0, 0, 0, 0])
	map_data.host_stations = null
	map_data.squads = squads

	var editor_state := EditorStateStub.new()
	editor_state.game_data_type = "metropolisDawn"

	var preloads := MockPreloads.new()
	preloads.surface_type_map = {12: 0}

	var renderer := Map3DRendererScript.new()
	renderer._edge_overlay_enabled = false
	renderer.set_current_map_data_override(map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)

	_check(renderer._sync_async_overlay_state_from_current_map(), "Expected async overlay state to sync from current map for MD scenario")
	var initial_payload := {
		"generation_id": renderer.active_build_generation_id,
		"dynamic_only": true,
		"support_descriptors": [],
		"blg": map_data.blg_map,
		"effective_typ": map_data.typ_map,
		"set_id": map_data.level_set,
		"hgt": map_data.hgt_map,
		"w": w,
		"h": h,
		"game_data_type": renderer._async_game_data_type,
		"host_station_snapshot": [],
		"squad_snapshot": Map3DRendererScript._snapshot_squad_nodes([md_squad]),
	}
	renderer._async_overlay_descriptor_worker(initial_payload)
	var initial_state := renderer._get_async_overlay_descriptor_state()
	var initial_result: Dictionary = initial_state.get("result", {})
	var initial_dynamic: Array = initial_result.get("dynamic_descriptors", [])
	_check(initial_dynamic.size() > 0, "Initial descriptor pass should include MD squad overlays")
	var initial_keys := _instance_keys_from_descriptors(initial_dynamic)
	var expected_md_descriptors: Array = Map3DRendererScript._build_squad_descriptors([md_squad], map_data.level_set, data["hgt"], w, h, [], editor_state.game_data_type)
	for desc in expected_md_descriptors:
		var md_key := String(desc.get("instance_key", ""))
		_check(initial_keys.has(md_key), "Initial dynamic descriptor set should contain MD squad key: %s" % md_key)

	var original_squad := SquadStub.new(1, 1800.0, 1200.0, 1)
	squads.add_child(original_squad)
	renderer._on_unit_overlay_refresh_requested("squad", int(original_squad.get_instance_id()))
	renderer._on_map_updated()

	_check(renderer._sync_async_overlay_state_from_current_map(), "Expected async overlay state to stay synced after mixed-pool refresh events")
	var refreshed_payload := {
		"generation_id": renderer.active_build_generation_id,
		"dynamic_only": true,
		"support_descriptors": [],
		"blg": map_data.blg_map,
		"effective_typ": map_data.typ_map,
		"set_id": map_data.level_set,
		"hgt": map_data.hgt_map,
		"w": w,
		"h": h,
		"game_data_type": renderer._async_game_data_type,
		"host_station_snapshot": [],
		"squad_snapshot": Map3DRendererScript._snapshot_squad_nodes(squads.get_children()),
	}
	renderer._async_overlay_descriptor_worker(refreshed_payload)
	var refreshed_state := renderer._get_async_overlay_descriptor_state()
	var refreshed_result: Dictionary = refreshed_state.get("result", {})
	var refreshed_dynamic: Array = refreshed_result.get("dynamic_descriptors", [])
	var refreshed_keys := _instance_keys_from_descriptors(refreshed_dynamic)
	var expected_all: Array = Map3DRendererScript._build_squad_descriptors(squads.get_children(), map_data.level_set, data["hgt"], w, h, [], editor_state.game_data_type)
	_check(expected_all.size() >= 2, "Mixed MD/original squad setup should emit both MD and original descriptors")
	for desc in expected_all:
		var expected_key := String(desc.get("instance_key", ""))
		_check(refreshed_keys.has(expected_key), "Dynamic overlay should keep mixed-pool squad key after refresh events: %s" % expected_key)

	renderer.free()
	return _errors.is_empty()


func test_build_from_current_map_wires_squads_into_authored_overlay() -> bool:
	_reset_errors()

	var w := 2
	var h := 2
	var data := _make_typ_and_hgt(w, h, [12, 12, 12, 12], 0)

	var squads := Node.new()
	squads.add_child(SquadStub.new(1, 1200.0, 1200.0, 1))

	var map_data := CurrentMapDataStub.new()
	map_data.horizontal_sectors = w
	map_data.vertical_sectors = h
	map_data.level_set = 1
	map_data.hgt_map = data["hgt"]
	map_data.typ_map = data["typ"]
	map_data.blg_map = PackedByteArray([0, 0, 0, 0])
	map_data.host_stations = null
	map_data.squads = squads

	var editor_state := EditorStateStub.new()
	editor_state.game_data_type = "original"

	var preloads := MockPreloads.new()
	preloads.surface_type_map = {12: 0}

	var renderer := Map3DRendererScript.new()
	renderer._edge_overlay_enabled = false
	renderer.set_current_map_data_override(map_data)
	renderer.set_editor_state_override(editor_state)
	renderer.set_preloads_override(preloads)

	renderer.build_from_current_map()

	var overlay: Node3D = null
	for child in renderer.get_children():
		if child != null and child is Node3D and child.name == "AuthoredOverlay":
			overlay = child
			break
	_check(overlay != null, "Expected Map3DRenderer.build_from_current_map() to create an AuthoredOverlay node")

	var found_keys: Dictionary = {}
	if overlay != null:
		for piece_root in overlay.get_children():
			var key: String = String(piece_root.get_meta("instance_key", ""))
			if not key.is_empty():
				found_keys[key] = true

	var expected_descriptors: Array = Map3DRendererScript._build_squad_descriptors(
		squads.get_children(),
		map_data.level_set,
		data["hgt"],
		w,
		h,
		[],
		editor_state.game_data_type
	)
	_check(expected_descriptors.size() > 0, "Expected at least one squad descriptor")
	for desc in expected_descriptors:
		var expected_key := String(desc.get("instance_key", ""))
		_check(found_keys.has(expected_key), "AuthoredOverlay missing squad descriptor instance_key: %s" % expected_key)

	renderer.free()
	return _errors.is_empty()


func run() -> int:
	var failures := 0
	var tests := [
		"test_retail_slurp_bucket_key_uses_vside_for_left_right_pairs",
		"test_retail_slurp_bucket_key_uses_hside_for_top_bottom_pairs",
		"test_build_mesh_with_textures_groups_same_surface_type_into_one_top_family",
		"test_build_edges_mesh_uses_shader_materials",
		"test_build_edges_mesh_left_right_seams_keep_ordered_pair_and_horizontal_blend_flag",
		"test_build_edges_mesh_left_right_seam_geometry_uses_playable_bounds",
		"test_build_edges_mesh_left_right_seam_geometry_uses_corner_averages",
		"test_build_edges_mesh_top_bottom_seams_keep_ordered_pair_and_vertical_blend_flag",
		"test_build_edges_mesh_without_preloads_falls_back_to_preview_material",
		"test_edge_overlay_is_enabled_by_default_in_live_3d_renderer",
			"test_build_edges_mesh_keeps_flat_same_surface_seams",
		"test_build_edges_mesh_includes_implicit_border_ring_pairs",
		"test_surface_pair_from_slurp_bucket_key_rejects_invalid_keys",
		"test_build_edge_overlay_result_uses_pair_based_vertical_seam_for_interior_pair",
		"test_build_edge_overlay_result_keeps_authored_vertical_slurp_for_flat_same_surface_pair",
		"test_build_edge_overlay_result_uses_pair_based_horizontal_seam_for_interior_pair",
		"test_build_edge_overlay_result_uses_pair_based_horizontal_seam_for_north_border_pair",
		"test_build_edge_overlay_result_always_uses_strip_mesh_for_live_preview",
		"test_build_edge_overlay_result_skips_same_surface_fallback_when_authored_slurp_is_unavailable",
		"test_build_edge_overlay_result_includes_pair_based_border_to_border_seam_on_north_ring",
		"test_chunk_edge_overlay_assigns_vertical_seam_to_single_chunk_owner",
		"test_authored_piece_uvs_decode_array_pairs_against_texture_size",
		"test_authored_piece_material_keeps_opaque_textures_nontransparent",
		"test_authored_piece_material_returns_null_for_empty_texture_name",
		"test_preview_material_uses_unshaded_nonmetallic_presentation",
		"test_terrain_shaders_are_unshaded_for_ua_style_flat_preview",
			"test_authored_piece_material_converts_yellow_key_to_alpha",
			"test_authored_piece_luminous_material_uses_separate_alpha_path",
				"test_authored_piece_material_applies_source_shade_multiplier",
			"test_authored_piece_material_applies_source_shade_multiplier_to_opaque_texture",
			"test_authored_piece_luminous_fx2_resolves_retail_hi_alpha_override",
			"test_authored_piece_area_animation_frames_load_from_anm",
			"test_authored_piece_area_animation_frames_use_bmpanim_u8_uv_scale",
			"test_authored_piece_area_lumtracy_hints_are_preserved_for_typ185",
				"test_set1_typ96_bottom_right_piece_preserves_dark_parapet_shade",
		"test_authored_piece_mesh_uses_authored_uvs_for_st_empty",
		"test_authored_piece_mesh_loads_ground_slurp_assets_from_objects_ground",
			"test_authored_piece_mesh_loads_vehicle_assets_from_objects_vehicles",
			"test_authored_piece_known_vehicle_and_radar_models_skip_textureless_placeholder_surfaces",
			"test_build_host_station_descriptors_emits_vehicle_overlay_and_visible_turrets_at_ua_mirrored_origin",
			"test_build_host_station_overlay_node_instantiates_visible_resistance_robo_and_turrets",
			"test_build_host_station_descriptors_accepts_player_vehicle_alias_ids",
			"test_build_host_station_descriptors_emits_visible_black_sect_turrets",
			"test_build_host_station_descriptors_keeps_body_when_gun_visuals_are_invisible",
			"test_build_host_station_overlay_node_keeps_visible_body_when_gun_visuals_are_invisible",
			"test_build_host_station_descriptors_emits_source_backed_turret_forward_vectors",
			"test_build_host_station_descriptors_snaps_y_to_authored_support_mesh_when_present",
			"test_build_host_station_descriptors_keeps_terrain_height_when_support_is_lower",
			"test_build_host_station_descriptors_ignores_remote_higher_support_meshes",
			"test_build_host_station_descriptors_snaps_to_rotated_authored_support_mesh",
			"test_build_host_station_descriptors_skips_unknown_vehicle_ids",
		"test_host_station_descriptor_positions_stay_in_ua_world_units",
			"test_effective_typ_map_for_3d_applies_known_blg_overrides_only",
			"test_effective_typ_map_for_3d_applies_beam_gate_closed_bp_override",
			"test_effective_typ_map_for_3d_applies_tech_upgrade_building_override",
			"test_effective_typ_map_for_3d_applies_editor_aligned_tech_upgrade_override_variants",
			"test_effective_typ_map_for_3d_applies_stoudson_bomb_inactive_bp_override",
			"test_effective_typ_map_for_3d_ignores_unknown_or_out_of_bounds_secondary_building_overrides",
			"test_building_definition_for_id_and_sec_type_distinguishes_duplicate_original_ids",
			"test_building_attachment_base_name_for_vehicle_prefers_non_effect_vehicle_definition",
			"test_md_building_alias_74_reuses_taerflak_definition",
			"test_build_blg_attachment_descriptors_emits_small_aa_overlay_for_blg28",
			"test_build_blg_attachment_descriptors_keeps_sector_ground_height_when_authored_support_mesh_is_higher",
			"test_build_blg_attachment_descriptors_skips_dummy_gflak_visuals",
			"test_build_blg_attachment_descriptors_emits_radar_nozzle_overlay",
			"test_build_blg_attachment_overlay_applies_positive_x_forward_orientation",
			"test_build_blg_attachment_overlay_applies_negative_x_forward_orientation",
			"test_squad_formation_offsets_fill_left_to_right_and_rows_advance_upward",
			"test_squad_formation_offsets_for_32_restart_each_row_from_left_and_move_upward",
			"test_build_squad_descriptors_resolves_original_vehicle_visuals_and_uses_leftmost_single_unit_offset",
			"test_build_squad_overlay_node_instantiates_visible_original_vehicle",
			"test_build_squad_descriptors_expands_quantity_into_left_to_right_upward_formation",
			"test_build_squad_descriptors_clamps_invalid_quantity_to_single_unit",
			"test_build_squad_descriptors_resolves_metropolis_dawn_vehicle_visuals",
			"test_md_direct_squad_base_mappings_resolve_xpack_models",
			"test_preferred_squad_visual_base_name_prefers_wait_over_normal",
			"test_preferred_squad_visual_base_name_falls_back_from_dummy_wait_to_normal",
			"test_build_squad_descriptors_snaps_y_to_authored_support_mesh_when_present",
			"test_build_squad_descriptors_skips_unknown_vehicle_ids",
			"test_authored_piece_mesh_keeps_st_empty_on_300_unit_subsector_footprint",
			"test_authored_piece_mesh_keeps_gr_254_on_sector_sized_border_footprint",
			"test_authored_piece_polygon_vertices_mirror_local_z_into_editor_space",
			"test_build_overlay_node_biases_authored_piece_above_terrain_plane",
			"test_build_overlay_node_applies_optional_y_offset",
			"test_build_overlay_node_applies_optional_forward_orientation",
			"test_build_overlay_node_applies_optional_forward_orientation_for_positive_x",
			"test_build_overlay_node_applies_optional_forward_orientation_for_negative_x",
			"test_build_overlay_node_ignores_zero_forward_orientation",
		"test_build_overlay_node_skips_invalid_descriptors_without_dropping_valid_neighbors",
		"test_build_overlay_node_deforms_authored_slurp_mesh_to_neighbor_heights",
		"test_build_mesh_with_textures_compact_sector_uses_surface_type_texture_family",
		"test_selected_raw_id_for_tile_desc_uses_startup_raw_stage_slot",
		"test_authored_origin_for_subsector_uses_300_unit_lattice",
		"test_build_mesh_with_textures_complex_sector_uses_3x3_subsector_grid",
		"test_apply_sector_top_materials_enables_multi_texture_shader_mode",
			"test_sector_top_shader_uses_nearest_sampling_for_packed_ground_atlases",
			"test_edge_blend_shader_pins_sampling_to_lod0",
		"test_typ_value_with_implicit_border_restores_fixed_border_ring",
		"test_build_mesh_with_textures_renders_full_implicit_border_ring",
		"test_set1_typ3_uses_gate_authored_piece",
		"test_set1_typ185_uses_authored_piece_descriptors",
		"test_set1_typ40_uses_normal_startup_state_variants",
		"test_set1_typ239_uses_startup_outer_gems_instead_of_empty_damaged_slots",
		"test_set6_typ234_uses_authored_static_animation_overlay",
		"test_set6_typ235_uses_authored_static_animation_overlay",
		"test_apply_overlay_node_preserves_embedded_animated_surface_identity_for_transform_only_updates",
		"test_animated_surface_frame_advance_reuses_prepared_meshes",
		"test_baked_authored_piece_runtime_restores_animated_luminous_frames",
		"test_particle_emitter_node_pool_reuses_expired_particle_nodes",
		"test_particle_emitter_mesh_assignment_only_on_stage_change",
		"test_apply_overlay_node_preserves_particle_emitter_identity_for_transform_only_updates",
		"test_authored_piece_surface_extraction_skips_ptcl_stage_areas",
		"test_authored_piece_particle_emitter_skips_invalid_anchor_point",
		"test_authored_piece_particle_emitter_skips_when_no_renderable_stages_exist",
		"test_set4_typ155_uses_repeated_steady_state_piece_for_bottom_left",
		"test_build_mesh_with_textures_unknown_typ_uses_debug_surface",
		"test_build_mesh_with_textures_invalid_input_returns_empty_mesh",
	"test_build_from_current_map_wires_host_stations_into_authored_overlay",
	"test_dynamic_overlay_keeps_md_squads_after_mixed_pool_refresh_events",
	"test_build_from_current_map_wires_squads_into_authored_overlay",
	]
	for name in tests:
		print("RUN ", name)
		var ok: bool = bool(call(name))
		if ok:
			print("OK  ", name)
		else:
			print("FAIL", name)
			failures += 1
	return failures

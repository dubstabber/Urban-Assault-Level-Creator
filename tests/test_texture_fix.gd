extends RefCounted

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const TerrainBuilder := preload("res://map/3d/terrain/map_3d_terrain_builder.gd")
const SetSdfParserScript = preload("res://map/terrain/set_sdf_parser.gd")

var _errors: Array[String] = []

func _reset_errors() -> void:
	_errors.clear()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

static func _surface_index_for_type(surface_map: Dictionary, surface_type: int) -> int:
	for surface_idx in surface_map.keys():
		if int(surface_map[surface_idx]) == surface_type:
			return int(surface_idx)
	return -1

func test_surface_type_selection_does_not_depend_on_removed_tile_metadata() -> bool:
	_reset_errors()
	var w := 1
	var h := 1
	var hgt := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var typ := PackedByteArray([12])
	# The active preview path intentionally ignores the removed tile/subsector metadata flow.
	# It should derive the textured top family only from typ -> surface_type.
	var result: Dictionary = TerrainBuilder.build_mesh_with_textures(
		hgt,
		typ,
		w,
		h,
		{12: 3}
	)
	_check(result.has("mesh"), "Textured builder should return mesh data")
	_check(result.has("surface_to_surface_type"), "Textured builder should return the mapping key")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, 3)
		_check(textured_surface_idx >= 0, "Expected textured surface for surface_type 3")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			_check(indices.size() == 2 * 3, "Surface-type fallback preview should keep the corrected single-sector top layout")
			_check(colors.size() > 0, "Surface-type preview should still include vertex colors")
			if colors.size() > 0:
				var first := colors[0]
				var file_idx := int(floor(clampf(first.g, 0.0, 0.9999) * 6.0))
				var variant_idx := int(floor(clampf(first.r, 0.0, 0.9999) * 1.0))
				_check(file_idx == 3, "Tile metadata should not override the surface_type-selected texture family")
				_check(variant_idx == 0, "Surface-type preview should use the base variant")
	return _errors.is_empty()

func test_set1_typ0_surface_type_drives_top_texture_family() -> bool:
	_reset_errors()
	var full_data: Dictionary = SetSdfParserScript.parse_full_typ_data(1)
	var mapping: Dictionary = full_data.get("surface_types", {})
	_check(mapping.has(0), "Expected set1 typ 0 to exist in surface type mapping")
	if not mapping.has(0):
		return _errors.is_empty()
	var expected_surface_type := int(mapping[0])

	var hgt := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0])
	var typ := PackedByteArray([0])
	var result: Dictionary = TerrainBuilder.build_mesh_with_textures(
		hgt,
		typ,
		1,
		1,
		mapping
	)
	_check(result.has("mesh"), "Expected textured build result for set1 typ 0")
	_check(result.has("surface_to_surface_type"), "Expected surface mapping for set1 typ 0")
	if result.has("mesh") and result.has("surface_to_surface_type"):
		var mesh: ArrayMesh = result["mesh"]
		var surface_map: Dictionary = result["surface_to_surface_type"]
		var textured_surface_idx := _surface_index_for_type(surface_map, expected_surface_type)
		_check(textured_surface_idx >= 0, "Expected a terrain surface for set1 typ 0 surface type")
		if textured_surface_idx >= 0:
			var arrays := mesh.surface_get_arrays(textured_surface_idx)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			_check(colors.size() > 0, "Expected vertex colors for set1 typ 0 textured mesh")
			if colors.size() > 0:
				var first := colors[0]
				var file_idx := int(floor(clampf(first.g, 0.0, 0.9999) * 6.0))
				var variant_idx := int(floor(clampf(first.r, 0.0, 0.9999) * 1.0))
				_check(file_idx == expected_surface_type, "Mesh vertex colors should encode the surface_type-selected ground texture for set1 typ 0")
				_check(variant_idx == 0, "Mesh vertex colors should use the base variant for the preview path")
	return _errors.is_empty()

func test_plain_geometry_builder_preserves_basic_geometry_output() -> bool:
	_reset_errors()
	var hgt := PackedByteArray([
		0, 0, 0, 0,
		0, 5, 10, 0,
		0, 15, 20, 0,
		0, 0, 0, 0,
	])
	var mesh: ArrayMesh = TerrainBuilder.build_mesh(hgt, 2, 2)
	_check(mesh.get_surface_count() == 1, "Plain geometry builder should still return one terrain surface")
	if mesh.get_surface_count() > 0:
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		_check(vertices.size() > 0, "Plain geometry builder should still emit vertices")
		var has_elevated_vertex := false
		for vertex in vertices:
			if vertex.y > 0.0:
				has_elevated_vertex = true
				break
		_check(has_elevated_vertex, "Plain geometry builder should preserve non-flat height information")
	return _errors.is_empty()

func run() -> int:
	var failures := 0
	var tests := [
		"test_surface_type_selection_does_not_depend_on_removed_tile_metadata",
		"test_set1_typ0_surface_type_drives_top_texture_family",
		"test_plain_geometry_builder_preserves_basic_geometry_output",
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

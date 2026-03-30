extends RefCounted
class_name UAAuthoredMaterialFactory

const SourceResolver = preload("res://map/terrain/ua_authored_piece_source_resolver.gd")
const ILBM_MASK_HAS_MASK := 1
const ILBM_MASK_TRANSPARENT_COLOR := 2

static var _material_cache := {}
static var _texture_cache := {}

static func clear_runtime_caches() -> void:
	_material_cache.clear()
	_texture_cache.clear()

static func clear_runtime_caches_for_tests() -> void:
	clear_runtime_caches()

static func has_material_cache(cache_key: String) -> bool:
	return _material_cache.has(cache_key)

static func get_cached_material(cache_key: String):
	return _material_cache.get(cache_key, null)

static func store_material(cache_key: String, material: Material) -> Material:
	_material_cache[cache_key] = material
	return material

static func has_texture_cache(cache_key: String) -> bool:
	return _texture_cache.has(cache_key)

static func get_cached_texture(cache_key: String):
	return _texture_cache.get(cache_key, null)

static func store_texture(cache_key: String, texture):
	_texture_cache[cache_key] = texture
	return _texture_cache[cache_key]

static func normalized_render_hints(render_hints: Dictionary) -> Dictionary:
	var mode := String(render_hints.get("transparency_mode", "auto"))
	if mode != "cutout" and mode != "lumtracy":
		mode = "auto"
	return {
		"transparency_mode": mode,
		"tracy_val": clampi(int(render_hints.get("tracy_val", 0)), 0, 255),
		"shade_value": clampi(int(render_hints.get("shade_value", 0)), 0, 255),
	}

static func render_cache_key(set_id: int, texture_file: String, render_hints: Dictionary, game_data_type: String) -> String:
	return "%d:%s:%s:%d:%d:%s" % [
		set_id,
		texture_file.to_lower(),
		String(render_hints.get("transparency_mode", "auto")),
		int(render_hints.get("tracy_val", 0)),
		int(render_hints.get("shade_value", 0)),
		game_data_type.to_lower(),
	]

static func texture_cache_key(set_id: int, texture_file: String, render_hints: Dictionary, game_data_type: String) -> String:
	return "%d:%s:%s:%s" % [
		set_id,
		texture_file.to_lower(),
		String(render_hints.get("transparency_mode", "auto")),
		game_data_type.to_lower(),
	]

static func surface_group_key(texture_name: String, render_hints: Dictionary) -> String:
	var hints := normalized_render_hints(render_hints)
	return "%s:%s:%d:%d" % [
		texture_name.to_lower(),
		String(hints.get("transparency_mode", "auto")),
		int(hints.get("tracy_val", 0)),
		int(hints.get("shade_value", 0)),
	]

static func shade_multiplier_from_value(shade_value: int) -> float:
	return clampf(1.0 - float(clampi(shade_value, 0, 255)) / 256.0, 0.0, 1.0)

static func raw_image_for_texture(set_id: int, texture_name: String, render_hints: Dictionary, game_data_type: String, external_source_root: String) -> Image:
	var raw_path := raw_texture_override_path(set_id, texture_name, render_hints, game_data_type, external_source_root)
	if raw_path.is_empty():
		return null
	return load_ilbm_image(raw_path)

static func raw_texture_override_path(set_id: int, texture_name: String, render_hints: Dictionary, game_data_type: String, external_source_root: String) -> String:
	if String(render_hints.get("transparency_mode", "auto")) != "lumtracy":
		return ""
	var base := texture_name.strip_edges().get_file().get_basename().to_lower()
	if base != "fx1" and base != "fx2" and base != "fx3":
		return ""
	return SourceResolver.find_file(SourceResolver.hi_alpha_dir(set_id, game_data_type, external_source_root), "%s.ilb" % base)

static func load_ilbm_image(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 12:
		return null
	if ascii_from_bytes(data, 0, 4) != "FORM":
		return null
	var form_type := ascii_from_bytes(data, 8, 4)
	if form_type != "ILBM" and form_type != "PBM ":
		return null
	var width := 0
	var height := 0
	var nplanes := 0
	var masking := 0
	var compression := 0
	var transparent_color := -1
	var palette: Array = []
	palette.resize(256)
	for i in palette.size():
		palette[i] = Color(0.0, 0.0, 0.0, 1.0)
	var body := PackedByteArray()
	var pos := 12
	while pos + 8 <= data.size():
		var tag := ascii_from_bytes(data, pos, 4)
		var chunk_size := read_u32_be(data, pos + 4)
		var chunk_start := pos + 8
		var chunk_end := chunk_start + chunk_size
		if chunk_end > data.size():
			break
		if tag == "BMHD" and chunk_size >= 20:
			width = read_u16_be(data, chunk_start)
			height = read_u16_be(data, chunk_start + 2)
			nplanes = int(data[chunk_start + 8])
			masking = int(data[chunk_start + 9])
			compression = int(data[chunk_start + 10])
			transparent_color = read_u16_be(data, chunk_start + 12)
		elif tag == "CMAP":
			var color_count := mini(int(float(chunk_size) / 3.0), 256)
			for i in color_count:
				var color_offset := chunk_start + i * 3
				palette[i] = Color(
					float(data[color_offset]) / 255.0,
					float(data[color_offset + 1]) / 255.0,
					float(data[color_offset + 2]) / 255.0,
					1.0
				)
		elif tag == "BODY":
			body.resize(chunk_size)
			for i in chunk_size:
				body[i] = data[chunk_start + i]
		pos = chunk_end + (chunk_size & 1)
	if width <= 0 or height <= 0 or nplanes <= 0 or body.is_empty():
		return null
	if compression == 1:
		body = byte_run1_decode(body)
	var plane_row_bytes := int(ceili(float(width) / 8.0))
	if (plane_row_bytes & 1) != 0:
		plane_row_bytes += 1
	var total_planes := nplanes + (1 if masking == ILBM_MASK_HAS_MASK else 0)
	var row_bytes := plane_row_bytes * total_planes
	if row_bytes <= 0 or body.size() < row_bytes * height:
		return null
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var row_offset := y * row_bytes
		var mask_offset := row_offset + plane_row_bytes * nplanes
		for x in width:
			var byte_index := int(x) >> 3
			var bit_mask := 1 << (7 - (x & 7))
			var color_index := 0
			for plane in nplanes:
				var plane_byte_offset := row_offset + plane * plane_row_bytes + byte_index
				if (int(body[plane_byte_offset]) & bit_mask) != 0:
					color_index |= 1 << plane
			var color: Color = palette[color_index] if color_index < palette.size() else Color(0.0, 0.0, 0.0, 1.0)
			if masking == ILBM_MASK_HAS_MASK:
				var mask_byte := int(body[mask_offset + byte_index])
				if (mask_byte & bit_mask) == 0:
					color = Color(0.0, 0.0, 0.0, 0.0)
			elif masking == ILBM_MASK_TRANSPARENT_COLOR and color_index == transparent_color:
				color = Color(0.0, 0.0, 0.0, 0.0)
			image.set_pixel(x, y, color)
	return image

static func byte_run1_decode(src: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	var i := 0
	while i < src.size():
		var control := int(src[i])
		if control > 127:
			control -= 256
		i += 1
		if control >= 0:
			var literal_count := control + 1
			for j in literal_count:
				if i + j >= src.size():
					break
				out.append(src[i + j])
			i += literal_count
		elif control >= -127:
			if i >= src.size():
				break
			var repeat_count := 1 - control
			var repeated := src[i]
			for _j in repeat_count:
				out.append(repeated)
			i += 1
	return out

static func ascii_from_bytes(data: PackedByteArray, start: int, size: int) -> String:
	var chars := PackedByteArray()
	chars.resize(size)
	for i in size:
		chars[i] = data[start + i]
	return chars.get_string_from_ascii()

static func read_u16_be(data: PackedByteArray, offset: int) -> int:
	return (int(data[offset]) << 8) | int(data[offset + 1])

static func read_u32_be(data: PackedByteArray, offset: int) -> int:
	return (
		(int(data[offset]) << 24)
		| (int(data[offset + 1]) << 16)
		| (int(data[offset + 2]) << 8)
		| int(data[offset + 3])
	)

static func apply_color_key_transparency(image: Image) -> Image:
	var converted := image.duplicate()
	if converted.get_format() != Image.FORMAT_RGBA8:
		converted.convert(Image.FORMAT_RGBA8)
	for y in converted.get_height():
		for x in converted.get_width():
			var px: Color = converted.get_pixel(x, y)
			if is_equal_approx(px.r, 1.0) and is_equal_approx(px.g, 1.0) and is_equal_approx(px.b, 0.0):
				converted.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return converted

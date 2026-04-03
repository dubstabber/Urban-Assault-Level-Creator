extends RefCounted
class_name UALegacyText

## Reads plain-text UA-era files without Godot UTF-8 parse errors. Retail assets are often
## Windows-1252 / ISO-8859-1; Godot's FileAccess text APIs assume UTF-8 and log on invalid bytes.

static func read_file(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var bytes := f.get_buffer(f.get_length())
	return decode_text_bytes(bytes)


## Reads at most the first `max_bytes` from disk. Use for user-selected files where the full file
## may be huge binary (avoids loading gigabytes into RAM before reject).
## When `utf8_text_only` is true (e.g. JSON), invalid UTF-8 returns "" immediately — avoids the
## slow Latin-1 path that string-concatenates every byte (painful on ~1MB random/binary data).
static func read_file_up_to(path: String, max_bytes: int, utf8_text_only: bool = false) -> String:
	if path.is_empty() or not FileAccess.file_exists(path) or max_bytes <= 0:
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var len_i := int(f.get_length())
	var n: int = mini(len_i, max_bytes)
	var bytes := f.get_buffer(n)
	if utf8_text_only:
		return decode_utf8_text_only(bytes)
	return decode_text_bytes(bytes)


## Same as `read_file_up_to(path, max_bytes, true)` — JSON/config snippets only (strict UTF-8, fast reject on binary).
static func read_utf8_text_file_up_to(path: String, max_bytes: int) -> String:
	return read_file_up_to(path, max_bytes, true)


## Reads one line using at most `max_line_bytes` of payload (excluding the newline). If the line
## would be longer, returns `{ "ok": false }` so callers can reject binary or corrupt files without
## reading until EOF in a single `get_line()` call.
static func read_line_bounded(file: FileAccess, max_line_bytes: int) -> Dictionary:
	if file == null or max_line_bytes <= 0:
		return {"ok": false, "line": ""}
	var ba := PackedByteArray()
	while file.get_position() < file.get_length():
		if ba.size() >= max_line_bytes:
			return {"ok": false, "line": ""}
		var b: int = file.get_8()
		if b == 10:
			break
		if b == 13:
			if file.get_position() < file.get_length():
				var next_pos := file.get_position()
				var b2: int = file.get_8()
				if b2 != 10:
					file.seek(next_pos)
			break
		ba.append(b)
	var line := _decode_line_bytes_for_scan(ba)
	return {"ok": true, "line": line}


static func is_probably_binary_data(data: PackedByteArray) -> bool:
	if _has_known_binary_signature(data):
		return true
	return _is_probably_binary(data)


## PNG / JPEG / … — instant reject for map open and text heuristics (NUL ratio misses these).
static func _has_known_binary_signature(data: PackedByteArray) -> bool:
	var n := data.size()
	if n < 4:
		return false
	var b0 := int(data[0])
	var b1 := int(data[1])
	var b2 := int(data[2])
	var b3 := int(data[3])
	# PNG
	if b0 == 0x89 and b1 == 0x50 and b2 == 0x4E and b3 == 0x47:
		return true
	# JPEG
	if b0 == 0xFF and b1 == 0xD8 and b2 == 0xFF:
		return true
	# GIF "GIF8"
	if b0 == 0x47 and b1 == 0x49 and b2 == 0x46 and b3 == 0x38:
		return true
	# BMP "BM"
	if b0 == 0x42 and b1 == 0x4D:
		return true
	# PDF "%PDF"
	if b0 == 0x25 and b1 == 0x50 and b2 == 0x44 and b3 == 0x46:
		return true
	# ZIP / Office / many packed formats "PK\x03\x04" or "PK\x05\x05"
	if b0 == 0x50 and b1 == 0x4B and (b2 == 0x03 or b2 == 0x05 or b2 == 0x07):
		return true
	# Gzip
	if b0 == 0x1F and b1 == 0x8B:
		return true
	# ELF
	if b0 == 0x7F and b1 == 0x45 and b2 == 0x4C and b3 == 0x46:
		return true
	# WebP: RIFF....WEBP
	if n >= 12 and b0 == 0x52 and b1 == 0x49 and b2 == 0x46 and b3 == 0x46:
		if data[8] == 0x57 and data[9] == 0x45 and data[10] == 0x42 and data[11] == 0x50:
			return true
	return false


static func decode_utf8_text_only(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	if _has_known_binary_signature(data) or _is_probably_binary(data):
		return ""
	if not _is_valid_utf8(data):
		return ""
	var has_bom := data.size() >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF
	var s := data.get_string_from_utf8()
	if has_bom and s.begins_with("\ufeff"):
		s = s.substr(1)
	return s


static func decode_text_bytes(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	if _has_known_binary_signature(data) or _is_probably_binary(data):
		return ""
	# Check for UTF-8 BOM in the raw bytes (EF BB BF) rather than in the
	# decoded string — get_string_from_utf8() can insert a phantom BOM that
	# was never in the source data, causing the first real character to be
	# stripped.
	var has_bom := data.size() >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF
	if _is_valid_utf8(data):
		var s := data.get_string_from_utf8()
		if has_bom and s.begins_with("\ufeff"):
			s = s.substr(1)
		return s
	return _bytes_to_iso8859_1_string(data)


## Bounded line decode for scanners: UTF-8 or small Latin-1 only — never O(n) Latin-1 on large binary chunks.
static func _decode_line_bytes_for_scan(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	if _has_known_binary_signature(data) or _is_probably_binary(data):
		return ""
	var has_bom := data.size() >= 3 and data[0] == 0xEF and data[1] == 0xBB and data[2] == 0xBF
	if _is_valid_utf8(data):
		var s := data.get_string_from_utf8()
		if has_bom and s.begins_with("\ufeff"):
			s = s.substr(1)
		return s
	const max_latin1_without_alloc_churn := 4096
	if data.size() <= max_latin1_without_alloc_churn:
		return _bytes_to_iso8859_1_string(data)
	return ""


static func _is_probably_binary(data: PackedByteArray, max_sample: int = 8192, max_nul_ratio: float = 0.01) -> bool:
	var n: int = mini(data.size(), max_sample)
	if n <= 0:
		return false
	var nul := 0
	for i in n:
		if data[i] == 0:
			nul += 1
	return (float(nul) / float(n)) > max_nul_ratio


static func _bytes_to_iso8859_1_string(data: PackedByteArray) -> String:
	var out := ""
	for i in data.size():
		out += char(data[i])
	return out


static func _is_valid_utf8(data: PackedByteArray) -> bool:
	var i := 0
	var n := data.size()
	while i < n:
		var b: int = data[i]
		if b < 0x80:
			i += 1
		elif (b & 0xE0) == 0xC0:
			if i + 1 >= n:
				return false
			if (data[i + 1] & 0xC0) != 0x80:
				return false
			var cp := ((b & 0x1F) << 6) | (data[i + 1] & 0x3F)
			if cp < 0x80:
				return false
			i += 2
		elif (b & 0xF0) == 0xE0:
			if i + 2 >= n:
				return false
			if (data[i + 1] & 0xC0) != 0x80 or (data[i + 2] & 0xC0) != 0x80:
				return false
			var cp2 := ((b & 0x0F) << 12) | ((data[i + 1] & 0x3F) << 6) | (data[i + 2] & 0x3F)
			if cp2 < 0x800:
				return false
			if cp2 >= 0xD800 and cp2 <= 0xDFFF:
				return false
			i += 3
		elif (b & 0xF8) == 0xF0:
			if i + 3 >= n:
				return false
			if (data[i + 1] & 0xC0) != 0x80 or (data[i + 2] & 0xC0) != 0x80 or (data[i + 3] & 0xC0) != 0x80:
				return false
			var cp3 := ((b & 0x07) << 18) | ((data[i + 1] & 0x3F) << 12) | ((data[i + 2] & 0x3F) << 6) | (data[i + 3] & 0x3F)
			if cp3 < 0x10000 or cp3 > 0x10FFFF:
				return false
			i += 4
		else:
			return false
	return true

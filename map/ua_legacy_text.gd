extends RefCounted
class_name UALegacyText

## Reads plain-text UA-era files without Godot UTF-8 parse errors. Retail assets are often
## Windows-1252 / ISO-8859-1; Godot's FileAccess text APIs assume UTF-8 and log on invalid bytes.

static func read_file(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	return decode_text_bytes(bytes)


static func decode_text_bytes(data: PackedByteArray) -> String:
	if data.is_empty():
		return ""
	if _is_probably_binary(data):
		return ""
	if _is_valid_utf8(data):
		var s := data.get_string_from_utf8()
		if s.begins_with("\ufeff"):
			s = s.substr(1)
		return s
	return _bytes_to_iso8859_1_string(data)


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

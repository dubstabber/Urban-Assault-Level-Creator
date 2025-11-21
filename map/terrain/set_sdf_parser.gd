extends Resource
class_name SetSdfParser

# Parses UA set.sdf and returns mappings for typ_id data
# Expected path per set: res://resources/ua/sets/set{N}/scripts/set.sdf
#
# Three sections in set.sdf:
# 1. Building definitions (before first '>') 
# 2. Tile mapping (between first and second '>', lines ~258-430)
# 3. Sector definitions (after second '>', lines 431+)
#
# Tile mapping format: subsector_index val0 val1 val2 val3 flag
# Sector format: typ_id SectorType SurfaceType GUIElementID [9 SubSector indices]
#
# The 4 values encode: ground_file_index and quadrant within that file
# Ground textures are 2×2 (4 subimages) except ground_4 which is 4×4 (16 subimages)

# Parse complete typ data including subsector patterns and tile mapping
# Returns: Dictionary with keys "surface_types", "subsector_patterns", and "tile_mapping"
# - surface_types: typ_id -> SurfaceType (0..5)
# - subsector_patterns: typ_id -> {surface_type, sector_type, subsectors: PackedInt32Array}
# - tile_mapping: subsector_index -> {val0, val1, val2, val3, flag}
static func parse_full_typ_data(set_id: int) -> Dictionary:
	if set_id < 1 or set_id > 6:
		push_warning("SetSdfParser: invalid set_id %d; defaulting to 1" % set_id)
		set_id = 1
	var path := "res://resources/ua/sets/set%d/scripts/set.sdf" % set_id
	return parse_full_typ_data_at(path)

static func parse_surface_type_map(set_id: int) -> Dictionary:
	if set_id < 1 or set_id > 6:
		push_warning("SetSdfParser: invalid set_id %d; defaulting to 1" % set_id)
		set_id = 1
	var path := "res://resources/ua/sets/set%d/scripts/set.sdf" % set_id
	return parse_surface_type_map_at(path)

static func parse_surface_type_map_at(path: String) -> Dictionary:
	var mapping: Dictionary = {}
	if path.is_empty():
		return mapping
	if not FileAccess.file_exists(path):
		push_warning("SetSdfParser: set.sdf not found at %s (will fallback to SurfaceType=0)" % path)
		return mapping
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SetSdfParser: cannot open %s" % path)
		return mapping
	# Read as raw bytes to avoid UTF-8 decode warnings (original files are Latin-1; comments may contain ä/ö/ü/ß)
	var section_idx := 0 # counts lines that start with '>'
	var in_sektor := false # true only between 2nd '>' and the next '>'
	var line_bytes := PackedByteArray()
	while not f.eof_reached():
		var b := f.get_8()
		if b == 10: # LF -> end of line
			# copy minus CR
			var tmp := PackedByteArray()
			for i in range(line_bytes.size()):
				var ch := line_bytes[i]
				if ch == 13: # CR
					continue
				tmp.append(ch)
			# check for '>' delimiter line (may have leading spaces and trailing comments)
			var k := 0
			while k < tmp.size() and (tmp[k] == 32 or tmp[k] == 9): # space or tab
				k += 1
			if k < tmp.size() and tmp[k] == 62: # '>'
				section_idx += 1
				in_sektor = (section_idx == 2)
				if section_idx > 2:
					# we've passed the sektor block; stop parsing further
					line_bytes.resize(0)
					break
				line_bytes.resize(0)
				continue
			if not in_sektor:
				line_bytes.resize(0)
				continue
			# cut at first ';' or '#'
			var cut := tmp.size()
			for j in range(tmp.size()):
				var ch2 := tmp[j]
				if ch2 == 59 or ch2 == 35: # ';' or '#'
					cut = j
					break
			# keep ASCII digits/space/sign/hex-only up to cut
			var ascii := PackedByteArray()
			for j in range(cut):
				var ch3 := tmp[j]
				var is_space := ch3 == 32 or ch3 == 9
				var is_digit := ch3 >= 48 and ch3 <= 57
				var is_sign := ch3 == 43 or ch3 == 45
				var is_hex := (ch3 >= 65 and ch3 <= 70) or (ch3 >= 97 and ch3 <= 102) or (ch3 == 120) or (ch3 == 88)
				if is_space or is_digit or is_sign or is_hex:
					ascii.append(ch3)
			var line := ascii.get_string_from_ascii().strip_edges()
			if not line.is_empty():
				var normalized := line.replace("\t", " ")
				var parts: PackedStringArray = normalized.split(" ", false)
				if parts.size() >= 4:
					var typ_id := _parse_int_auto(parts[0], -1)
					var sector_type := _parse_int_auto(parts[1], -1)
					var surface_type := _parse_int_auto(parts[2], -1) # UA: 0=typ_id, 1=SectorType, 2=SurfaceType
					if typ_id >= 0 and typ_id <= 255 and sector_type >= 0:
						if surface_type < 0 or surface_type > 5:
							surface_type = 0
						mapping[typ_id] = surface_type
			line_bytes.resize(0)
		else:
			line_bytes.append(b)
	# process last line if file doesn't end with LF
	if line_bytes.size() > 0 and in_sektor:
		var tmp2 := PackedByteArray()
		for i in range(line_bytes.size()):
			var ch := line_bytes[i]
			if ch == 13:
				continue
			tmp2.append(ch)
		var k2 := 0
		while k2 < tmp2.size() and (tmp2[k2] == 32 or tmp2[k2] == 9):
			k2 += 1
		if not (k2 < tmp2.size() and tmp2[k2] == 62):
			var cut2 := tmp2.size()
			for j in range(tmp2.size()):
				var ch2 := tmp2[j]
				if ch2 == 59 or ch2 == 35:
					cut2 = j
					break
			var ascii2 := PackedByteArray()
			for j in range(cut2):
				var c3 := tmp2[j]
				var is_space2 := c3 == 32 or c3 == 9
				var is_digit2 := c3 >= 48 and c3 <= 57
				var is_sign2 := c3 == 43 or c3 == 45
				var is_hex2 := (c3 >= 65 and c3 <= 70) or (c3 >= 97 and c3 <= 102) or (c3 == 120) or (c3 == 88)
				if is_space2 or is_digit2 or is_sign2 or is_hex2:
					ascii2.append(c3)
			var line2 := ascii2.get_string_from_ascii().strip_edges()
			if not line2.is_empty():
				var normalized2 := line2.replace("\t", " ")
				var parts2: PackedStringArray = normalized2.split(" ", false)
				if parts2.size() >= 4:
					var typ2 := _parse_int_auto(parts2[0], -1)
					var sec2 := _parse_int_auto(parts2[1], -1)
					var surf2 := _parse_int_auto(parts2[2], -1)
					if typ2 >= 0 and typ2 <= 255 and sec2 >= 0:
						if surf2 < 0 or surf2 > 5:
							surf2 = 0
						mapping[typ2] = surf2
	f.close()
	return mapping

# Parse tile mapping section (between first and second '>')
# Returns: Dictionary mapping subsector_index -> {val0, val1, val2, val3, flag}
static func parse_tile_mapping(path: String) -> Dictionary:
	var tile_map := {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return tile_map
	
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return tile_map
	
	var section_idx := 0
	var in_tile_section := false
	var implicit_idx := 0 # UA: subsector id increments per parsed line
	var line_bytes := PackedByteArray()
	
	while not f.eof_reached():
		var b := f.get_8()
		if b == 10: # LF
			var tmp := PackedByteArray()
			for i in range(line_bytes.size()):
				var ch := line_bytes[i]
				if ch != 13:
					tmp.append(ch)
			
			# Check for section delimiter
			var k := 0
			while k < tmp.size() and (tmp[k] == 32 or tmp[k] == 9):
				k += 1
			if k < tmp.size() and tmp[k] == 62: # '>'
				section_idx += 1
				in_tile_section = (section_idx == 1)
				if section_idx > 1:
					break
				line_bytes.resize(0)
				continue
			
			if not in_tile_section:
				line_bytes.resize(0)
				continue
			
			# Cut at first comment
			var cut := tmp.size()
			for j in range(tmp.size()):
				var ch2 := tmp[j]
				if ch2 == 59 or ch2 == 35:
					cut = j
					break
			
			# Parse numeric values
			var ascii := PackedByteArray()
			for j in range(cut):
				var ch3 := tmp[j]
				var is_valid := (ch3 >= 48 and ch3 <= 57) or ch3 == 32 or ch3 == 9 or ch3 == 43 or ch3 == 45
				var is_hex := (ch3 >= 65 and ch3 <= 70) or (ch3 >= 97 and ch3 <= 102) or ch3 == 120 or ch3 == 88
				if is_valid or is_hex:
					ascii.append(ch3)
			
			var line := ascii.get_string_from_ascii().strip_edges()
			if not line.is_empty():
				var normalized := line.replace("\t", " ")
				var parts: PackedStringArray = normalized.split(" ", false)
				
				# UA: Each non-empty line in this section defines one subsector in order.
				# Format: val0 val1 val2 val3 [flag]
				if parts.size() >= 5:
					var val0 := _parse_int_auto(parts[0], 0)
					var val1 := _parse_int_auto(parts[1], 0)
					var val2 := _parse_int_auto(parts[2], 0)
					var val3 := _parse_int_auto(parts[3], 0)
					var flag := _parse_int_auto(parts[4], 0)
					if implicit_idx >= 0 and implicit_idx <= 255:
						tile_map[implicit_idx] = {
							"val0": val0,
							"val1": val1,
							"val2": val2,
							"val3": val3,
							"flag": flag
						}
					implicit_idx += 1
			
			line_bytes.resize(0)
		else:
			line_bytes.append(b)
	
	f.close()
	print("[SetSdfParser] Parsed %d tile definitions from %s" % [tile_map.size(), path])
	return tile_map

# Parse full typ data including subsector patterns from a specific path
static func parse_full_typ_data_at(path: String) -> Dictionary:
	var result := {
		"surface_types": {},
		"subsector_patterns": {},
		"tile_mapping": {}
	}
	if path.is_empty():
		return result
	if not FileAccess.file_exists(path):
		push_warning("SetSdfParser: set.sdf not found at %s" % path)
		return result
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SetSdfParser: cannot open %s" % path)
		return result
	
	var section_idx := 0
	var in_sektor := false
	var line_bytes := PackedByteArray()
	
	while not f.eof_reached():
		var b := f.get_8()
		if b == 10: # LF
			var tmp := PackedByteArray()
			for i in range(line_bytes.size()):
				var ch := line_bytes[i]
				if ch != 13: # Skip CR
					tmp.append(ch)
			
			# Check for section delimiter
			var k := 0
			while k < tmp.size() and (tmp[k] == 32 or tmp[k] == 9):
				k += 1
			if k < tmp.size() and tmp[k] == 62: # '>'
				section_idx += 1
				in_sektor = (section_idx == 2)
				if section_idx > 2:
					break
				line_bytes.resize(0)
				continue
			
			if not in_sektor:
				line_bytes.resize(0)
				continue
			
			# Cut at first comment
			var cut := tmp.size()
			for j in range(tmp.size()):
				var ch2 := tmp[j]
				if ch2 == 59 or ch2 == 35: # ';' or '#'
					cut = j
					break
			
			# Keep only ASCII numeric and space
			var ascii := PackedByteArray()
			for j in range(cut):
				var ch3 := tmp[j]
				var is_valid := (ch3 >= 48 and ch3 <= 57) or ch3 == 32 or ch3 == 9 or ch3 == 43 or ch3 == 45
				var is_hex := (ch3 >= 65 and ch3 <= 70) or (ch3 >= 97 and ch3 <= 102) or ch3 == 120 or ch3 == 88
				if is_valid or is_hex:
					ascii.append(ch3)
			
			var line := ascii.get_string_from_ascii().strip_edges()
			if not line.is_empty():
				var normalized := line.replace("\t", " ")
				var parts: PackedStringArray = normalized.split(" ", false)
				
				if parts.size() >= 4:
					var typ_id := _parse_int_auto(parts[0], -1)
					var sector_type := _parse_int_auto(parts[1], -1)
					var surface_type := _parse_int_auto(parts[2], -1)
					var gui_id := _parse_int_auto(parts[3], -1)
					
					if typ_id >= 0 and typ_id <= 255 and sector_type >= 0:
						if surface_type < 0 or surface_type > 5:
							surface_type = 0
						
						result["surface_types"][typ_id] = surface_type
						
						# Parse subsectors (should be 9 values for 3x3 grid)
						var subsectors := PackedInt32Array()
						for i in range(4, parts.size()):
							var sub_val := _parse_int_auto(parts[i], -1)
							if sub_val >= 0:
								subsectors.append(sub_val)
						
						# Store pattern data
						result["subsector_patterns"][typ_id] = {
							"surface_type": surface_type,
							"sector_type": sector_type,
							"gui_id": gui_id,
							"subsectors": subsectors
						}
			
			line_bytes.resize(0)
		else:
			line_bytes.append(b)
	
	f.close()
	
	# Also parse tile mapping
	result["tile_mapping"] = parse_tile_mapping(path)
	
	return result

static func _strip_comments(s: String) -> String:
	var semi := s.find(";")
	var hash_idx := s.find("#")
	var cut := -1
	if semi >= 0 and hash_idx >= 0:
		cut = min(semi, hash_idx)
	elif semi >= 0:
		cut = semi
	elif hash_idx >= 0:
		cut = hash_idx
	return s.substr(0, cut) if cut >= 0 else s

static func _parse_int_auto(token: String, fallback: int) -> int:
	if token.is_empty():
		return fallback
	token = token.strip_edges()
	if token.begins_with("0x") or token.begins_with("0X"):
		var hex := token.substr(2, token.length() - 2)
		if _is_hex(hex):
			return _parse_hex(hex)
		else:
			return fallback
	# decimal
	if _is_dec(token):
		return int(token)
	return fallback

static func _is_dec(s: String) -> bool:
	for i in s.length():
		var c := s[i]
		if i == 0 and (c == "+" or c == "-"):
			continue
		if c < "0" or c > "9":
			return false
	return true

static func _is_hex(s: String) -> bool:
	for c in s:
		var up := c.to_upper()
		if not ((up >= "0" and up <= "9") or (up >= "A" and up <= "F")):
			return false
	return true


static func _parse_hex(hex: String) -> int:
	var v := 0
	var digits := "0123456789ABCDEF"
	for i in hex.length():
		var c := hex[i].to_upper()
		var d := digits.find(c)
		if d < 0:
			return 0
		v = v * 16 + d
	return v

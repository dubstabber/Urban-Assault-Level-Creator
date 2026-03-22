extends Resource
class_name SetSdfParser

const _UAProjectDataRoots = preload("res://map/ua_project_data_roots.gd")
const _UALegacyText = preload("res://map/ua_legacy_text.gd")

# Parses UA set.sdf and returns authoring metadata keyed by typ_id.
# Path: UAProjectDataRoots.set_sdf_path_for_set (bundled sets, then optional in-project UA trees).
#
# Confirmed high-level layout:
# 1. Lego/building definitions (before first '>')
# 2. Tile-entry table (between first and second '>')
# 3. Sector definitions (after second '>')
#
# Tile-entry format: implicit subsector_index -> val0 val1 val2 val3 flag [opt]
# Sector format: typ_id SectorType SurfaceType GUIElementID [SubSector indices]
#
# Important: current retail RE indicates the tile-entry values feed a later stage/object
# selector path, not a directly verified top-surface UV compositor. The active Godot editor
# preview therefore treats SectorRec.surface_type as the reliable top-texture family input,
# while still exposing the parsed tile-entry table for analysis and future work.

# Parse complete typ data including sector metadata and the raw tile-entry table
# Returns: Dictionary with keys "surface_types", "subsector_patterns", "tile_mapping", and "lego_defs"
# - surface_types: typ_id -> SurfaceType (0..5)
# - subsector_patterns: typ_id -> {surface_type, sector_type, subsectors: PackedInt32Array}
# - tile_mapping: subsector_index -> {val0, val1, val2, val3, flag}
# - lego_defs: raw selected tile id -> {raw_id, base_name, base_file, skeleton_ref}
static func parse_full_typ_data(set_id: int, game_data_type: String = "original") -> Dictionary:
	if set_id < 1 or set_id > 6:
		push_warning("SetSdfParser: invalid set_id %d; defaulting to 1" % set_id)
		set_id = 1
	var path := _UAProjectDataRoots.set_sdf_path_for_set(set_id, game_data_type)
	var res := parse_full_typ_data_at(path)
	var subs: Dictionary = res.get("subsector_patterns", {})
	var tiles: Dictionary = res.get("tile_mapping", {})
	if subs.is_empty() and tiles.is_empty():
		var alt := ""
		if not path.is_empty():
			var dir := path.get_base_dir()
			var fn := path.get_file().to_lower()
			if fn == "set.sdf":
				alt = "%s/set.sdf.bak_pre_strip" % dir
			elif fn == "set.sdf.bak_pre_strip":
				alt = "%s/set.sdf" % dir
		var res2 := parse_full_typ_data_at(alt)
		var subs2: Dictionary = res2.get("subsector_patterns", {})
		var tiles2: Dictionary = res2.get("tile_mapping", {})
		var lego2: Dictionary = res2.get("lego_defs", {})
		if not subs2.is_empty() or not tiles2.is_empty() or not lego2.is_empty():
			return res2
	return res

static func parse_lego_defs(path: String) -> Dictionary:
	var lego_defs := {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return lego_defs
	var full := _UALegacyText.read_file(path)
	if full.is_empty():
		return lego_defs
	var raw_id := 0
	for line_raw in full.split("\n"):
		var line := _strip_comments(line_raw).strip_edges()
		if line.is_empty():
			continue
		if line.begins_with(">"):
			break
		var tokens: PackedStringArray = line.replace("\t", " ").split(" ", false)
		if tokens.is_empty():
			continue
		var base_file := String(tokens[0]).strip_edges()
		var base_name := base_file.get_basename()
		var skeleton_ref := ""
		if tokens.size() > 1:
			var skel_token := String(tokens[1]).strip_edges()
			if skel_token.to_lower().contains(".sklt"):
				skeleton_ref = skel_token
		lego_defs[raw_id] = {
			"raw_id": raw_id,
			"base_name": base_name,
			"base_file": base_file,
			"skeleton_ref": skeleton_ref
		}
		raw_id += 1
	return lego_defs

static func parse_surface_type_map(set_id: int, game_data_type: String = "original") -> Dictionary:
	if set_id < 1 or set_id > 6:
		push_warning("SetSdfParser: invalid set_id %d; defaulting to 1" % set_id)
		set_id = 1
	var path := _UAProjectDataRoots.set_sdf_path_for_set(set_id, game_data_type)
	var mapping := parse_surface_type_map_at(path)
	if mapping.is_empty():
		var alt := ""
		if not path.is_empty():
			var dir := path.get_base_dir()
			var fn := path.get_file().to_lower()
			if fn == "set.sdf":
				alt = "%s/set.sdf.bak_pre_strip" % dir
			elif fn == "set.sdf.bak_pre_strip":
				alt = "%s/set.sdf" % dir
		var mapping2 := parse_surface_type_map_at(alt)
		if not mapping2.is_empty():
			return mapping2
	return mapping

static func parse_surface_type_map_at(path: String) -> Dictionary:
	# Delegate to parse_full_typ_data_at for consistent parsing
	var full_data := parse_full_typ_data_at(path)
	return full_data.get("surface_types", {})

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
				var idx := -1
				var val0 := 0
				var val1 := 0
				var val2 := 0
				var val3 := 0
				var flag := 0
				var opt := 0
				# UA uses implicit indexing; support optional 6th integer (+8)
				if parts.size() >= 6:
					idx = implicit_idx
					val0 = _parse_int_auto(parts[0], 0)
					val1 = _parse_int_auto(parts[1], 0)
					val2 = _parse_int_auto(parts[2], 0)
					val3 = _parse_int_auto(parts[3], 0)
					flag = 255 if _parse_int_auto(parts[4], 0) != 0 else 0
					opt = _parse_int_auto(parts[5], 0)
				elif parts.size() == 5:
					idx = implicit_idx
					val0 = _parse_int_auto(parts[0], 0)
					val1 = _parse_int_auto(parts[1], 0)
					val2 = _parse_int_auto(parts[2], 0)
					val3 = _parse_int_auto(parts[3], 0)
					flag = 255 if _parse_int_auto(parts[4], 0) != 0 else 0
				elif parts.size() == 4:
					idx = implicit_idx
					val0 = _parse_int_auto(parts[0], 0)
					val1 = _parse_int_auto(parts[1], 0)
					val2 = _parse_int_auto(parts[2], 0)
					val3 = _parse_int_auto(parts[3], 0)
					flag = 0
				if idx >= 0 and idx <= 255 and parts.size() >= 4:
					tile_map[idx] = {
						"val0": val0,
						"val1": val1,
						"val2": val2,
						"val3": val3,
						"flag": flag,
						"opt": opt
					}
					implicit_idx += 1
			
			line_bytes.resize(0)
		else:
			line_bytes.append(b)
	
	f.close()
	print("[SetSdfParser] Parsed %d tile definitions from %s" % [tile_map.size(), path])
	return tile_map

# Parse full typ data including subsector patterns from a specific path
# SET.SDF sektor section format (after '>' delimiter):
#   base_file skeleton_file 0 sector_type height surface_type [building_data...]
# typ_id is determined by LINE NUMBER (implicit indexing), not from the data.
# The numeric fields after filenames are: [0] [sector_type] [height] [surface_type] ...
static func parse_full_typ_data_at(path: String) -> Dictionary:
	var result := {
		"surface_types": {},
		"subsector_patterns": {},
		"tile_mapping": {},
		"lego_defs": {}
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
	
	# Parse tile mapping section up-front using a dedicated routine
	result["tile_mapping"] = parse_tile_mapping(path)
	result["lego_defs"] = parse_lego_defs(path)
	
	var section_idx := 0
	var in_sektor := false
	var typ_id := 0 # Implicit line-based typ_id counter
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
			
			# Parse the line properly: split by whitespace first, then extract numeric fields
			# Formats seen in UA assets:
			# A) Numeric sector table (after 2nd '>'):
			#    typ_id sector_type surface_type gui_id [subsector_indices...]
			# B) Legacy filename-based lines (fallback):
			#    base_file skeleton_file 0 sector_type height surface_type [data...]
			var line_str := ""
			for j in range(cut):
				line_str += char(tmp[j])
			line_str = line_str.strip_edges()
			
			if not line_str.is_empty():
				var normalized := line_str.replace("\t", " ")
				var tokens: PackedStringArray = normalized.split(" ", false)
				if tokens.is_empty():
					line_bytes.resize(0)
					continue
				
				# Prefer explicit typ_id table format when the first token is numeric.
				var first_val := _parse_int_auto(tokens[0], -99999)
				if first_val != -99999:
					var nums: Array[int] = []
					for t in tokens:
						var v := _parse_int_auto(t, -99999)
						if v != -99999:
							nums.append(v)
					if nums.size() >= 4:
						var typ_idx := nums[0]
						var sector_type := nums[1]
						var surface_type := nums[2]
						var gui_id := nums[3]
						if surface_type < 0 or surface_type > 5:
							surface_type = 0
						if typ_idx >= 0 and typ_idx <= 255:
							var subs := PackedInt32Array()
							for si in range(4, nums.size()):
								subs.append(nums[si])
							result["surface_types"][typ_idx] = surface_type
							result["subsector_patterns"][typ_idx] = {
								"surface_type": surface_type,
								"sector_type": sector_type,
								"gui_id": gui_id,
								"subsectors": subs
							}
				else:
					# Legacy fallback: line-number-based typ_id and numeric fields after filenames.
					var numeric_parts: Array[int] = []
					for t in tokens:
						var val := _parse_int_auto(t, -99999)
						if val != -99999:
							numeric_parts.append(val)
					if numeric_parts.size() >= 4:
						var sector_type := numeric_parts[1]
						var surface_type := numeric_parts[3]
						if surface_type < 0 or surface_type > 5:
							surface_type = 0
						if typ_id >= 0 and typ_id <= 255:
							result["surface_types"][typ_id] = surface_type
							result["subsector_patterns"][typ_id] = {
								"surface_type": surface_type,
								"sector_type": sector_type,
								"gui_id": 0,
								"subsectors": PackedInt32Array()
							}
						typ_id += 1 # Increment for next line
			
			line_bytes.resize(0)
		else:
			line_bytes.append(b)
	
	f.close()
	print("[SetSdfParser] Parsed %d sector definitions from %s" % [result["surface_types"].size(), path])
	# Debug: show first 10 surface_type mappings
	var all_keys: Array = result["surface_types"].keys()
	var count := mini(10, all_keys.size())
	for i in count:
		var k: int = all_keys[i]
		print("  typ %d -> surface_type %d" % [k, result["surface_types"][k]])
	
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

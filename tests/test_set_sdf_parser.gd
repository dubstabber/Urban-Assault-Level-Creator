extends RefCounted

# Unit tests for SetSdfParser

func run() -> int:
	var failures := 0
	var tmp_path := "user://temp_set.sdf"
	# Create a temporary set.sdf with mixed decimal and hex, comments, and whitespace
	var content := \
"""
; dummy lego section (ignored)
BASENAME.base  skeleton/Dummy.sklt  0   1   0  0
> ; end lego
; dummy subsector section (ignored)
 1  2  3  4   0
 5  6  7  8   1
> ; begin sektor section: typ_id SectorType SurfaceType GUIElementID [...]
10 0 3 0   ; typ 10 -> SurfaceType 3
0x1F  1  5  9   # hex typ -> SurfaceType 5
7 2 -1 0         ; out-of-range surface -> clamped to 0
# empty and malformed lines below

123
"""
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open temp file for writing: %s" % tmp_path)
		return 1
	f.store_string(content)
	f.close()

	var Parser := load("res://map/terrain/set_sdf_parser.gd")
	if Parser == null:
		push_error("Failed to load SetSdfParser")
		return 1
	var mapping: Dictionary = Parser.parse_surface_type_map_at(tmp_path)
	var full_data: Dictionary = Parser.parse_full_typ_data_at(tmp_path)
	var lego_defs: Dictionary = full_data.get("lego_defs", {})
	var tile_mapping: Dictionary = full_data.get("tile_mapping", {})
	# Expectations:
	# 10 -> 3, 0x1F (31) -> 5, 7 -> clamped 0
	if not mapping.has(10) or mapping[10] != 3:
		push_error("Expected typ 10 -> 3, got: %s" % (str(mapping.get(10, null))))
		failures += 1
	if not mapping.has(31) or mapping[31] != 5:
		push_error("Expected typ 31 -> 5, got: %s" % (str(mapping.get(31, null))))
		failures += 1
	if not mapping.has(7) or mapping[7] != 0:
		push_error("Expected typ 7 -> 0 (clamped), got: %s" % (str(mapping.get(7, null))))
		failures += 1
	if not lego_defs.has(0) or String(lego_defs[0].get("base_name", "")) != "BASENAME":
		push_error("Expected lego raw id 0 -> BASENAME, got: %s" % str(lego_defs.get(0, {})))
		failures += 1
	if not lego_defs.has(0) or String(lego_defs[0].get("skeleton_ref", "")) != "skeleton/Dummy.sklt":
		push_error("Expected lego raw id 0 skeleton ref to be preserved")
		failures += 1
	if not tile_mapping.has(0) or int(tile_mapping[0].get("flag", -1)) != 0:
		push_error("Expected tile 0 flag to stay 0, got: %s" % str(tile_mapping.get(0, {})))
		failures += 1
	if not tile_mapping.has(1) or int(tile_mapping[1].get("flag", -1)) != 255:
		push_error("Expected tile 1 flag to normalize textual nonzero to 255, got: %s" % str(tile_mapping.get(1, {})))
		failures += 1
	return failures


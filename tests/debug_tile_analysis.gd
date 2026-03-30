extends Node

# Debug tool to analyze tile mapping and figure out the encoding scheme
# Run this script to see how subsector values map to ground textures

func _ready():
	analyze_tile_mapping()

func analyze_tile_mapping():
	print("\n=== TILE MAPPING ANALYSIS ===\n")
	
	var set_id := 1
	var full_data := SetSdfParser.parse_full_typ_data(set_id)
	var tile_mapping: Dictionary = full_data.get("tile_mapping", {})
	var subsector_patterns: Dictionary = full_data.get("subsector_patterns", {})
	
	if tile_mapping.is_empty():
		print("ERROR: No tile mapping loaded!")
		return
	
	print("Total tile definitions: %d" % tile_mapping.size())
	print("\n--- Sample Tile Definitions ---")
	
	# Show first 20 entries
	var count := 0
	for subsector_idx in tile_mapping.keys():
		if count >= 20:
			break
		var tile_def = tile_mapping[subsector_idx]
		print("Subsector %3d: [%3d, %3d, %3d, %3d] flag=%d" % [
			subsector_idx,
			tile_def.val0, tile_def.val1, tile_def.val2, tile_def.val3,
			tile_def.flag
		])
		count += 1
	
	# Analyze typ_185 specifically (the user's example)
	print("\n--- Analyzing typ_id 185 (user example) ---")
	if subsector_patterns.has(185):
		var pattern = subsector_patterns[185]
		var subsectors: PackedInt32Array = pattern.get("subsectors", PackedInt32Array())
		print("typ_185 uses subsectors: %s" % str(subsectors))
		print("Surface type: %d" % pattern.get("surface_type", -1))
		print("\nLooking up tile definitions for each subsector:")
		
		for i in range(subsectors.size()):
			var sub_idx = subsectors[i]
			if tile_mapping.has(sub_idx):
				var tile_def = tile_mapping[sub_idx]
				print("  [%d] Subsector %3d: [%3d, %3d, %3d, %3d] flag=%d" % [
					i, sub_idx,
					tile_def.val0, tile_def.val1, tile_def.val2, tile_def.val3,
					tile_def.flag
				])
	
	# Analyze value distribution
	print("\n--- Value Distribution Analysis ---")
	var val_min := 999
	var val_max := 0
	var val_histogram := {}
	
	for subsector_idx in tile_mapping.keys():
		var tile_def = tile_mapping[subsector_idx]
		for val_key in ["val0", "val1", "val2", "val3"]:
			var val = tile_def[val_key]
			val_min = min(val_min, val)
			val_max = max(val_max, val)
			if not val_histogram.has(val):
				val_histogram[val] = 0
			val_histogram[val] += 1
	
	print("Value range: %d to %d" % [val_min, val_max])
	print("Total unique values: %d" % val_histogram.size())
	
	# Attempt to decode values
	print("\n--- Decoding Attempt ---")
	print("If values encode ground_file + quadrant:")
	print("  Scheme A: file = val / 64, quadrant = val %% 4")
	print("  Scheme B: file = val / 4, quadrant = val %% 4")
	print("  Scheme C: file = val / 16, quadrant = val %% 16")
	
	# Test with subsector 107 (has mixed values)
	if tile_mapping.has(107):
		var tile_def = tile_mapping[107]
		print("\nSubsector 107: [%d, %d, %d, %d]" % [
			tile_def.val0, tile_def.val1, tile_def.val2, tile_def.val3
		])
		for scheme in ["A", "B", "C"]:
			print("  Scheme %s:" % scheme)
			for val_key in ["val0", "val1", "val2", "val3"]:
				var val = tile_def[val_key]
				var file := 0
				var quad := 0
				match scheme:
					"A":
						file = val / 64
						quad = val % 4
					"B":
						file = val / 4
						quad = val % 4
					"C":
						file = val / 16
						quad = val % 16
				print("    %s=%d -> ground_%d.png quadrant/tile %d" % [val_key, val, file, quad])
	
	print("\n=== END ANALYSIS ===\n")
	print("Check console output above to understand the encoding!")
	print("Once you know the scheme, update Map3DRenderer to decode tile values.")

@tool
extends EditorScript

# Quick test script - run this from Script → Run Script in Godot editor

func _run():
	print("\n=== TILE MAPPING QUICK TEST ===\n")
	
	# Parse set.sdf
	var full_data := SetSdfParser.parse_full_typ_data(1)
	var tile_mapping = full_data.get("tile_mapping", {})
	var subsector_patterns = full_data.get("subsector_patterns", {})
	
	print("Loaded %d tile definitions" % tile_mapping.size())
	print("Loaded %d sector patterns" % subsector_patterns.size())
	
	# Analyze typ_185 (user's example)
	print("\n--- typ_id 185 Analysis ---")
	if subsector_patterns.has(185):
		var pattern = subsector_patterns[185]
		var subs: PackedInt32Array = pattern.subsectors
		print("Subsectors (3×3 grid): %s" % str(subs))
		print("SurfaceType: %d\n" % pattern.surface_type)
		
		print("Tile definitions for each subsector:")
		for i in range(subs.size()):
			var sub_idx = subs[i]
			if tile_mapping.has(sub_idx):
				var td = tile_mapping[sub_idx]
				var pos := ""
				match i:
					0: pos = "NW"
					1: pos = "N "
					2: pos = "NE"
					3: pos = "W "
					4: pos = "C "
					5: pos = "E "
					6: pos = "SW"
					7: pos = "S "
					8: pos = "SE"
				
				print("  %s [%d] subsector %3d: values=[%3d, %3d, %3d, %3d] flag=%d" % [
					pos, i, sub_idx,
					td.val0, td.val1, td.val2, td.val3,
					td.flag
				])
	
	# Test decoding schemes
	print("\n--- Decoding Test (Subsector 107) ---")
	if tile_mapping.has(107):
		var td = tile_mapping[107]
		print("Subsector 107: [%d, %d, %d, %d] flag=%d" % [
			td.val0, td.val1, td.val2, td.val3, td.flag
		])
		
		print("\nTesting encoding schemes:")
		for val_key in ["val0", "val1", "val2", "val3"]:
			var val = td[val_key]
			print("  %s = %d:" % [val_key, val])
			print("    Scheme A (val/64, val%%4):  ground_%d.png quad %d" % [val / 64, val % 4])
			print("    Scheme B (val/4,  val%%4):  ground_%d.png quad %d" % [val / 4, val % 4])
			print("    Scheme C (val/16, val%%16): ground_%d.png tile %d" % [val / 16, val % 16])
	
	print("\n=== END TEST ===")
	print("\nNOTE: Check which scheme produces valid ground file indices (0-5)")
	print("and makes sense with your observation of the textures!")

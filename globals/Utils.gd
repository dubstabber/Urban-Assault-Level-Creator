extends Node


func increment_typ_map() -> void:
	if CurrentMapData.typ_map.is_empty() or CurrentMapData.selected_sector_idx < 0: 
		return
	var temp := CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]
	temp += 1
	if temp > 255:
		temp = 0
	match CurrentMapData.level_set:
		1:
			if temp > 53 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 95: temp = 95
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 120: temp = 120
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 236 and temp < 239: temp = 239
		2:
			if temp > 24 and temp < 27: temp = 27
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 118: temp = 118
			if temp > 131 and temp < 133: temp = 133
			if temp > 133 and temp < 150: temp = 150
			if temp > 195 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 210: temp = 210
			if temp > 225 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		3:
			if temp > 49 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 100: temp = 100
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		4:
			if temp > 49 and temp < 59: temp = 59
			if temp > 60 and temp < 66: temp = 66
			if temp > 82 and temp < 100: temp = 100
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		5:
			if temp > 95 and temp < 97: temp = 97
			if temp > 116 and temp < 118: temp = 118
			if temp > 131 and temp < 133: temp = 133
			if temp > 137 and temp < 150: temp = 150
			if temp > 191 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 210: temp = 210
			if temp > 225 and temp < 228: temp = 228
			if temp > 230 and temp < 239: temp = 239
		6:
			if temp > 49 and temp < 59: temp = 59
			if temp > 59 and temp < 66: temp = 66
			if temp > 82 and temp < 95: temp = 95
			if temp > 104 and temp < 110: temp = 110
			if temp > 113 and temp < 121: temp = 121
			if temp > 121 and temp < 130: temp = 130
			if temp > 141 and temp < 150: temp = 150
			if temp > 189 and temp < 198: temp = 198
			if temp > 205 and temp < 207: temp = 207
			if temp > 208 and temp < 228: temp = 228
			if temp > 235 and temp < 239: temp = 239
	CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = temp


func decrement_typ_map() -> void:
	if CurrentMapData.typ_map.is_empty() or CurrentMapData.selected_sector_idx < 0: 
		return
	
	var temp := CurrentMapData.typ_map[CurrentMapData.selected_sector_idx]
	temp -= 1
	if temp < 0:
		temp = 255
	match CurrentMapData.level_set:
		1:
			if temp > 53 and temp < 59: temp = 53
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 95: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 120: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 236 and temp < 239: temp = 236
		2:
			if temp > 24 and temp < 27: temp = 24
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 118: temp = 113
			if temp > 131 and temp < 133: temp = 131
			if temp > 133 and temp < 150: temp = 133
			if temp > 195 and temp < 198: temp = 195
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 210: temp = 208
			if temp > 225 and temp < 228: temp = 225
			if temp > 230 and temp < 239: temp = 230
		3:
			if temp > 49 and temp < 59: temp = 49
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 100: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 230 and temp < 239: temp = 230
		4:
			if temp > 49 and temp < 59: temp = 49
			if temp > 60 and temp < 66: temp = 60
			if temp > 82 and temp < 100: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 230 and temp < 239: temp = 230
		5:
			if temp > 95 and temp < 97: temp = 95
			if temp > 116 and temp < 118: temp = 116
			if temp > 131 and temp < 133: temp = 131
			if temp > 137 and temp < 150: temp = 137
			if temp > 191 and temp < 198: temp = 191
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 210: temp = 208
			if temp > 225 and temp < 228: temp = 225
			if temp > 230 and temp < 239: temp = 230
		6:
			if temp > 49 and temp < 59: temp = 49
			if temp > 59 and temp < 66: temp = 59
			if temp > 82 and temp < 95: temp = 82
			if temp > 104 and temp < 110: temp = 104
			if temp > 113 and temp < 121: temp = 113
			if temp > 121 and temp < 130: temp = 121
			if temp > 141 and temp < 150: temp = 141
			if temp > 189 and temp < 198: temp = 189
			if temp > 205 and temp < 207: temp = 205
			if temp > 208 and temp < 228: temp = 208
			if temp > 235 and temp < 239: temp = 235
	CurrentMapData.typ_map[CurrentMapData.selected_sector_idx] = temp


func randomize_whole_typ_map() -> void:
	if CurrentMapData.typ_map.is_empty(): return
	
	for i in CurrentMapData.typ_map.size():
		var fail := true
		var rand: int
		
		while fail:
			rand = randi_range(0,255)
			fail = false
			
			match CurrentMapData.level_set:
				1:
					if rand > 53 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 95: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 120: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 236 and rand < 239: fail = true
				2:
					if rand > 24 and rand < 27: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 118: fail = true
					if rand > 131 and rand < 133: fail = true
					if rand > 133 and rand < 150: fail = true
					if rand > 195 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 210: fail = true
					if rand > 225 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				3:
					if rand > 49 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 100: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				4:
					if rand > 49 and rand < 59: fail = true
					if rand > 60 and rand < 66: fail = true
					if rand > 82 and rand < 100: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				5:
					if rand > 95 and rand < 97: fail = true
					if rand > 116 and rand < 118: fail = true
					if rand > 131 and rand < 133: fail = true
					if rand > 137 and rand < 150: fail = true
					if rand > 191 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 210: fail = true
					if rand > 225 and rand < 228: fail = true
					if rand > 230 and rand < 239: fail = true
				6:
					if rand > 49 and rand < 59: fail = true
					if rand > 59 and rand < 66: fail = true
					if rand > 82 and rand < 95: fail = true
					if rand > 104 and rand < 110: fail = true
					if rand > 113 and rand < 121: fail = true
					if rand > 121 and rand < 130: fail = true
					if rand > 141 and rand < 150: fail = true
					if rand > 189 and rand < 198: fail = true
					if rand > 205 and rand < 207: fail = true
					if rand > 208 and rand < 228: fail = true
					if rand > 235 and rand < 239: fail = true
			
			CurrentMapData.typ_map[i] = rand
		
	EventSystem.map_updated.emit()


func convert_sky_name_case(sky_name: String) -> String:
	for sky in Preloads.skies.keys():
		if sky.to_lower() == sky_name.to_lower():
			return sky
	
	return Preloads.skies.get(0)

extends RefCounted

const CHUNK_SIZE := 4
const CHUNK_SHIFT := 2


static func sector_to_chunk(sx: int, sy: int) -> Vector2i:
	return Vector2i(sx >> CHUNK_SHIFT, sy >> CHUNK_SHIFT)


static func chunk_sector_range(cx: int, cy: int) -> Rect2i:
	return Rect2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)


static func chunk_count_for_map(map_w: int, map_h: int) -> Vector2i:
	if map_w <= 0 or map_h <= 0:
		return Vector2i.ZERO
	var cx := (map_w + CHUNK_SIZE - 1) >> CHUNK_SHIFT
	var cy := (map_h + CHUNK_SIZE - 1) >> CHUNK_SHIFT
	return Vector2i(cx, cy)


static func chunks_for_hgt_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if sx < 0 or sy < 0 or sx >= map_w or sy >= map_h:
		return result
	var primary := sector_to_chunk(sx, sy)
	var chunk_count := chunk_count_for_map(map_w, map_h)
	var touches_left_boundary := (sx % CHUNK_SIZE) == 0 and primary.x > 0
	var touches_right_boundary := (sx % CHUNK_SIZE) == (CHUNK_SIZE - 1) and (primary.x + 1) < chunk_count.x
	var touches_top_boundary := (sy % CHUNK_SIZE) == 0 and primary.y > 0
	var touches_bottom_boundary := (sy % CHUNK_SIZE) == (CHUNK_SIZE - 1) and (primary.y + 1) < chunk_count.y
	result.append(primary)
	if touches_left_boundary:
		result.append(Vector2i(primary.x - 1, primary.y))
	if touches_right_boundary:
		result.append(Vector2i(primary.x + 1, primary.y))
	if touches_top_boundary:
		result.append(Vector2i(primary.x, primary.y - 1))
	if touches_bottom_boundary:
		result.append(Vector2i(primary.x, primary.y + 1))
	if touches_left_boundary and touches_top_boundary:
		result.append(Vector2i(primary.x - 1, primary.y - 1))
	if touches_right_boundary and touches_top_boundary:
		result.append(Vector2i(primary.x + 1, primary.y - 1))
	if touches_left_boundary and touches_bottom_boundary:
		result.append(Vector2i(primary.x - 1, primary.y + 1))
	if touches_right_boundary and touches_bottom_boundary:
		result.append(Vector2i(primary.x + 1, primary.y + 1))
	return result


static func chunks_for_typ_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	return chunks_for_hgt_edit(sx, sy, map_w, map_h)


static func chunks_for_blg_edit(sx: int, sy: int, map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if sx < 0 or sy < 0 or sx >= map_w or sy >= map_h:
		return result
	result.append(sector_to_chunk(sx, sy))
	return result


static func all_chunks_for_map(map_w: int, map_h: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var chunk_count := chunk_count_for_map(map_w, map_h)
	for cy in chunk_count.y:
		for cx in chunk_count.x:
			result.append(Vector2i(cx, cy))
	return result

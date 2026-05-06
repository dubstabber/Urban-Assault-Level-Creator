extends RefCounted
const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")


static func invalidation_for_hgt_border_indices(border_indices: Array, w: int, h: int) -> Dictionary:
	return _build_hgt_invalidation(border_indices, w, h)


static func invalidation_for_typ_indices(typ_indices: Array, w: int, h: int) -> Dictionary:
	return _build_playable_invalidation(typ_indices, w, h, "typ", true)


static func invalidation_for_blg_indices(blg_indices: Array, w: int, h: int) -> Dictionary:
	return _build_playable_invalidation(blg_indices, w, h, "blg", true)


static func _build_hgt_invalidation(border_indices: Array, w: int, h: int) -> Dictionary:
	var sectors := sectors_for_hgt_border_indices(border_indices, w, h)
	return {
		"dirty_sectors": sectors,
		"dirty_chunks": dirty_chunks_for_sectors(sectors, w, h, "hgt"),
		"localized": not sectors.is_empty(),
		"effective_typ_dirty": false,
		"edit_type": "hgt",
	}


static func _build_playable_invalidation(indices: Array, w: int, h: int, edit_type: String, effective_typ_dirty: bool) -> Dictionary:
	var sectors := sectors_for_playable_indices(indices, w, h)
	return {
		"dirty_sectors": sectors,
		"dirty_chunks": dirty_chunks_for_sectors(sectors, w, h, edit_type),
		"localized": not sectors.is_empty(),
		"effective_typ_dirty": effective_typ_dirty,
		"edit_type": edit_type,
	}


static func sectors_for_playable_indices(indices: Array, w: int, h: int) -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	var seen := {}
	if w <= 0 or h <= 0:
		return sectors
	for idx_value in indices:
		var idx := int(idx_value)
		if idx < 0 or idx >= (w * h):
			continue
		var sx := idx % w
		var sy: int = floori(float(idx) / float(w))
		var sector := Vector2i(sx, sy)
		if seen.has(sector):
			continue
		seen[sector] = true
		sectors.append(sector)
	return sectors


static func sectors_for_hgt_border_indices(border_indices: Array, w: int, h: int) -> Array[Vector2i]:
	var sectors: Array[Vector2i] = []
	var seen := {}
	if w <= 0 or h <= 0:
		return sectors
	var bw := w + 2
	var total := bw * (h + 2)
	for idx_value in border_indices:
		var border_idx := int(idx_value)
		if border_idx < 0 or border_idx >= total:
			continue
		var bx := border_idx % bw
		var by: int = floori(float(border_idx) / float(bw))
		var sx: int = bx - 1
		var sy: int = by - 1
		for oy in [-1, 0, 1]:
			var py: int = sy + oy
			if py < 0 or py >= h:
				continue
			for ox in [-1, 0, 1]:
				var px: int = sx + ox
				if px < 0 or px >= w:
					continue
				var sector := Vector2i(px, py)
				if seen.has(sector):
					continue
				seen[sector] = true
				sectors.append(sector)
	return sectors


static func dirty_chunks_for_sectors(sectors: Array, w: int, h: int, edit_type: String) -> Array[Vector2i]:
	var chunks: Array[Vector2i] = []
	var seen := {}
	if w <= 0 or h <= 0:
		return chunks
	for sector_value in sectors:
		if not (sector_value is Vector2i):
			continue
		var sector := Vector2i(sector_value)
		var affected: Array[Vector2i] = []
		if edit_type == "blg":
			affected = ChunkGrid.chunks_for_blg_edit(sector.x, sector.y, w, h)
		else:
			affected = ChunkGrid.chunks_for_hgt_edit(sector.x, sector.y, w, h)
		for chunk_coord in affected:
			if seen.has(chunk_coord):
				continue
			seen[chunk_coord] = true
			chunks.append(chunk_coord)
	return chunks

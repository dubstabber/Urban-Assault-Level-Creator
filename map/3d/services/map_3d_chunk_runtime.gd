extends RefCounted
## Chunk-level state and decision logic extracted from Map3DRenderer.
##
## Owns dirty-chunk tracking, full-vs-incremental rebuild decisions,
## terrain authored-piece descriptor cache bookkeeping, initial-build
## batching state, and the chunked-terrain feature flag.
##
## Scene-tree operations (node creation, material application, queue_free)
## remain in the renderer; this service is pure data.

const ChunkGrid := preload("res://map/3d/terrain/map_3d_chunk_grid.gd")


# ---- Feature flag ----

var chunked_terrain_enabled := true


# ---- Dirty chunk tracking ----

var _dirty_chunks: Dictionary = {}
var explicit_chunk_invalidation_pending := false
var localized_chunk_invalidation_pending := false


func has_dirty_chunks() -> bool:
	return not _dirty_chunks.is_empty()


func get_dirty_chunk_count() -> int:
	return _dirty_chunks.size()


func mark_chunk_dirty(chunk_coord: Vector2i) -> void:
	_dirty_chunks[chunk_coord] = true


func erase_dirty_chunk(chunk_coord: Vector2i) -> void:
	_dirty_chunks.erase(chunk_coord)


func clear_dirty_chunks() -> void:
	_dirty_chunks.clear()
	explicit_chunk_invalidation_pending = false
	localized_chunk_invalidation_pending = false


func take_localized_chunk_invalidation_pending() -> bool:
	var pending := localized_chunk_invalidation_pending
	localized_chunk_invalidation_pending = false
	return pending


func invalidate_all_chunks(w: int, h: int) -> void:
	_dirty_chunks.clear()
	var all_chunks: Array[Vector2i] = ChunkGrid.all_chunks_for_map(w, h)
	for chunk_coord in all_chunks:
		_dirty_chunks[chunk_coord] = true
	explicit_chunk_invalidation_pending = true
	localized_chunk_invalidation_pending = false


func invalidate_chunks_for_sector_edit(sx: int, sy: int, w: int, h: int, edit_type: String) -> void:
	var affected: Array[Vector2i]
	if edit_type == "hgt" or edit_type == "typ":
		affected = ChunkGrid.chunks_for_hgt_edit(sx, sy, w, h)
	else:
		affected = ChunkGrid.chunks_for_blg_edit(sx, sy, w, h)
	for chunk_coord in affected:
		_dirty_chunks[chunk_coord] = true
	explicit_chunk_invalidation_pending = true
	localized_chunk_invalidation_pending = true


func dirty_chunks_sorted_by_priority(focus_chunk: Vector2i) -> Array[Vector2i]:
	var ordered: Array[Vector2i] = []
	for key in _dirty_chunks.keys():
		if key is Vector2i:
			ordered.append(key)
	if ordered.size() <= 1:
		return ordered
	ordered.sort_custom(func(a, b) -> bool:
		return chunk_distance_sq(Vector2i(a), focus_chunk) < chunk_distance_sq(Vector2i(b), focus_chunk)
	)
	return ordered


# ---- Map dimensions / level-set tracking ----

var last_map_dimensions: Vector2i = Vector2i.ZERO
var last_level_set: int = -1


# ---- Full-rebuild decision support ----

func needs_full_rebuild(w: int, h: int, level_set: int, has_chunk_nodes: bool) -> bool:
	var dims := Vector2i(w, h)
	if dims != last_map_dimensions:
		return true
	if level_set != last_level_set:
		return true
	if not has_chunk_nodes and _dirty_chunks.is_empty():
		return true
	return false

func prepare_chunked_full_rebuild(w: int, h: int, level_set: int) -> void:
	last_map_dimensions = Vector2i(w, h)
	last_level_set = level_set
	invalidate_all_chunks(w, h)


# ---- Initial-build batching ----

var initial_build_in_progress := false
var initial_build_batch_size := 4
var initial_build_accumulated_authored_descriptors: Array = []


# ---- Terrain authored-piece descriptor cache ----

# Keyed by instance_key -> descriptor dictionary.
var _terrain_authored_cache_by_key: Dictionary = {}
# Instance-key reference counts across chunks.
# Border-inclusive chunk meshes generate overlapping authored descriptors, so
# keys can contribute to multiple chunks simultaneously. We must not erase
# a key globally just because one chunk rebuild dropped its contribution.
var _terrain_authored_cache_key_ref_counts: Dictionary = {}
# Maps a chunk coord to the authored descriptor instance-keys it contributed last time.
var _terrain_chunk_authored_cache_keys: Dictionary = {}


func get_support_descriptors() -> Array:
	return _terrain_authored_cache_by_key.values().duplicate()


func clear_authored_caches() -> void:
	_terrain_authored_cache_by_key.clear()
	_terrain_authored_cache_key_ref_counts.clear()
	_terrain_chunk_authored_cache_keys.clear()


func update_terrain_authored_cache_for_chunk(chunk_coord: Vector2i, chunk_descriptors: Array) -> void:
	# Remove previously cached authored pieces for this chunk.
	if _terrain_chunk_authored_cache_keys.has(chunk_coord):
		for key in _terrain_chunk_authored_cache_keys[chunk_coord]:
			var k := String(key)
			if _terrain_authored_cache_key_ref_counts.has(k):
				var new_ref_count := int(_terrain_authored_cache_key_ref_counts[k]) - 1
				if new_ref_count <= 0:
					_terrain_authored_cache_key_ref_counts.erase(k)
					_terrain_authored_cache_by_key.erase(k)
				else:
					_terrain_authored_cache_key_ref_counts[k] = new_ref_count
		_terrain_chunk_authored_cache_keys.erase(chunk_coord)

	var new_keys: Array = []
	var seen_in_chunk := {}
	for desc in chunk_descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.is_empty():
			continue
		if seen_in_chunk.has(key):
			continue
		seen_in_chunk[key] = true
		_terrain_authored_cache_by_key[key] = d
		_terrain_authored_cache_key_ref_counts[key] = int(_terrain_authored_cache_key_ref_counts.get(key, 0)) + 1
		new_keys.append(key)

	_terrain_chunk_authored_cache_keys[chunk_coord] = new_keys


func reset_terrain_authored_cache_from_descriptors(support_descriptors: Array, w: int, h: int) -> void:
	_terrain_authored_cache_by_key.clear()
	_terrain_chunk_authored_cache_keys.clear()
	_terrain_authored_cache_key_ref_counts.clear()
	if w <= 0 or h <= 0:
		return

	var chunk_count: Vector2i = ChunkGrid.chunk_count_for_map(w, h)

	for desc in support_descriptors:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		var d := desc as Dictionary
		var key := String(d.get("instance_key", ""))
		if key.is_empty():
			continue

		# Cache lookups for chunk invalidation rely on being able to associate a descriptor
		# with all chunks that could have generated it when building chunk meshes with
		# `include_border=true` (so border/seam geometry is produced redundantly).
		var cell_x := 0
		var cell_y := 0
		var cache_mode: String = "terrain"
		if key.begins_with("terrain:"):
			var parts := key.split(":")
			# terrain:<set_id>:<x>:<y>:...
			if parts.size() >= 4:
				cell_x = int(parts[2])
				cell_y = int(parts[3])
		elif key.begins_with("slurp:v:"):
			cache_mode = "slurp_v"
			var parts := key.split(":")
			# slurp:v:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])
		elif key.begins_with("slurp:h:"):
			cache_mode = "slurp_h"
			var parts := key.split(":")
			# slurp:h:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])
		elif key.begins_with("slurp:"):
			# Fallback for unknown slurp variants; keep old behavior.
			cache_mode = "slurp_unknown"
			var parts := key.split(":")
			# slurp:<family>:<set_id>:<x>:<y>:...
			if parts.size() >= 5:
				cell_x = int(parts[3])
				cell_y = int(parts[4])

		_terrain_authored_cache_by_key[key] = d

		# Determine conservatively which chunk coords are eligible to include this raw
		# cell coordinate based on border-expanded chunk ranges.
		var candidate_chunks: Array[Vector2i] = []
		var cx_center: int = int(cell_x) >> ChunkGrid.CHUNK_SHIFT
		var cy_center: int = int(cell_y) >> ChunkGrid.CHUNK_SHIFT
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cx: int = cx_center + dx
				var cy: int = cy_center + dy
				if cx < 0 or cy < 0 or cx >= chunk_count.x or cy >= chunk_count.y:
					continue

				var main_sx_min: int = cx * ChunkGrid.CHUNK_SIZE
				var main_sy_min: int = cy * ChunkGrid.CHUNK_SIZE
				var main_sx_max: int = mini(main_sx_min + ChunkGrid.CHUNK_SIZE, w)
				var main_sy_max: int = mini(main_sy_min + ChunkGrid.CHUNK_SIZE, h)

				# Match the loop extents used by the generators for the given instance key type.
				# This ensures refcounts for shared seam descriptors don't underflow when
				# only a neighboring chunk is rebuilt.
				var exp_sx_min := maxi(main_sx_min - 1, -1)
				var exp_sy_min := maxi(main_sy_min - 1, -1)
				var exp_sx_max: int
				var exp_sy_max: int
				if cache_mode == "terrain" or cache_mode == "slurp_unknown":
					# Map3DTerrainBuilder.build_chunk_mesh_with_textures(..., include_border=true)
					# loop extents for x/y indices.
					exp_sx_max = mini(main_sx_max + 1, w + 1) # exclusive
					exp_sy_max = mini(main_sy_max + 1, h + 1) # exclusive
				elif cache_mode == "slurp_v":
					# Map3DSlurpBuilder.build_chunk_edge_overlay_result vertical loop:
					#   x == -1 only for the first chunk, otherwise sx_min <= x < sx_max
					#   y == -1 only for the top chunk, y == h only for the bottom chunk,
					#   otherwise sy_min <= y < sy_max
					exp_sx_min = (-1 if main_sx_min == 0 else main_sx_min)
					exp_sy_min = (-1 if main_sy_min == 0 else main_sy_min)
					exp_sx_max = main_sx_max # exclusive
					exp_sy_max = (h + 1 if main_sy_max == h else main_sy_max) # exclusive
				elif cache_mode == "slurp_h":
					# Map3DSlurpBuilder.build_chunk_edge_overlay_result horizontal loop:
					#   x == -1 only for the left chunk, x == w only for the right chunk,
					#   otherwise sx_min <= x < sx_max
					#   y == -1 only for the top chunk, otherwise sy_min <= y < sy_max
					exp_sx_min = (-1 if main_sx_min == 0 else main_sx_min)
					exp_sy_min = (-1 if main_sy_min == 0 else main_sy_min)
					exp_sx_max = (w + 1 if main_sx_max == w else main_sx_max) # exclusive
					exp_sy_max = main_sy_max # exclusive
				else:
					# Defensive fallback.
					exp_sx_max = mini(main_sx_max + 1, w + 1) # exclusive
					exp_sy_max = mini(main_sy_max + 1, h + 1) # exclusive

				if cell_x >= exp_sx_min and cell_x < exp_sx_max and cell_y >= exp_sy_min and cell_y < exp_sy_max:
					candidate_chunks.append(Vector2i(cx, cy))

		# Fallback: if no candidates matched, associate with clamped cell coordinates.
		if candidate_chunks.is_empty():
			var playable_x := clampi(cell_x, 0, w - 1)
			var playable_y := clampi(cell_y, 0, h - 1)
			candidate_chunks.append(ChunkGrid.sector_to_chunk(playable_x, playable_y))

		# Deduplicate candidates.
		var seen_chunks: Dictionary = {}
		var unique_chunks: Array[Vector2i] = []
		for cc in candidate_chunks:
			var kk := "%d:%d" % [cc.x, cc.y]
			if seen_chunks.has(kk):
				continue
			seen_chunks[kk] = true
			unique_chunks.append(cc)

		_terrain_authored_cache_key_ref_counts[key] = unique_chunks.size()
		for chunk_coord in unique_chunks:
			var chunk_keys: Array = _terrain_chunk_authored_cache_keys.get(chunk_coord, [])
			if not chunk_keys.has(key):
				chunk_keys.append(key)
			_terrain_chunk_authored_cache_keys[chunk_coord] = chunk_keys


# ---- Utility ----

static func chunk_distance_sq(a: Vector2i, b: Vector2i) -> int:
	var dx := a.x - b.x
	var dy := a.y - b.y
	return dx * dx + dy * dy

extends Node2D

# Emitted after any camera pan/zoom/clamp so the container can sync its scrollbars.
signal view_changed

var zoom_minimum := Constants.ZOOM_MINIMUM
var zoom_maximum := Constants.ZOOM_MAXIMUM
var zoom_speed := Constants.ZOOM_SPEED
var sector_indent := Constants.SECTOR_INDENT
var font: Font
var sector_font_size := Constants.SECTOR_FONT_SIZE

# Extra ring of sectors drawn just outside the visible rect to avoid pop-in at edges.
const CULL_MARGIN := 1

var right_clicked_x_global: int
var right_clicked_y_global: int
var right_clicked_x: int
var right_clicked_y: int
var is_selection_kept := false
var is_multi_selection := false
var selection_start_point := Vector2.ZERO
var current_mouse_pos := Vector2.ZERO

@onready var map_camera: Camera2D = $Camera2D

var _owner_colors := {
	0: Color.BLACK,
	1: Color.BLUE,
	2: Color.GREEN,
	3: Color.WHITE,
	4: Color.YELLOW,
	5: Color.DIM_GRAY,
	6: Color.RED,
	7: Color(0.110088, 0.0, 0.188627, 1),
	-1: Color.TRANSPARENT
}

# Cached values for performance
var _sector_rect_size: float
var _total_horizontal_sectors: int
var _total_vertical_sectors: int
var _third_indent: float # Cache sector_indent/3.0
var _two_thirds_indent: float # Cache 1200-sector_indent/3.0
var _cached_level_set: int = -1
var _cached_horizontal_sectors: int = 0
var _cached_vertical_sectors: int = 0


func _ready() -> void:
	CurrentMapData.host_stations = $HostStations
	CurrentMapData.squads = $Squads
	font = ThemeDB.fallback_font
	EventSystem.hoststation_added.connect(add_hoststation)
	EventSystem.squad_added.connect(add_squad)
	EventSystem.map_updated.connect(_on_map_changed)
	EventSystem.map_view_updated.connect(request_redraw)
	# Units move their own Sprite2D (not the map canvas); track them so add/remove
	# and drag still re-composite the viewport under on-demand rendering.
	$HostStations.child_entered_tree.connect(_on_unit_entered)
	$Squads.child_entered_tree.connect(_on_unit_entered)
	$HostStations.child_exiting_tree.connect(_on_unit_exited)
	$Squads.child_exiting_tree.connect(_on_unit_exited)
	EventSystem.global_right_clicked.connect(func(x, y):
		right_clicked_x_global = x
		right_clicked_y_global = y
	)
	EventSystem.map_created.connect(func():
		map_camera.zoom = Constants.DEFAULT_ZOOM
		_invalidate_cache()
		_center_camera()
		request_redraw()
		view_changed.emit()
		)
	_sector_rect_size = Constants.SECTOR_SIZE - (sector_indent * 2)
	_third_indent = sector_indent / 3.0
	_two_thirds_indent = Constants.SECTOR_SIZE - _third_indent
	# Idle by default: _process only runs while a zoom key is held (see _input).
	set_process(false)


func _on_map_changed() -> void:
	"""Called when map data changes to invalidate cache and redraw."""
	_invalidate_cache()
	request_redraw()


func _invalidate_cache() -> void:
	"""Invalidate cached map dimensions."""
	_cached_horizontal_sectors = 0
	_cached_vertical_sectors = 0
	_cached_level_set = -1


func _input(event: InputEvent) -> void:
	# Start polling only when a zoom key goes down; _process stops itself on release.
	if event is InputEventKey and (event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out")):
		set_process(true)


func _process(delta) -> void:
	if Input.is_action_pressed("zoom_out"):
		_zoom_keyboard(-zoom_speed * delta)
	elif Input.is_action_pressed("zoom_in"):
		_zoom_keyboard(zoom_speed * delta)
	else:
		set_process(false)  # no zoom key held -> stop per-frame polling


# --- On-demand rendering -----------------------------------------------------
# The SubViewport renders only when something changes (UPDATE_ONCE, which Godot
# resets to UPDATE_DISABLED after one frame). A static map therefore costs no
# per-frame re-rasterization regardless of zoom. Every visual change must route
# through request_redraw()/request_viewport_update() to schedule that one frame.

func _mark_viewport_dirty() -> void:
	var vp := get_viewport()
	if vp is SubViewport:
		(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE


func request_redraw() -> void:
	# Map content or camera changed: re-run _draw() and render the viewport once.
	_mark_viewport_dirty()
	queue_redraw()


func request_viewport_update() -> void:
	# Only the composite changed (e.g. a unit sprite moved): no _draw() needed,
	# just re-render the viewport once.
	_mark_viewport_dirty()


func _on_unit_entered(node: Node) -> void:
	if node is Unit:
		if not node.position_changed.is_connected(request_viewport_update):
			node.position_changed.connect(request_viewport_update)
		# create()/positioning runs synchronously after add_child this same frame,
		# so the scheduled render shows the finished unit.
		request_viewport_update()


func _on_unit_exited(node: Node) -> void:
	# Render after the node has actually left (queue_free defers to frame end).
	if node is Unit:
		call_deferred("request_viewport_update")


# --- Camera (pan / zoom) -----------------------------------------------------

func pan_by(screen_delta: Vector2) -> void:
	"""Pan the view by a screen-space mouse delta (middle-mouse drag)."""
	if map_camera.zoom.x <= 0.0 or map_camera.zoom.y <= 0.0:
		return
	map_camera.position -= screen_delta / map_camera.zoom
	_clamp_camera()
	request_redraw()
	view_changed.emit()


func set_view_center(center: Vector2) -> void:
	"""Move the camera so `center` (world coords) is at the view centre. Used by scrollbars."""
	map_camera.position = center
	_clamp_camera()
	request_redraw()
	view_changed.emit()


func get_view_metrics() -> Dictionary:
	"""World-space extents the scrollbars need: map size, visible window size, centre."""
	_ensure_dimension_cache()
	var view_size := get_viewport().get_visible_rect().size
	var zoom := map_camera.zoom
	var view_w := view_size.x / zoom.x if zoom.x > 0.0 else 0.0
	var view_h := view_size.y / zoom.y if zoom.y > 0.0 else 0.0
	return {
		"map_w": float(_total_horizontal_sectors * Constants.SECTOR_SIZE),
		"map_h": float(_total_vertical_sectors * Constants.SECTOR_SIZE),
		"view_w": view_w,
		"view_h": view_h,
		"center": map_camera.position,
	}


func zoom_at_cursor(factor: float) -> void:
	"""Zoom keeping the world point under the mouse fixed (mouse wheel)."""
	var new_zoom: Vector2 = (map_camera.zoom * factor).clamp(zoom_minimum, zoom_maximum)
	if new_zoom.is_equal_approx(map_camera.zoom):
		return
	var world_before := get_local_mouse_position()
	map_camera.zoom = new_zoom
	var world_after := get_local_mouse_position()
	map_camera.position += world_before - world_after
	_clamp_camera()
	request_redraw()
	view_changed.emit()


func _zoom_keyboard(delta_zoom: Vector2) -> void:
	"""Zoom around the view center (keyboard +/-)."""
	var new_zoom: Vector2 = (map_camera.zoom + delta_zoom).clamp(zoom_minimum, zoom_maximum)
	if new_zoom.is_equal_approx(map_camera.zoom):
		return
	map_camera.zoom = new_zoom
	_clamp_camera()
	request_redraw()
	view_changed.emit()


func on_view_changed() -> void:
	"""Called when the panel/window resizes or the map dimensions change."""
	_ensure_dimension_cache()
	_clamp_camera()
	request_redraw()
	view_changed.emit()


func _center_camera() -> void:
	_ensure_dimension_cache()
	map_camera.position = Vector2(
		_total_horizontal_sectors * Constants.SECTOR_SIZE,
		_total_vertical_sectors * Constants.SECTOR_SIZE) * 0.5
	_clamp_camera()


func _clamp_camera() -> void:
	"""Keep the visible rect inside the map footprint; center when map < view."""
	_ensure_dimension_cache()
	var view_size := get_viewport().get_visible_rect().size
	var zoom := map_camera.zoom
	if zoom.x <= 0.0 or zoom.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	var half := Vector2(view_size.x / zoom.x, view_size.y / zoom.y) * 0.5
	var map_w := float(_total_horizontal_sectors * Constants.SECTOR_SIZE)
	var map_h := float(_total_vertical_sectors * Constants.SECTOR_SIZE)
	var pos := map_camera.position
	if map_w <= half.x * 2.0:
		pos.x = map_w * 0.5
	else:
		pos.x = clampf(pos.x, half.x, map_w - half.x)
	if map_h <= half.y * 2.0:
		pos.y = map_h * 0.5
	else:
		pos.y = clampf(pos.y, half.y, map_h - half.y)
	map_camera.position = pos


func _ensure_dimension_cache() -> void:
	if (_cached_horizontal_sectors != CurrentMapData.horizontal_sectors or
		_cached_vertical_sectors != CurrentMapData.vertical_sectors or
		_cached_level_set != CurrentMapData.level_set):
		_cached_horizontal_sectors = CurrentMapData.horizontal_sectors
		_cached_vertical_sectors = CurrentMapData.vertical_sectors
		_cached_level_set = CurrentMapData.level_set
		_total_horizontal_sectors = CurrentMapData.horizontal_sectors + 2
		_total_vertical_sectors = CurrentMapData.vertical_sectors + 2


# --- Pure helpers (testable, no node state) ----------------------------------

static func playable_index(x: int, y: int, w: int) -> int:
	"""Index into typ/own/blg maps (size w*h) for a playable cell (1..w, 1..h)."""
	return (y - 1) * w + (x - 1)


static func border_index(x: int, y: int, w: int) -> int:
	"""Index into hgt map (footprint size (w+2)*(h+2)) for cell (0..w+1, 0..h+1)."""
	return y * (w + 2) + x


static func compute_visible_sector_range(center: Vector2, zoom: Vector2, view_size: Vector2,
		total_h: int, total_v: int, margin: int, sector_size: int) -> Rect2i:
	"""Clamped [x0,x1) x [y0,y1) sector range covering the camera's visible rect."""
	if zoom.x <= 0.0 or zoom.y <= 0.0 or view_size.x <= 0.0 or view_size.y <= 0.0:
		return Rect2i(0, 0, total_h, total_v)
	var half := Vector2(view_size.x / zoom.x, view_size.y / zoom.y) * 0.5
	var min_world := center - half
	var max_world := center + half
	var x0 := int(floor(min_world.x / sector_size)) - margin
	var y0 := int(floor(min_world.y / sector_size)) - margin
	var x1 := int(floor(max_world.x / sector_size)) + 1 + margin
	var y1 := int(floor(max_world.y / sector_size)) + 1 + margin
	x0 = clampi(x0, 0, total_h)
	y0 = clampi(y0, 0, total_v)
	x1 = clampi(x1, 0, total_h)
	y1 = clampi(y1, 0, total_v)
	if x1 < x0:
		x1 = x0
	if y1 < y0:
		y1 = y0
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _is_valid_map_size() -> bool:
	return CurrentMapData.horizontal_sectors != 0 and CurrentMapData.vertical_sectors != 0


func _draw() -> void:
	if not _is_valid_map_size():
		return

	_ensure_dimension_cache()

	var total_h := _total_horizontal_sectors
	var horizontal_sectors := _cached_horizontal_sectors
	var level_set := _cached_level_set

	# Only iterate the sectors that intersect the camera's visible rect.
	var rng := compute_visible_sector_range(
		map_camera.position, map_camera.zoom, get_viewport().get_visible_rect().size,
		total_h, _total_vertical_sectors, CULL_MARGIN, Constants.SECTOR_SIZE)
	var x_start := rng.position.x
	var y_start := rng.position.y
	var x_end := rng.position.x + rng.size.x
	var y_end := rng.position.y + rng.size.y

	# Precompute a border_idx -> selected lookup (replaces per-sector any()).
	var selected_set := {}
	for sector_dict in EditorState.selected_sectors:
		selected_set[int(sector_dict.border_idx)] = true

	var rect_base := Rect2(0, 0, _sector_rect_size, _sector_rect_size)
	var selection_color := Color(0.184314, 0.309804, 0.309804, 0.6)
	var full_sector := Vector2(Constants.SECTOR_SIZE, Constants.SECTOR_SIZE)

	for y_sector in range(y_start, y_end):
		var v_grid := y_sector * Constants.SECTOR_SIZE
		var row_border_base := y_sector * total_h

		for x_sector in range(x_start, x_end):
			var h_grid := x_sector * Constants.SECTOR_SIZE
			var border_sector := row_border_base + x_sector

			if _is_valid_sector(x_sector, y_sector):
				var current_sector := (y_sector - 1) * horizontal_sectors + (x_sector - 1)
				_draw_sector_content(current_sector, h_grid, v_grid, rect_base, level_set)
				_draw_height_differences(border_sector, x_sector, y_sector, h_grid, v_grid,
						horizontal_sectors, _cached_vertical_sectors)

			if selected_set.has(border_sector):
				draw_rect(Rect2(Vector2(h_grid, v_grid), full_sector), selection_color)

	# Special elements + value overlays (value overlays are culled to rng).
	_draw_beam_gates()
	_draw_bombs()
	_draw_tech_upgrades()
	_draw_sector_values(rng)
	_draw_selection_rect()


func _is_valid_sector(x: int, y: int) -> bool:
	return x > 0 and x < _total_horizontal_sectors - 1 and y > 0 and y < _total_vertical_sectors - 1


func _draw_sector_content(current_sector: int, h_grid: int, v_grid: int, rect_base: Rect2, level_set: int) -> void:
	var typ := CurrentMapData.typ_map[current_sector]
	var blg := CurrentMapData.blg_map[current_sector]
	var rect := rect_base
	rect.position = Vector2(h_grid + sector_indent, v_grid + sector_indent)

	# Draw typ map image
	var top_img: Texture2D = Preloads.get_building_top_image(level_set, typ)
	if top_img != null:
		if EditorState.typ_map_images_visible:
			draw_texture_rect(top_img,
					 Rect2(h_grid, v_grid, Constants.SECTOR_SIZE, Constants.SECTOR_SIZE), false)
	else:
		draw_texture_rect(Preloads.error_sign, rect, false)

	# Draw special building indicators
	if (blg == Constants.SPECIAL_BUILDING_62 and level_set in [Constants.LEVEL_SET_3, Constants.LEVEL_SET_4, Constants.LEVEL_SET_5]) or (blg == Constants.SPECIAL_BUILDING_55 and level_set in [Constants.LEVEL_SET_2, Constants.LEVEL_SET_5]):
		draw_texture_rect(Preloads.error_sign, rect, false)

	if Preloads.special_building_images.has(blg):
		draw_texture_rect(Preloads.special_building_images[blg], rect, false)

	# Draw owner color
	var owner_id := CurrentMapData.own_map[current_sector]
	var color_index := owner_id if owner_id >= 0 and owner_id <= 7 else -1
	draw_rect(rect, _owner_colors[color_index], false, -1.0)


func _draw_height_differences(border_sector: int, x: int, y: int, h_grid: int, v_grid: int, horizontal_sectors: int, vertical_sectors: int) -> void:
	var hgt_map := CurrentMapData.hgt_map
	var height_threshold := Constants.HEIGHT_THRESHOLD

	# Top edge - check if sector above is higher
	if y > 1 and hgt_map[border_sector - (horizontal_sectors + 2)] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + sector_indent, v_grid + _third_indent),
			Vector2(h_grid + Constants.SECTOR_SIZE - sector_indent, v_grid + _third_indent),
			Color.AQUA,
			-1.0
		)

	# Right edge - check if sector to the right is higher
	if x < horizontal_sectors and hgt_map[border_sector + 1] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + _two_thirds_indent, v_grid + sector_indent),
			Vector2(h_grid + _two_thirds_indent, v_grid + Constants.SECTOR_SIZE - sector_indent),
			Color.AQUA,
			-1.0
		)

	# Bottom edge - check if sector below is higher
	if y < vertical_sectors and hgt_map[border_sector + (horizontal_sectors + 2)] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + sector_indent, v_grid + _two_thirds_indent),
			Vector2(h_grid + Constants.SECTOR_SIZE - sector_indent, v_grid + _two_thirds_indent),
			Color.AQUA,
			-1.0
		)

	# Left edge - check if sector to the left is higher
	if x > 1 and hgt_map[border_sector - 1] - hgt_map[border_sector] > height_threshold:
		draw_line(
			Vector2(h_grid + _third_indent, v_grid + sector_indent),
			Vector2(h_grid + _third_indent, v_grid + Constants.SECTOR_SIZE - sector_indent),
			Color.AQUA,
			-1.0
		)


func add_hoststation(owner_id: int, vehicle_id: int) -> void:
	var undo_redo_manager = get_node("/root/UndoRedoManager")
	undo_redo_manager.begin_group("Add host station")
	var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
	var hoststation = Preloads.HOSTSTATION.instantiate()
	CurrentMapData.host_stations.add_child(hoststation)
	hoststation.create(owner_id, vehicle_id)
	hoststation.position.x = clampi(right_clicked_x, Constants.SECTOR_SIZE + 5, ((CurrentMapData.horizontal_sectors + 1) * Constants.SECTOR_SIZE) - 5)
	hoststation.position.y = clampi(right_clicked_y, Constants.SECTOR_SIZE + 5, ((CurrentMapData.vertical_sectors + 1) * Constants.SECTOR_SIZE) - 5)

	EditorState.selected_unit = hoststation
	UnitChangeDispatcher.emit_for_unit(hoststation, "created")
	if CurrentMapData.player_host_station == null or not is_instance_valid(CurrentMapData.player_host_station):
		CurrentMapData.player_host_station = CurrentMapData.host_stations.get_child(0)
	CurrentMapData.is_saved = false
	if CurrentMapData.host_stations.get_child_count() > Constants.HOST_STATION_LIMIT:
		EventSystem.safe_host_station_limit_exceeded.emit()
	undo_redo_manager.record_unit_snapshot(unit_before, undo_redo_manager.create_unit_snapshot())
	undo_redo_manager.commit_group()


func add_squad(owner_id: int, vehicle_id: int) -> void:
	var undo_redo_manager = get_node("/root/UndoRedoManager")
	undo_redo_manager.begin_group("Add squad")
	var unit_before: Dictionary = undo_redo_manager.create_unit_snapshot()
	var squad = Preloads.SQUAD.instantiate()
	CurrentMapData.squads.add_child(squad)
	squad.create(owner_id, vehicle_id)
	squad.position.x = clampi(right_clicked_x, Constants.SECTOR_SIZE + 5, ((CurrentMapData.horizontal_sectors + 1) * Constants.SECTOR_SIZE) - 5)
	squad.position.y = clampi(right_clicked_y, Constants.SECTOR_SIZE + 5, ((CurrentMapData.vertical_sectors + 1) * Constants.SECTOR_SIZE) - 5)

	CurrentMapData.is_saved = false
	EditorState.selected_unit = squad
	UnitChangeDispatcher.emit_for_unit(squad, "created")
	undo_redo_manager.record_unit_snapshot(unit_before, undo_redo_manager.create_unit_snapshot())
	undo_redo_manager.commit_group()

func _draw_key_sector(pos_x: int, pos_y: int, texture) -> void:
	var key_rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)
	draw_texture_rect(texture, key_rect, false)

func _draw_beam_gates() -> void:
	for beam_gate in CurrentMapData.beam_gates:
		var pos_x := int(beam_gate.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(beam_gate.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)

		draw_texture_rect(Preloads.sector_item_images.beam_gate, rect, false)

		if beam_gate.target_levels.is_empty():
			draw_texture_rect(Preloads.error_sign, rect, false)

		for key_sector in beam_gate.key_sectors:
			_draw_key_sector(
				int(key_sector.x * Constants.SECTOR_SIZE + sector_indent),
				int(key_sector.y * Constants.SECTOR_SIZE + sector_indent),
				Preloads.sector_item_images.beam_gate_key_sector
			)

func _draw_bombs() -> void:
	for bomb in CurrentMapData.stoudson_bombs:
		var pos_x := int(bomb.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(bomb.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)

		draw_texture_rect(Preloads.sector_item_images.stoudson_bomb, rect, false)

		if bomb.inactive_bp == Constants.INACTIVE_BP_68 and CurrentMapData.level_set in [Constants.LEVEL_SET_2, Constants.LEVEL_SET_3, Constants.LEVEL_SET_4, Constants.LEVEL_SET_5]:
			draw_texture_rect(Preloads.error_sign, rect, false)

		for key_sector in bomb.key_sectors:
			_draw_key_sector(
				int(key_sector.x * Constants.SECTOR_SIZE + sector_indent),
				int(key_sector.y * Constants.SECTOR_SIZE + sector_indent),
				Preloads.sector_item_images.bomb_key_sector
			)

func _draw_tech_upgrades() -> void:
	for tech_upgrade in CurrentMapData.tech_upgrades:
		var pos_x := int(tech_upgrade.sec_x * Constants.SECTOR_SIZE + sector_indent)
		var pos_y := int(tech_upgrade.sec_y * Constants.SECTOR_SIZE + sector_indent)
		var rect := Rect2(pos_x, pos_y, _sector_rect_size, _sector_rect_size)

		var texture = Preloads.sector_item_images.tech_upgrades.get(
			tech_upgrade.building_id,
			Preloads.sector_item_images.tech_upgrades["unknown"]
		)
		draw_texture_rect(texture, rect, false)

		if tech_upgrade.building_id == Constants.TECH_UPGRADE_BUILDING_ID_60 and CurrentMapData.level_set != Constants.LEVEL_SET_5:
			draw_texture_rect(Preloads.error_sign, rect, false)

func _draw_sector_values(rng: Rect2i) -> void:
	if not (EditorState.typ_map_values_visible or
			EditorState.own_map_values_visible or
			EditorState.hgt_map_values_visible or
			EditorState.blg_map_values_visible):
		return

	var total_h := _total_horizontal_sectors
	var horizontal_sectors := _cached_horizontal_sectors
	var x_end := rng.position.x + rng.size.x
	var y_end := rng.position.y + rng.size.y
	var base_pos := Vector2.ZERO

	for y_sector in range(rng.position.y, y_end):
		var v_grid := y_sector * Constants.SECTOR_SIZE
		var row_border_base := y_sector * total_h

		for x_sector in range(rng.position.x, x_end):
			var h_grid := x_sector * Constants.SECTOR_SIZE
			var border_sector := row_border_base + x_sector

			if _is_valid_sector(x_sector, y_sector):
				var current_sector := (y_sector - 1) * horizontal_sectors + (x_sector - 1)
				base_pos.x = h_grid + sector_indent
				base_pos.y = v_grid

				if EditorState.typ_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size),
							  "typ: " + str(CurrentMapData.typ_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)

				if EditorState.own_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size * 2),
							  "own: " + str(CurrentMapData.own_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)

				if EditorState.blg_map_values_visible:
					draw_string(font, base_pos + Vector2(0, sector_font_size * 4),
							  "blg: " + str(CurrentMapData.blg_map[current_sector]),
							  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)

			if EditorState.hgt_map_values_visible:
				draw_string(font, Vector2(h_grid + sector_indent, v_grid + sector_font_size * 3),
						  "hgt: " + str(CurrentMapData.hgt_map[border_sector]),
						  HORIZONTAL_ALIGNMENT_LEFT, -1, sector_font_size)

func _draw_selection_rect() -> void:
	if not (is_multi_selection and selection_start_point != Vector2.ZERO):
		return

	current_mouse_pos = get_local_mouse_position()
	current_mouse_pos.x = clampf(current_mouse_pos.x, 0, _total_horizontal_sectors * Constants.SECTOR_SIZE)
	current_mouse_pos.y = clampf(current_mouse_pos.y, 0, _total_vertical_sectors * Constants.SECTOR_SIZE)

	var rect_size := current_mouse_pos - selection_start_point
	draw_rect(Rect2(selection_start_point, rect_size), Color.CHARTREUSE, false, -1.0)

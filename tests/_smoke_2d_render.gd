extends SceneTree

# Manual runtime smoke test (NOT auto-discovered: filename lacks "test_" prefix).
# Instantiates the real 2D map scene, drives a synthetic map through map_created,
# and exercises _draw() culling + camera pan/zoom/clamp across several frames to
# surface runtime errors that the headless unit suite (which never instantiates
# the 2D scene) cannot. Run:
#   ./Godot ... --headless --path . --script res://tests/_smoke_2d_render.gd
#
# Autoloads are fetched via get_node at runtime: a --script SceneTree file is
# compiled before autoload globals are registered, so they can't be named directly.

var _frame := 0
var _bars_ok := true
var _resize_page_before := 0.0
var _map: Node2D
var _inst: Control
var _unit: Node
var _ev: Node
var _cmd: Node
var _es: Node


func _init() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_ev = root.get_node_or_null("/root/EventSystem")
	_cmd = root.get_node_or_null("/root/CurrentMapData")
	_es = root.get_node_or_null("/root/EditorState")
	if _ev == null or _cmd == null or _es == null:
		print("SMOKE_SKIP autoloads unavailable ev=%s cmd=%s es=%s" % [_ev, _cmd, _es])
		quit(0)
		return
	_inst = load("res://map/map_container.tscn").instantiate()
	root.add_child(_inst)
	# Top-left anchors so the harness controls the panel size directly (the scene
	# root is full-rect; under the bare Window that would track the window size).
	_inst.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_inst.size = Vector2(1000, 700)
	_map = _inst.get_node("%Map")
	_build_map(64, 64)
	_ev.map_created.emit()
	process_frame.connect(_on_frame)


func _build_map(w: int, h: int) -> void:
	_cmd.horizontal_sectors = w
	_cmd.vertical_sectors = h
	var playable := w * h
	var footprint := (w + 2) * (h + 2)
	_cmd.typ_map = PackedByteArray()
	_cmd.typ_map.resize(playable)
	_cmd.own_map = PackedByteArray()
	_cmd.own_map.resize(playable)
	_cmd.blg_map = PackedByteArray()
	_cmd.blg_map.resize(playable)
	_cmd.hgt_map = PackedByteArray()
	_cmd.hgt_map.resize(footprint)
	for i in footprint:
		_cmd.hgt_map[i] = (i * 7) % 32  # variation -> height-diff lines
	for i in playable:
		_cmd.own_map[i] = i % 8

	# Exercise selection highlight + value overlays + culling on a big map.
	var mid_x := w / 2
	var mid_y := h / 2
	_es.selected_sectors.clear()
	_es.selected_sectors.append({
		"border_idx": mid_y * (w + 2) + mid_x,
		"x": mid_x, "y": mid_y,
		"idx": (mid_y - 1) * w + (mid_x - 1),
	})
	_es.hgt_map_values_visible = true
	_es.typ_map_values_visible = true
	_es.own_map_values_visible = true


func _on_frame() -> void:
	_frame += 1
	match _frame:
		1:
			_map.request_redraw()
		2:
			_map.pan_by(Vector2(400, 250)); _map.request_redraw()
		3:
			_map.zoom_at_cursor(1.3); _map.request_redraw()
		4:
			_map.zoom_at_cursor(0.4); _map.request_redraw()
		5:
			_map.pan_by(Vector2(-99999, -99999)); _map.request_redraw()  # clamp to min
		6:
			_map.pan_by(Vector2(99999, 99999)); _map.request_redraw()    # clamp to max
		7:
			_map.on_view_changed(); _map.request_redraw()
		8:
			# Drive the camera via the scrollbars (exercises the two-way binding).
			var hsb: HScrollBar = _inst.get_node("%HScrollBar")
			var vsb: VScrollBar = _inst.get_node("%VScrollBar")
			hsb.value = hsb.max_value * 0.25
			vsb.value = vsb.max_value * 0.75
			_map.request_redraw()
		9:
			# 64x64 overflows the view at every allowed zoom -> both bars visible.
			_report_bars("big-map-overflow", true, true)
			# Both bars visible -> the viewport is inset (gutter) on both axes.
			_report_gutter("big-map", true, true)
			# Resize the panel WITHOUT calling on_view_changed: only the
			# SubViewport.size_changed hook can re-sync (the maximize/restore fix).
			_resize_page_before = (_inst.get_node("%HScrollBar") as HScrollBar).page
			_inst.size = Vector2(600, 700)
		11:
			var page_after: float = (_inst.get_node("%HScrollBar") as HScrollBar).page
			_report_resize(_resize_page_before, page_after)
			# Switch to a tiny map that fully fits the view -> no overflow -> hidden.
			_inst.size = Vector2(1000, 700)
			_build_map(2, 2)
			_ev.map_created.emit()
		13:
			_report_bars("small-map-fits", false, false)
			# No bars -> the viewport fills the whole panel (no gutter).
			_report_gutter("small-map", false, false)
			# The dummy headless renderer never consumes UPDATE_ONCE, so clear it
			# ourselves and then watch what our code does on idle / on changes.
			_set_vp_mode(SubViewport.UPDATE_DISABLED)
		14:
			# Static map: nothing re-bumps the viewport (no per-frame work).
			_report_mode("idle", SubViewport.UPDATE_DISABLED)
			# Adding a unit must schedule one render (on-demand).
			_unit = load("res://map/ua_structures/unit.tscn").instantiate()
			_map.get_node("HostStations").add_child(_unit)
		15:
			_report_mode("unit-added", SubViewport.UPDATE_ONCE)
			_set_vp_mode(SubViewport.UPDATE_DISABLED)
			_unit.position_changed.emit()  # simulate a drag step
		16:
			_report_mode("unit-moved", SubViewport.UPDATE_ONCE)
			# _process idle-gating: nothing dragging/zooming -> no per-frame _process.
			_report_processing("map-idle", _map, false)
			_report_processing("unit-idle", _unit, false)
			# The _input handler must re-enable _process on a zoom-key press. (The
			# engine routes _input to every node in the SubViewport - the sibling
			# InputHandler relies on the same path - so we exercise the handler
			# directly and check the flag flips before _process self-disables.)
			var ev := InputEventKey.new()
			ev.physical_keycode = 4194437  # KP_ADD -> the "zoom_in" action
			ev.pressed = true
			print("SMOKE_PROC zoom-event-matches is_action_pressed=%s" % ev.is_action_pressed("zoom_in"))
			_map._input(ev)
			_report_processing("map-zoom-enables", _map, true)
			_finish()


func _vp() -> SubViewport:
	return _inst.get_node("SubViewportMapContainer/SubViewport")


func _set_vp_mode(mode: int) -> void:
	_vp().render_target_update_mode = mode


func _report_mode(label: String, want: int) -> void:
	var got: int = _vp().render_target_update_mode
	var ok: bool = got == want
	if not ok:
		_bars_ok = false
	print("SMOKE_MODE %s mode=%d want=%d %s" % [label, got, want, "OK" if ok else "FAIL"])


func _report_processing(label: String, node: Node, want: bool) -> void:
	var got: bool = node.is_processing()
	var ok: bool = got == want
	if not ok:
		_bars_ok = false
	print("SMOKE_PROC %s processing=%s want=%s %s" % [label, got, want, "OK" if ok else "FAIL"])


func _report_gutter(label: String, want_w_inset: bool, want_h_inset: bool) -> void:
	# A visible bar must shrink the SubViewport on its axis (VScrollBar -> width,
	# HScrollBar -> height) so the bar sits in a gutter beside the map, not over it.
	var sv: SubViewport = _inst.get_node("SubViewportMapContainer/SubViewport")
	var panel: Vector2 = _inst.size
	var w_inset: bool = float(sv.size.x) < panel.x - 1.0
	var h_inset: bool = float(sv.size.y) < panel.y - 1.0
	var ok: bool = w_inset == want_w_inset and h_inset == want_h_inset
	if not ok:
		_bars_ok = false
	print("SMOKE_GUTTER %s sv=%s panel=%s w_inset=%s h_inset=%s %s" % [
		label, sv.size, panel, w_inset, h_inset, "OK" if ok else "FAIL"])


func _report_resize(before: float, after: float) -> void:
	# A panel resize must change the visible-world page via SubViewport.size_changed,
	# with no manual on_view_changed call.
	var ok: bool = not is_equal_approx(before, after)
	if not ok:
		_bars_ok = false
	print("SMOKE_RESIZE page_before=%.1f page_after=%.1f changed=%s %s" % [
		before, after, ok, "OK" if ok else "FAIL"])


func _report_bars(label: String, want_h: bool, want_v: bool) -> void:
	var hsb: HScrollBar = _inst.get_node("%HScrollBar")
	var vsb: VScrollBar = _inst.get_node("%VScrollBar")
	var ok: bool = hsb.visible == want_h and vsb.visible == want_v
	if not ok:
		_bars_ok = false
	print("SMOKE_BARS %s h=%s v=%s (want %s/%s) %s" % [
		label, hsb.visible, vsb.visible, want_h, want_v, "OK" if ok else "FAIL"])


func _finish() -> void:
	var cam: Camera2D = _map.map_camera
	print("SMOKE_OK frames=%d bars_ok=%s final_zoom=%s view=%s" % [
		_frame, _bars_ok, cam.zoom, _map.get_viewport().get_visible_rect().size])
	quit(0 if _bars_ok else 1)

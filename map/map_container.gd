extends Control

# Camera-driven 2D map panel.
# Panning moves Camera2D.position (was ScrollContainer scroll); the SubViewport is
# sized to the visible panel only (was zoom * whole-map-size), so the GPU render
# target stays small regardless of map size or zoom.

const WHEEL_ZOOM_FACTOR := 1.1
const SCROLLBAR_THICKNESS := 14.0

var is_dragging: bool = false
var _syncing_scrollbars: bool = false

@onready var sub_viewport_map_container = %SubViewportMapContainer
@onready var sub_viewport: SubViewport = $SubViewportMapContainer/SubViewport
@onready var map = %Map
@onready var h_scroll: HScrollBar = %HScrollBar
@onready var v_scroll: VScrollBar = %VScrollBar


func _ready():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().root.size_changed.connect(_on_resize)
	# root.size_changed fires BEFORE the SubViewportContainer relays out the
	# SubViewport, so it carries the stale render size (maximize/restore would not
	# update the scrollbars until a manual interaction). The SubViewport's own
	# size_changed fires once the render size has settled, so sync off that too.
	sub_viewport.size_changed.connect(_on_resize)
	EventSystem.map_created.connect(_on_ui_map_created)
	EventSystem.map_load_started.connect(_on_map_load_started)
	EventSystem.map_load_finished.connect(_on_map_load_finished)
	sub_viewport_map_container.gui_input.connect(_on_map_gui_input)
	map.view_changed.connect(_sync_scrollbars)
	h_scroll.value_changed.connect(_on_h_scroll)
	v_scroll.value_changed.connect(_on_v_scroll)
	_on_resize()
	_sync_scrollbars()


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					is_dragging = true
					Input.set_default_cursor_shape(Input.CURSOR_DRAG)
				else:
					is_dragging = false
					Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					map.zoom_at_cursor(WHEEL_ZOOM_FACTOR)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					map.zoom_at_cursor(1.0 / WHEEL_ZOOM_FACTOR)
	elif event is InputEventMouseMotion and is_dragging:
		map.pan_by(event.relative)


func _on_ui_map_created():
	_on_resize()


func _on_map_load_started() -> void:
	var o: Control = %Map2DLoadingOverlay
	o.visible = true
	o.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_map_load_finished() -> void:
	var o: Control = %Map2DLoadingOverlay
	o.visible = false
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_resize():
	# Fired on window resize and on every get_tree().root.size_changed.emit()
	# (map create/resize/close). Re-clamp the camera to the (possibly new) map
	# bounds and redraw; the SubViewport is sized by the container, not here.
	# map.on_view_changed() emits view_changed, which re-syncs the scrollbars.
	if map:
		map.on_view_changed()


# --- Scrollbars (camera-driven) ----------------------------------------------
# The scrollbars mirror Camera2D state: value = left/top world edge of the view,
# page = visible world size, max = whole-map world size. _syncing_scrollbars
# guards the two-way binding against feedback (camera move -> bar update -> camera
# move ...).

func _sync_scrollbars() -> void:
	if _syncing_scrollbars or map == null:
		return
	_syncing_scrollbars = true
	var m: Dictionary = map.get_view_metrics()
	# Only show a bar when the map actually overflows the view on that axis.
	var h_overflow: bool = m.map_w > m.view_w + 0.5
	var v_overflow: bool = m.map_h > m.view_h + 0.5
	h_scroll.visible = h_overflow
	v_scroll.visible = v_overflow
	# When only one bar is shown, let it span the full edge (no reserved corner).
	h_scroll.offset_right = -SCROLLBAR_THICKNESS if v_overflow else 0.0
	v_scroll.offset_bottom = -SCROLLBAR_THICKNESS if h_overflow else 0.0
	# Reserve a gutter for each visible bar so the map renders beside it, not under
	# it. Only assign on change: resizing the SubViewport is what re-fires this sync,
	# so unconditional writes would churn layout on every pan. The gutter shrinks the
	# view, which can only increase overflow -> the toggle is hysteretic (no flicker).
	var gutter_right: float = -SCROLLBAR_THICKNESS if v_overflow else 0.0
	var gutter_bottom: float = -SCROLLBAR_THICKNESS if h_overflow else 0.0
	if sub_viewport_map_container.offset_right != gutter_right:
		sub_viewport_map_container.offset_right = gutter_right
	if sub_viewport_map_container.offset_bottom != gutter_bottom:
		sub_viewport_map_container.offset_bottom = gutter_bottom
	_apply_scrollbar(h_scroll, m.map_w, m.view_w, m.center.x)
	_apply_scrollbar(v_scroll, m.map_h, m.view_h, m.center.y)
	_syncing_scrollbars = false


func _apply_scrollbar(bar: ScrollBar, total: float, page: float, center: float) -> void:
	bar.min_value = 0.0
	bar.max_value = total
	bar.page = page
	bar.value = clampf(center - page * 0.5, 0.0, maxf(0.0, total - page))


func _on_h_scroll(value: float) -> void:
	if _syncing_scrollbars or map == null:
		return
	var m: Dictionary = map.get_view_metrics()
	map.set_view_center(Vector2(value + m.view_w * 0.5, m.center.y))


func _on_v_scroll(value: float) -> void:
	if _syncing_scrollbars or map == null:
		return
	var m: Dictionary = map.get_view_metrics()
	map.set_view_center(Vector2(m.center.x, value + m.view_h * 0.5))

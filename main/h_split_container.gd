extends HSplitContainer

@onready var map_container: Control = $MapContainer
@onready var map_3d_container: SubViewportContainer = $Map3DContainer
@onready var map_3d_viewport: SubViewport = $Map3DContainer/SubViewport
@onready var map_3d_renderer: Map3DRenderer = $Map3DContainer/SubViewport/Map3D
@onready var map_3d_loading_overlay: Control = $Map3DContainer/LoadingOverlay
@onready var map_3d_loading_label: Label = $Map3DContainer/LoadingOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var _build_3d_status_label: Label = %Build3DStatusLabel

# Width of the left (map) pane as a fraction of the container, so the split keeps
# the same proportion when the window is resized / maximized / restored instead of
# holding a fixed pixel offset. -1.0 means "not captured yet".
var _split_ratio: float = -1.0
const _MIN_SPLIT_RATIO: float = 0.1
const _MAX_SPLIT_RATIO: float = 0.9

func _ready() -> void:
	EventSystem.map_view_updated.connect(_apply_view_mode)
	if map_3d_renderer != null and is_instance_valid(map_3d_renderer):
		map_3d_renderer.build_state_changed.connect(_on_3d_build_state_changed)
		map_3d_renderer.build_finished.connect(_on_3d_build_finished)
	map_3d_container.resized.connect(_sync_map_3d_loading_overlay_layout)
	map_3d_loading_overlay.visibility_changed.connect(_sync_map_3d_loading_overlay_layout)
	_setup_proportional_split()
	_apply_view_mode()
	call_deferred("_sync_map_3d_loading_overlay_layout")
	_refresh_loading_overlay()


# --- Proportional split ------------------------------------------------------
# HSplitContainer stores a fixed pixel split_offset, so resizing the window changes
# the left/right proportion. We instead remember the split as a ratio of the total
# width, re-applying it on resize and whenever the visible pane set changes, and
# updating it whenever the user drags the splitter.

func _setup_proportional_split() -> void:
	resized.connect(_on_split_resized)
	dragged.connect(_on_split_dragged)
	for child in get_children():
		var pane := child as Control
		if pane != null:
			pane.visibility_changed.connect(_on_pane_visibility_changed)
	# Capture the designed proportion once the first real layout has happened.
	_sync_split.call_deferred()


func _on_split_resized() -> void:
	_sync_split()


func _on_split_dragged(_offset: int = 0) -> void:
	# The user moved the splitter: remember the new proportion.
	_capture_split_ratio()


func _on_pane_visibility_changed() -> void:
	# The visible pane set changed (2D/3D toggle, properties / building-design
	# panel shown or hidden); re-establish the proportion once the layout settles.
	_sync_split.call_deferred()


func _sync_split() -> void:
	if _split_ratio < 0.0:
		_capture_split_ratio()
	else:
		_apply_split_ratio()


func _first_visible_pane() -> Control:
	for child in get_children():
		var pane := child as Control
		if pane != null and pane.visible:
			return pane
	return null


func _visible_pane_count() -> int:
	var count := 0
	for child in get_children():
		var pane := child as Control
		if pane != null and pane.visible:
			count += 1
	return count


func _capture_split_ratio() -> void:
	# Only meaningful when there are two panes to split between.
	if _visible_pane_count() < 2:
		return
	var available := size.x
	var left := _first_visible_pane()
	if available <= 0.0 or left == null or left.size.x <= 0.0:
		return
	_split_ratio = clampf(left.size.x / available, _MIN_SPLIT_RATIO, _MAX_SPLIT_RATIO)


func _apply_split_ratio() -> void:
	if _split_ratio < 0.0 or _visible_pane_count() < 2:
		return
	var available := size.x
	if available <= 0.0:
		return
	# The map pane never uses SIZE_EXPAND, so the split's default (zero-offset)
	# position is the start of the container; that makes split_offset equal to the
	# left pane's width. The proportional width is therefore just ratio * total.
	# Setting it absolutely (instead of nudging by a delta) keeps the proportion
	# exact even when the offset was clamped against a min size at a previous size.
	split_offset = int(round(_split_ratio * available))
	clamp_split_offset()

func _apply_view_mode() -> void:
	map_3d_container.visible = EditorState.view_mode_3d
	map_container.visible = not EditorState.view_mode_3d
	# UPDATE_WHEN_VISIBLE avoids unnecessary redraws while preserving live preview updates in 3D mode.
	map_3d_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if EditorState.view_mode_3d else SubViewport.UPDATE_DISABLED
	_refresh_loading_overlay()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_view"):
		EditorState.view_mode_3d = not EditorState.view_mode_3d


func _on_3d_build_state_changed(is_building: bool, completed: int, total: int, status: String) -> void:
	var progress_text := status
	if status.begins_with("Rendering map") and total > 0:
		progress_text = "%s\n%d / %d chunks" % [status, completed, total]
	elif total > 0:
		progress_text = "%s\nChunks ready: %d / %d" % [status, completed, total]
	map_3d_loading_label.text = progress_text
	map_3d_loading_overlay.visible = EditorState.view_mode_3d and is_building
	_sync_map_3d_loading_overlay_layout()
	_update_status_bar_3d_indicator(is_building, completed, total)


func _on_3d_build_finished(_success: bool) -> void:
	_refresh_loading_overlay()
	_update_status_bar_3d_indicator(false, 0, 0)


func _update_status_bar_3d_indicator(is_building: bool, completed: int, total: int) -> void:
	if _build_3d_status_label == null:
		return
	if not is_building or EditorState.view_mode_3d:
		_build_3d_status_label.text = ""
		return
	if total > 0:
		_build_3d_status_label.text = "| 3D: %d/%d chunks" % [completed, total]
	else:
		_build_3d_status_label.text = "| 3D: Building..."


func _refresh_loading_overlay() -> void:
	if map_3d_renderer == null or not is_instance_valid(map_3d_renderer):
		map_3d_loading_overlay.visible = false
		return
	var build_state := map_3d_renderer.get_build_state_snapshot()
	var text: String = String(build_state.get("status_text", ""))
	var completed := int(build_state.get("completed_chunks", 0))
	var total := int(build_state.get("total_chunks", 0))
	var is_building := bool(build_state.get("is_building_3d", false))
	if text.begins_with("Rendering map") and total > 0:
		text = "%s\n%d / %d chunks" % [text, completed, total]
	elif total > 0:
		text = "%s\nChunks ready: %d / %d" % [text, completed, total]
	map_3d_loading_label.text = text if not text.is_empty() else "Rendering map..."
	map_3d_loading_overlay.visible = EditorState.view_mode_3d and is_building
	_sync_map_3d_loading_overlay_layout()
	_update_status_bar_3d_indicator(is_building, completed, total)


func _sync_map_3d_loading_overlay_layout() -> void:
	if map_3d_loading_overlay == null or not is_instance_valid(map_3d_loading_overlay):
		return
	if map_3d_container == null or not is_instance_valid(map_3d_container):
		return
	map_3d_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

extends HSplitContainer

@onready var map_container: ScrollContainer = $MapContainer
@onready var map_3d_container: SubViewportContainer = $Map3DContainer
@onready var map_3d_viewport: SubViewport = $Map3DContainer/SubViewport
@onready var map_3d_renderer: Map3DRenderer = $Map3DContainer/SubViewport/Map3D
@onready var map_3d_loading_overlay: Control = $Map3DContainer/LoadingOverlay
@onready var map_3d_loading_label: Label = $Map3DContainer/LoadingOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var _build_3d_status_label: Label = %Build3DStatusLabel

func _ready() -> void:
	EventSystem.map_view_updated.connect(_apply_view_mode)
	if map_3d_renderer != null and is_instance_valid(map_3d_renderer):
		map_3d_renderer.build_state_changed.connect(_on_3d_build_state_changed)
		map_3d_renderer.build_finished.connect(_on_3d_build_finished)
	map_3d_container.resized.connect(_sync_map_3d_loading_overlay_layout)
	map_3d_loading_overlay.visibility_changed.connect(_sync_map_3d_loading_overlay_layout)
	_apply_view_mode()
	call_deferred("_sync_map_3d_loading_overlay_layout")
	_refresh_loading_overlay()

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
	map_3d_loading_overlay.position = Vector2.ZERO
	map_3d_loading_overlay.size = map_3d_container.size

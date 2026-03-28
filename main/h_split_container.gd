extends HSplitContainer

@onready var map_container: ScrollContainer = $MapContainer
@onready var map_3d_container: SubViewportContainer = $Map3DContainer
@onready var map_3d_viewport: SubViewport = $Map3DContainer/SubViewport
@onready var map_3d_renderer: Map3DRenderer = $Map3DContainer/SubViewport/Map3D
@onready var map_3d_loading_overlay: Control = $Map3DContainer/LoadingOverlay
@onready var map_3d_loading_label: Label = $Map3DContainer/LoadingOverlay/PanelContainer/MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	EventSystem.map_view_updated.connect(_apply_view_mode)
	if map_3d_renderer != null and is_instance_valid(map_3d_renderer):
		map_3d_renderer.build_state_changed.connect(_on_3d_build_state_changed)
		map_3d_renderer.build_finished.connect(_on_3d_build_finished)
	_apply_view_mode()
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


func _on_3d_build_finished(_success: bool) -> void:
	_refresh_loading_overlay()


func _refresh_loading_overlay() -> void:
	if map_3d_renderer == null or not is_instance_valid(map_3d_renderer):
		map_3d_loading_overlay.visible = false
		return
	var text: String = String(map_3d_renderer.status_text)
	if text.begins_with("Rendering map") and map_3d_renderer.total_chunks > 0:
		text = "%s\n%d / %d chunks" % [text, map_3d_renderer.completed_chunks, map_3d_renderer.total_chunks]
	elif map_3d_renderer.total_chunks > 0:
		text = "%s\nChunks ready: %d / %d" % [text, map_3d_renderer.completed_chunks, map_3d_renderer.total_chunks]
	map_3d_loading_label.text = text if not text.is_empty() else "Rendering map..."
	map_3d_loading_overlay.visible = EditorState.view_mode_3d and map_3d_renderer.is_building_3d

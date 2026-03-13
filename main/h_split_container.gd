extends HSplitContainer

@onready var map_container: ScrollContainer = $MapContainer
@onready var map_3d_container: SubViewportContainer = $Map3DContainer
@onready var map_3d_viewport: SubViewport = $Map3DContainer/SubViewport

func _ready() -> void:
	EventSystem.map_view_updated.connect(_apply_view_mode)
	_apply_view_mode()

func _apply_view_mode() -> void:
	map_3d_container.visible = EditorState.view_mode_3d
	map_container.visible = not EditorState.view_mode_3d
	map_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if EditorState.view_mode_3d else SubViewport.UPDATE_DISABLED

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_view"):
		EditorState.view_mode_3d = not EditorState.view_mode_3d

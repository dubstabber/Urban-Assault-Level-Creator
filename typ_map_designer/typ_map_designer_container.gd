extends PanelContainer

signal container_resized


func _ready() -> void:
	if visible: EditorState.mode = EditorState.State.TypMapDesign
	else: EditorState.mode = EditorState.State.Select
	visibility_changed.connect(func():
		if visible: EditorState.mode = EditorState.State.TypMapDesign
		else: EditorState.mode = EditorState.State.Select
		)
	EventSystem.editor_mode_changed.connect(func():
		if EditorState.mode == EditorState.State.TypMapDesign:
			show()
		elif EditorState.mode == EditorState.State.Select:
			hide()
		)
	_refresh_images()
	EventSystem.level_set_changed.connect(_refresh_images)


func _refresh_images() -> void:
	for child in %TypMapImagesContainer.get_children():
		%TypMapImagesContainer.remove_child(child)
		child.queue_free()
	
	for idx in Preloads.building_side_images[CurrentMapData.level_set]:
		var typ_map_image = TextureButton.new()
		typ_map_image.texture_normal = Preloads.building_side_images[CurrentMapData.level_set][idx]
		typ_map_image.custom_minimum_size.x = 90
		typ_map_image.custom_minimum_size.y = 90
		typ_map_image.ignore_texture_size = true
		typ_map_image.stretch_mode = TextureButton.STRETCH_SCALE
		typ_map_image.set_meta("index", idx)
		typ_map_image.pressed.connect(func():
			EditorState.selected_typ_map = typ_map_image.get_meta("index")
			)
		%TypMapImagesContainer.add_child(typ_map_image)


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		container_resized.emit()

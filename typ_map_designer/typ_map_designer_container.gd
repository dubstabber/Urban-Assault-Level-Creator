extends PanelContainer

signal container_resized

enum ViewModes {
	Side,
	Top
}

@export var BUILDING_BUTTON: PackedScene
@export var button_size := 100.0

var view_mode := ViewModes.Side:
	set(value):
		view_mode = value
		if view_mode == ViewModes.Side:
			for typ_map_img in %TypMapImagesContainer.get_children():
				typ_map_img.show_side_image()
		elif view_mode == ViewModes.Top:
			for typ_map_img in %TypMapImagesContainer.get_children():
				typ_map_img.show_top_image()


func _ready() -> void:
	if not Preloads.ua_data.data.has("original"): return
	if visible: EditorState.mode = EditorState.States.TypMapDesign
	else: EditorState.mode = EditorState.States.Select
	visibility_changed.connect(func():
		if visible: EditorState.mode = EditorState.States.TypMapDesign
		else: EditorState.mode = EditorState.States.Select
		)
	EventSystem.editor_mode_changed.connect(func():
		if EditorState.mode == EditorState.States.TypMapDesign:
			show()
		elif EditorState.mode == EditorState.States.Select:
			hide()
		)
	_refresh_images()
	EventSystem.level_set_changed.connect(_refresh_images)
	%ImagesSlider.value = button_size
	%ImagesSlider.value_changed.connect(func(value: float):
		button_size = value
		for typ_map_button in %TypMapImagesContainer.get_children():
			typ_map_button.custom_minimum_size = Vector2(button_size, button_size)
		container_resized.emit()
		)
	%SideViewCheckBox.pressed.connect(func():
		view_mode = ViewModes.Side
		)
	%TopViewCheckBox.pressed.connect(func():
		view_mode = ViewModes.Top
		)


func _refresh_images() -> void:
	for child in %TypMapImagesContainer.get_children():
		%TypMapImagesContainer.remove_child(child)
		child.queue_free()
	
	if CurrentMapData.level_set > 6 or CurrentMapData.level_set < 1: return
	for idx in Preloads.building_side_images[CurrentMapData.level_set]:
		var typ_map_button = BUILDING_BUTTON.instantiate()
		typ_map_button.side_building_texture = Preloads.building_side_images[CurrentMapData.level_set][idx]
		typ_map_button.top_building_texture = Preloads.building_top_images[CurrentMapData.level_set][idx]
		typ_map_button.building_id = idx
		typ_map_button.custom_minimum_size = Vector2(button_size, button_size)
		%TypMapImagesContainer.add_child(typ_map_button)
		if view_mode == ViewModes.Side: typ_map_button.show_side_image()
		elif view_mode == ViewModes.Top: typ_map_button.show_top_image()


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		container_resized.emit()

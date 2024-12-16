extends TextureButton

var side_building_texture: CompressedTexture2D
var top_building_texture: CompressedTexture2D
var building_id: int

@onready var side_texture_rect: TextureRect = $SideTextureRect
@onready var top_texture_rect: TextureRect = $TopTextureRect


func _ready() -> void:
	side_texture_rect.texture = side_building_texture
	top_texture_rect.texture = top_building_texture
	pressed.connect(func():
		EditorState.selected_typ_map = building_id
		)
	resized.connect(_resize)
	_resize()
	pressed.connect(func():
		get_tree().call_group("building_button", "_unpress")
		button_pressed = true
		)


func _resize() -> void:
	side_texture_rect.custom_minimum_size = Vector2(custom_minimum_size.x / 1.25, custom_minimum_size.y / 1.25)
	top_texture_rect.custom_minimum_size = Vector2(custom_minimum_size.x / 1.25, custom_minimum_size.y / 1.25)


func _unpress() -> void:
	button_pressed = false


func show_side_image() -> void:
	side_texture_rect.show()
	top_texture_rect.hide()


func show_top_image() -> void:
	side_texture_rect.hide()
	top_texture_rect.show()

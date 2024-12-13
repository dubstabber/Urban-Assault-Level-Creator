extends GridContainer

@export var grid_spacing: int = 10
@export var texture_size_ratio: float = 10.5

var typ_map_designer_container: PanelContainer


func _ready():
	typ_map_designer_container = owner.get_node("%TypMapDesignerContainer")
	self["theme_override_constants/h_separation"] = grid_spacing
	self["theme_override_constants/v_separation"] = grid_spacing
	_update_grid_layout()
	typ_map_designer_container.container_resized.connect(_update_grid_layout)


func _update_grid_layout():
	var container_size = typ_map_designer_container.get_size()
	if container_size.x == 0 or grid_spacing == 0:
		return
	
	var column_count = max(1, int(container_size.x / (texture_size_ratio * grid_spacing)))
	columns = column_count
	
	for texture_rect in get_children():
		if texture_rect is TextureRect:
			var _size = container_size.x / column_count - grid_spacing
			texture_rect.rect_min_size = Vector2(_size, _size * texture_size_ratio)

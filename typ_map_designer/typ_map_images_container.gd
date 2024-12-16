extends GridContainer


func _ready():
	_update_grid_layout()
	owner.container_resized.connect(_update_grid_layout)


func _update_grid_layout():
	var container_size = owner.get_size()
	if container_size.x == 0:
		return
	
	var column_count = max(1, int((container_size.x - 20) / owner.button_size))
	columns = column_count

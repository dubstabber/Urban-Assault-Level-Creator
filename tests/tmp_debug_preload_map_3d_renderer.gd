extends SceneTree

func _init() -> void:
	var ok := false
	var err := ""
	# Force compile-time load.
	var script = load("res://map/map_3d_renderer.gd")
	if script == null:
		print("FAILED load map_3d_renderer.gd")
	else:
		print("LOADED map_3d_renderer.gd")
	quit()


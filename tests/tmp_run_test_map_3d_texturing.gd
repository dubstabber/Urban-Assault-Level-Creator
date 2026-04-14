extends SceneTree

func _init() -> void:
	var Test = load("res://tests/test_map_3d_texturing.gd")
	if Test == null:
		push_error("Failed to load test_map_3d_texturing.gd")
		quit(1)
	var t = Test.new()
	var res = t.run()
	print("run() -> ", res)
	# Mirror test_runner semantics: bool true => 0 failures, false => 1 failure.
	if typeof(res) == TYPE_BOOL:
		quit(0 if bool(res) else 1)
	elif typeof(res) == TYPE_INT:
		quit(int(res))
	else:
		quit(1)


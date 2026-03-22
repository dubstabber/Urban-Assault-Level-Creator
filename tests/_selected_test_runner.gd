extends SceneTree


func _init() -> void:
	var test_script := load("res://tests/test_map_3d_texturing.gd")
	if test_script == null:
		push_error("Failed to load selected test file")
		quit(1)
		return
	var test = test_script.new()
	if not test.has_method("run"):
		push_error("Selected test script is missing run()")
		quit(1)
		return
	var failures := int(test.run())
	if failures == 0:
		print("Selected tests passed")
		quit(0)
	else:
		push_error("%d selected test(s) failed" % failures)
		quit(failures)
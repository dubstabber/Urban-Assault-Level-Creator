extends SceneTree

# Run with: godot4 --headless -s res://tests/test_runner.gd

func _init() -> void:
	var Test := load("res://tests/test_map_3d_renderer.gd")
	if Test == null:
		push_error("Failed to load test file")
		quit(1)
		return
	var t = Test.new()
	var failures: int = int(t.run())
	if failures == 0:
		print("All tests passed")
		quit(0)
	else:
		push_error("%d test(s) failed" % failures)
		quit(failures)


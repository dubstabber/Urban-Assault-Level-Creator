extends SceneTree

func _init() -> void:
	var Test = load("res://tests/test_ua_sky_runtime.gd")
	if Test == null:
		push_error("Failed to load test_ua_sky_runtime.gd")
		quit(1)
	var t = Test.new()
	var res = t.run()
	if typeof(res) == TYPE_BOOL:
		quit(0 if bool(res) else 1)
	if typeof(res) == TYPE_INT:
		quit(int(res))
	quit(1)


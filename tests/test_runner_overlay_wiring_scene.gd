extends Node

func _ready() -> void:
	var failures := 0

	var test_script := load("res://tests/test_map_3d_texturing.gd")
	if test_script == null:
		push_error("Failed to load test_map_3d_texturing.gd")
		get_tree().quit(1)
		return

	var t = test_script.new()
	var tests := [
		"test_build_from_current_map_wires_host_stations_into_authored_overlay",
		"test_build_from_current_map_wires_squads_into_authored_overlay",
	]

	for test_name in tests:
		print("RUN ", test_name)
		var ok: bool = bool(t.call(test_name))
		if ok:
			print("OK  ", test_name)
		else:
			print("FAIL", test_name)
			failures += 1

	# Give the MCP harness a moment to collect the log before quitting.
	OS.delay_msec(3000)
	get_tree().quit(failures)


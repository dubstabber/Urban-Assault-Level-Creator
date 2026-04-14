extends SceneTree

# Run with: godot4 --headless -s res://tests/test_runner.gd

func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures := 0
	var dir := "res://tests"
	for f in DirAccess.get_files_at(dir):
		# Skip this runner itself
		# These helper scripts are executed via scenes/automation and are not unit tests.
		if f == "test_runner.gd" or f == "test_runner_scene.gd" or f == "test_runner_overlay_wiring_scene.gd":
			continue
		if not f.ends_with(".gd"):
			continue
		if not f.begins_with("test_"):
			continue
		var path := "%s/%s" % [dir, f]
		var Test := load(path)
		if Test == null:
			push_error("Failed to load test file: %s" % path)
			failures += 1
			continue
		var base_type: String = String(Test.get_instance_base_type())
		if base_type == "EditorScript" or not ClassDB.can_instantiate(base_type):
			print("SKIP ", path, " (editor-only or non-instantiable test script)")
			continue
		var t = Test.new()
		if not t.has_method("run"):
			push_error("Test %s missing run() method" % path)
			failures += 1
			continue
		var res = t.run()
		var count := 0
		if typeof(res) == TYPE_INT:
			count = int(res)
		elif typeof(res) == TYPE_BOOL:
			count = (0 if bool(res) else 1)
		else:
			count = int(res)
		failures += count
	if failures == 0:
		print("All tests passed")
		quit(0)
	else:
		push_error("%d test(s) failed" % failures)
		quit(failures)

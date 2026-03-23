extends Node

#
# Alternative headless runner intended for automation environments where the
# `godot4 --headless -s ...` CLI entrypoint may not be available.
#
# Run via a Godot main scene pointing to `res://tests/test_runner_scene.tscn`.
#
func _ready() -> void:
	var failures := 0
	var dir := "res://tests"

	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		if not f.begins_with("test_"):
			continue
		# Skip runner scripts themselves.
		if f == "test_runner.gd" or f == "test_runner_scene.gd" or f == "_selected_test_runner.gd":
			continue

		var path := "%s/%s" % [dir, f]
		var Test := load(path)
		if Test == null:
			push_error("Failed to load test file: %s" % path)
			failures += 1
			continue

		var base_type: String = String(Test.get_instance_base_type())
		if base_type == "EditorScript" or not ClassDB.can_instantiate(base_type):
			# Unit tests should all be instantiable (RefCounted).
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
		get_tree().quit(0)
	else:
		push_error("%d test(s) failed" % failures)
		get_tree().quit(failures)


extends SceneTree

# Manual runtime smoke (NOT auto-discovered). Loads the real editor scene and
# verifies the 3D subtree is paused (process_mode DISABLED) while the 2D view is
# shown and resumes (INHERIT) when switching to 3D. Run:
#   ./Godot ... --headless --path . --script res://tests/_smoke_3d_pause.gd

var _frame := 0
var _ok := true
var _main: Node
var _map3d: Node
var _es: Node


func _init() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_es = root.get_node_or_null("/root/EditorState")
	if _es == null:
		print("SMOKE3D_SKIP no EditorState")
		quit(0)
		return
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	_map3d = _main.find_child("Map3D", true, false)
	if _map3d == null:
		print("SMOKE3D_SKIP Map3D node not found")
		quit(0)
		return
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frame += 1
	match _frame:
		2:
			_report("initial-2d", _map3d.process_mode, Node.PROCESS_MODE_DISABLED)
			_es.view_mode_3d = true
		4:
			_report("switched-3d", _map3d.process_mode, Node.PROCESS_MODE_INHERIT)
			_es.view_mode_3d = false
		6:
			_report("back-to-2d", _map3d.process_mode, Node.PROCESS_MODE_DISABLED)
			print("SMOKE3D_OK ok=%s" % _ok)
			quit(0 if _ok else 1)


func _report(label: String, got: int, want: int) -> void:
	var ok: bool = got == want
	if not ok:
		_ok = false
	print("SMOKE3D %s process_mode=%d want=%d %s" % [label, got, want, "OK" if ok else "FAIL"])

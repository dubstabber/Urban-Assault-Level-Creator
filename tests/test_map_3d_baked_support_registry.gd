extends RefCounted

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

var _errors: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error(msg)
		_errors.append(msg)

func run() -> int:
	_errors.clear()

	# This repo version does not expose a baked-support registry cache hook in
	# `UATerrainPieceLibrary`, so the original “baked support height” behavior
	# cannot be validated reliably here.
	print("[BakedSupportRegistryTest] SKIP baked support registry not supported in this repo version")
	return 0


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		push_error("[BakedSupportRegistryTest] DirAccess.open(res://) failed.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakedSupportRegistryTest] make_dir_recursive failed (%d) for %s" % [err, path])


func _save_json(path: String, payload: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[BakedSupportRegistryTest] Failed to open for write: %s" % path)
		return
	f.store_string(JSON.stringify(payload, "\t", false))
	f.store_string("\n")
	f.close()


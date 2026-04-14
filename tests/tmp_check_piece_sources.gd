extends SceneTree

const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")

const LEGACY_SET_ROOT := "res://resources/ua/bundled/sets"

func _init() -> void:
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)
	print("--- piece source checks (set_id=1) ---")
	for base in [
		"VP_BSECT",
		"VP_MFLAK",
		"VP_FLAK2",
		"VP_ROBO",
		"VP_DFLAK",
		"ST_EMPTY",
		"S00V",
	]:
		print(base, " => ", AuthoredPieceLibrary.has_piece_source(1, base))
	quit()


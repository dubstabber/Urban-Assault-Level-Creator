extends SceneTree

const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")
const LEGACY_SET_ROOT := "res://resources/ua/bundled/sets"

func _init() -> void:
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)
	var mesh: ArrayMesh = AuthoredPieceLibrary._load_piece_mesh(1, "ST_EMPTY")
	if mesh == null:
		print("mesh null")
		quit()
		return
	var verts := mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for v in verts:
		min_x = min(min_x, v.x)
		max_x = max(max_x, v.x)
		min_z = min(min_z, v.z)
		max_z = max(max_z, v.z)
	print("ST_EMPTY bounds x=[", min_x, ",", max_x, "] z=[", min_z, ",", max_z, "] sample v0=", (verts[0] if verts.size() > 0 else Vector3.ZERO))
	quit()


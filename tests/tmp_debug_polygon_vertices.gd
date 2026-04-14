extends SceneTree

const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")

func _init() -> void:
	# Mirror the exact inputs used by `test_authored_piece_polygon_vertices_mirror_local_z_into_editor_space`.
	var polygon := AuthoredPieceLibrary._polygon_vertices(
		[
			{"x": 10.0, "y": -5.0, "z": 7.0},
			{"x": -2.0, "y": 3.0, "z": -11.0},
		],
		[[0, 1]],
		0
	)
	print("polygon=", polygon)
	print("expected0=", Vector3(10.0 / 1200.0, 5.0 / 1200.0, -7.0 / 1200.0))
	print("expected1=", Vector3(-2.0 / 1200.0, -3.0 / 1200.0, 11.0 / 1200.0))
	quit()


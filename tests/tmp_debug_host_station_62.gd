extends SceneTree

const OverlayProducers = preload("res://map/3d/overlays/map_3d_overlay_descriptor_producers.gd")
const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")

const LEGACY_SET_ROOT := "res://resources/ua/bundled/sets"

static func _ua_vec3(x: float, y: float, z: float) -> Vector3:
	return Vector3(x / 1200.0, y / 1200.0, z / 1200.0)

class HostStationStub:
	extends Node2D
	var vehicle := 0
	var pos_y := -500
	func _init(vehicle_id: int, pos_x: float, pos_z_abs: float, ua_y: int) -> void:
		vehicle = vehicle_id
		pos_y = ua_y
		position = Vector2(pos_x, pos_z_abs)

func _init_map(w: int, h: int, height: int, typ_values: Array) -> Dictionary:
	var typ := PackedByteArray(typ_values)
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	for i in hgt.size():
		hgt[i] = height
	return {"typ": typ, "hgt": hgt}

func _init() -> void:
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)

	var w := 1
	var h := 1
	var data := _init_map(w, h, 0, [12])

	var descriptors := OverlayProducers.build_host_station_descriptors(
		[HostStationStub.new(62, 1200.0, 1200.0, -500)],
		1,
		data["hgt"],
		w,
		h
	)
	print("--- host station 62 descriptors ---")
	print("count=", descriptors.size())
	for d in descriptors:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var base := String(d.get("base_name", ""))
		var o: Vector3 = d.get("origin", Vector3.ZERO)
		print(base, " origin=", o, " forward=", d.get("forward", Vector3.ZERO))
	print("--- expected vs actual (scaled world) ---")
	print("Expected body:", _ua_vec3(1200.0, 500.0, 1200.0))
	print("Expected front gun:", _ua_vec3(1200.0, 650.0, 825.0))
	print("Expected rear gun:", _ua_vec3(1200.0, 620.0, 1580.0))
	quit()

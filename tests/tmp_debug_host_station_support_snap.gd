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
	var data := _init_map(w, h, 12, [12])

	var support := [
		{"set_id": 1, "base_name": "ST_EMPTY", "raw_id": 101, "origin": _ua_vec3(0.0, 2000.0, 0.0)}
	]

	var descriptors := OverlayProducers.build_host_station_descriptors(
		[HostStationStub.new(56, 150.0, 150.0, -500)],
		1,
		data["hgt"],
		w,
		h,
		support
	)

	var world_x: float = 150.0 * (1.0 / 1200.0)
	var world_z: float = 150.0 * (1.0 / 1200.0)
	var terrain_y: float = OverlayProducers.ground_height_at_world_position(data["hgt"], w, h, world_x, world_z)
	var authored_y: Variant = AuthoredPieceLibrary.support_height_at_world_position(support, world_x, world_z)
	var support_y_via_producers: float = OverlayProducers.support_height_at_world_position(data["hgt"], w, h, support, world_x, world_z)
	print("--- support sampler debug ---")
	print("world_x/world_z=", world_x, ",", world_z)
	print("terrain_y(unscaled)=", terrain_y)
	print("authored_y=", authored_y)
	print("support_y_via_producers(unscaled UA)=", support_y_via_producers)

	print("--- support snap (host station 56) ---")
	print("count=", descriptors.size())
	for d in descriptors:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		print(String(d.get("base_name", "")), " origin=", d.get("origin", Vector3.ZERO), " forward=", d.get("forward", Vector3.ZERO))

	print("--- expected scaled values (from unit test) ---")
	print("Expected body VP_ROBO:", _ua_vec3(150.0, 2508.0, 150.0))

	quit()

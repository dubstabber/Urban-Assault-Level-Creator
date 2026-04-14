extends SceneTree

const Map3DRendererScript = preload("res://map/map_3d_renderer.gd")
const AuthoredPieceLibrary = preload("res://map/terrain/ua_authored_piece_library.gd")

const LEGACY_SET_ROOT := "res://resources/ua/bundled/sets"

class MockPreloads:
	extends RefCounted
	var _textures: Array[Texture2D] = []
	func _init() -> void:
		_textures.resize(6)
		for i in 6:
			var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
			img.fill(Color(float(i + 1) / 6.0, 0.25, 0.5, 1.0))
			_textures[i] = ImageTexture.create_from_image(img)
	func get_ground_texture(surface_type: int) -> Texture2D:
		return _textures[clampi(surface_type, 0, 5)]

func _init() -> void:
	AuthoredPieceLibrary._clear_runtime_caches_for_tests()
	AuthoredPieceLibrary.set_external_source_loading_enabled(true)
	AuthoredPieceLibrary.set_external_source_root(LEGACY_SET_ROOT)

	var w := 2
	var h := 1
	var typ := PackedByteArray([12, 12])
	var hgt := PackedByteArray()
	hgt.resize((w + 2) * (h + 2))
	for i in hgt.size():
		hgt[i] = 5

	var renderer = Map3DRendererScript.new()
	var mapping := {12: 1, 248: 0, 249: 0, 250: 0, 251: 0, 252: 0, 253: 0, 254: 0, 255: 0}
	var result: Dictionary = renderer._build_edge_overlay_result(hgt, w, h, typ, mapping, 1, MockPreloads.new())

	var descriptors: Array = result.get("authored_piece_descriptors", [])
	print("authored desc count=", descriptors.size())
	for d in descriptors:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var bn := String(d.get("base_name", ""))
		var o := Vector3(d.get("origin", Vector3.INF))
		print(" - ", bn, " origin=", o, " warp=", String(d.get("warp_mode","")))

	var has := false
	for d in descriptors:
		if typeof(d) == TYPE_DICTIONARY and String(d.get("base_name","")) == "S00V":
			has = true
			print("FOUND S00V origin=", Vector3(d.get("origin", Vector3.INF)))
	if not has:
		print("NO S00V descriptor emitted")

	quit()


extends SceneTree

const PieceLibraryScript := preload("res://map/terrain/ua_authored_piece_library.gd")

const OUT_ROOT := "res://resources/ua/sets"
const SCHEMA_VERSION := 1
const LEGACY_SET_ROOT := "res://urban_assault_decompiled-master/assets/sets"

func _init() -> void:
	var args := OS.get_cmdline_args()
	var set_id := _int_arg(args, "--set", 1)
	var count := _int_arg(args, "--count", 0)
	PieceLibraryScript.set_external_source_loading_enabled(true)
	PieceLibraryScript.set_external_source_root(LEGACY_SET_ROOT)
	if count <= 0:
		count = 32

	var set_dir := "%s/set%d" % [OUT_ROOT, maxi(set_id, 1)]
	var metadata_dir := "%s/metadata" % set_dir
	_ensure_dir(metadata_dir)

	var registry_path := "%s/particles.json" % metadata_dir
	var registry := _load_registry(registry_path)
	if not registry.has("schema_version"):
		registry["schema_version"] = SCHEMA_VERSION
	if typeof(registry.get("emitters", {})) != TYPE_DICTIONARY:
		registry["emitters"] = {}
	var emitters: Dictionary = registry["emitters"]

	# For now, walk a small number of BAS-authored PTCL emitters by calling into
	# the same extraction helpers used at runtime.
	var baked: int = 0

	for raw_id in count:
		var lego_id := int(raw_id)
		var dummy_origin := Vector3.ZERO
		var resolved := PieceLibraryScript.resolve_authored_descriptor(set_id, lego_id, {}, dummy_origin)
		if resolved.is_empty():
			continue
		# resolve_authored_descriptor only tells us base_name/origin; to keep this
		# scaffolding simple, rely on the existing PTCL extraction:
		var piece_root := PieceLibraryScript.build_overlay_node([resolved])
		if piece_root == null:
			continue
		for child in piece_root.get_children():
			if child == null or not child.has_meta("ua_authored_particle_emitter"):
				continue
			# The emitter node already has its baked definition stored via setup_emitter.
			var def: Dictionary = {}
			if child.has_method("get"):
				def = child.get("definition")
			if typeof(def) != TYPE_DICTIONARY or def.is_empty():
				continue
		piece_root.queue_free()

	# NOTE: current scaffolding is conservative; a future iteration can call
	# into the lower-level `_particle_emitter_from_ptcl(...)` helpers directly
	# when driving from explicit BAS/RSRC pool inputs.

	registry["emitters"] = emitters
	_save_registry(registry_path, registry)
	print("[BakeParticles] Done. baked=", baked, " set=", set_id, " registry=", registry_path)
	quit(0)


func _int_arg(args: PackedStringArray, name: String, default_value: int) -> int:
	for arg in args:
		if arg.begins_with(name + "="):
			return int(arg.get_slice("=", 1))
	return default_value


func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		_fail("DirAccess.open(res://) failed; cannot create output directories.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[BakeParticles] make_dir_recursive failed (%d) for %s" % [err, path])


func _load_registry(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_registry(path: String, registry: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_fail("Failed to open registry for write: %s" % path)
		return
	f.store_string(JSON.stringify(registry, "\t", false))
	f.store_string("\n")
	f.close()


func _fail(message: String) -> void:
	push_error("[BakeParticles] " + message)
	quit(1)

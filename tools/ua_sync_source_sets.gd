extends SceneTree

# Imports UA set assets and shared .SCR pools into res://resources/ua/bundled (runtime path).
# Does not reference external folders at runtime — pass your local checkout via --from.
const BUNDLED_SETS_ROOT := "res://resources/ua/bundled/sets"
const BUNDLED_ORIGINAL_SCRIPTS_DST := "res://resources/ua/bundled/shared_scripts/original"
const BUNDLED_METROPOLIS_SCRIPTS_DST := "res://resources/ua/bundled/shared_scripts/metropolis_dawn"
const SET_SUBDIRECTORIES := ["objects", "Skeleton", "rsrcpool", "hi", "scripts"]

var _import_sets_root: String = ""

func _init() -> void:
	var args := OS.get_cmdline_args()
	_import_sets_root = _string_arg(args, "--from", "")
	if _import_sets_root.is_empty():
		_import_sets_root = String(OS.get_environment("UA_EXTERNAL_SETS_ROOT")).strip_edges()
	if _import_sets_root.is_empty():
		_fail(
			"Missing import source. Set --from=res://path/to/assets/sets "
			+ "(folder containing set1, set2, …) or UA_EXTERNAL_SETS_ROOT."
		)
		return
	var from_original_scripts := _string_arg(args, "--from_original_scripts", "")
	if from_original_scripts.is_empty():
		from_original_scripts = String(OS.get_environment("UA_EXTERNAL_ORIGINAL_SCRIPTS")).strip_edges()
	var from_metropolis_scripts := _string_arg(args, "--from_metropolis_scripts", "")
	if from_metropolis_scripts.is_empty():
		from_metropolis_scripts = String(OS.get_environment("UA_EXTERNAL_METROPOLIS_SCRIPTS")).strip_edges()

	var set_ids := _set_ids_arg(args)
	var include_xp := _bool_arg(args, "--include_xp", true)
	var sync_shared_scripts := _bool_arg(args, "--sync_shared_scripts", true)
	var copied_files := 0
	for set_id in set_ids:
		copied_files += _sync_set(set_id, false)
		if include_xp:
			copied_files += _sync_set(set_id, true)
	if sync_shared_scripts and not from_original_scripts.is_empty():
		copied_files += _sync_shared_script_root("original", from_original_scripts, BUNDLED_ORIGINAL_SCRIPTS_DST)
	elif sync_shared_scripts:
		print("[SyncSourceSets] Skip retail shared scripts (no --from_original_scripts / UA_EXTERNAL_ORIGINAL_SCRIPTS)")
	if sync_shared_scripts and not from_metropolis_scripts.is_empty():
		copied_files += _sync_shared_script_root("metropolis_dawn", from_metropolis_scripts, BUNDLED_METROPOLIS_SCRIPTS_DST)
	elif sync_shared_scripts:
		print("[SyncSourceSets] Skip Metropolis Dawn shared scripts (no --from_metropolis_scripts / UA_EXTERNAL_METROPOLIS_SCRIPTS)")
	print("[SyncSourceSets] Done. copied=", copied_files, " sets=", PackedInt32Array(set_ids))
	quit(0)

func _sync_set(set_id: int, use_xp: bool) -> int:
	var suffix := "_xp" if use_xp else ""
	var src_root := "%s/set%d%s" % [_import_sets_root, maxi(set_id, 1), suffix]
	if not DirAccess.dir_exists_absolute(src_root):
		print("[SyncSourceSets] Skip missing source root ", src_root)
		return 0
	var dst_root := "%s/set%d%s" % [BUNDLED_SETS_ROOT, maxi(set_id, 1), suffix]
	_ensure_dir(dst_root)
	var copied := _copy_files_in_directory(src_root, dst_root)
	for subdir_value in SET_SUBDIRECTORIES:
		var subdir := String(subdir_value)
		var src_subdir := "%s/%s" % [src_root, subdir]
		if not DirAccess.dir_exists_absolute(src_subdir):
			continue
		var dst_subdir := "%s/%s" % [dst_root, subdir]
		copied += _copy_tree(src_subdir, dst_subdir)
	var visproto_src := _first_existing_file([
		"%s/scripts/visproto.lst" % src_root,
		"%s/scripts/VISPROTO.LST" % src_root,
	])
	if not visproto_src.is_empty():
		var lookup_dir := "%s/lookup" % dst_root
		_ensure_dir(lookup_dir)
		copied += _copy_file(visproto_src, "%s/visproto.lst" % lookup_dir)
	print("[SyncSourceSets] Synced set ", set_id, suffix, " copied=", copied)
	return copied

func _sync_shared_script_root(_label: String, src_root: String, dst_root: String) -> int:
	if src_root.is_empty() or not DirAccess.dir_exists_absolute(src_root):
		print("[SyncSourceSets] Skip missing shared script root: ", src_root)
		return 0
	_ensure_dir(dst_root)
	var copied := _copy_tree(src_root, dst_root)
	print("[SyncSourceSets] Synced shared scripts -> ", dst_root, " copied=", copied)
	return copied

func _copy_tree(src_dir: String, dst_dir: String) -> int:
	_ensure_dir(dst_dir)
	var copied := _copy_files_in_directory(src_dir, dst_dir)
	for child_dir_value in DirAccess.get_directories_at(src_dir):
		var child_dir := String(child_dir_value)
		if child_dir.begins_with("."):
			continue
		copied += _copy_tree("%s/%s" % [src_dir, child_dir], "%s/%s" % [dst_dir, child_dir])
	return copied

func _copy_files_in_directory(src_dir: String, dst_dir: String) -> int:
	_ensure_dir(dst_dir)
	var copied := 0
	for entry_value in DirAccess.get_files_at(src_dir):
		var entry := String(entry_value)
		var extension := entry.get_extension().to_lower()
		if entry.begins_with(".") or extension == "bak" or extension == "import":
			continue
		copied += _copy_file("%s/%s" % [src_dir, entry], "%s/%s" % [dst_dir, entry])
	return copied

func _copy_file(src_path: String, dst_path: String) -> int:
	var parent_dir := dst_path.get_base_dir()
	if not parent_dir.is_empty():
		_ensure_dir(parent_dir)
	var src_bytes := FileAccess.get_file_as_bytes(src_path)
	if src_bytes.is_empty() and FileAccess.get_open_error() != OK:
		push_warning("[SyncSourceSets] Failed to read %s" % src_path)
		return 0
	var out := FileAccess.open(dst_path, FileAccess.WRITE)
	if out == null:
		push_warning("[SyncSourceSets] Failed to write %s" % dst_path)
		return 0
	out.store_buffer(src_bytes)
	out.close()
	return 1

func _first_existing_file(candidates: Array) -> String:
	for candidate_value in candidates:
		var candidate := String(candidate_value)
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			return candidate
	return ""

func _string_arg(args: PackedStringArray, name: String, default_value: String) -> String:
	var prefix := name + "="
	for arg in args:
		if arg.begins_with(prefix):
			return String(arg.get_slice("=", 1)).strip_edges()
	return default_value

func _set_ids_arg(args: PackedStringArray) -> Array[int]:
	for arg in args:
		if arg.begins_with("--sets="):
			var result: Array[int] = []
			for token_value in String(arg.get_slice("=", 1)).split(",", false):
				var token := String(token_value).strip_edges()
				if token.is_empty():
					continue
				result.append(maxi(int(token), 1))
			if not result.is_empty():
				return result
		if arg.begins_with("--set="):
			return [maxi(int(arg.get_slice("=", 1)), 1)]
	var defaults: Array[int] = []
	for set_id in range(1, 7):
		defaults.append(set_id)
	return defaults

func _bool_arg(args: PackedStringArray, name: String, default_value: bool) -> bool:
	for arg in args:
		if arg.begins_with(name + "="):
			var raw := String(arg.get_slice("=", 1)).strip_edges().to_lower()
			return not (raw == "0" or raw == "false" or raw == "no")
	return default_value

func _ensure_dir(path: String) -> void:
	var da := DirAccess.open("res://")
	if da == null:
		_fail("DirAccess.open(res://) failed; cannot create output directories.")
		return
	var rel := path.replace("res://", "")
	var err := da.make_dir_recursive(rel)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("[SyncSourceSets] make_dir_recursive failed (%d) for %s" % [err, path])

func _fail(message: String) -> void:
	push_error("[SyncSourceSets] " + message)
	quit(1)

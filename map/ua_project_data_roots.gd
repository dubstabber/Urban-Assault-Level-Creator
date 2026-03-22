extends RefCounted
class_name UAProjectDataRoots

# All UA terrain / script data is read from files inside the Godot project directory.
# Nothing is shipped as pre-baked Godot mesh assets for map pieces: set.sdf, BAS/SKLT JSON,
# textures, and global .SCR pools drive `UATerrainPieceLibrary` and parsers at runtime.
#
# Primary copy for version control: `resources/ua/bundled/` (sets + shared_scripts).
#
# Optional in-project trees (often gitignored): same layouts as retail / decomp tooling.
# Drop these next to `project.godot` if you do not use the bundled copy:
#   urban_assault_decompiled-master/   — e.g. assets/sets
#   UA_source/                           — assets/sets, sets, DATA/SCRIPTS, XP/…
#   ua_source_code_prototype/          — e.g. UA_RC1/DATA/SCRIPTS
#   scripts/                           — global .SCR pool at project root
#   .usor/                             — e.g. openua/DATA/SCRIPTS (Metropolis Dawn)
# Resolution order: bundled first, then each optional path below in order.
const BUNDLED_ROOT := "res://resources/ua/bundled"
const BUNDLED_SETS_ROOT := "res://resources/ua/bundled/sets"
const BUNDLED_ORIGINAL_SHARED_SCRIPTS := "res://resources/ua/bundled/shared_scripts/original"
const BUNDLED_METROPOLIS_DAWN_SHARED_SCRIPTS := "res://resources/ua/bundled/shared_scripts/metropolis_dawn"

# Optional editor-only JSON (see Preloads.reload_surface_type_map).
const EDITOR_OVERRIDES_ROOT := "res://resources/ua/editor_overrides"

# Extra `setN` / `setN_xp` parents under the project root (gitignored local trees). Tried after bundled.
const OPTIONAL_IN_PROJECT_SET_ROOT_BASES: Array[String] = [
	"res://urban_assault_decompiled-master/assets/sets",
	"res://UA_source/assets/sets",
	"res://UA_source/sets",
]

# Global .SCR pools (retail / XP) when not using bundled/shared_scripts.
const OPTIONAL_ORIGINAL_SHARED_SCRIPTS: Array[String] = [
	"res://ua_source_code_prototype/UA_RC1/DATA/SCRIPTS",
	"res://UA_source/DATA/SCRIPTS",
	"res://scripts",
]
const OPTIONAL_METROPOLIS_DAWN_SHARED_SCRIPTS: Array[String] = [
	"res://.usor/openua/DATA/SCRIPTS",
	"res://UA_source/XP/DATA/SCRIPTS",
]


static func normalized_game_data_type(game_data_type: String) -> String:
	return "metropolisDawn" if game_data_type.to_lower() == "metropolisdawn" else "original"


static func all_set_root_base_paths() -> Array[String]:
	var out: Array[String] = [BUNDLED_SETS_ROOT]
	for p in OPTIONAL_IN_PROJECT_SET_ROOT_BASES:
		out.append(String(p))
	return out


## First existing `set{N}` or `set{N}_xp` directory on disk (searches bundled, then optional in-project trees).
static func first_existing_set_directory(set_id: int, game_data_type: String) -> String:
	var norm := normalized_game_data_type(game_data_type)
	var sid := maxi(set_id, 1)
	var xp_suffix := "_xp" if norm == "metropolisDawn" else ""
	for base in all_set_root_base_paths():
		var candidate := "%s/set%d%s" % [base, sid, xp_suffix]
		if DirAccess.dir_exists_absolute(candidate):
			return candidate
	if norm == "metropolisDawn":
		for base in all_set_root_base_paths():
			var retail := "%s/set%d" % [base, sid]
			if DirAccess.dir_exists_absolute(retail):
				return retail
	return "%s/set%d%s" % [BUNDLED_SETS_ROOT, sid, xp_suffix]


static func primary_set_root(set_id: int, game_data_type: String) -> String:
	return first_existing_set_directory(set_id, game_data_type)


static func first_existing_file(candidates: Array) -> String:
	for candidate_value in candidates:
		var candidate := String(candidate_value)
		if not candidate.is_empty() and FileAccess.file_exists(candidate):
			return candidate
	return ""


## First `relative_path` under `set{N}` / `set{N}_xp` that exists (bundled, then optional trees).
## Example: `"scripts/tile_remap.json"`.
static func first_existing_path_under_set_roots(set_id: int, game_data_type: String, relative_path: String) -> String:
	var rel := relative_path.strip_edges().trim_prefix("/")
	if rel.is_empty():
		return ""
	var norm := normalized_game_data_type(game_data_type)
	var sid := maxi(set_id, 1)
	var xp_suffix := "_xp" if norm == "metropolisDawn" else ""
	for base in all_set_root_base_paths():
		var set_dir := "%s/set%d%s" % [base, sid, xp_suffix]
		var candidate := "%s/%s" % [set_dir, rel]
		if FileAccess.file_exists(candidate):
			return candidate
	if norm == "metropolisDawn":
		for base in all_set_root_base_paths():
			var retail_root := "%s/set%d" % [base, sid]
			var candidate := "%s/%s" % [retail_root, rel]
			if FileAccess.file_exists(candidate):
				return candidate
	return ""


static func set_sdf_path_for_set(set_id: int, game_data_type: String) -> String:
	var norm := normalized_game_data_type(game_data_type)
	var sid := maxi(set_id, 1)
	var xp_suffix := "_xp" if norm == "metropolisDawn" else ""
	var candidates: Array[String] = []
	for base in all_set_root_base_paths():
		var set_dir := "%s/set%d%s" % [base, sid, xp_suffix]
		candidates.append("%s/scripts/set.sdf" % set_dir)
		candidates.append("%s/scripts/set.sdf.bak_pre_strip" % set_dir)
	if norm == "metropolisDawn":
		for base in all_set_root_base_paths():
			var retail_root := "%s/set%d" % [base, sid]
			candidates.append("%s/scripts/set.sdf" % retail_root)
			candidates.append("%s/scripts/set.sdf.bak_pre_strip" % retail_root)
	var found := first_existing_file(candidates)
	if not found.is_empty():
		return found
	return "%s/set%d%s/scripts/set.sdf" % [BUNDLED_SETS_ROOT, sid, xp_suffix]


static func shared_script_root_for_game_data_type(game_data_type: String) -> String:
	var norm := normalized_game_data_type(game_data_type)
	var bundled := BUNDLED_ORIGINAL_SHARED_SCRIPTS if norm == "original" else BUNDLED_METROPOLIS_DAWN_SHARED_SCRIPTS
	if DirAccess.dir_exists_absolute(bundled):
		return bundled
	var optionals: Array[String] = OPTIONAL_ORIGINAL_SHARED_SCRIPTS if norm == "original" else OPTIONAL_METROPOLIS_DAWN_SHARED_SCRIPTS
	for p in optionals:
		if DirAccess.dir_exists_absolute(p):
			return p
	return bundled

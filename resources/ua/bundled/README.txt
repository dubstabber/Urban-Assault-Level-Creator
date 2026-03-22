Urban Assault 3D/editor data bundled for export (UTF-8 text).

3D map preview does not use pre-baked Godot meshes for terrain pieces: it parses `set.sdf`,
BAS/SKLT JSON under each set’s `objects/`, textures, and shared `.SCR` pools at runtime.

Layout:
  sets/set{N}/          — per-set objects, Skeleton, rsrcpool, hi, scripts/set.sdf, …
  sets/set{N}_xp/       — Metropolis Dawn sets when used
  shared_scripts/original/     — global .SCR pool (retail)
  shared_scripts/metropolis_dawn/ — global .SCR pool (XP), optional

Populate with Godot tool:
  godot --headless -s res://tools/ua_sync_source_sets.gd -- --from=res://path/to/assets/sets
  Optional env: UA_EXTERNAL_SETS_ROOT, UA_EXTERNAL_ORIGINAL_SCRIPTS, UA_EXTERNAL_METROPOLIS_SCRIPTS
  Optional: --from_original_scripts=res://path/to/DATA/SCRIPTS
            --from_metropolis_scripts=res://path/to/XP/DATA/SCRIPTS

Shell equivalent (from repo root, paths are examples):
  rsync -a --delete urban_assault_decompiled-master/assets/sets/ resources/ua/bundled/sets/
  rsync -a --delete ua_source_code_prototype/UA_RC1/DATA/SCRIPTS/ resources/ua/bundled/shared_scripts/original/
  rsync -a --delete .usor/openua/DATA/SCRIPTS/ resources/ua/bundled/shared_scripts/metropolis_dawn/

After that, run tools/ua_reencode_text_to_utf8.py on resources/ua/bundled if Godot logs UTF-8 warnings.

Runtime resolution (map/ua_project_data_roots.gd): tries resources/ua/bundled first, then optional
in-project folders that mirror a local checkout (same names as in .gitignore), for example:
  urban_assault_decompiled-master/assets/sets, UA_source/assets/sets,
  ua_source_code_prototype/.../DATA/SCRIPTS, .usor/openua/DATA/SCRIPTS, scripts/, etc.
Legacy `resources/ua/sets/` (old bake output) is obsolete — do not use.

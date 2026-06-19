# Architecture Review — Urban Assault Level Creator

Date: 2026-06-19
Status: review complete; "quick wins" batch applied (see § Applied in this session).

## Method & scope

A 9-reviewer audit covered every subsystem — global autoloads, 2D render/input,
LDF parsers, app shell / modals / properties, the 3D runtime, terrain & sky,
the entity model, cross-cutting concerns, and tests/tooling. Every
high-severity finding was then **adversarially verified** against the actual
code (a second pass tasked with *refuting* each claim). That pass did real
work: of 17 high-severity findings, **4 held at high, 11 were downgraded to
medium, 2 to low, and several specific sub-claims were debunked**. Severities
below are the *post-verification* (corrected) ones.

Overall total: 64 findings across the 9 subsystems.

## Executive summary

This is a **mature, working editor in generally good shape**. The 3D subsystem
was genuinely refactored well (real thread/mutex discipline, per-frame
budgeting, focused services) and the 2D renderer's recent culling work is sound.
The weaknesses are not crashes or rot — they are **structural debt that nearly
all traces back to one missing abstraction**, plus ordinary solo-project gaps
(scratch files committed, no CI until now, AI-config sprawl).

The headline: there is **no authoritative plain-data map model**. That single
gap is the upstream cause of most of the serious findings.

---

## Root cause: there is no authoritative data model

Map state is fragmented across four incompatible stores:

| Concern | Stored as | Where |
|---|---|---|
| Host stations, squads | `Sprite2D` **scene-tree nodes** | `CurrentMapData.host_stations/squads: Node2D` (`CurrentMapData.gd:29-30`) |
| Beam gates, bombs, tech upgrades | `RefCounted` **arrays** | `CurrentMapData.gd:37-39` |
| Terrain (typ/own/hgt/blg) | global **`PackedByteArray`** | `CurrentMapData.gd:33-36` |
| "Currently selected" entity | a **third singleton** | `EditorState.gd:62-74` |
| Per-faction enabled units/buildings | **14 parallel arrays** | `CurrentMapData.gd:42-58` |

Because units *are* the mutable scene tree (not data), the codebase had to grow
an `editor_unit_id` identity scheme **plus** a 268-line
`globals/unit_snapshot_reconciler.gd` **plus** snapshot/restore code in
`UndoRedoManager` — machinery that exists *only* for the node-backed entities
(beam gates/bombs are plain data and need none of it). This is confirmed, not
speculative; the workaround is even unit-tested (`tests/test_unit_snapshot_reconciler.gd`).

**Highest-leverage refactor (large, multi-week):** introduce a plain-data
`MapModel` aggregate that owns all five entity types + the byte maps as *data*,
with render nodes demoted to a thin view layer. It would collapse the faction
arrays into dictionaries, unify the two undo-restore paths, and reduce the
reconciler to "replace and rebind." Everything below becomes smaller and safer
once this exists — so it is the spine, but it should be approached *after* the
cheaper hardening items that de-risk it.

---

## HIGH severity (survived adversarial verification)

### H1 — No single domain model *(architecture, large)*
As above. Note the sharpest symptom: `map/ua_structures/tech_upgrade.gd:27-65`
writes `CurrentMapData.typ_map[EditorState.selected_sector_idx]` — a data class
mutating a global byte-array keyed by *transient UI selection* rather than its
own `sec_x/sec_y`. Latent bug if ever synchronized while a different sector is
selected.

### H2 — Load/save format knowledge is hand-duplicated and has drifted into a live data-loss bug *(correctness, medium-effort fix)*
`main/parsers/singleplayer_opener.gd` and `singleplayer_saver.gd` independently
encode the UA wire format. The saver writes `fire_x/fire_y/fire_z`
(`saver.gd:284-286`, gated on `num_weapons != 0`) but **the opener never reads
them back** (no `fire_` handling anywhere), so a weapon modifier silently loses
its fire offsets on a load→save→load round trip, reverting to the hardcoded
defaults 30/5/15 (`tech_upgrade.gd:130-132`). There is **no round-trip test**.
- **Scope is narrow**: no UI exposes `fire_x/y/z`, and no bundled test level
  uses `num_weapons`, so only a hand-authored LDF hits this path today.
- **Debunked sibling claim**: reviewers also flagged "player host station loses
  budget/delay fields." This is **not a bug** — the player is the first
  `begin_robo` block by definition, and budget/delay are AI-behaviour fields the
  game *ignores* for the player. Omitting (or writing) them is harmless; the
  saver's player-vs-AI split mirrors the original format. Only `fire_x/y/z` is real.
- **Fix**: add a UI-free **golden round-trip test** (load a real level → save →
  reload → assert field equality) — this is the single highest-value test to
  add and would have caught H2. Then either parse `fire_x/y/z` in the opener or
  stop writing them. Long term, fold load+save onto one shared field table.

### H3 — 14+ parallel per-faction arrays with copy-pasted 7-way switches *(duplication, medium)*
`resistance_/ghorkov_/…/training_enabled_units` (×7) plus the same for
buildings (`CurrentMapData.gd:42-58`), with **no canonical `owner_id→faction`
table anywhere**. The identical `match owner_id` ladder is re-encoded across
`modals/components/item_check_box_container.gd` (4× *in one file*), the opener,
the saver, `main/status_bar_container_right.gd`, and `map/ua_structures/squad.gd`'s
colour map — ~140 references across 6+ files. `close_map()` clears all 16 by
hand (`CurrentMapData.gd:122-138`).
- **Debunked sub-claim**: the scarier "opener and saver use *conflicting*
  owner_id orderings → round-trip corruption" is **false** — all sites encode
  the same bijection; they merely *list* factions in different source order. So
  this is a maintainability hazard, not an active correctness bug.
- **Fix**: two `Dictionary[int, Array[int]]` keyed by `owner_id` +
  `is_enabled()/set_enabled()` helpers + one `FACTIONS = {owner_id: name}` table
  in `Constants`. Preserve the `unknown_enabled_*` bucket for out-of-range ids.

### H4 — Test coverage protects the wrong subsystem *(testing, medium-effort / high value)*
**28 of 42 test files are `test_map_3d_*`.** The editor's core promise — open
and save `.ldf` files without corruption — has **effectively zero automated
tests**: the 1,431-line binary parsers, all 27 modals, all property panels,
`input_handler`, and undo/redo are unverified. (`test_set_sdf_parser.gd` covers
a read-only auxiliary table, not the level format.)
- **Fix**: the golden round-trip test from H2 is the highest-value addition;
  follow with smoke-construction tests for a few modals/properties.

---

## MEDIUM severity (grouped by theme)

### Fat singletons with side-effecting setters
- `CurrentMapData.is_saved` does window-title / `get_viewport()` work *inside the
  setter* (`CurrentMapData.gd:61-76`), with a load-bearing
  `if horizontal_sectors and vertical_sectors` guard hidden in it. Move
  presentation to a listener on a `dirty_changed` signal.
- `EditorState.game_data_type` emits `map_updated` unconditionally
  (`EditorState.gd:8-12`), so re-selecting the *same* dataset marks the map
  dirty (`game_content_window.gd:27`). Emit only `game_type_changed`; let real
  mutations mark dirty.
- `EditorState` bundles three concerns with different lifetimes (read-mostly DBs,
  transient selection, UI toggles) → 66-file fan-in. Consider splitting into
  `UnitDatabase` / `Selection` / `ViewSettings` (large).
- Autoload `_ready` methods cross-reference other singletons
  (`project.godot:30-37`, `Preloads.gd`, `EditorState.gd:97-101`); boot order is
  correct only by accident. Make the dependency explicit / guard the reads.

### Coarse signal bus
- `map_updated` (47 emit sites) and `map_view_updated` (8 setters) are
  "repaint everything" hammers. Every inspector panel does full
  **teardown+rebuild** of its node tree on each `map_updated`
  (`beam_gate_section.gd:96-127`).
- **Debunked**: this is *not* an unbatched 2D raster "storm" — Godot coalesces
  `queue_redraw()` per frame and the subviewport renders on-demand, so the 2D
  cost is largely defused. The real cost is inspector node-churn + coupling.
- **Fix**: split into targeted signals (`overlay_visibility_changed`,
  `sector_data_changed(idx)`); have panels early-out when their bound entity is
  unchanged.

### UI copy-paste families
- **No base class for 33 modals** (20 `extends Window`, etc.); `close()`/popup
  ceremony and an inconsistently-applied focus workaround are duplicated ~20×.
  Introduce `BaseModalWindow`.
- `tech_upgrade_modifier_1/2/3.gd` are fork-variants; dirty-flag handling has
  **already diverged** (`modifier_1.gd:56` marks dirty unconditionally; 2/3 only
  on actual change). Extract a base or descriptor-driven modifier.
- Context-menu builders use string-literal dispatch where *every* builder's
  handler fires on *every* click (`map/context_menu_builders/`), inconsistent
  with the `id_pressed`/item-id style used by the submenu builders in the same
  family. Use stable ids + `id_pressed`.
- Sector-clear logic is duplicated near-verbatim between
  `input_handler.gd:247-312` and `clean_sector_context_menu.gd:12-80`. Extract a
  shared `SectorEditOps`. (`input_handler` is broadly a God `_input` that owns
  model mutation + undo grouping; the same `SectorEditOps` seam addresses both.)
- Per-field "snapshot/compare/set/dirty/emit/record" boilerplate is copy-pasted
  dozens of times in `host_station_properties.gd` / `squad_properties.gd`; a
  programmatic UI sync also re-fires edit handlers and records spurious undo
  snapshots on selection (`squad_properties.gd:31-42`) — add a `_loading`
  reentrancy guard / `set_block_signals`.

### Parser hardening
- The opener is **well decomposed** into per-section `_handle_*` methods (it is
  *not* a god function), but two handlers are oversized:
  `_handle_tech_upgrades` (~215 lines, 4-deep nesting) and `_handle_host_stations`
  (~170). Extract `_parse_modify_{vehicle,weapon,building}` + a
  `_next_significant_line()` helper.
- The opener writes destructively into the global `CurrentMapData` mid-parse with
  only post-hoc validation and dialog-dependent cleanup. Parse into a local
  result and commit only after the size/consistency checks pass.
- ~80 copies of a `replacen`-based `key = value` idiom; add one `_kv_int(line, key)`
  splitting on the first `=`. Name the magic border bytes (e.g. `0xF8`) and the
  stride/offset constants.
- HostStation/Squad's ~26-field serialization is hand-maintained in 4–6 places
  (reconciler, `UndoRedoManager` ×2, the parsers, `duplicate_unit.gd`). Add
  `to_dict()`/`from_dict()` on the entities; today, miss a field and undo
  silently drops it.

### 3D runtime — the self-assessment is generous
`3D_MAP_HEALTH_STATUS.md` rates this "high health." The skeptical audit says
**medium health with good test coverage** — the refactor is real and shippable,
but the doc oversells it:
- The "slim 703-line, 19-method facade" is actually a **710-line node with 135
  functions** (~90 thin delegators); `facade_contract()` is a whitelist, not the
  file's true surface.
- `_init()` is a **60-line hand-wired graph of 17 collaborators** with positional
  `.bind()` — reorder an argument and GDScript silently binds the wrong object.
  Nine forwarding ports for one subviewport renderer is over-engineering.
- The admitted **shutdown leak is real and unaddressed**: material/shader RIDs and
  orphan `MeshInstance3D` nodes accumulate on every map reload
  (`map_3d_scene_graph.gd:29-57`). This is the source of the RID-leak spam at the
  end of the headless test run.
- Worker threads receive **shallow-duplicated descriptor Arrays whose element
  Dictionaries are still shared** with main-thread state
  (`map_3d_async_overlay_pipeline.gd:81-102`). Safe *today* only by an unenforced
  "one worker at a time" invariant. PackedByteArrays are CoW-safe; the dicts are
  the soft spot. Deep-copy them (or make them immutable) and document the invariant.
- Overlay upsert/rebuild logic is duplicated between the static one-shot path and
  the budgeted-step path (`map_3d_authored_overlay_manager.gd`). Extract one
  `_upsert_piece_node(...)`.

### Caching & lifecycle (terrain)
- `UATerrainPieceLibrary` is 1,124 lines, but the "god-facade coupling" framing was
  **debunked**: ~26 of its private passthrough thunks are simply **dead code**
  (leftover re-export stubs from the extraction refactor, called by nothing).
  Cleanup, not a coupling crisis.
- Six static caches (`_piece_scene_root_cache`, `_mesh_cache`, `_texture_cache`,
  `_material_cache`, samplers) grow **unbounded** — only the slurp-mesh cache got
  the recent cap. `_piece_scene_root_cache` stores live `Node3D` templates that
  **leak orphan nodes on clear** (`ua_authored_piece_library.gd:43,305-333`) —
  `free()` them before clearing, or cache `PackedScene`/source data instead.
- The worker/main-thread `game_data_type` fix is correct but papers over the real
  coupling: piece resolution reads a mutable process-global instead of taking
  `game_data_type` as a parameter. Thread it through (it is already in every cache
  key), or assert main-thread in the setter.

---

## LOW severity (one-liners)

- Sky runtime mixes registry/manifest/geometry/material/texture/per-frame scaling
  in 884 lines; `_material_for_texture` shadows the terrain library's same-named
  method with different semantics; `_billboard_material_for_texture` duplicates the
  material every call, defeating the cache.
- 3D cross-module data flow is untyped `Dictionary` with stringly-typed keys (no
  compiler-checked contract between "focused services").
- Recursive `_find_first_*` JSON tree-walkers are a near-identical family.
- Parse errors surface only via `printerr` + one shared `AcceptDialog` with coarse
  categories.
- Menu items dispatched by matching *translated* display strings.
- Hand-rolled test harness duplicates `_check`/`_check_eq` across 20+ files;
  `test_map_3d_texturing.gd` (3,008 lines) keeps a hand-maintained ~95-name array —
  switch to reflective `get_method_list()` discovery and split the file.
- Test-only `clear_*_caches_for_tests()` hooks leak into ~8 production modules.
- Five overlapping AI-config toolchains (`.augment/.cursor/.codex/.windsurf/.claude`);
  some reference Godot **4.5.1** while the project ships **4.6.2**.

---

## What the audit checked and *dismissed* (don't chase these)

- The 2D repaint "storm" — Godot coalesces redraws; mostly a non-issue.
- The player host-station budget/delay "round-trip loss" — by design; AI-only
  fields the game ignores for the player (the first `begin_robo` block).
- The owner_id ordering "conflict" between opener and saver — same bijection.
- The piece-library "god-facade coupling" — actually ~26 dead stubs.
- "Opener is a 1,035-line god function" — it is properly decomposed.

---

## Applied in this session (quick wins)

All verified against the headless suite (`All tests passed`, exit 0, zero
script/parse errors; pre-existing RID-leak-at-exit warnings are the 3D shutdown
gap, unrelated):

1. **Deleted `docs/Preloads.gd`** — a stale, unreferenced 338-line copy of the
   live 397-line `globals/Preloads.gd` (was untracked local clutter).
2. **Removed 28 tracked scratch files** (`git rm`): 4 `.pyc`, `scripts/tmp_scan_ilb.py`,
   and 11 `tests/tmp_*`/`debug_*` scripts + their `.uid` companions + a
   `tmp_texturing_latest.txt`. Hardened `.gitignore` (`*.pyc`, `tests/tmp_*`,
   `tests/debug_*`) so they cannot silently return. (These never ran — the test
   runner only picks up `test_*.gd`.)
3. **Normalized `UndoRedoManager` access** in 26 files: replaced the untyped,
   runtime-tree-lookup `get_node("/root/UndoRedoManager")` with the typed autoload
   global `UndoRedoManager` (behaviour-preserving — same node, same access timing).
4. **Added `Makefile`** (`make test` / `test-py` / `test-all` / `run` / `clean`)
   wrapping the documented commands, plus **`.github/workflows/tests.yml`** (CI:
   downloads pinned Godot, runs the headless suite gated on its non-zero exit; the
   Python step is non-blocking due to optional `sky_import` assets). The auto-run
   GDScript suite references no gitignored assets and the bundled UA resources are
   tracked, so CI is self-contained.

> Note: this file and `3D_MAP_HEALTH_STATUS.md` sit at the repo root. The latter
> is gitignored; decide whether you want this review tracked or ignored to match.

---

## Recommended sequence

1. *(done)* Quick wins above — removes noise, adds the CI safety net.
2. **Golden round-trip parser test** + fix the `fire_x/y/z` read gap (≈ half a day)
   — protects the core promise *before* any refactor.
3. **Faction arrays → dictionaries + `Constants.FACTIONS`** (≈ 1 day) — high-ratio
   cleanup that also simplifies the parsers.
4. **Entity `to_dict()`/`from_dict()`** to kill the 4–6× serialization duplication
   (≈ 1 day).
5. **Then** design the plain-data `MapModel` aggregate (H1). Steps 2–4 make that
   refactor smaller and safer.

Lower-priority, independent: `BaseModalWindow`; split `map_updated`/`map_view_updated`
into targeted signals; 3D shutdown teardown (free RIDs/nodes in `_exit_tree`);
bound the terrain caches; deep-copy worker descriptor dicts.

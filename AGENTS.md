# Repository Guidelines

## Project Structure & Module Organization
- `main/` contains application entrypoints, menus, and LDF parsing flow.
- `map/` holds the 2D and 3D map runtime, terrain builders, context menus, and `ua_structures/` entity scripts.
- `properties/` and `modals/` contain inspector panels and editor dialogs.
- `globals/` stores shared state and services such as `CurrentMapData`, preload registries, and event dispatch.
- `resources/`, `themes/`, and `shaders/` contain bundled Urban Assault assets, UI themes, and rendering shaders.
- `tests/` contains headless GDScript tests plus a small Python suite; `scripts/` and `tools/` contain asset conversion and maintenance utilities.

## Build, Test, and Development Commands
- `./Godot_v4.5.1-stable_linux.x86_64 --path .` opens the project in the repository-pinned Godot version.
- `env HOME=/tmp XDG_DATA_HOME=/tmp ./Godot_v4.5.1-stable_linux.x86_64 --headless --path . --script res://tests/test_runner.gd` runs the GDScript suite in headless mode.
- `env PYTHONPATH=. pytest tests/test_ua_convert_sky.py -q` runs the Python sky conversion tests.
- `./Godot_v4.5.1-stable_linux.x86_64 --headless --path . --export-release Linux` builds an export after configuring templates in Godot.

## Coding Style & Naming Conventions
- Follow existing GDScript style: tabs for indentation, `snake_case` for functions/variables/files, and `PascalCase` for engine classes/constants only where already established.
- Python scripts use 4-space indentation, type hints, and `pathlib`-based file handling.
- Name new tests `test_*.gd` or `test_*.py`. Godot unit scripts should expose `run()` so `tests/test_runner.gd` can execute them.
- Keep comments sparse and practical; prefer small helper functions over dense inline logic.

## Testing Guidelines
- Put fast, isolated editor/runtime checks in `tests/` and reuse `tests/helpers/` stubs where possible.
- Run the headless Godot suite before opening a PR when touching `map/`, `globals/`, rendering, or serialization code.
- The Python sky tests currently depend on `resources/ua/sky_import`; if that source bundle is absent, note the limitation in your PR.

## Commit & Pull Request Guidelines
- Match recent history: concise imperative commit subjects such as `Add ...`, `Refactor ...`, or `Enhance ...`.
- Keep commits focused on one subsystem or behavior change.
- PRs should include a short problem statement, the validation commands you ran, and screenshots or clips for editor/UI changes.
- Call out asset-heavy changes explicitly, especially under `resources/ua/bundled/`, because they affect repo size and import time.

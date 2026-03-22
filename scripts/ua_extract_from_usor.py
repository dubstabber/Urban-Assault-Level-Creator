#!/usr/bin/env python3
"""
ua_extract_from_usor.py

Purpose:
- Extract Urban Assault ground textures (SurfaceType indices 0..5) per environment set
  from a local .usor tree or a UA install dir, and convert them to PNGs under
  resources/terrain/textures/set{N}/ground_{i}.png.

Key points:
- .usor (the open-source UA code repo) does not include proprietary art assets.
  This tool expects that you provide a manifest mapping, or that the target dir
  actually contains the textures in readable formats (e.g., .iff/.lbm/.bmp/.png).

Two modes:
1) Manifest-driven (recommended):
   Provide --manifest pointing to a JSON like:
   {
     "set1": {"0": "path/GRASS.iff", "1": "path/DIRT.iff", ...},
     "set2": { ... }
   }
   Paths are relative to --usor-dir. This is the most reliable way.

2) Heuristic (best-effort):
   If no manifest is provided, we try to pick 6 files per set based on common
   name keywords. This may fail; when it does, the script writes a template
   manifest and exits so you can fill it in.

Dependencies:
  pip install pillow pillow-iff

Usage examples:
  python3 scripts/ua_extract_from_usor.py --usor-dir .usor --manifest .usor/ground_textures_manifest.json
  python3 scripts/ua_extract_from_usor.py --usor-dir /path/to/UA --out-dir resources/terrain/textures --sets 1 2 3

"""
import argparse
import json
import os
from pathlib import Path
from typing import Dict, List, Tuple

# Lazy import PIL so the script can still write a manifest template without Pillow installed
Image = None
try:
    from PIL import Image as _Image
    Image = _Image
except Exception:
    Image = None

SURFACE_OUTPUT_NAMES = [f"ground_{i}.png" for i in range(6)]
KEYWORDS_BY_INDEX = {
    0: ["grass", "green"],
    1: ["dirt", "soil", "earth"],
    2: ["concrete", "road", "paved"],
    3: ["rock", "stone"],
    4: ["water", "sea", "lake"],
    5: ["sand", "desert", "beach"],
}
IMAGE_EXTS = {".iff", ".lbm", ".ilbm", ".bmp", ".png", ".tga", ".jpg", ".jpeg"}


def parse_args():
    ap = argparse.ArgumentParser(
        description="Extract UA ground textures from a .usor/UA tree")
    ap.add_argument("--usor-dir", dest="usor_dir", default=".usor",
                    help="Root directory to scan (default: .usor)")
    ap.add_argument("--out-dir", dest="out_dir", default="resources/terrain/textures",
                    help="Output base dir (default: resources/terrain/textures)")
    ap.add_argument("--manifest", dest="manifest", default=None,
                    help="JSON manifest mapping set->index->relative path")
    ap.add_argument("--sets", dest="sets", nargs="*", type=int,
                    help="Specific set ids to extract (1..6). Default: all 1..6")
    return ap.parse_args()


def load_manifest(path: Path) -> Dict[str, Dict[str, str]]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def find_candidates(root: Path) -> List[Path]:
    cands: List[Path] = []
    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() in IMAGE_EXTS:
            cands.append(p)
    return cands


def pick_by_keywords(cands: List[Path]) -> Dict[int, Path]:
    # naive first-match per index by keywords
    chosen: Dict[int, Path] = {}
    lower_map = {p: p.name.lower() for p in cands}
    for idx in range(6):
        for p, name in lower_map.items():
            if any(kw in name for kw in KEYWORDS_BY_INDEX[idx]):
                if idx not in chosen:
                    chosen[idx] = p
                    break
    return chosen


def write_manifest_template(path: Path, mapping: Dict[int, Path]):
    tmpl = {"set1": {}}  # only a template; user can replicate for other sets
    for i in range(6):
        tmpl["set1"][str(i)] = str(mapping.get(i, Path("REPLACE_ME.iff")))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(tmpl, f, indent=2)
    print(
        f"[INFO] Wrote manifest template to {path}. Edit paths and rerun with --manifest.")


def convert_and_save(src: Path, out_path: Path):
    # Lazy import to avoid requiring Pillow when only generating a manifest
    global Image
    if Image is None:
        try:
            from PIL import Image as _Image
            Image = _Image
        except Exception:
            raise SystemExit(
                "[ERROR] Pillow not available. Install with: pip install pillow pillow-iff")
    src = src.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(src)
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    im.save(out_path, format="PNG")
    print(f"[OK] {src.name} -> {out_path}")


def main():
    args = parse_args()
    usor_dir = Path(args.usor_dir).resolve()
    out_dir = Path(args.out_dir).resolve()
    sets: List[int] = args.sets if args.sets else [1, 2, 3, 4, 5, 6]

    if args.manifest:
        manifest = load_manifest(Path(args.manifest))
    else:
        manifest = None

    for set_id in sets:
        set_key = f"set{set_id}"
        print(f"\n[SET {set_id}] Starting extraction...")
        mapping: Dict[int, Path] = {}

        if manifest and set_key in manifest:
            for idx_str, rel in manifest[set_key].items():
                idx = int(idx_str)
                mapping[idx] = usor_dir / rel
        else:
            # Heuristic: search within the usor_dir for candidates
            cands = find_candidates(usor_dir)
            guessed = pick_by_keywords(cands)
            if len(guessed) < 6:
                # Write template and stop
                tmpl_path = usor_dir / "ground_textures_manifest.json"
                write_manifest_template(tmpl_path, guessed)
                raise SystemExit(
                    f"Could not heuristically find 6 textures for set {set_id}. "
                    f"A template manifest was written to {tmpl_path}. Fill it in and rerun with --manifest."
                )
            mapping = guessed

        # Validate mapping
        for i in range(6):
            if i not in mapping:
                raise SystemExit(
                    f"Mapping for SurfaceType {i} missing in set {set_id}")
            if not Path(mapping[i]).exists():
                raise SystemExit(
                    f"Source file not found for set {set_id}, SurfaceType {i}: {mapping[i]}")

        # Convert
        dest_set_dir = out_dir / f"set{set_id}"
        for i in range(6):
            src = Path(mapping[i])
            out_path = dest_set_dir / SURFACE_OUTPUT_NAMES[i]
            convert_and_save(src, out_path)

    print("\nAll requested sets processed. Restart the editor or switch sets to reload.")


if __name__ == "__main__":
    main()

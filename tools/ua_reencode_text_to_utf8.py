#!/usr/bin/env python3
"""
Re-encode legacy text assets to UTF-8 so Godot's FileAccess / ResourceLoader
do not emit Unicode parse errors (invalid continuation bytes, replacement chars).

Typical Urban Assault-era files were saved as Windows-1252 (Western European)
or Latin-1; Godot interprets file text as UTF-8.

Usage (dry-run — list files that are not valid UTF-8):
  python3 tools/ua_reencode_text_to_utf8.py --dry-run resources/ua/bundled

Convert in place (after backup or git commit):
  python3 tools/ua_reencode_text_to_utf8.py resources/ua/bundled

Force source encoding:
  python3 tools/ua_reencode_text_to_utf8.py --from cp1252 path/to/dir

Pure shell alternative (when you know the source is Windows-1252):
  iconv -f WINDOWS-1252 -t UTF-8 -o file.utf8 file && mv file.utf8 file

  find urban_assault_decompiled-master -name '*.scr' -print0 | while IFS= read -r -d '' f; do
    iconv -f WINDOWS-1252 -t UTF-8 -o "$f.tmp" "$f" && mv "$f.tmp" "$f"
  done
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Try these when UTF-8 strict decode fails (order matters).
_DEFAULT_FALLBACKS: tuple[str, ...] = (
    "cp1252",  # Windows Western European — common for UA-era text
    "iso-8859-1",
    "iso-8859-2",
    "cp1250",  # Central European
)


def _is_probably_binary(sample: bytes, max_nul_ratio: float = 0.01) -> bool:
    if not sample:
        return False
    nul = sample.count(0)
    return (nul / len(sample)) > max_nul_ratio


def _try_decode(data: bytes, encoding: str) -> str | None:
    try:
        return data.decode(encoding, errors="strict")
    except UnicodeDecodeError:
        return None


def process_file(
    path: Path,
    *,
    dry_run: bool,
    force_from: str | None,
    verbose: bool,
) -> tuple[str, str | None]:
    """
    Returns (status, detail) where status is 'ok_utf8' | 'converted' | 'skipped' | 'error'
    """
    try:
        data = path.read_bytes()
    except OSError as e:
        return "error", str(e)

    if _is_probably_binary(data[: min(8192, len(data))]):
        return "skipped", "binary"

    # Already valid UTF-8
    if _try_decode(data, "utf-8") is not None:
        return "ok_utf8", None

    if force_from:
        text = _try_decode(data, force_from)
        if text is None:
            return "error", f"decode failed as {force_from}"
        if not dry_run:
            path.write_text(text, encoding="utf-8")
        return "converted", force_from

    for enc in _DEFAULT_FALLBACKS:
        text = _try_decode(data, enc)
        if text is None:
            continue
        # Reject if re-encoding to UTF-8 doesn't need changes but utf-8 failed — shouldn't happen
        if not dry_run:
            path.write_text(text, encoding="utf-8")
        if verbose:
            return "converted", enc
        return "converted", enc

    return "error", "no matching legacy encoding"


def main() -> int:
    p = argparse.ArgumentParser(
        description="Convert legacy-encoded text files to UTF-8 for Godot."
    )
    p.add_argument(
        "roots",
        nargs="+",
        type=Path,
        help="Directories to walk (e.g. urban_assault_decompiled-master)",
    )
    p.add_argument(
        "--extensions",
        default=".sdf,.scr,.lst,.txt,.csv,.md,.json,.xml,.html,.htm,.cfg,.ini,.log",
        help="Comma-separated suffixes (include leading dot)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Only report files that are not valid UTF-8; do not write",
    )
    p.add_argument(
        "--from",
        dest="force_from",
        metavar="ENCODING",
        help="Force this source encoding (e.g. cp1252, latin-1)",
    )
    p.add_argument("-v", "--verbose", action="store_true")
    args = p.parse_args()

    exts = {e.strip().lower() for e in args.extensions.split(",") if e.strip()}
    if not exts:
        print("No extensions configured.", file=sys.stderr)
        return 2

    stats = {"ok_utf8": 0, "converted": 0, "skipped": 0, "error": 0}
    errors: list[tuple[Path, str]] = []

    for root in args.roots:
        if not root.exists():
            print(f"Missing: {root}", file=sys.stderr)
            stats["error"] += 1
            continue
        for dirpath, _dirnames, filenames in os.walk(root):
            for name in filenames:
                path = Path(dirpath) / name
                suf = path.suffix.lower()
                if suf not in exts:
                    continue
                status, detail = process_file(
                    path,
                    dry_run=args.dry_run,
                    force_from=args.force_from,
                    verbose=args.verbose,
                )
                stats[status] = stats.get(status, 0) + 1
                if status == "error":
                    errors.append((path, detail or ""))
                elif status == "converted":
                    prefix = "[dry-run] would convert" if args.dry_run else "converted"
                    enc = detail or "?"
                    print(f"{prefix}: {path} (from {enc})")
                elif args.verbose and status == "ok_utf8":
                    print(f"ok utf-8: {path}")
                elif args.verbose and status == "skipped":
                    print(f"skipped ({detail}): {path}")

    print(
        "Summary: ok_utf8=%(ok_utf8)d converted=%(converted)d skipped=%(skipped)d error=%(error)d"
        % stats
    )
    if errors:
        print("\nErrors:", file=sys.stderr)
        for path, msg in errors[:50]:
            print(f"  {path}: {msg}", file=sys.stderr)
        if len(errors) > 50:
            print(f"  ... and {len(errors) - 50} more", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

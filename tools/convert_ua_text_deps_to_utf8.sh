#!/usr/bin/env bash
set -euo pipefail

# Converts known UA editor *dependency* text files to UTF-8 to silence Godot's
# "Unicode parsing error" logs.
#
# Safe by default:
# - creates a side-by-side .bak copy before converting each file
# - only touches file extensions/patterns we expect to be plain text
#
# NOT intended for user-imported content (e.g. .ldf).
#
# Usage:
#   tools/convert_ua_text_deps_to_utf8.sh --root "path/to/ua/game/data"
#   tools/convert_ua_text_deps_to_utf8.sh --root "resources/ua/bundled"
#   tools/convert_ua_text_deps_to_utf8.sh --root "path1" --root "path2"
#
# Options:
#   --from=WINDOWS-1252   Source encoding (default: WINDOWS-1252)
#   --dry-run             Print files that would be converted

FROM_ENCODING="WINDOWS-1252"
DRY_RUN=0
ROOTS=()

for arg in "$@"; do
  case "$arg" in
    --from=*)
      FROM_ENCODING="${arg#--from=}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --root)
      echo "ERROR: --root requires a value (use: --root=PATH)" >&2
      exit 2
      ;;
    --root=*)
      ROOTS+=("${arg#--root=}")
      ;;
    *)
      echo "ERROR: Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if [[ ${#ROOTS[@]} -eq 0 ]]; then
  echo "ERROR: Provide at least one --root=PATH" >&2
  exit 2
fi

if ! command -v iconv >/dev/null 2>&1; then
  echo "ERROR: iconv not found. Install it (glibc/binutils locales) and retry." >&2
  exit 2
fi

shopt -s nullglob

convert_file() {
  local f="$1"
  local bak="${f}.bak"

  if [[ -e "$bak" ]]; then
    # Avoid repeated backups if the script is re-run.
    bak="${f}.bak.$(date +%s)"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "DRY: $f"
    return 0
  fi

  if [[ ! -w "$f" ]]; then
    echo "SKIP (not writable): $f" >&2
    return 0
  fi

  cp -p -- "$f" "$bak"
  # -c: skip invalid sequences rather than failing hard (keeps conversion robust)
  # We prefer a successful UTF-8 result over preserving rare junk bytes in comments.
  iconv -f "$FROM_ENCODING" -t UTF-8 -c -- "$bak" > "$f"
}

for root in "${ROOTS[@]}"; do
  if [[ ! -d "$root" ]]; then
    echo "WARN: root not found, skipping: $root" >&2
    continue
  fi

  if [[ $DRY_RUN -ne 1 && ! -w "$root" ]]; then
    echo "WARN: root not writable: $root" >&2
    echo "      Fix ownership/permissions (example): sudo chown -R \"$USER:$USER\" \"$root\"" >&2
  fi

  # Common UA script/list formats we parse as text.
  while IFS= read -r -d '' f; do
    convert_file "$f"
  done < <(
    find "$root" -type f \( \
      -iname '*.scr' -o \
      -iname '*.sdf' -o \
      -iname '*.lst' -o \
      -iname 'visproto.lst' \
    \) -print0
  )
done

echo "Done."


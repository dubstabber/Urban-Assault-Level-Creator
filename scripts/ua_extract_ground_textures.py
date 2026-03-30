#!/usr/bin/env python3
"""
ua_extract_ground_textures.py

Purpose:
- Convert Urban Assault ground textures (SurfaceType 0..5 per environment set) from legacy formats
  (embedded in SET.BAS or standalone ILBM) into Godot-ready PNGs.
- Supports auto-detect from OBJECTS/SET.BAS (embedded resources) or manual/legacy ILB mapping.

Usage:
  Auto from OBJECTS/SET.BAS (recommended):
    python3 scripts/ua_extract_ground_textures.py \
      --in path/to/DATA/SET1 --set 1 --auto-objects \
      --out resources/terrain/textures/set1

  Manual mapping (fallback):
    python3 scripts/ua_extract_ground_textures.py \
      --in path/to/DATA/SET1 --set 1 \
      --map 0:OBJECTS/SET.BAS:BODEN1.ILBM 1:OBJECTS/SET.BAS:BODEN2.ILBM ... \
      --out resources/terrain/textures/set1

  Legacy ILB hypothesis (not terrain; for reference only):
    python3 scripts/ua_extract_ground_textures.py \
      --in path/to/DATA/SET1 --set 1 --auto-ilb \
      --out resources/terrain/textures/set1

Notes:
- This script does NOT include any UA assets and assumes you legally own them.
- Pillow is required to write PNGs. If Pillow cannot open ILB/ILBM directly, this
  script falls back to a built-in ILBM decoder (ByteRun1 + 1/2/4/8 planes).
- The tool will create the output directory if needed and write ground_0.png..ground_5.png.

Important:
- UA embeds ground textures as VBMP/ILBM forms inside OBJECTS/SET.BAS under ilbm.class entries
  typically named BODEN1.ILBM..BODEN5.ILBM (German "Boden" = ground). A sixth SurfaceType may
  map to a non-"BODEN" name (e.g., water) depending on the set.
"""

import argparse
import os
from pathlib import Path
from typing import List, Tuple, Optional, Dict

try:
    from PIL import Image
except Exception:
    Image = None

SURFACE_NAMES = [
    "ground_0.png", "ground_1.png", "ground_2.png",
    "ground_3.png", "ground_4.png", "ground_5.png",
]

# ---------------- IFF helpers (ILBM and VBMP) ----------------


def _read_chunks_ilbm(data: bytes):
    assert data[0:4] == b"FORM"
    size = int.from_bytes(data[4:8], 'big')
    form = data[8:12]
    if form != b"ILBM":
        raise ValueError("Not ILBM FORM")
    off = 12
    while off + 8 <= len(data):
        ck = data[off:off+4]
        off += 4
        sz = int.from_bytes(data[off:off+4], 'big')
        off += 4
        chunk = data[off:off+sz]
        off += sz + (sz & 1)
        yield ck, chunk


def _byterun1_decompress(src: bytes) -> bytes:
    # Amiga ByteRun1 RLE
    out = bytearray()
    i = 0
    L = len(src)
    while i < L:
        n = int.from_bytes(src[i:i+1], 'big', signed=True)
        i += 1
        if n >= 0:
            # copy next n+1 bytes
            run = src[i:i+n+1]
            i += n+1
            out.extend(run)
        elif n != -128:
            # repeat next byte (-n + 1) times
            b = src[i:i+1]
            i += 1
            out.extend(b * (-n + 1))
        # else n == -128: NOOP
    return bytes(out)


def _ilbm_to_image(data: bytes) -> 'Image.Image':
    if Image is None:
        raise SystemExit(
            "[ERROR] Pillow not available. Install with: pip install pillow")
    w = h = planes = None
    cmaps: List[int] = []
    body: Optional[bytes] = None
    compression = 0
    for ck, chunk in _read_chunks_ilbm(data):
        if ck == b"BMHD":
            w = int.from_bytes(chunk[0:2], 'big')
            h = int.from_bytes(chunk[2:4], 'big')
            planes = chunk[8]
            compression = chunk[10]
        elif ck == b"CMAP":
            cmaps = list(chunk)  # 3*n bytes
        elif ck == b"BODY":
            body = chunk
    if None in (w, h, planes) or body is None:
        raise ValueError("ILBM missing BMHD/CMAP/BODY")

    if compression == 1:
        body = _byterun1_decompress(body)

    bpr = ((w + 15) // 16) * 2
    rows = []
    off = 0
    for _y in range(h):
        plane_rows = []
        for p in range(planes):
            plane_rows.append(body[off:off+bpr])
            off += bpr
        row = bytearray(w)
        for x in range(w):
            bit = 7 - (x & 7)
            byte_idx = x >> 3
            val = 0
            for p in range(planes):
                b = plane_rows[p][byte_idx]
                val |= ((b >> bit) & 1) << p
            row[x] = val
        rows.append(bytes(row))

    im = Image.frombytes('P', (w, h), b''.join(rows))
    if cmaps:
        pal = cmaps[:]
        if len(pal) < 768:
            pal += [0] * (768 - len(pal))
        im.putpalette(pal)
        im = im.convert('RGBA')
    else:
        im = im.convert('RGBA')
    return im


def open_image_any(src: Path) -> 'Image.Image':
    data = src.read_bytes()
    if data[0:4] == b'FORM' and data[8:12] == b'ILBM':
        return _ilbm_to_image(data)
    if Image is None:
        raise SystemExit(
            "[ERROR] Pillow not available. Install with: pip install pillow")
    return Image.open(src)


def _read_cmap_from_ilbm_bytes(data: bytes) -> Optional[List[int]]:
    if not (data[0:4] == b'FORM' and data[8:12] == b'ILBM'):
        return None
    for ck, chunk in _read_chunks_ilbm(data):
        if ck == b"CMAP":
            pal = list(chunk)
            if len(pal) < 768:
                pal += [0] * (768 - len(pal))
            return pal
    return None


def _load_standard_palette(in_dir: Path) -> Optional[List[int]]:
    # Try set-specific palette first
    pal_path = _find_case_insensitive(in_dir, 'PALETTE/Standard.pal')
    if pal_path and pal_path.exists():
        try:
            return _read_cmap_from_ilbm_bytes(pal_path.read_bytes())
        except Exception:
            pass
    # Fallback: global DATA/MC2RES/STANDARD.PAL
    root = in_dir
    # climb up until we hit DATA
    while root.name.upper() != 'DATA' and root.parent != root:
        root = root.parent
    glob_pal = _find_case_insensitive(
        root, 'MC2RES/STANDARD.PAL') if root.name.upper() == 'DATA' else None
    if glob_pal and glob_pal.exists():
        try:
            return _read_cmap_from_ilbm_bytes(glob_pal.read_bytes())
        except Exception:
            pass
    return None

# ---------------- CLI and extraction ----------------


def parse_args():
    ap = argparse.ArgumentParser(
        description="Extract/convert UA ground textures to PNG")
    ap.add_argument("--in", dest="in_dir", required=True,
                    help="Input directory (e.g., path/to/DATA/SET1)")
    ap.add_argument("--set", dest="set_id", type=int,
                    required=True, help="Environment set id (1..6)")
    ap.add_argument("--map", dest="mapping", nargs=6, metavar="IDX:FILE",
                    help="Six mappings 'i:filename' for i=0..5 (relative to --in). For SET.BAS entries use OBJECTS/SET.BAS:NAME.ILBM")
    ap.add_argument("--out", dest="out_dir", required=True,
                    help="Output directory (e.g., resources/terrain/textures/set1)")
    ap.add_argument("--auto-ilb", dest="auto_ilb", action="store_true",
                    help="Auto-detect six ILB textures under HI/{ALPHA,BETA,GAMMA}/FX{1,2} (not recommended; SFX, not ground).")
    ap.add_argument("--auto-objects", dest="auto_objects", action="store_true",
                    help="Auto-extract ground textures from OBJECTS/SET.BAS (BODEN*.ILBM, WATER/WASSER).")
    return ap.parse_args()


def _find_case_insensitive(base: Path, rel: str) -> Optional[Path]:
    cand = base / rel
    if cand.exists():
        return cand
    # Case-insensitive search
    parts = Path(rel).parts
    cur = base
    for part in parts:
        low = part.lower()
        hit = None
        for child in cur.iterdir():
            if child.name.lower() == low:
                hit = child
                break
        if not hit:
            return None
        cur = hit
    return cur


def _auto_ilb_pairs(in_dir: Path) -> List[Tuple[int, Path]]:
    order = [
        "HI/ALPHA/FX1.ILB",
        "HI/ALPHA/FX2.ILB",
        "HI/BETA/FX1.ILB",
        "HI/BETA/FX2.ILB",
        "HI/GAMMA/FX1.ILB",
        "HI/GAMMA/FX2.ILB",
    ]
    pairs: List[Tuple[int, Path]] = []
    for idx, rel in enumerate(order):
        p = _find_case_insensitive(in_dir, rel)
        if p is None:
            raise SystemExit(
                f"[AUTO] Missing expected ILB: {rel} under {in_dir}")
        pairs.append((idx, p))
    return pairs
# ----- OBJECTS/SET.BAS extraction -----


def _iter_emrs(b: bytes):
    off = 0
    L = len(b)
    while True:
        i = b.find(b'EMRS', off)
        if i < 0:
            break
        size = int.from_bytes(b[i+4:i+8], 'big')
        body = b[i+8:i+8+size]
        parts = body.split(b'\x00', 2)
        if len(parts) >= 2:
            classname = parts[0].decode('latin-1', 'ignore')
            resname = parts[1].decode('latin-1', 'ignore')
            payload = body[len(parts[0])+len(parts[1])+2:]
            yield (classname, resname, payload)
        off = i + 8 + size


def _vbmp_to_image(data: bytes, fallback_palette: Optional[List[int]] = None) -> 'Image.Image':
    if Image is None:
        raise SystemExit(
            "[ERROR] Pillow required. Install with: pip install pillow")
    if not (data[0:4] == b'FORM' and data[8:12] == b'VBMP'):
        raise ValueError('Not a VBMP FORM')
    end = 8 + int.from_bytes(data[4:8], 'big')
    i = 12
    w = h = None
    palette = None
    pixels = None
    while i + 8 <= len(data) and i < end:
        tag = data[i:i+4]
        sz = int.from_bytes(data[i+4:i+8], 'big')
        i2 = i + 8
        if tag == b'HEAD':
            w = int.from_bytes(data[i2:i2+2], 'big')
            h = int.from_bytes(data[i2+2:i2+4], 'big')
        elif tag == b'CMAP':
            palbytes = data[i2:i2+sz]
            palette = list(palbytes)
            if len(palette) < 768:
                palette += [0] * (768 - len(palette))
        elif tag == b'BODY':
            pixels = data[i2:i2+sz]
        i = i + 8 + ((sz + 1) & ~1)
    if None in (w, h) or pixels is None:
        raise ValueError('VBMP missing HEAD/BODY')
    im = Image.frombytes('P', (w, h), pixels[:w*h])
    # If VBMP has no palette, fallback to provided set palette
    if palette is None and fallback_palette is not None:
        palette = fallback_palette
    if palette:
        im.putpalette(palette)
        return im.convert('RGBA')
    # Last resort: grayscale
    return im.convert('RGBA')


def _extract_ground_from_set_bas(bas_path: Path, fallback_palette: Optional[List[int]] = None) -> Dict[str, Image.Image]:
    b = bas_path.read_bytes()
    found: Dict[str, Image.Image] = {}
    off = 0
    while True:
        i = b.find(b'EMRS', off)
        if i < 0:
            break
        size = int.from_bytes(b[i+4:i+8], 'big')
        body = b[i+8:i+8+size]
        parts = body.split(b'\x00', 2)
        classname = parts[0].decode(
            'latin-1', 'ignore') if len(parts) > 0 else ''
        resname = parts[1].decode(
            'latin-1', 'ignore') if len(parts) > 1 else ''
        name_up = resname.upper()
        nxt = i + 8 + size
        # The resource data immediately follows as an IFF FORM chunk
        if nxt + 12 <= len(b) and b[nxt:nxt+4] == b'FORM':
            formtype = b[nxt+8:nxt+12]
            chunk_size = int.from_bytes(b[nxt+4:nxt+8], 'big')
            data = b[nxt:nxt+8+chunk_size]
            try:
                if formtype == b'ILBM':
                    im = _ilbm_to_image(data)
                elif formtype == b'VBMP':
                    im = _vbmp_to_image(data, fallback_palette)
                else:
                    im = None
            except Exception:
                im = None
            if im is not None and name_up.endswith('.ILBM'):
                if name_up.startswith('BODEN') or name_up in ('WATER.ILBM', 'WASSER.ILBM'):
                    found[name_up] = im
        off = nxt
    return found


def _auto_objects_pairs(in_dir: Path) -> List[Tuple[int, Image.Image]]:
    """
    Extract ground textures from SET.BAS and map them to SurfaceType indices 0-5.

    UA Texture Mapping:
    - Original UA has BODEN1-5 (5 textures, 1-indexed) and optionally WATER/WASSER
    - SurfaceType values in set.sdf range from 0-5 (6 values)
    - Mapping:
      - SurfaceType 0 → WATER if available, else BODEN1 (ground_0.png)
      - SurfaceType 1 → BODEN1 (ground_1.png)
      - SurfaceType 2 → BODEN2 (ground_2.png)
      - SurfaceType 3 → BODEN3 (ground_3.png)
      - SurfaceType 4 → BODEN4 (ground_4.png) - often water/special in some sets
      - SurfaceType 5 → BODEN5 (ground_5.png)

    Note: When no WATER texture exists, ground_0 and ground_1 will be identical
    (both using BODEN1). This is intentional as both SurfaceType 0 and 1 should
    use the same base ground texture in sets without water.
    """
    bas = _find_case_insensitive(in_dir, 'OBJECTS/SET.BAS')
    if not bas or not bas.exists():
        raise SystemExit(f"Missing {in_dir}/OBJECTS/SET.BAS")
    # Load set palette to apply to VBMPs that don't carry their own CMAP
    set_palette = _load_standard_palette(in_dir)
    imgs = _extract_ground_from_set_bas(bas, set_palette)
    if not imgs:
        raise SystemExit(f"No ground textures found in {bas}")

    # Build final list of six images by index 0..5
    final: List[Optional[Image.Image]] = [None] * 6

    # Index 0: prefer WATER/WASSER if present, else fall back to BODEN1
    water = None
    for k in ('WATER.ILBM', 'WASSER.ILBM'):
        if k in imgs:
            water = imgs[k]
            print(f"[INFO] Found {k} for SurfaceType 0")
            break
    if water is not None:
        final[0] = water
    elif 'BODEN1.ILBM' in imgs:
        final[0] = imgs['BODEN1.ILBM']
        print(
            "[INFO] No WATER texture found; SurfaceType 0 will use BODEN1 (same as SurfaceType 1)")
    else:
        final[0] = next(iter(imgs.values()))
        print(
            "[WARN] No WATER or BODEN1 found; using first available texture for SurfaceType 0")

    # Indices 1..5: map to BODEN{i}
    for i in range(1, 6):
        key = f'BODEN{i}.ILBM'
        if key in imgs:
            final[i] = imgs[key]
        else:
            # Fallback: use previous texture if BODEN{i} doesn't exist
            final[i] = final[i-1] if final[i -
                                           1] is not None else next(iter(imgs.values()))
            print(
                f"[WARN] {key} not found; SurfaceType {i} will use fallback texture")

    return [(i, final[i]) for i in range(6)]


def _save_image(im: Image.Image, out_path: Path) -> None:
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path, format='PNG')


def convert_and_save(src: Path, out_path: Path) -> None:
    im = open_image_any(src)
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im.save(out_path, format="PNG")


def main():
    args = parse_args()
    in_dir = Path(args.in_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    file_pairs: List[Tuple[int, Path]] = []
    image_pairs: List[Tuple[int, Image.Image]] = []

    if args.auto_objects:
        image_pairs = _auto_objects_pairs(in_dir)
    elif args.auto_ilb:
        file_pairs = _auto_ilb_pairs(in_dir)
    elif args.mapping:
        bas_cache: Optional[Dict[str, Image.Image]] = None
        for token in args.mapping:
            try:
                idx_str, spec = token.split(":", 1)
                idx = int(idx_str)
                if idx < 0 or idx > 5:
                    raise ValueError("index out of range")
                if spec.upper().startswith('OBJECTS/SET.BAS:'):
                    bas_rel, name = spec.split(':', 1)
                    bas = _find_case_insensitive(in_dir, bas_rel)
                    if bas is None:
                        raise SystemExit(f"Missing {in_dir}/{bas_rel}")
                    if bas_cache is None:
                        bas_cache = _extract_ground_from_set_bas(bas)
                    name_up = name.upper()
                    if name_up not in bas_cache:
                        raise SystemExit(f"Resource {name} not found in {bas}")
                    image_pairs.append((idx, bas_cache[name_up]))
                else:
                    p = _find_case_insensitive(in_dir, spec)
                    if p is None:
                        raise SystemExit(
                            f"Missing source file (case-insensitive): {in_dir}/{spec}")
                    file_pairs.append((idx, p))
            except Exception:
                raise SystemExit(
                    f"Invalid --map token: {token} (expected i:filename or i:OBJECTS/SET.BAS:NAME)")
    else:
        raise SystemExit(
            "Provide one of: --auto-objects | --auto-ilb | --map with six entries i:... for i=0..5")

    # Normalize to images
    pairs: List[Tuple[int, Image.Image]] = []
    if image_pairs:
        pairs = sorted(image_pairs, key=lambda t: t[0])
        # Pad if fewer than 6
        if len(pairs) < 6 and pairs:
            while len(pairs) < 6:
                pairs.append((len(pairs), pairs[-1][1]))
    else:
        if len(file_pairs) != 6:
            raise SystemExit(f"Need six textures; got {len(file_pairs)}")
        pairs = sorted(file_pairs, key=lambda t: t[0])
        pairs = [(i, open_image_any(p)) for (i, p) in pairs]

    # Save
    for idx, im in pairs:
        try:
            out_path = out_dir / SURFACE_NAMES[idx]
            _save_image(im, out_path)
            print(f"[OK] ground_{idx}.png -> {out_path}")
        except Exception as e:
            raise SystemExit(f"Failed to save ground_{idx}: {e}")

    print("All six ground textures written to:", out_dir)
    print("Restart the editor or switch sets to reload.")


if __name__ == "__main__":
    main()

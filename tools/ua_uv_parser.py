#!/usr/bin/env python3
import argparse
import csv
import json
import os
import re
from collections import defaultdict
from typing import Dict, Tuple, Any

TokenRe = re.compile(r"(\w+)=([^\s]+)")

# Helpers to parse composite tokens like sec=(x,y) u=[a,b]


def _parse_pair(val: str) -> Tuple[float, float]:
    if not val:
        return 0.0, 0.0
    v = val.strip()
    # Trim surrounding [] or () if present
    if (v.startswith('[') and v.endswith(']')) or (v.startswith('(') and v.endswith(')')):
        v = v[1:-1]
    a, b = v.split(',', 1)
    return float(a), float(b)


def _parse_int(val: str) -> int:
    # handle (nil) and pointers
    if val == '(nil)':
        return 0
    # hex pointer like 0x1234abcd
    if val.startswith('0x'):
        try:
            return int(val, 16)
        except Exception:
            return 0
    try:
        return int(val)
    except Exception:
        return 0


def _parse_float(val: str) -> float:
    try:
        return float(val)
    except Exception:
        return 0.0


def parse_line(line: str) -> Dict[str, Any]:
    # Expected keys: set, typ, surf, sec=(x,y), sub=(x,y), lego, tex, name, u=[a,b], v=[a,b], verts
    out: Dict[str, Any] = {}
    # name can contain spaces? In current format it doesn't (comes from resource name), but be defensive
    # We'll scan tokens manually
    parts = line.strip().split()
    i = 0
    while i < len(parts):
        tok = parts[i]
        if '=' not in tok:
            i += 1
            continue
        key, val = tok.split('=', 1)
        # If value seems unfinished (e.g., name with spaces), join until token ends not with comma
        if key == 'name' and (val.endswith(',') or (i + 1 < len(parts) and not parts[i+1].startswith(('set=', 'typ=', 'surf=', 'sec=', 'sub=', 'lego=', 'tex=', 'name=', 'u=', 'v=', 'verts=')))):
            # accumulate remaining tokens until next key or end
            j = i + 1
            while j < len(parts) and '=' not in parts[j]:
                val += ' ' + parts[j]
                j += 1
            i = j - 1
        if key in ('sec', 'sub', 'u', 'v', 'size'):
            a, b = _parse_pair(val)
            if key == 'sec':
                out['secx'], out['secy'] = int(a), int(b)
            elif key == 'sub':
                out['subx'], out['suby'] = int(a), int(b)
            elif key == 'u':
                out['umin'], out['umax'] = a, b
            elif key == 'v':
                out['vmin'], out['vmax'] = a, b
            elif key == 'size':
                out['tex_w'], out['tex_h'] = int(a), int(b)
        elif key in ('set', 'typ', 'surf', 'lego', 'verts'):
            out[key] = _parse_int(val)
        elif key == 'tex':
            out['tex_ptr'] = _parse_int(val)
        elif key == 'name':
            out['name'] = val
        else:
            # ignore unknowns
            pass
        i += 1
    return out


def aggregate(records: Dict[str, Any]):
    by_sector_sub: Dict[Tuple[int, int, int, int, int, int], Dict[str, Dict[str, Any]]] = defaultdict(lambda: defaultdict(lambda: {
        'count': 0,
        'umin':  1e9,
        'umax': -1e9,
        'vmin':  1e9,
        'vmax': -1e9,
        'verts': 0,
        'u_px_min':  1e9,
        'u_px_max': -1e9,
        'v_px_min':  1e9,
        'v_px_max': -1e9,
        'tex_w': None,
        'tex_h': None,
    }))

    by_sector: Dict[Tuple[int, int, int], Dict[str, Dict[str, Any]]] = defaultdict(lambda: defaultdict(lambda: {
        'count': 0,
        'umin':  1e9,
        'umax': -1e9,
        'vmin':  1e9,
        'vmax': -1e9,
        'verts': 0,
        'u_px_min':  1e9,
        'u_px_max': -1e9,
        'v_px_min':  1e9,
        'v_px_max': -1e9,
        'tex_w': None,
        'tex_h': None,
    }))

    textures: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
        'count': 0,
        'sectors': set(),
        'names': set(),
    })

    for rec in records:
        name = rec.get('name', '<unknown>')
        set_id = rec.get('set', -1)
        typ = rec.get('typ', -1)
        surf = rec.get('surf', -1)
        secx = rec.get('secx', -1)
        secy = rec.get('secy', -1)
        subx = rec.get('subx', -1)
        suby = rec.get('suby', -1)
        lego = rec.get('lego', -1)
        verts = rec.get('verts', 0)
        umin = rec.get('umin', 0.0)
        umax = rec.get('umax', 0.0)
        vmin = rec.get('vmin', 0.0)
        vmax = rec.get('vmax', 0.0)
        tw = rec.get('tex_w')
        th = rec.get('tex_h')

        k_sub = (set_id, secx, secy, subx, suby, lego)
        k_sec = (set_id, secx, secy)

        agg_s = by_sector_sub[k_sub][name]
        agg_s['count'] += 1
        agg_s['verts'] += verts
        agg_s['umin'] = min(agg_s['umin'], umin)
        agg_s['umax'] = max(agg_s['umax'], umax)
        agg_s['vmin'] = min(agg_s['vmin'], vmin)
        agg_s['vmax'] = max(agg_s['vmax'], vmax)
        if tw is not None and th is not None:
            agg_s['tex_w'] = tw
            agg_s['tex_h'] = th
            agg_s['u_px_min'] = min(agg_s['u_px_min'], umin * tw)
            agg_s['u_px_max'] = max(agg_s['u_px_max'], umax * tw)
            agg_s['v_px_min'] = min(agg_s['v_px_min'], vmin * th)
            agg_s['v_px_max'] = max(agg_s['v_px_max'], vmax * th)

        agg = by_sector[k_sec][name]
        agg['count'] += 1
        agg['verts'] += verts
        agg['umin'] = min(agg['umin'], umin)
        agg['umax'] = max(agg['umax'], umax)
        agg['vmin'] = min(agg['vmin'], vmin)
        agg['vmax'] = max(agg['vmax'], vmax)
        if tw is not None and th is not None:
            agg['tex_w'] = tw
            agg['tex_h'] = th
            agg['u_px_min'] = min(agg['u_px_min'], umin * tw)
            agg['u_px_max'] = max(agg['u_px_max'], umax * tw)
            agg['v_px_min'] = min(agg['v_px_min'], vmin * th)
            agg['v_px_max'] = max(agg['v_px_max'], vmax * th)

        tex = textures[name]
        tex['count'] += 1
        tex['sectors'].add(k_sec)
        tex['names'].add(name)

    # Convert sets to lists for JSON serialization
    textures_json = {}
    for name, meta in textures.items():
        textures_json[name] = {
            'count': meta['count'],
            'sectors': [list(x) for x in sorted(meta['sectors'])],
        }

    return by_sector_sub, by_sector, textures_json


def write_outputs(outdir: str,
                  by_sector_sub: Dict,
                  by_sector: Dict,
                  textures_json: Dict):
    os.makedirs(outdir, exist_ok=True)

    # JSON summaries
    with open(os.path.join(outdir, 'summary_by_sector.json'), 'w') as f:
        json.dump({str(k): v for k, v in by_sector.items()}, f, indent=2)

    with open(os.path.join(outdir, 'summary_by_sector_subcell.json'), 'w') as f:
        json.dump({str(k): v for k, v in by_sector_sub.items()}, f, indent=2)

    with open(os.path.join(outdir, 'textures.json'), 'w') as f:
        json.dump(textures_json, f, indent=2)

    # CSV flat summary
    csv_path = os.path.join(outdir, 'summary.csv')
    with open(csv_path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(['set', 'secx', 'secy', 'subx', 'suby', 'lego', 'name', 'count', 'umin', 'umax',
                   'vmin', 'vmax', 'verts', 'tex_w', 'tex_h', 'u_px_min', 'u_px_max', 'v_px_min', 'v_px_max'])
        for k, tex_map in by_sector_sub.items():
            set_id, secx, secy, subx, suby, lego = k
            for name, agg in tex_map.items():
                w.writerow([
                    set_id, secx, secy, subx, suby, lego, name,
                    agg['count'],
                    f"{agg['umin']:.6f}", f"{agg['umax']:.6f}",
                    f"{agg['vmin']:.6f}", f"{agg['vmax']:.6f}",
                    agg['verts'],
                    agg['tex_w'] if agg['tex_w'] is not None else '',
                    agg['tex_h'] if agg['tex_h'] is not None else '',
                    f"{agg['u_px_min']:.3f}" if agg['tex_w'] is not None else '',
                    f"{agg['u_px_max']:.3f}" if agg['tex_w'] is not None else '',
                    f"{agg['v_px_min']:.3f}" if agg['tex_h'] is not None else '',
                    f"{agg['v_px_max']:.3f}" if agg['tex_h'] is not None else '',
                ])


def main():
    ap = argparse.ArgumentParser(
        description='Parse UA terrain UV debug logs and aggregate per sector/subcell.')
    ap.add_argument('logfile', help='Path to terrain_debug.txt')
    ap.add_argument('--out', default='docs/uv/out',
                    help='Output directory for summaries')
    ap.add_argument('--set', dest='f_set', type=int,
                    help='Filter: terrain set id')
    ap.add_argument('--sec', dest='f_sec', help='Filter: sector as x,y')
    ap.add_argument('--sub', dest='f_sub', help='Filter: subcell as x,y')
    ap.add_argument('--lego', dest='f_lego', type=int, help='Filter: lego id')
    args = ap.parse_args()

    if not os.path.isfile(args.logfile):
        raise SystemExit(f"Input logfile not found: {args.logfile}")

    def parse_xy(xy: str):
        if not xy:
            return None
        try:
            x, y = xy.split(',', 1)
            return int(x), int(y)
        except Exception:
            return None

    f_sec = parse_xy(args.f_sec)
    f_sub = parse_xy(args.f_sub)

    records = []
    with open(args.logfile, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            rec = parse_line(line)
            if not rec:
                continue
            # Apply filters if provided
            if args.f_set is not None and rec.get('set') != args.f_set:
                continue
            if f_sec is not None and (rec.get('secx'), rec.get('secy')) != f_sec:
                continue
            if f_sub is not None and (rec.get('subx'), rec.get('suby')) != f_sub:
                continue
            if args.f_lego is not None and rec.get('lego') != args.f_lego:
                continue
            records.append(rec)

    by_sector_sub, by_sector, textures_json = aggregate(records)
    write_outputs(args.out, by_sector_sub, by_sector, textures_json)
    print(f"Wrote summaries to {args.out}")


if __name__ == '__main__':
    main()

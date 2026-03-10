#!/usr/bin/env python3
import argparse
import json
import os
import re
from collections import defaultdict
from typing import Dict, Any, Tuple

# Reuse parse from ua_uv_parser, but keep local to avoid import hassles
PTR_RE = re.compile(r"^0x[0-9a-fA-F]+$")


def _parse_pair(val: str) -> Tuple[float, float]:
    v = val.strip()
    if (v.startswith('[') and v.endswith(']')) or (v.startswith('(') and v.endswith(')')):
        v = v[1:-1]
    a, b = v.split(',', 1)
    return float(a), float(b)


def parse_line(line: str) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    parts = line.strip().split()
    for tok in parts:
        if '=' not in tok:
            continue
        key, val = tok.split('=', 1)
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
            try:
                out[key] = int(val) if val != '(nil)' else 0
            except Exception:
                out[key] = 0
        elif key == 'tex':
            # keep original string and numeric if hex
            out['tex_ptr_str'] = val
            try:
                out['tex_ptr'] = int(val, 16) if PTR_RE.match(val) else 0
            except Exception:
                out['tex_ptr'] = 0
        elif key == 'name':
            out['name'] = val
    return out


def correlate(logfile: str, outlines_path: str, f_set=None, f_sec=None, f_sub=None, f_lego=None):
    # Load outlines JSON
    with open(outlines_path, 'r') as f:
        outlines = json.load(f)
    # Map by pointer int
    outline_by_ptr: Dict[int, Dict[str, Any]] = {}
    for entry in outlines:
        ptr_str = entry.get('ptr')
        if isinstance(ptr_str, str) and ptr_str.startswith('0x'):
            try:
                ptr = int(ptr_str, 16)
            except Exception:
                continue
            outline_by_ptr[ptr] = entry

    # Aggregate by tex_ptr
    by_ptr: Dict[int, Dict[str, Any]] = defaultdict(lambda: {
        'count': 0,
        'name': None,
        'tex_w': None,
        'tex_h': None,
        'umin':  1e9, 'umax': -1e9,
        'vmin':  1e9, 'vmax': -1e9,
    })

    with open(logfile, 'r') as f:
        for line in f:
            if not line or line[0] == '#':
                continue
            rec = parse_line(line)
            if not rec:
                continue
            if f_set is not None and rec.get('set') != f_set:
                continue
            if f_sec is not None and (rec.get('secx'), rec.get('secy')) != f_sec:
                continue
            if f_sub is not None and (rec.get('subx'), rec.get('suby')) != f_sub:
                continue
            if f_lego is not None and rec.get('lego') != f_lego:
                continue
            ptr = rec.get('tex_ptr', 0)
            if ptr == 0:
                continue
            agg = by_ptr[ptr]
            agg['count'] += 1
            if rec.get('name'):
                agg['name'] = rec['name']
            if rec.get('tex_w') and rec.get('tex_h'):
                agg['tex_w'] = rec['tex_w']
                agg['tex_h'] = rec['tex_h']
            umin = rec.get('umin')
            umax = rec.get('umax')
            vmin = rec.get('vmin')
            vmax = rec.get('vmax')
            if umin is not None and umax is not None and vmin is not None and vmax is not None:
                agg['umin'] = min(agg['umin'], umin)
                agg['umax'] = max(agg['umax'], umax)
                agg['vmin'] = min(agg['vmin'], vmin)
                agg['vmax'] = max(agg['vmax'], vmax)

    # Build correlation entries
    results = []
    for ptr, agg in by_ptr.items():
        entry = {
            'ptr': f"0x{ptr:x}",
            'name': agg['name'] or '<unknown>',
            'count': agg['count'],
            'umin': agg['umin'], 'umax': agg['umax'],
            'vmin': agg['vmin'], 'vmax': agg['vmax'],
            'tex_w': agg['tex_w'], 'tex_h': agg['tex_h'],
            'u_px_min': None, 'u_px_max': None, 'v_px_min': None, 'v_px_max': None,
            'outline_points': None,
        }
        if agg['tex_w'] and agg['tex_h']:
            entry['u_px_min'] = agg['umin'] * agg['tex_w']
            entry['u_px_max'] = agg['umax'] * agg['tex_w']
            entry['v_px_min'] = agg['vmin'] * agg['tex_h']
            entry['v_px_max'] = agg['vmax'] * agg['tex_h']
        if ptr in outline_by_ptr:
            entry['outline_points'] = len(
                outline_by_ptr[ptr].get('outline', []))
        results.append(entry)

    return results


def main():
    ap = argparse.ArgumentParser(
        description='Correlate UV logs with ILBM OTL2 outlines for a filtered region.')
    ap.add_argument('logfile', help='Path to terrain_debug.txt')
    ap.add_argument('outlines', help='Path to terrain_outlines.json')
    ap.add_argument('--set', dest='f_set', type=int)
    ap.add_argument('--sec', dest='f_sec')
    ap.add_argument('--sub', dest='f_sub')
    ap.add_argument('--lego', dest='f_lego', type=int)
    ap.add_argument('--out', default='docs/uv/out/correlation.json')
    args = ap.parse_args()

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

    results = correlate(args.logfile, args.outlines,
                        args.f_set, f_sec, f_sub, args.f_lego)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, 'w') as f:
        json.dump({'results': results}, f, indent=2)
    print(f"Wrote correlation to {args.out} with {len(results)} textures")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def to_int(x):
    if x is None:
        return None
    # round to nearest int for pretty output
    return int(round(float(x)))


def main():
    ap = argparse.ArgumentParser(
        description='Generate a markdown report for a sector correlation JSON')
    ap.add_argument('correlation', help='Path to correlation_*.json')
    ap.add_argument('--out', default='docs/uv/out/Top-Sector.md',
                    help='Output markdown path')
    args = ap.parse_args()

    data = json.loads(Path(args.correlation).read_text())
    rows = data.get('results', [])
    rows.sort(key=lambda r: r.get('count', 0), reverse=True)

    lines = []
    lines.append('# Top-Sector Composition Report')
    lines.append('')
    lines.append(f'Source: `{args.correlation}`')
    lines.append('')
    lines.append(
        '| # | ptr | name | count | u_px_min | u_px_max | v_px_min | v_px_max | width | height |')
    lines.append(
        '|---|-----|------|-------|----------|----------|----------|----------|-------|--------|')

    for i, r in enumerate(rows, 1):
        upmin = to_int(r.get('u_px_min'))
        upmax = to_int(r.get('u_px_max'))
        vpmin = to_int(r.get('v_px_min'))
        vpmax = to_int(r.get('v_px_max'))
        w = (upmax - upmin) if (upmin is not None and upmax is not None) else ''
        h = (vpmax - vpmin) if (vpmin is not None and vpmax is not None) else ''
        lines.append('| {} | {} | {} | {} | {} | {} | {} | {} | {} | {} |'.format(
            i, r.get('ptr'), r.get('name'), r.get('count'),
            '' if upmin is None else upmin,
            '' if upmax is None else upmax,
            '' if vpmin is None else vpmin,
            '' if vpmax is None else vpmax,
            '' if w == '' else w,
            '' if h == '' else h,
        ))

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text('\n'.join(lines))
    print(f'Wrote {args.out} with {len(rows)} entries')


if __name__ == '__main__':
    main()

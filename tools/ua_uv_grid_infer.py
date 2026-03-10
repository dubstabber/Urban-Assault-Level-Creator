#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from collections import Counter

TOL = 1.5  # px tolerance for edge alignment


def choose_step(rects):
    # Candidate steps for 256 atlas
    candidates = [256//n for n in (2, 4, 8, 16)]  # [128, 64, 32, 16]
    best = None
    best_score = -1
    for step in candidates:
        score = 0
        for r in rects:
            upmin = r.get('u_px_min')
            upmax = r.get('u_px_max')
            vpmin = r.get('v_px_min')
            vpmax = r.get('v_px_max')
            if upmin is None or upmax is None or vpmin is None or vpmax is None:
                continue
            for v in (upmin, upmax, vpmin, vpmax):
                # count if close to a multiple of step or to border +/-1px
                m = round(v/step)*step
                if abs(v - m) <= TOL or abs((v-1) - round((v-1)/step)*step) <= TOL or abs((v+1) - round((v+1)/step)*step) <= TOL:
                    score += 1
        if score > best_score:
            best_score = score
            best = step
    return best or 64


def quantize(v, step):
    # Snap to nearest grid index, considering 1px border
    if v is None:
        return None
    idx = round(v/step)
    return int(idx)


def main():
    ap = argparse.ArgumentParser(
        description='Infer atlas grid cells for correlation JSON')
    ap.add_argument('correlation', help='Path to correlation_*.json')
    ap.add_argument('--out', default='docs/uv/out/Top-Sector-grid.md')
    args = ap.parse_args()

    data = json.loads(Path(args.correlation).read_text())
    rows = data.get('results', [])
    # Filter to those with px values
    rects = [r for r in rows if r.get('u_px_min') is not None]

    step = choose_step(rects)

    # Build markdown
    lines = []
    lines.append('# Inferred Atlas Grid Mapping')
    lines.append('')
    lines.append(f'Correlation: `{args.correlation}`')
    lines.append(f'Chosen grid step: {step} px (approx)')
    lines.append('')
    lines.append(
        '| # | ptr | name | count | u_px_min..max | v_px_min..max | grid u[i0..i1] | grid v[j0..j1] |')
    lines.append(
        '|---|-----|------|-------|----------------|----------------|-----------------|-----------------|')

    rows.sort(key=lambda r: r.get('count', 0), reverse=True)
    for i, r in enumerate(rows, 1):
        upmin = r.get('u_px_min')
        upmax = r.get('u_px_max')
        vpmin = r.get('v_px_min')
        vpmax = r.get('v_px_max')
        if upmin is None:
            ui0 = ui1 = ji0 = ji1 = ''
        else:
            ui0 = quantize(upmin, step)
            ui1 = quantize(upmax, step)
            ji0 = quantize(vpmin, step)
            ji1 = quantize(vpmax, step)
        lines.append('| {} | {} | {} | {} | {}..{} | {}..{} | {}..{} | {}..{} |'.format(
            i, r.get('ptr'), r.get('name'), r.get('count'),
            '' if upmin is None else int(
                round(upmin)), '' if upmax is None else int(round(upmax)),
            '' if vpmin is None else int(
                round(vpmin)), '' if vpmax is None else int(round(vpmax)),
            ui0, ui1, ji0, ji1,
        ))

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text('\n'.join(lines))
    print(f'Wrote {args.out} with {len(rows)} entries, step={step}')


if __name__ == '__main__':
    main()

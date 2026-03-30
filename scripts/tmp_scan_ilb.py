#!/usr/bin/env python3
import sys, struct
from pathlib import Path

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("resources/ua/bundled/sets/set1")
files = sorted(list(root.rglob('*.ILB'))) + sorted(list(root.rglob('*.ilb')))

def scan(path: Path):
    try:
        with open(path, 'rb') as f:
            data = f.read(65536)
    except Exception as e:
        return None
    if data[0:4] != b'FORM':
        return None
    form_type = data[8:12]
    if form_type != b'ILBM':
        return None
    off = 12
    w = h = planes = None
    while off + 8 <= len(data):
        ck = data[off:off+4]; off += 4
        sz = int.from_bytes(data[off:off+4], 'big'); off += 4
        chunk = data[off:off+sz]; off += sz + (sz & 1)
        if ck == b'BMHD' and len(chunk) >= 20:
            w = int.from_bytes(chunk[0:2], 'big')
            h = int.from_bytes(chunk[2:4], 'big')
            planes = chunk[8]
            return (w, h, planes)
    return None

for p in files:
    info = scan(p)
    print(f"{p}: {info}")


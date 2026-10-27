#!/usr/bin/env python3
"""Check the real original Andelst day-one route against the omitted-demand defect.

Consumes completed native runs; never recompiles or repeats their model period.
The wet original first day has positive soil demand and positive Boesten drying
history. This check is intentionally not an oracle for arbitrary dry/frozen cases.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import struct
import zlib

ORIGINAL_SWP = 'c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b'


def check(path):
    manifest = json.loads((path / 'manifest.json').read_text())
    assert manifest['status'] == 'COMPLETE'
    assert manifest['stop_after'] == 1
    assert manifest['preparation']['original_sources']['original_swp'] == ORIGINAL_SWP
    for name in ['input.swp', 'input.nml', 'macro.nml', 'budget.csv', 'restart.bin']:
        assert hashlib.sha256((path / name).read_bytes()).hexdigest() == manifest['files'][name]
    rows = list(csv.DictReader((path / 'budget.csv').open()))
    assert len(rows) == 1 and int(rows[0]['day']) == 1
    row = rows[0]
    assert float(row['t0']) == 0.0 and float(row['t1']) == 1.0
    assert float(row['soil_evap_cm']) > 0.0, 'original positive soil demand was omitted'
    assert abs(float(row['water_residual_cm'])) <= 1.e-10
    raw = (path / 'restart.bin').read_bytes()
    assert raw[:8] == b'S5WM0001'
    assert zlib.crc32(raw[:-4]) == struct.unpack_from('<I', raw, len(raw) - 4)[0]
    assert struct.unpack_from('<d', raw, 204)[0] == 1.0
    nodes = struct.unpack_from('<i', raw, 72)[0]
    spev, saev = struct.unpack_from('<2d', raw, 216 + 2 * nodes * 8 + 16)
    assert spev > 0.0 and saev > 0.0, 'active Boesten drying history stayed at zero'
    return raw, {'soil_evap_cm': float(row['soil_evap_cm']), 'SPEV': spev, 'SAEV': saev}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--compare', type=Path, help='independent O0/O2 original day-one run')
    args = parser.parse_args()
    raw, result = check(args.run)
    if args.compare:
        other, _ = check(args.compare)
        for name in ['state.csv', 'temperature.csv', 'budget.csv', 'progress.csv']:
            assert (args.run / name).read_bytes() == (args.compare / name).read_bytes(), name
        # The executor binding and resulting CRC intentionally identify each build.
        assert raw[:8] + raw[72:-4] == other[:8] + other[72:-4]
        result['O0_O2_physical_exact'] = True
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Validate complete accepted-column diagnostic lines from an actual SWAP5 log.
Usage: python3 validate_state_dump.py path/to/dry_diagnostic.log
This validates completeness, not physical or cross-model restart equivalence.
"""
import math
import pathlib
import sys

def check(path):
    header = None
    nodes = {}
    for line in path.read_text(errors="replace").splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "KALMTHOUT_STATE_HEADER":
            if header is not None:
                raise ValueError("multiple state headers")
            if len(parts) != 6:
                raise ValueError("malformed header")
            header = (parts[1], int(parts[2]), *map(float, parts[3:]))
        if parts[0] == "KALMTHOUT_STATE_NODE":
            if len(parts) != 7:
                raise ValueError("malformed node")
            timestamp, i = parts[1], int(parts[2])
            if i in nodes:
                raise ValueError("duplicate node")
            nodes[i] = (timestamp, *map(float, parts[3:]))
    if header is None:
        raise ValueError("missing state header (no completed diagnostic run)")
    timestamp, count, pond, groundwater, evap = header
    if count < 1 or sorted(nodes) != list(range(1, count + 1)):
        raise ValueError("incomplete or noncontiguous nodes")
    for i, (date, z, dz, h, theta) in nodes.items():
        if date != timestamp or not all(map(math.isfinite, (z, dz, h, theta))):
            raise ValueError(f"invalid node {i}")
        if dz <= 0 or not 0 <= theta <= 1:
            raise ValueError(f"invalid grid/water content {i}")
    print(f"STATE_DUMP_COMPLETE=PASS timestamp={timestamp} nodes={count} pond_cm={pond:.16g}")
    print("NOTE: complete observational fields do not imply restart equivalence")

if __name__ == "__main__":
    try:
        check(pathlib.Path(sys.argv[1]))
    except (OSError, ValueError, IndexError) as exc:
        print(f"STATE_DUMP_COMPLETE=FAIL: {exc}", file=sys.stderr)
        sys.exit(1)

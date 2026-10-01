#!/usr/bin/env python3
"""Prepare an exact B1.5p1 OxygenStress oracle tree with diagnostic trace hooks.

Research/qualification tooling only. This reuses the VQ reconstruction contract and refuses to
instrument unless the reconstructed oxygenstress bytes match the pinned B1.5p1 target identity.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from b1_reconstruct import reconstruct

B1_OXYGEN_SHA256 = "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()

    result = reconstruct(args.archive, args.output_dir)
    oxygen = args.output_dir / "oxygenstress.f90"
    observed = sha256(oxygen)
    if observed != B1_OXYGEN_SHA256:
        raise SystemExit(f"refuse instrumentation: oxygenstress identity {observed}")

    # Do not silently edit physics here. C3Q instrumentation is applied by a separately reviewed
    # byte transformation once the exact insertion point and route-tag fields are pinned.
    print(f"C3Q_B1_RECONSTRUCTION=PASS")
    print(f"C3Q_OXYGEN_SHA256={observed}")
    print(f"C3Q_SOURCE_MANIFEST_SHA256={result['source_tree']['manifest_sha256']}")
    print(f"C3Q_INSTRUMENTATION=NOT_YET_APPLIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

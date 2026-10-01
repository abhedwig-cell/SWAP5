#!/usr/bin/env python3
"""Prepare exact current B1.11 OxygenStress oracle source for C3Q."""
from __future__ import annotations
import argparse, hashlib
from pathlib import Path
from b1_11_reconstruct import reconstruct

B1_11_MANIFEST_SHA256 = "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
# OxygenStress is unchanged after admitted SWAP-007; later B1 patches target other files.
B1_11_OXYGEN_SHA256 = "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--archive",required=True,type=Path)
    ap.add_argument("--output-dir",required=True,type=Path)
    a=ap.parse_args()
    result=reconstruct(a.archive,a.output_dir)
    if result["source_tree"]["manifest_sha256"] != B1_11_MANIFEST_SHA256:
        raise SystemExit("C3Q_B1_11_MANIFEST=FAIL")
    observed=sha256(a.output_dir/"oxygenstress.f90")
    if observed != B1_11_OXYGEN_SHA256:
        raise SystemExit(f"C3Q_B1_11_OXYGEN=FAIL:{observed}")
    print("C3Q_B1_11_RECONSTRUCTION=PASS")
    print(f"C3Q_OXYGEN_SHA256={observed}")
    print(f"C3Q_SOURCE_MANIFEST_SHA256={result['source_tree']['manifest_sha256']}")
    return 0
if __name__=="__main__":
    raise SystemExit(main())

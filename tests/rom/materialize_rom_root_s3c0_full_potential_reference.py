#!/usr/bin/env python3
"""Materialize ROM-ROOT Stage 3 C0 full-potential Reference control.

Input is an already materialized RA02R stress-panel Reference harness. The
normal Feddes process is still evaluated to construct the exact potential
fine-node root distribution. For this diagnostic control only, the resulting
root sink is then replaced by diagnostics%potential_root_sink, i.e. alpha=1.
No production source is changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

MARKER = "ROM_ROOT_S3C0_FULL_POTENTIAL_REFERENCE"

def one(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {n}")
    return text.replace(old, new, 1)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--manifest", type=Path)
    args = ap.parse_args()

    before = args.input.read_text()
    if MARKER in before:
        raise SystemExit("S3-C0 full-potential control already materialized")

    anchor = """    call evaluate_macro_feddes_drought_uptake(parameters,view,request,fluxes,diagnostics)
    call require(diagnostics%status==ROOT_UPTAKE_OK.and.diagnostics%evaluated,'LAREDYN0R C6R root process evaluated')
"""
    replacement = """    call evaluate_macro_feddes_drought_uptake(parameters,view,request,fluxes,diagnostics)
    call require(diagnostics%status==ROOT_UPTAKE_OK.and.diagnostics%evaluated,'LAREDYN0R C6R root process evaluated')
    ! ROM_ROOT_S3C0_FULL_POTENTIAL_REFERENCE:
    ! Diagnostic no-drought-reduction control. Retain the exact potential
    ! fine-node root distribution but set alpha=1 after process evaluation.
    fluxes%root_extraction_sink=diagnostics%potential_root_sink
    fluxes%actual_uptake_total=diagnostics%potential_uptake_total
"""
    text = one(before, anchor, replacement, "full-potential root control")

    base = "  write(*,'(A)') 'ROM_ROOT_RA02R_P2E20_REPRESENTATION_FLOOR=TRUE'\n"
    seg = base
    if base not in text:
        raise SystemExit("RA02R policy marker not found")
    text = one(
        text,
        base,
        base + "  write(*,'(A)') 'ROM_ROOT_S3C0_FULL_POTENTIAL_REFERENCE=TRUE'\n",
        "S3-C0 completion marker",
    )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text)
    manifest = {
        "schema": "swap5.rom_root.s3c0.materialization.v1",
        "state": "MATERIALIZED_FULL_POTENTIAL_REFERENCE_CONTROL",
        "root_distribution": "unchanged fine-node RA02R distribution",
        "potential_transpiration": "unchanged RA02R schedule",
        "drought_reduction_factor": 1.0,
        "feddes_parameters_changed": False,
        "hydraulic_solver_changed": False,
        "numerical_policy_changed": False,
        "initial_state_changed": False,
        "forcing_changed": False,
        "production_source_changed": False,
        "response_based": False,
        "input_sha256": hashlib.sha256(before.encode()).hexdigest(),
        "output_sha256": hashlib.sha256(text.encode()).hexdigest(),
    }
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps(manifest, sort_keys=True))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

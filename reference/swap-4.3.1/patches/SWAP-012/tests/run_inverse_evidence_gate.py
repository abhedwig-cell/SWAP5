#!/usr/bin/env python3
"""Fail-closed provenance/evidence gate for the isolated SWAP-012 inverse fix.

The 600-point actual-source Fortran test was executed during qualification.
This CI gate binds that result to the exact stored patch, exact B0 preimage and
exact corrected target; it does not relabel an unexecuted synthetic test as a
fresh production run.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
PATCH = ROOT / "reference/swap-4.3.1/patches/SWAP-012/fix.patch"
HELPER = ROOT / "reference/swap-4.3.1/patches/SWAP-012/apply_and_verify.py"
EVIDENCE = Path(__file__).with_name("actual_source_roundtrip_evidence.json")

PATCH_SHA = "263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131"
B0_SHA = "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"
CORRECTED_SHA = "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"

REQUIRED_PATCH_TOKENS = (
    "use WC_K_models_04_11, only: functionvalue_04_11",
    "else if (imod == 3 .OR. imod >= 5) then",
    "do iter = 1, 100",
    "wcmid = functionvalue_04_11(1,node,iHWCKmodel,cofgen_in,hmid)",
    "wcmid = dble(WCRIA(hmid*1.0_dp))",
    "else  ! use analytical default MvG inverse (models 1 and 4)",
)
FORBIDDEN_TOKENS = (
    "dhconduc",
    "hconduc_dh",
    "RIAKDerivativeAnalytic",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if sha(PATCH) != PATCH_SHA:
        raise SystemExit("SWAP-012 gate: stored patch SHA mismatch")
    patch_text = PATCH.read_text(encoding="utf-8")
    if any(token not in patch_text for token in REQUIRED_PATCH_TOKENS):
        raise SystemExit("SWAP-012 gate: required prhead patch token missing")
    if any(token in patch_text for token in FORBIDDEN_TOKENS):
        raise SystemExit("SWAP-012 gate: SWAP-011 content leaked into isolated patch")

    helper = HELPER.read_text(encoding="utf-8")
    for token in (PATCH_SHA, B0_SHA, CORRECTED_SHA):
        if token not in helper:
            raise SystemExit("SWAP-012 gate: applicator identity pin missing")

    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence.get("canonical_b0_target_sha256") != B0_SHA:
        raise SystemExit("SWAP-012 gate: evidence B0 target mismatch")
    if evidence.get("candidate_target_sha256") != CORRECTED_SHA:
        raise SystemExit("SWAP-012 gate: evidence candidate target mismatch")
    if evidence.get("stored_patch_sha256") != PATCH_SHA:
        raise SystemExit("SWAP-012 gate: evidence patch mismatch")
    if evidence.get("b0", {}).get("total_points") != 600:
        raise SystemExit("SWAP-012 gate: unexpected B0 test point count")
    if evidence.get("b0", {}).get("failures") != 513:
        raise SystemExit("SWAP-012 gate: unexpected B0 failure count")
    if evidence.get("candidate", {}).get("total_points") != 600:
        raise SystemExit("SWAP-012 gate: unexpected candidate point count")
    if evidence.get("candidate", {}).get("failures") != 0:
        raise SystemExit("SWAP-012 gate: corrected inverse did not qualify")
    if float(evidence.get("candidate", {}).get("max_abs_log10_head_error_decade", 1.0)) >= 1e-6:
        raise SystemExit("SWAP-012 gate: corrected inverse exceeds tolerance")

    print("SWAP-012_INVERSE_EVIDENCE_GATE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

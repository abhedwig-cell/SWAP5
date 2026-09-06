#!/usr/bin/env python3
"""Fail-closed static admission gate for the current B1.7 corrected reference.

This gate verifies repository identity/provenance, ordered-preimage bookkeeping
for the shared SWAP-009/SWAP-010 target, and admission records. It does not
compile Fortran or replace the recorded SWAP-010 execution/mass gates.
"""
from __future__ import annotations

import json
from pathlib import Path

import yaml

try:
    from .b1_snapshot_identity import verify_snapshot
except ImportError:
    from b1_snapshot_identity import verify_snapshot

REPO_ROOT = Path(__file__).resolve().parents[2]
PIN = REPO_ROOT / "tools" / "vq" / "cases" / "b1-7-reference-pin.json"
MANIFEST = REPO_ROOT / "reference" / "swap-4.3.1" / "b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference" / "swap-4.3.1" / "snapshots" / "B1.7.yml"
QUALIFICATION = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-010" / "qualification.md"
CHECKLIST = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-010" / "ADMISSION_CHECKLIST.md"
HELPER = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-010" / "apply_and_verify.py"
EXPECTED_PATCH_ORDER = ["SWAP-001", "SWAP-005", "SWAP-006", "SWAP-007", "SWAP-008", "SWAP-009", "SWAP-010"]
EXPECTED_SOURCE_MANIFEST = "62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba"
EXPECTED_ORDERED_PREIMAGE = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
EXPECTED_CORRECTED_TARGET = "7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e"


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid YAML mapping: {path}")
    return data


def patch_by_id(items: list[dict], patch_id: str) -> dict:
    matches = [item for item in items if item.get("id") == patch_id]
    if len(matches) != 1:
        return {}
    return matches[0]


def assess() -> dict:
    identity = verify_snapshot(REPO_ROOT, PIN)
    manifest = load_yaml(MANIFEST)
    snapshot = load_yaml(SNAPSHOT)
    b1 = manifest.get("b1", {})

    manifest_patches = b1.get("patches", [])
    snapshot_patches = snapshot.get("patches", [])
    manifest_ids = [p.get("id") for p in manifest_patches]
    snapshot_ids = [p.get("id") for p in snapshot_patches]
    m010 = patch_by_id(manifest_patches, "SWAP-010")
    s010 = patch_by_id(snapshot_patches, "SWAP-010")
    helper_text = HELPER.read_text(encoding="utf-8")

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.7",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.7.yml",
        "patch_order_manifest": manifest_ids == EXPECTED_PATCH_ORDER,
        "patch_order_snapshot": snapshot_ids == EXPECTED_PATCH_ORDER,
        "patch_identity_manifest_snapshot": all(
            m.get("id") == s.get("id")
            and m.get("patch_path") == s.get("patch_path")
            and m.get("patch_sha256") == s.get("patch_sha256")
            for m, s in zip(manifest_patches, snapshot_patches)
        ) and len(manifest_patches) == len(snapshot_patches),
        "source_manifest_manifest": b1.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_SOURCE_MANIFEST,
        "source_manifest_snapshot": snapshot.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_SOURCE_MANIFEST,
        "swap010_manifest_ordered_preimage": (
            m010.get("ordered_preimage_snapshot") == "B1.6"
            and m010.get("ordered_preimage_sha256") == EXPECTED_ORDERED_PREIMAGE
            and m010.get("corrected_target_sha256") == EXPECTED_CORRECTED_TARGET
        ),
        "swap010_snapshot_ordered_preimage": (
            s010.get("ordered_preimage_snapshot") == "B1.6"
            and s010.get("ordered_preimage_sha256") == EXPECTED_ORDERED_PREIMAGE
            and s010.get("corrected_target_sha256") == EXPECTED_CORRECTED_TARGET
        ),
        "swap010_helper_pins_ordered_preimage": EXPECTED_ORDERED_PREIMAGE in helper_text,
        "swap010_helper_pins_corrected_target": EXPECTED_CORRECTED_TARGET in helper_text,
        "swap010_qualification_admitted": "Current B1 admission status: **ADMITTED IN B1.7**" in QUALIFICATION.read_text(encoding="utf-8"),
        "swap010_checklist_complete": "Current conclusion: **SWAP-010 is admitted as the seventh corrected-reference patch in immutable snapshot B1.7.**" in CHECKLIST.read_text(encoding="utf-8"),
    }

    passed = all(checks.values())
    return {
        "snapshot": "B1.7",
        "status": "PASS" if passed else "FAIL",
        "checks": checks,
        "snapshot_identity": identity,
    }


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

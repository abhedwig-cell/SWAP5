#!/usr/bin/env python3
"""Fail-closed static admission gate for the current B1.6 corrected reference.

This gate verifies repository identity/provenance and bookkeeping. It does not
compile Fortran or replace the already-recorded SWAP-009 execution/mass gates.
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
PIN = REPO_ROOT / "tools" / "vq" / "cases" / "b1-6-reference-pin.json"
MANIFEST = REPO_ROOT / "reference" / "swap-4.3.1" / "b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference" / "swap-4.3.1" / "snapshots" / "B1.6.yml"
QUALIFICATION = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-009" / "qualification.md"
CHECKLIST = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-009" / "ADMISSION_CHECKLIST.md"
EXPECTED_PATCH_ORDER = ["SWAP-001", "SWAP-005", "SWAP-006", "SWAP-007", "SWAP-008", "SWAP-009"]
EXPECTED_SOURCE_MANIFEST = "aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0"


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid YAML mapping: {path}")
    return data


def assess() -> dict:
    identity = verify_snapshot(REPO_ROOT, PIN)
    manifest = load_yaml(MANIFEST)
    snapshot = load_yaml(SNAPSHOT)
    b1 = manifest.get("b1", {})

    manifest_patches = b1.get("patches", [])
    snapshot_patches = snapshot.get("patches", [])
    manifest_ids = [p.get("id") for p in manifest_patches]
    snapshot_ids = [p.get("id") for p in snapshot_patches]

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.6",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.6.yml",
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
        "swap009_qualification_admitted": "Current B1 admission status: **ADMITTED IN B1.6**" in QUALIFICATION.read_text(encoding="utf-8"),
        "swap009_checklist_complete": "Current conclusion: **SWAP-009 is admitted as the sixth corrected-reference patch in immutable snapshot B1.6.**" in CHECKLIST.read_text(encoding="utf-8"),
    }

    passed = all(checks.values())
    return {
        "snapshot": "B1.6",
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

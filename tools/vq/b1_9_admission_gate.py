#!/usr/bin/env python3
"""Fail-closed static admission gate for B1.9 / SWAP-012."""
from __future__ import annotations

import json
from pathlib import Path
import yaml

try:
    from .b1_snapshot_identity import verify_snapshot
except ImportError:
    from b1_snapshot_identity import verify_snapshot

REPO_ROOT = Path(__file__).resolve().parents[2]
PIN = REPO_ROOT / "tools/vq/cases/b1-9-reference-pin.json"
MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference/swap-4.3.1/snapshots/B1.9.yml"
QUALIFICATION = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-012/qualification.md"
CHECKLIST = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-012/ADMISSION_CHECKLIST.md"
HELPER = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-012/apply_and_verify.py"
EVIDENCE = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-012/tests/actual_source_roundtrip_evidence.json"
EXPECTED_PATCH_ORDER = ["SWAP-001","SWAP-005","SWAP-006","SWAP-007","SWAP-008","SWAP-009","SWAP-010","SWAP-013","SWAP-012"]
EXPECTED_SOURCE_MANIFEST = "5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657"
EXPECTED_PREIMAGE = "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"
EXPECTED_CORRECTED = "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
EXPECTED_PATCH_SHA = "263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131"


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid YAML mapping: {path}")
    return data


def one(items: list[dict], patch_id: str) -> dict:
    matches = [item for item in items if item.get("id") == patch_id]
    return matches[0] if len(matches) == 1 else {}


def assess() -> dict:
    identity = verify_snapshot(REPO_ROOT, PIN)
    manifest = load_yaml(MANIFEST)
    snapshot = load_yaml(SNAPSHOT)
    b1 = manifest.get("b1", {})
    mp = b1.get("patches", [])
    sp = snapshot.get("patches", [])
    m012 = one(mp, "SWAP-012")
    s012 = one(sp, "SWAP-012")
    helper = HELPER.read_text(encoding="utf-8")
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.9",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.9.yml",
        "patch_order_manifest": [p.get("id") for p in mp] == EXPECTED_PATCH_ORDER,
        "patch_order_snapshot": [p.get("id") for p in sp] == EXPECTED_PATCH_ORDER,
        "patch_identity_manifest_snapshot": all(
            m.get("id") == s.get("id")
            and m.get("patch_path") == s.get("patch_path")
            and m.get("patch_sha256") == s.get("patch_sha256")
            for m, s in zip(mp, sp)
        ) and len(mp) == len(sp),
        "source_manifest_manifest": b1.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_SOURCE_MANIFEST,
        "source_manifest_snapshot": snapshot.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_SOURCE_MANIFEST,
        "swap012_manifest_preimage": (
            m012.get("ordered_preimage_snapshot") == "B1.8"
            and m012.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and m012.get("canonical_b0_target_sha256") == EXPECTED_PREIMAGE
            and m012.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and m012.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "swap012_snapshot_preimage": (
            s012.get("ordered_preimage_snapshot") == "B1.8"
            and s012.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and s012.get("b0_target_sha256") == EXPECTED_PREIMAGE
            and s012.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and s012.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "helper_pins_preimage": EXPECTED_PREIMAGE in helper,
        "helper_pins_corrected": EXPECTED_CORRECTED in helper,
        "helper_pins_patch": EXPECTED_PATCH_SHA in helper,
        "evidence_b0_failures": evidence.get("b0", {}).get("failures") == 513,
        "evidence_candidate_failures": evidence.get("candidate", {}).get("failures") == 0,
        "evidence_candidate_within_tolerance": float(evidence.get("candidate", {}).get("max_abs_log10_head_error_decade", 1.0)) < 1e-6,
        "qualification_prepared": "Current B1 admission status: **PREPARED FOR B1.9 ADMISSION**" in QUALIFICATION.read_text(encoding="utf-8"),
        "checklist_prepared": "Current conclusion: **SWAP-012 is prepared for admission as the ninth corrected-reference patch in immutable snapshot B1.9.**" in CHECKLIST.read_text(encoding="utf-8"),
    }
    passed = all(checks.values())
    return {"snapshot":"B1.9","status":"PASS" if passed else "FAIL","checks":checks,"snapshot_identity":identity}


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

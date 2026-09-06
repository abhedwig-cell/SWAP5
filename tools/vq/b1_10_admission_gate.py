#!/usr/bin/env python3
"""Fail-closed static admission gate for B1.10 / SWAP-002."""
from __future__ import annotations

import json
from pathlib import Path
import yaml

try:
    from .b1_snapshot_identity import verify_snapshot
except ImportError:
    from b1_snapshot_identity import verify_snapshot

REPO_ROOT = Path(__file__).resolve().parents[2]
PIN = REPO_ROOT / "tools/vq/cases/b1-10-reference-pin.json"
MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml"
QUALIFICATION = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/qualification.md"
CHECKLIST = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/ADMISSION_CHECKLIST.md"
HELPER = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/apply_and_verify.py"
PATCH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/fix.patch"
EVIDENCE = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-002/tests/actual_source_start_evidence.json"
EXPECTED_PATCH_ORDER = ["SWAP-001","SWAP-005","SWAP-006","SWAP-007","SWAP-008","SWAP-009","SWAP-010","SWAP-013","SWAP-012","SWAP-002"]
EXPECTED_SOURCE_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
EXPECTED_PREIMAGE = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
EXPECTED_CORRECTED = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
EXPECTED_PATCH_SHA = "80e12cd4e9f47c192bd6c7d5ee7d460c473b3a2b29a5a553e8c35cf0b90b5c13"
FORBIDDEN = (
    "i_n_model=2 requires PCLAY > 0",
    "allocate(iTT1(tmax))",
    "TYPE_TILLAGE is outside the range defined by ITYPE_TILLAGE",
)


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
    m002 = one(mp, "SWAP-002")
    s002 = one(sp, "SWAP-002")
    helper = HELPER.read_text(encoding="utf-8")
    patch_text = PATCH.read_text(encoding="utf-8")
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.10",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.10.yml",
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
        "swap002_manifest_preimage": (
            m002.get("ordered_preimage_snapshot") == "B1.9"
            and m002.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and m002.get("canonical_b0_target_sha256") == EXPECTED_PREIMAGE
            and m002.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and m002.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "swap002_snapshot_preimage": (
            s002.get("ordered_preimage_snapshot") == "B1.9"
            and s002.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and s002.get("b0_target_sha256") == EXPECTED_PREIMAGE
            and s002.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and s002.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "helper_pins_preimage": EXPECTED_PREIMAGE in helper,
        "helper_pins_corrected": EXPECTED_CORRECTED in helper,
        "helper_pins_patch": EXPECTED_PATCH_SHA in helper,
        "evidence_b0_reproduces_defect": evidence.get("b0", {}).get("passed") == 3 and evidence.get("b0", {}).get("total") == 6,
        "evidence_candidate_passes": evidence.get("candidate", {}).get("passed") == 6 and evidence.get("candidate", {}).get("total") == 6,
        "unrelated_tillage_fixes_absent": all(token not in patch_text for token in FORBIDDEN),
        "qualification_candidate": "QUALIFIED CANDIDATE FOR B1.10" in QUALIFICATION.read_text(encoding="utf-8"),
        "checklist_present": "SWAP-002 B1.10 admission checklist" in CHECKLIST.read_text(encoding="utf-8"),
    }
    passed = all(checks.values())
    return {"snapshot":"B1.10","status":"PASS" if passed else "FAIL","checks":checks,"snapshot_identity":identity}


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

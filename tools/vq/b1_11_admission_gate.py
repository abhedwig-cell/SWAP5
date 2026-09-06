#!/usr/bin/env python3
"""Fail-closed static admission gate for B1.11 / SWAP-004."""
from __future__ import annotations

import json
from pathlib import Path
import yaml

try:
    from .b1_snapshot_identity import verify_snapshot
except ImportError:
    from b1_snapshot_identity import verify_snapshot

REPO_ROOT = Path(__file__).resolve().parents[2]
PIN = REPO_ROOT / "tools/vq/cases/b1-11-reference-pin.json"
MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference/swap-4.3.1/snapshots/B1.11.yml"
QUALIFICATION = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/qualification.md"
CHECKLIST = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/ADMISSION_CHECKLIST.md"
HELPER = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/apply_and_verify.py"
PATCH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/fix.patch"
EVIDENCE = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-004/tests/evidence.json"
EXPECTED_PATCH_ORDER = ["SWAP-001","SWAP-005","SWAP-006","SWAP-007","SWAP-008","SWAP-009","SWAP-010","SWAP-013","SWAP-012","SWAP-002","SWAP-004"]
EXPECTED_SOURCE_MANIFEST = "a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6"
EXPECTED_B0 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
EXPECTED_PREIMAGE = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
EXPECTED_CORRECTED = "41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede"
EXPECTED_PATCH_SHA = "0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818"
FORBIDDEN = (
    "i_n_model=2 requires PCLAY > 0",
    "PCLAY should be larger than zero",
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
    m004 = one(mp, "SWAP-004")
    s004 = one(sp, "SWAP-004")
    helper = HELPER.read_text(encoding="utf-8")
    patch_text = PATCH.read_text(encoding="utf-8")
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    binding = evidence.get("source_binding", {})
    cases = evidence.get("candidate_cases", {})

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.11",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.11.yml",
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
        "swap004_manifest_preimage": (
            m004.get("ordered_preimage_snapshot") == "B1.10"
            and m004.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and m004.get("canonical_b0_target_sha256") == EXPECTED_B0
            and m004.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and m004.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "swap004_snapshot_preimage": (
            s004.get("ordered_preimage_snapshot") == "B1.10"
            and s004.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and s004.get("b0_target_sha256") == EXPECTED_B0
            and s004.get("corrected_target_sha256") == EXPECTED_CORRECTED
            and s004.get("patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "helper_pins_b0": EXPECTED_B0 in helper,
        "helper_pins_preimage": EXPECTED_PREIMAGE in helper,
        "helper_pins_corrected": EXPECTED_CORRECTED in helper,
        "helper_pins_patch": EXPECTED_PATCH_SHA in helper,
        "evidence_binding": (
            binding.get("canonical_b0_tillage_sha256") == EXPECTED_B0
            and binding.get("ordered_b1_10_tillage_sha256") == EXPECTED_PREIMAGE
            and binding.get("stored_patch_sha256") == EXPECTED_PATCH_SHA
            and binding.get("candidate_tillage_sha256") == EXPECTED_CORRECTED
        ),
        "evidence_candidate_passes": cases.get("total") == "4/4 PASS",
        "dense_valid_mapping_unchanged": cases.get("dense_legacy_mapping_unchanged") == "PASS",
        "missing_mapping_rejected": cases.get("missing_type_record_rejected") == "PASS",
        "swap003_absent": all(token not in patch_text for token in FORBIDDEN),
        "qualification_candidate": "QUALIFIED CANDIDATE" in QUALIFICATION.read_text(encoding="utf-8"),
        "checklist_present": "SWAP-004 B1 admission checklist" in CHECKLIST.read_text(encoding="utf-8"),
    }
    passed = all(checks.values())
    return {"snapshot":"B1.11","status":"PASS" if passed else "FAIL","checks":checks,"snapshot_identity":identity}


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

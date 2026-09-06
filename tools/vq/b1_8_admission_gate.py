#!/usr/bin/env python3
"""Fail-closed static admission gate for B1.8 / SWAP-013."""
from __future__ import annotations

import json
from pathlib import Path
import yaml

try:
    from .b1_snapshot_identity import verify_snapshot
except ImportError:
    from b1_snapshot_identity import verify_snapshot

REPO_ROOT = Path(__file__).resolve().parents[2]
PIN = REPO_ROOT / "tools/vq/cases/b1-8-reference-pin.json"
MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference/swap-4.3.1/snapshots/B1.8.yml"
QUALIFICATION = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-013/qualification.md"
CHECKLIST = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-013/ADMISSION_CHECKLIST.md"
HELPER = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-013/apply_and_verify.py"
EXPECTED_PATCH_ORDER = ["SWAP-001","SWAP-005","SWAP-006","SWAP-007","SWAP-008","SWAP-009","SWAP-010","SWAP-013"]
EXPECTED_SOURCE_MANIFEST = "e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae"
EXPECTED_PREIMAGE = "3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2"
EXPECTED_CORRECTED = "e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c"


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
    m013 = one(mp, "SWAP-013")
    s013 = one(sp, "SWAP-013")
    helper = HELPER.read_text(encoding="utf-8")

    checks = {
        "snapshot_identity": bool(identity.get("qualified_identity")),
        "current_manifest_snapshot": b1.get("snapshot") == "B1.8",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.8.yml",
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
        "swap013_manifest_preimage": (
            m013.get("ordered_preimage_snapshot") == "B1.7"
            and m013.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and m013.get("canonical_b0_target_sha256") == EXPECTED_PREIMAGE
            and m013.get("corrected_target_sha256") == EXPECTED_CORRECTED
        ),
        "swap013_snapshot_preimage": (
            s013.get("ordered_preimage_snapshot") == "B1.7"
            and s013.get("ordered_preimage_sha256") == EXPECTED_PREIMAGE
            and s013.get("b0_target_sha256") == EXPECTED_PREIMAGE
            and s013.get("corrected_target_sha256") == EXPECTED_CORRECTED
        ),
        "helper_pins_preimage": EXPECTED_PREIMAGE in helper,
        "helper_pins_corrected": EXPECTED_CORRECTED in helper,
        "qualification_admitted": "Current B1 admission status: **ADMITTED IN B1.8**" in QUALIFICATION.read_text(encoding="utf-8"),
        "checklist_complete": "Current conclusion: **SWAP-013 is admitted as the eighth corrected-reference patch in immutable snapshot B1.8.**" in CHECKLIST.read_text(encoding="utf-8"),
    }
    passed = all(checks.values())
    return {"snapshot":"B1.8","status":"PASS" if passed else "FAIL","checks":checks,"snapshot_identity":identity}


def main() -> int:
    result = assess()
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

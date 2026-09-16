#!/usr/bin/env python3
"""Fail-closed static admission gate for current corrected reference B1.11 / SWAP-011.

This gate does not rerun the external full-B0 replay. It verifies that the
repository's current B1.11 admission metadata, exact stored ordered patch,
full-replay evidence, frozen source manifest, expected-difference ledger and
reconstruction/applicator pins are mutually consistent with the qualified
F-PE19 authorities.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b1-manifest.yml"
SNAPSHOT = REPO_ROOT / "reference/swap-4.3.1/snapshots/B1.11.yml"
B0_MANIFEST = REPO_ROOT / "reference/swap-4.3.1/b0/file-manifest.sha256"
PATCH_DIR = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-011"
PATCH = PATCH_DIR / "fix.patch"
HELPER = PATCH_DIR / "apply_and_verify.py"
QUALIFICATION = PATCH_DIR / "qualification.md"
PROVENANCE = PATCH_DIR / "PATCH_PROVENANCE.md"
CHECKLIST = PATCH_DIR / "ADMISSION_CHECKLIST.md"
RECONSTRUCTOR = REPO_ROOT / "tools/vq/b1_11_reconstruct.py"
REPLAY = REPO_ROOT / "docs/performance/evidence/F-PE19_B1_11_FULL_REPLAY.json"
SOURCE_MANIFEST = REPO_ROOT / "docs/performance/evidence/F-PE19_B1_11_source_manifest.sha256"
EXPECTED_DIFFERENCES = REPO_ROOT / "docs/verification/expected-differences.json"
LEDGER = REPO_ROOT / "docs/verification/legacy-differences.md"

EXPECTED_ORDER = [
    "SWAP-001", "SWAP-005", "SWAP-006", "SWAP-007", "SWAP-008",
    "SWAP-009", "SWAP-010", "SWAP-013", "SWAP-012", "SWAP-002",
    "SWAP-011",
]
EXPECTED_PATCH_SHA = "1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238"
EXPECTED_HISTORICAL_E7_SHA = "9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110"
EXPECTED_E7_PACKAGE_SHA = "97e31ea1216e4796ab3df5cb062f1d46c2c396f5dcbe90b4f783144b8a9162ac"
EXPECTED_B0_DISTRIBUTION = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"
EXPECTED_B0_SOURCE_ARCHIVE = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
EXPECTED_B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
EXPECTED_B1_11_MANIFEST = "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"
EXPECTED_MEMBER_COUNT = 63
EXPECTED_SOURCE_BYTES = 1_886_519
EXPECTED_HEADCALC = "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5"
TARGETS = {
    "SWAP/MOD_MvG_functions.f90": {
        "b0": "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390",
        "pre": "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1",
        "post": "6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104",
    },
    "SWAP/WC_K_models_04_11.f90": {
        "b0": "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd",
        "pre": "7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e",
        "post": "d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126",
    },
    "SWAP/MOD_RIA.f90": {
        "b0": "a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3",
        "pre": "a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3",
        "post": "673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a",
    },
}


def sha256_file(path: Path) -> str | None:
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid YAML mapping: {path}")
    return data


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"invalid JSON mapping: {path}")
    return data


def one(items: list[dict], item_id: str) -> dict:
    matches = [item for item in items if item.get("id") == item_id]
    return matches[0] if len(matches) == 1 else {}


def load_member_manifest(path: Path) -> dict[str, tuple[str, int]]:
    result: dict[str, tuple[str, int]] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        digest, size, member = line.split(maxsplit=2)
        result[member] = (digest.lower(), int(size))
    return result


def patch_targets(path: Path) -> list[str]:
    targets: list[str] = []
    for line in path.read_bytes().splitlines():
        if line.startswith(b"diff --git a/"):
            match = re.match(br"diff --git a/(.+) b/(.+)$", line)
            if not match or match.group(1) != match.group(2):
                return []
            targets.append(match.group(1).decode("ascii"))
    return targets


def snapshot_target_map(entry: dict) -> dict[str, dict]:
    result: dict[str, dict] = {}
    for item in entry.get("targets", []):
        target = item.get("target")
        if isinstance(target, str):
            result[target] = item
    return result


def assess() -> dict:
    manifest = load_yaml(MANIFEST)
    snapshot = load_yaml(SNAPSHOT)
    replay = load_json(REPLAY)
    expected = load_json(EXPECTED_DIFFERENCES)
    b0 = load_member_manifest(B0_MANIFEST)
    frozen = load_member_manifest(SOURCE_MANIFEST)

    b1 = manifest.get("b1", {})
    mp = b1.get("patches", [])
    sp = snapshot.get("patches", [])
    m011 = one(mp, "SWAP-011")
    s011 = one(sp, "SWAP-011")
    s_targets = snapshot_target_map(s011)
    helper = HELPER.read_text(encoding="utf-8")
    reconstructor = RECONSTRUCTOR.read_text(encoding="utf-8")
    qualification = QUALIFICATION.read_text(encoding="utf-8")
    provenance = PROVENANCE.read_text(encoding="utf-8")
    checklist = CHECKLIST.read_text(encoding="utf-8")
    ledger = LEDGER.read_text(encoding="utf-8")
    edge = expected.get("comparison_edges", {}).get("B0_to_B1", {})
    diff011 = [x for x in edge.get("entries", []) if x.get("difference_id") == "SWAP-011"]
    replay_b111 = replay.get("reconstructed_snapshots", {}).get("B1.11", {})
    replay_targets = replay.get("swap011_targets", {})

    patch_ids_manifest = [p.get("id") for p in mp]
    patch_ids_snapshot = [p.get("id") for p in sp]
    target_set = set(TARGETS)
    observed_patch_targets = patch_targets(PATCH)

    checks = {
        "current_manifest_snapshot": b1.get("snapshot") == "B1.11",
        "current_oracle_status": b1.get("oracle_status") == "QUALIFIED_NUMERICAL_BEHAVIOURAL",
        "snapshot_definition": b1.get("snapshot_definition") == "reference/swap-4.3.1/snapshots/B1.11.yml",
        "snapshot_declares_predecessor": snapshot.get("supersedes") == "B1.10",
        "patch_order_manifest": patch_ids_manifest == EXPECTED_ORDER,
        "patch_order_snapshot": patch_ids_snapshot == EXPECTED_ORDER,
        "patch_identity_manifest_snapshot": (
            len(mp) == len(sp)
            and all(
                m.get("id") == s.get("id")
                and m.get("patch_path") == s.get("patch_path")
                and m.get("patch_sha256") == s.get("patch_sha256")
                for m, s in zip(mp, sp)
            )
        ),
        "ordered_patch_sha256": sha256_file(PATCH) == EXPECTED_PATCH_SHA,
        "ordered_patch_target_set": set(observed_patch_targets) == target_set and len(observed_patch_targets) == len(target_set),
        "manifest_swap011_identity": (
            m011.get("patch_sha256") == EXPECTED_PATCH_SHA
            and m011.get("ordered_preimage_snapshot") == "B1.10"
            and m011.get("historical_e7_patch_sha256") == EXPECTED_HISTORICAL_E7_SHA
        ),
        "snapshot_swap011_identity": (
            s011.get("patch_sha256") == EXPECTED_PATCH_SHA
            and s011.get("ordered_preimage_snapshot") == "B1.10"
            and s011.get("historical_e7_patch_sha256") == EXPECTED_HISTORICAL_E7_SHA
        ),
        "canonical_b0_target_preimages": all(b0.get(path, (None, 0))[0] == pins["b0"] for path, pins in TARGETS.items()),
        "snapshot_ordered_target_identities": (
            set(s_targets) == target_set
            and all(
                s_targets[path].get("ordered_preimage_sha256") == pins["pre"]
                and s_targets[path].get("corrected_target_sha256") == pins["post"]
                for path, pins in TARGETS.items()
            )
        ),
        "source_tree_manifest_manifest": b1.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_B1_11_MANIFEST,
        "source_tree_manifest_snapshot": snapshot.get("source_tree", {}).get("member_manifest_sha256") == EXPECTED_B1_11_MANIFEST,
        "source_tree_shape_manifest": (
            b1.get("source_tree", {}).get("member_count") == EXPECTED_MEMBER_COUNT
            and b1.get("source_tree", {}).get("source_bytes") == EXPECTED_SOURCE_BYTES
        ),
        "source_tree_shape_snapshot": (
            snapshot.get("source_tree", {}).get("member_count") == EXPECTED_MEMBER_COUNT
            and snapshot.get("source_tree", {}).get("source_bytes") == EXPECTED_SOURCE_BYTES
        ),
        "frozen_source_manifest_file_sha256": sha256_file(SOURCE_MANIFEST) == EXPECTED_B1_11_MANIFEST,
        "frozen_source_manifest_member_count": len(frozen) == EXPECTED_MEMBER_COUNT,
        "frozen_source_manifest_targets": all(frozen.get(path, (None, 0))[0] == pins["post"] for path, pins in TARGETS.items()),
        "headcalc_unchanged": frozen.get("SWAP/headcalc.f90", (None, 0))[0] == EXPECTED_HEADCALC,
        "helper_pins_exact_authorities": (
            EXPECTED_PATCH_SHA in helper
            and all(pins["pre"] in helper and pins["post"] in helper for pins in TARGETS.values())
        ),
        "reconstructor_pins_exact_authorities": (
            EXPECTED_PATCH_SHA in reconstructor
            and EXPECTED_HISTORICAL_E7_SHA in reconstructor
            and EXPECTED_B1_10_MANIFEST in reconstructor
            and EXPECTED_B1_11_MANIFEST in reconstructor
        ),
        "replay_verdict": replay.get("verdict") == "PASS",
        "replay_input_authorities": (
            replay.get("inputs", {}).get("b0_distribution_sha256") == EXPECTED_B0_DISTRIBUTION
            and replay.get("inputs", {}).get("b0_source_archive_sha256") == EXPECTED_B0_SOURCE_ARCHIVE
            and replay.get("inputs", {}).get("e7_upstream_package_sha256") == EXPECTED_E7_PACKAGE_SHA
            and replay.get("inputs", {}).get("historical_e7_patch_sha256") == EXPECTED_HISTORICAL_E7_SHA
            and replay.get("inputs", {}).get("ordered_b1_10_admission_patch_sha256") == EXPECTED_PATCH_SHA
        ),
        "replay_b1_11_identity": (
            replay_b111.get("member_count") == EXPECTED_MEMBER_COUNT
            and replay_b111.get("source_bytes") == EXPECTED_SOURCE_BYTES
            and replay_b111.get("member_manifest_sha256") == EXPECTED_B1_11_MANIFEST
        ),
        "replay_target_identities": (
            set(replay_targets) == target_set
            and all(
                replay_targets[path].get("preimage_sha256") == pins["pre"]
                and replay_targets[path].get("postimage_sha256") == pins["post"]
                for path, pins in TARGETS.items()
            )
        ),
        "replay_nonproduction_contract": (
            replay.get("production_source_modified") is False
            and replay.get("mass_tolerance_changed") is False
            and replay.get("solver_policy_changed") is False
        ),
        "expected_difference_registry": (
            edge.get("candidate") == "B1.11"
            and len(diff011) == 1
            and diff011[0].get("status") == "ADMITTED_B1"
            and diff011[0].get("first_admitted_tag_or_commit") == "B1.11"
        ),
        "human_ledger_admission": "| `B1.11` | `SWAP-011` |" in ledger,
        "qualification_admitted": "ADMITTED_B1" in qualification and EXPECTED_B1_11_MANIFEST in qualification,
        "provenance_authorities": (
            EXPECTED_E7_PACKAGE_SHA in provenance
            and EXPECTED_HISTORICAL_E7_SHA in provenance
            and EXPECTED_PATCH_SHA in provenance
            and EXPECTED_B1_11_MANIFEST in provenance
        ),
        "checklist_complete": (
            "Full reconstruction from canonical B0 distribution reproduces frozen B1.11 identity | PASS" in checklist
            and "B1.11 published as immutable corrected-reference snapshot | PASS" in checklist
        ),
    }
    passed = all(checks.values())
    return {
        "snapshot": "B1.11",
        "status": "PASS" if passed else "FAIL",
        "checks": checks,
        "authorities": {
            "ordered_patch_sha256": sha256_file(PATCH),
            "historical_e7_patch_sha256": EXPECTED_HISTORICAL_E7_SHA,
            "b1_11_source_manifest_sha256": sha256_file(SOURCE_MANIFEST),
        },
    }


def main() -> int:
    try:
        result = assess()
    except Exception as exc:
        result = {"snapshot": "B1.11", "status": "FAIL", "failure": str(exc)}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result.get("status") == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())

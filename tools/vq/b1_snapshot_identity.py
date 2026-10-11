#!/usr/bin/env python3
"""Fail-closed identity gate for a pinned corrected-reference B1 snapshot.

Verification infrastructure only. This gate does not apply patches or execute SWAP.
It verifies the exact snapshot blob, canonical B0 member manifest, stored patch bytes,
and every declared B0 target preimage before B1 may be used as a numerical oracle.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PIN = REPO_ROOT / "tools" / "vq" / "cases" / "b1-5p1-reference-pin.json"


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git_blob_sha1(path: Path) -> str:
    data = path.read_bytes()
    header = f"blob {len(data)}\0".encode("ascii")
    return hashlib.sha1(header + data).hexdigest()


def load_member_manifest(path: Path) -> dict[str, str]:
    members: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split(maxsplit=2)
        if len(parts) != 3:
            raise ValueError(f"invalid B0 member manifest line: {raw}")
        digest, _size, member = parts
        members[member] = digest.lower()
    return members


def verify_snapshot(reference_root: Path, pin_path: Path = DEFAULT_PIN) -> dict[str, Any]:
    pin = json.loads(pin_path.read_text(encoding="utf-8"))
    result: dict[str, Any] = {
        "snapshot": pin["snapshot"],
        "integration_commit": pin["integration_commit"],
        "reference_root": str(reference_root),
        "pin": str(pin_path),
        "snapshot_identity": {},
        "b0_manifest_identity": {},
        "patches": [],
        "qualified_identity": True,
    }

    snapshot_path = reference_root / pin["snapshot_path"]
    snapshot_observed = git_blob_sha1(snapshot_path) if snapshot_path.is_file() else None
    snapshot_matches = snapshot_observed == pin["snapshot_git_blob_sha1"]
    result["snapshot_identity"] = {
        "path": str(snapshot_path),
        "expected_git_blob_sha1": pin["snapshot_git_blob_sha1"],
        "observed_git_blob_sha1": snapshot_observed,
        "matches": snapshot_matches,
    }
    if not snapshot_matches:
        result["qualified_identity"] = False

    manifest_path = reference_root / pin["b0_member_manifest_path"]
    manifest_observed = git_blob_sha1(manifest_path) if manifest_path.is_file() else None
    manifest_matches = manifest_observed == pin["b0_member_manifest_git_blob_sha1"]
    result["b0_manifest_identity"] = {
        "path": str(manifest_path),
        "expected_git_blob_sha1": pin["b0_member_manifest_git_blob_sha1"],
        "observed_git_blob_sha1": manifest_observed,
        "matches": manifest_matches,
    }
    if not manifest_matches:
        result["qualified_identity"] = False
        members: dict[str, str] = {}
    else:
        members = load_member_manifest(manifest_path)

    for expected in pin["patches"]:
        path = reference_root / expected["path"]
        observed = sha256_file(path) if path.is_file() else None
        patch_matches = observed == expected["expected_sha256"].lower()
        target = expected["b0_target"]
        manifest_preimage = members.get(target)
        preimage_matches = manifest_preimage == expected["expected_b0_sha256"].lower()
        item: dict[str, Any] = {
            "id": expected["id"],
            "path": str(path),
            "expected_sha256": expected["expected_sha256"],
            "observed_sha256": observed,
            "patch_matches": patch_matches,
            "b0_target": target,
            "expected_b0_sha256": expected["expected_b0_sha256"],
            "manifest_b0_sha256": manifest_preimage,
            "b0_preimage_matches": preimage_matches,
            "matches": bool(patch_matches and preimage_matches),
        }
        if not path.is_file():
            item["failure"] = "patch_not_found"
        elif not patch_matches:
            item["failure"] = "patch_artifact_identity_mismatch"
        elif not preimage_matches:
            item["failure"] = "b0_preimage_identity_mismatch"
        if not item["matches"]:
            result["qualified_identity"] = False
        result["patches"].append(item)

    if not result["qualified_identity"]:
        result["failure"] = "b1_snapshot_identity_mismatch"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify a pinned B1 snapshot identity and canonical B0 preimages.")
    parser.add_argument(
        "--reference-root",
        type=Path,
        default=REPO_ROOT,
        help="Repository checkout containing reference/swap-4.3.1",
    )
    parser.add_argument("--pin", type=Path, default=DEFAULT_PIN)
    args = parser.parse_args()
    result = verify_snapshot(args.reference_root, args.pin)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["qualified_identity"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

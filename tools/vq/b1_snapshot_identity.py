#!/usr/bin/env python3
"""Verify exact patch-artifact identities for a pinned B1 snapshot.

Verification infrastructure only. It does not apply patches or execute SWAP.
A B1 oracle pin fails closed when any patch file is missing or its SHA-256 differs
from the pinned immutable snapshot evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PIN = REPO_ROOT / "tools" / "vq" / "cases" / "b1-4-reference-pin.json"


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_snapshot(reference_root: Path, pin_path: Path = DEFAULT_PIN) -> dict[str, Any]:
    pin = json.loads(pin_path.read_text(encoding="utf-8"))
    result: dict[str, Any] = {
        "snapshot": pin["snapshot"],
        "integration_commit": pin["integration_commit"],
        "reference_root": str(reference_root),
        "pin": str(pin_path),
        "patches": [],
        "qualified_identity": True,
    }

    for expected in pin["patches"]:
        path = reference_root / expected["path"]
        item: dict[str, Any] = {
            "id": expected["id"],
            "path": str(path),
            "expected_sha256": expected["expected_sha256"],
            "observed_sha256": None,
            "matches": False,
        }
        if path.is_file():
            observed = sha256_file(path)
            item["observed_sha256"] = observed
            item["matches"] = observed.lower() == expected["expected_sha256"].lower()
        else:
            item["failure"] = "patch_not_found"
        if not item["matches"]:
            result["qualified_identity"] = False
        result["patches"].append(item)

    if not result["qualified_identity"]:
        result["failure"] = "patch_artifact_identity_mismatch"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify a pinned B1 patch-artifact set.")
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

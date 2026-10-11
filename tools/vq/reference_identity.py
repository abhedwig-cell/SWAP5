#!/usr/bin/env python3
"""Verify that a supplied archive is the exact documented B0 distribution.

This tool is verification infrastructure only. It does not execute or modify SWAP.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO_ROOT / "docs" / "verification" / "reference-baseline.json"


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_b0_identity(manifest_path: Path) -> dict[str, Any]:
    with manifest_path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    return manifest["reference_chain"]["B0"]["distribution"]


def verify_b0_archive(archive_path: Path, manifest_path: Path = DEFAULT_MANIFEST) -> dict[str, Any]:
    expected = load_b0_identity(manifest_path)

    result: dict[str, Any] = {
        "baseline": "B0",
        "archive": str(archive_path),
        "manifest": str(manifest_path),
        "expected": {
            "name": expected["name"],
            "size_bytes": expected["size_bytes"],
            "sha256": expected["sha256"],
        },
        "observed": None,
        "qualified_identity": False,
    }

    if not archive_path.is_file():
        result["failure"] = "archive_not_found"
        return result

    observed_size = archive_path.stat().st_size
    observed_sha256 = sha256_file(archive_path)
    result["observed"] = {
        "name": archive_path.name,
        "size_bytes": observed_size,
        "sha256": observed_sha256,
    }

    size_matches = observed_size == expected["size_bytes"]
    hash_matches = observed_sha256.lower() == expected["sha256"].lower()
    result["checks"] = {
        "size_matches": size_matches,
        "sha256_matches": hash_matches,
    }
    result["qualified_identity"] = bool(size_matches and hash_matches)

    if not result["qualified_identity"]:
        result["failure"] = "identity_mismatch"

    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Verify the exact B0 SWAP 4.3.1 distribution identity."
    )
    parser.add_argument("--archive", required=True, type=Path, help="Path to candidate B0 ZIP archive")
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST,
        help="Reference baseline manifest (defaults to the repository manifest)",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    result = verify_b0_archive(args.archive, args.manifest)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["qualified_identity"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

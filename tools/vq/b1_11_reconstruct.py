#!/usr/bin/env python3
"""Deterministically reconstruct B1.11 from exact B0 through qualified B1.10."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

try:
    from .b1_10_reconstruct import reconstruct as reconstruct_b1_10
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_10_reconstruct import reconstruct as reconstruct_b1_10
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = "B1.11"
PATCH_DIR = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-011"
PATCH_PATH = PATCH_DIR / "fix.patch"
HELPER_PATH = PATCH_DIR / "apply_and_verify.py"
PATCH_SHA256 = "1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238"
HISTORICAL_E7_PATCH_SHA256 = "9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110"
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
SOURCE_MEMBER_COUNT = 63
SOURCE_BYTES = 1_886_519
SOURCE_MANIFEST_SHA256 = "24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helper():
    spec = importlib.util.spec_from_file_location("swap011_apply", HELPER_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load SWAP-011 ordered applicator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_10(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.10 predecessor reconstruction did not qualify")
    if base.get("source_tree", {}).get("manifest_sha256") != B1_10_MANIFEST:
        raise ValueError("B1.10 predecessor source identity mismatch")
    patch_sha = sha256_file(PATCH_PATH)
    if patch_sha != PATCH_SHA256:
        raise ValueError(f"SWAP-011 ordered patch SHA mismatch: {patch_sha}")
    helper = load_helper()
    if helper.PATCH_SHA256 != PATCH_SHA256:
        raise ValueError("SWAP-011 helper patch pin mismatch")
    results = helper.apply_tree(output_dir, PATCH_PATH)
    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)
    if member_count != SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.11 member count mismatch: {member_count}")
    if source_bytes != SOURCE_BYTES:
        raise ValueError(f"B1.11 source byte count mismatch: {source_bytes}")
    if manifest_sha != SOURCE_MANIFEST_SHA256:
        raise ValueError(f"B1.11 source manifest mismatch: expected {SOURCE_MANIFEST_SHA256}, got {manifest_sha}")
    manifest_path = output_dir.parent / "B1.11-source-manifest.sha256"
    manifest_path.write_bytes(manifest)
    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {"snapshot": "B1.10", "source_manifest_sha256": B1_10_MANIFEST},
        "admitted_correction": {
            "id": "SWAP-011",
            "ordered_patch_sha256": patch_sha,
            "historical_e7_patch_sha256": HISTORICAL_E7_PATCH_SHA256,
            "targets": results,
            "status": "PASS",
        },
        "source_tree": {
            "member_count": member_count,
            "bytes": source_bytes,
            "manifest_sha256": manifest_sha,
            "manifest_path": str(manifest_path),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.11 source from exact B0")
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = reconstruct(args.archive, args.output_dir)
    except Exception as exc:
        print(json.dumps({"snapshot": SNAPSHOT, "qualified_reconstruction": False, "failure": str(exc)}, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Deterministically reconstruct B1.10 from exact B0 through qualified B1.9.

Verification infrastructure only. B1.10 adds the isolated SWAP-002 tillage
start-event indexing correction and deliberately excludes SWAP-003/SWAP-004.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

try:
    from .b1_9_reconstruct import reconstruct as reconstruct_b1_9
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_9_reconstruct import reconstruct as reconstruct_b1_9
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = "B1.10"
PATCH_DIR = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-002"
PATCH_PATH = PATCH_DIR / "fix.patch"
HELPER_PATH = PATCH_DIR / "apply_and_verify.py"
TARGET = "tillage.f90"
PATCH_SHA256 = "e6f501f510f0de3599cfb2ef208744862e7ef9173c9cf1bf434f2e3ea450613b"
CANONICAL_B0_SHA256 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
ORDERED_B1_9_SHA256 = CANONICAL_B0_SHA256
CORRECTED_SHA256 = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
B1_9_MANIFEST = "5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657"
SOURCE_MEMBER_COUNT = 63
SOURCE_BYTES = 1_863_575
SOURCE_MANIFEST_SHA256 = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helper():
    spec = importlib.util.spec_from_file_location("swap002_apply", HELPER_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load SWAP-002 applicator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_9(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.9 predecessor reconstruction did not qualify")
    if base.get("source_tree", {}).get("manifest_sha256") != B1_9_MANIFEST:
        raise ValueError("B1.9 predecessor source identity mismatch")

    patch_sha = sha256_file(PATCH_PATH)
    if patch_sha != PATCH_SHA256:
        raise ValueError(f"SWAP-002 stored patch SHA mismatch: {patch_sha}")

    helper = load_helper()
    if helper.B0_SHA256 != CANONICAL_B0_SHA256:
        raise ValueError("SWAP-002 helper canonical preimage pin mismatch")
    if helper.CORRECTED_SHA256 != CORRECTED_SHA256:
        raise ValueError("SWAP-002 helper corrected-target pin mismatch")

    target = output_dir / TARGET
    observed = sha256_file(target)
    if observed != ORDERED_B1_9_SHA256:
        raise ValueError(
            f"SWAP-002 ordered B1.9 preimage mismatch: expected {ORDERED_B1_9_SHA256}, got {observed}"
        )
    target.write_bytes(helper.apply(target.read_bytes()))
    if sha256_file(target) != CORRECTED_SHA256:
        raise ValueError("SWAP-002 corrected target identity mismatch after apply")

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)
    if member_count != SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.10 member count mismatch: {member_count}")
    if source_bytes != SOURCE_BYTES:
        raise ValueError(f"B1.10 source byte count mismatch: {source_bytes}")
    if manifest_sha != SOURCE_MANIFEST_SHA256:
        raise ValueError(
            f"B1.10 source manifest mismatch: expected {SOURCE_MANIFEST_SHA256}, got {manifest_sha}"
        )

    manifest_path = output_dir.parent / "B1.10-source-manifest.sha256"
    manifest_path.write_bytes(manifest)
    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {
            "snapshot": "B1.9",
            "source_manifest_sha256": base["source_tree"]["manifest_sha256"],
        },
        "admitted_correction": {
            "id": "SWAP-002",
            "patch_sha256": patch_sha,
            "canonical_b0_target_sha256": CANONICAL_B0_SHA256,
            "ordered_preimage_snapshot": "B1.9",
            "ordered_preimage_sha256": ORDERED_B1_9_SHA256,
            "corrected_target_sha256": CORRECTED_SHA256,
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
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.10 source from exact B0")
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

#!/usr/bin/env python3
"""Deterministically reconstruct B1.9 from exact B0 through qualified B1.8.

Verification infrastructure only. B1.9 adds the isolated SWAP-012 prhead
inverse correction and deliberately excludes the historical SWAP-011 dhconduc
changes that once shared the same broad audit patch.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

try:
    from .b1_8_reconstruct import reconstruct as reconstruct_b1_8
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_8_reconstruct import reconstruct as reconstruct_b1_8
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = "B1.9"
PATCH_DIR = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-012"
PATCH_PATH = PATCH_DIR / "fix.patch"
HELPER_PATH = PATCH_DIR / "apply_and_verify.py"
TARGET = "MOD_MvG_functions.f90"
PATCH_SHA256 = "263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131"
CANONICAL_B0_SHA256 = "a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390"
ORDERED_B1_8_SHA256 = CANONICAL_B0_SHA256
CORRECTED_SHA256 = "4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
B1_8_MANIFEST = "e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae"
SOURCE_MEMBER_COUNT = 63
SOURCE_BYTES = 1_863_300
SOURCE_MANIFEST_SHA256 = "5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helper():
    spec = importlib.util.spec_from_file_location("swap012_apply", HELPER_PATH)
    if spec is None or spec.loader is None:
        raise ValueError("cannot load SWAP-012 applicator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_8(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.8 predecessor reconstruction did not qualify")
    if base.get("source_tree", {}).get("manifest_sha256") != B1_8_MANIFEST:
        raise ValueError("B1.8 predecessor source identity mismatch")

    patch_sha = sha256_file(PATCH_PATH)
    if patch_sha != PATCH_SHA256:
        raise ValueError(f"SWAP-012 stored patch SHA mismatch: {patch_sha}")

    helper = load_helper()
    if helper.B0_SHA256 != CANONICAL_B0_SHA256:
        raise ValueError("SWAP-012 helper canonical preimage pin mismatch")
    if helper.CORRECTED_SHA256 != CORRECTED_SHA256:
        raise ValueError("SWAP-012 helper corrected-target pin mismatch")

    target = output_dir / TARGET
    observed = sha256_file(target)
    if observed != ORDERED_B1_8_SHA256:
        raise ValueError(
            f"SWAP-012 ordered B1.8 preimage mismatch: expected {ORDERED_B1_8_SHA256}, got {observed}"
        )
    target.write_bytes(helper.apply(target.read_bytes()))
    if sha256_file(target) != CORRECTED_SHA256:
        raise ValueError("SWAP-012 corrected target identity mismatch after apply")

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)
    if member_count != SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.9 member count mismatch: {member_count}")
    if source_bytes != SOURCE_BYTES:
        raise ValueError(f"B1.9 source byte count mismatch: {source_bytes}")
    if manifest_sha != SOURCE_MANIFEST_SHA256:
        raise ValueError(
            f"B1.9 source manifest mismatch: expected {SOURCE_MANIFEST_SHA256}, got {manifest_sha}"
        )

    manifest_path = output_dir.parent / "B1.9-source-manifest.sha256"
    manifest_path.write_bytes(manifest)
    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {
            "snapshot": "B1.8",
            "source_manifest_sha256": base["source_tree"]["manifest_sha256"],
        },
        "admitted_correction": {
            "id": "SWAP-012",
            "patch_sha256": patch_sha,
            "canonical_b0_target_sha256": CANONICAL_B0_SHA256,
            "ordered_preimage_snapshot": "B1.8",
            "ordered_preimage_sha256": ORDERED_B1_8_SHA256,
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
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.9 source from exact B0")
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

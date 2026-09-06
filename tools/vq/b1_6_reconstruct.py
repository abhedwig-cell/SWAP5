#!/usr/bin/env python3
"""Deterministically reconstruct B1.6 from exact B0 through qualified B1.5p1.

Verification infrastructure only. B1.6 is defined as the VQ-qualified B1.5p1
source tree plus the exact admitted SWAP-009 Kelvin-sign correction.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from .b1_reconstruct import reconstruct as reconstruct_b1_5p1
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_reconstruct import reconstruct as reconstruct_b1_5p1
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]

SNAPSHOT = "B1.6"
SWAP009_PATCH_PATH = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-009" / "fix.patch"
SWAP009_PATCH_SHA256 = "43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66"
SWAP009_TARGET = "WC_K_models_04_11.f90"
SWAP009_B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
SWAP009_CORRECTED_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
SWAP009_OLD = b"Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
SWAP009_NEW = b"Kvap = Kvap_func (WC, h, Temp) * Conv"
SWAP009_OCCURRENCES = 4

B1_6_SOURCE_MEMBER_COUNT = 63
B1_6_SOURCE_BYTES = 1_860_085
B1_6_SOURCE_MANIFEST_SHA256 = "aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def apply_swap009(data: bytes) -> bytes:
    observed = sha256_bytes(data)
    if observed != SWAP009_B0_SHA256:
        raise ValueError(
            f"SWAP-009: expected canonical B0 target {SWAP009_B0_SHA256}, got {observed}"
        )
    count = data.count(SWAP009_OLD)
    if count != SWAP009_OCCURRENCES:
        raise ValueError(
            f"SWAP-009: expected {SWAP009_OCCURRENCES} target occurrences, found {count}"
        )
    corrected = data.replace(SWAP009_OLD, SWAP009_NEW)
    observed_corrected = sha256_bytes(corrected)
    if observed_corrected != SWAP009_CORRECTED_SHA256:
        raise ValueError(
            "SWAP-009: corrected target SHA mismatch: "
            f"expected {SWAP009_CORRECTED_SHA256}, got {observed_corrected}"
        )
    return corrected


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_5p1(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.5p1 predecessor reconstruction did not qualify")

    if not SWAP009_PATCH_PATH.is_file():
        raise ValueError(f"SWAP-009 patch missing: {SWAP009_PATCH_PATH}")
    patch_sha = sha256_file(SWAP009_PATCH_PATH)
    if patch_sha != SWAP009_PATCH_SHA256:
        raise ValueError(
            f"SWAP-009 stored patch SHA mismatch: expected {SWAP009_PATCH_SHA256}, got {patch_sha}"
        )

    target = output_dir / SWAP009_TARGET
    corrected = apply_swap009(target.read_bytes())
    target.write_bytes(corrected)

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)

    if member_count != B1_6_SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.6 member count mismatch: {member_count}")
    if source_bytes != B1_6_SOURCE_BYTES:
        raise ValueError(f"B1.6 source byte count mismatch: {source_bytes}")
    if manifest_sha != B1_6_SOURCE_MANIFEST_SHA256:
        raise ValueError(
            f"B1.6 source manifest SHA mismatch: expected "
            f"{B1_6_SOURCE_MANIFEST_SHA256}, got {manifest_sha}"
        )

    manifest_path = output_dir.parent / "B1.6-source-manifest.sha256"
    manifest_path.write_bytes(manifest)

    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {
            "snapshot": "B1.5p1",
            "qualified_reconstruction": True,
            "source_manifest_sha256": base["source_tree"]["manifest_sha256"],
        },
        "admitted_correction": {
            "id": "SWAP-009",
            "patch_sha256": patch_sha,
            "b0_target_sha256": SWAP009_B0_SHA256,
            "corrected_target_sha256": SWAP009_CORRECTED_SHA256,
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
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.6 source from exact B0")
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = reconstruct(args.archive, args.output_dir)
    except Exception as exc:
        print(json.dumps({
            "snapshot": SNAPSHOT,
            "qualified_reconstruction": False,
            "failure": str(exc),
        }, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

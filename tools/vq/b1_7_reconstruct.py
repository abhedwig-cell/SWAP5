#!/usr/bin/env python3
"""Deterministically reconstruct B1.7 from exact B0 through qualified B1.6.

Verification infrastructure only. B1.7 is defined as the qualified B1.6 source
tree plus the exact admitted SWAP-010 model-7 capacity correction. Because
SWAP-009 and SWAP-010 share WC_K_models_04_11.f90, the SWAP-010 executable
preimage is explicitly the ordered B1.6 target, while canonical B0 remains the
provenance origin.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from .b1_6_reconstruct import reconstruct as reconstruct_b1_6
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_6_reconstruct import reconstruct as reconstruct_b1_6
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]

SNAPSHOT = "B1.7"
SWAP010_PATCH_PATH = REPO_ROOT / "reference" / "swap-4.3.1" / "patches" / "SWAP-010" / "fix.patch"
SWAP010_PATCH_SHA256 = "f3d67771908e27a23610a650c4ad72813d882169f360a973472f86f545ee5deb"
SWAP010_TARGET = "WC_K_models_04_11.f90"
SWAP010_CANONICAL_B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
SWAP010_ORDERED_B1_6_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
SWAP010_CORRECTED_SHA256 = "7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e"

SWAP010_OLD = (
    b"   Gam01 = Gamma1 (dabs(h0))\r\n"
    b"   Gam02 = Gamma2 (dabs(h0))\r\n"
    b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))\r\n"
)
SWAP010_NEW = (
    b"   Gam01 = Omega1*Gamma1 (dabs(h0))\r\n"
    b"   Gam02 = Omega2*Gamma2 (dabs(h0))\r\n"
    b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Gam01-Gam02)\r\n"
)

B1_7_SOURCE_MEMBER_COUNT = 63
B1_7_SOURCE_BYTES = 1_860_091
B1_7_SOURCE_MANIFEST_SHA256 = "62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def apply_swap010(data: bytes) -> bytes:
    observed = sha256_bytes(data)
    if observed == SWAP010_CANONICAL_B0_SHA256:
        raise ValueError(
            "SWAP-010 received canonical B0 directly; SWAP-009 must precede it on the shared target"
        )
    if observed != SWAP010_ORDERED_B1_6_SHA256:
        raise ValueError(
            "SWAP-010 ordered preimage SHA mismatch: expected "
            f"{SWAP010_ORDERED_B1_6_SHA256}, got {observed}"
        )

    count = data.count(SWAP010_OLD)
    if count != 1:
        raise ValueError(f"SWAP-010: expected one capacity target sequence, found {count}")

    corrected = data.replace(SWAP010_OLD, SWAP010_NEW, 1)
    observed_corrected = sha256_bytes(corrected)
    if observed_corrected != SWAP010_CORRECTED_SHA256:
        raise ValueError(
            "SWAP-010 corrected target SHA mismatch: expected "
            f"{SWAP010_CORRECTED_SHA256}, got {observed_corrected}"
        )
    return corrected


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_6(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.6 predecessor reconstruction did not qualify")
    if base.get("source_tree", {}).get("manifest_sha256") != (
        "aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0"
    ):
        raise ValueError("B1.6 predecessor source identity mismatch")

    if not SWAP010_PATCH_PATH.is_file():
        raise ValueError(f"SWAP-010 patch missing: {SWAP010_PATCH_PATH}")
    patch_sha = sha256_file(SWAP010_PATCH_PATH)
    if patch_sha != SWAP010_PATCH_SHA256:
        raise ValueError(
            f"SWAP-010 stored patch SHA mismatch: expected {SWAP010_PATCH_SHA256}, got {patch_sha}"
        )

    target = output_dir / SWAP010_TARGET
    corrected = apply_swap010(target.read_bytes())
    target.write_bytes(corrected)

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)

    if member_count != B1_7_SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.7 member count mismatch: {member_count}")
    if source_bytes != B1_7_SOURCE_BYTES:
        raise ValueError(f"B1.7 source byte count mismatch: {source_bytes}")
    if manifest_sha != B1_7_SOURCE_MANIFEST_SHA256:
        raise ValueError(
            "B1.7 source manifest SHA mismatch: expected "
            f"{B1_7_SOURCE_MANIFEST_SHA256}, got {manifest_sha}"
        )

    manifest_path = output_dir.parent / "B1.7-source-manifest.sha256"
    manifest_path.write_bytes(manifest)

    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {
            "snapshot": "B1.6",
            "qualified_reconstruction": True,
            "source_manifest_sha256": base["source_tree"]["manifest_sha256"],
        },
        "admitted_correction": {
            "id": "SWAP-010",
            "patch_sha256": patch_sha,
            "canonical_b0_target_sha256": SWAP010_CANONICAL_B0_SHA256,
            "ordered_preimage_snapshot": "B1.6",
            "ordered_preimage_sha256": SWAP010_ORDERED_B1_6_SHA256,
            "corrected_target_sha256": SWAP010_CORRECTED_SHA256,
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
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.7 source from exact B0")
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

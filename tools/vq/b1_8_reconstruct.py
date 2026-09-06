#!/usr/bin/env python3
"""Deterministically reconstruct B1.8 from exact B0 through qualified B1.7.

Verification infrastructure only. B1.8 adds the exact SWAP-013 PDI HA/H0
input-domain guard to the qualified B1.7 corrected reference.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from .b1_7_reconstruct import reconstruct as reconstruct_b1_7
    from .b1_reconstruct import source_manifest, sha256_bytes
except ImportError:
    from b1_7_reconstruct import reconstruct as reconstruct_b1_7
    from b1_reconstruct import source_manifest, sha256_bytes

REPO_ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = "B1.8"

PATCH_PATH = REPO_ROOT / "reference/swap-4.3.1/patches/SWAP-013/fix.patch"
PATCH_SHA256 = "066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3"
TARGET = "readswap.f90"
CANONICAL_B0_SHA256 = "3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2"
ORDERED_B1_7_SHA256 = CANONICAL_B0_SHA256
CORRECTED_SHA256 = "e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c"

OLD = (
    b"                  call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)\r\n"
    b"                  call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)\r\n"
)
NEW = (
    b"                  call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)\r\n"
    b"                  do lay = 1, numlay\r\n"
    b"                     if (iHWCKmodel(lay) >= 8 .AND. iHWCKmodel(lay) <= 11) then\r\n"
    b"                        if (ha(lay) <= 0.0d0 .OR. ha(lay) >= h0(lay)) then\r\n"
    b"                           call swap_error ('readswap', 'PDI requires 0 < abs(HA) < abs(H0) for every PDI soil layer')\r\n"
    b"                        end if\r\n"
    b"                     end if\r\n"
    b"                  end do\r\n"
    b"                  call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)\r\n"
)

SOURCE_MEMBER_COUNT = 63
SOURCE_BYTES = 1_860_493
SOURCE_MANIFEST_SHA256 = "e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae"


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply_swap013(data: bytes) -> bytes:
    observed = sha256_bytes(data)
    if observed != ORDERED_B1_7_SHA256:
        raise ValueError(
            f"SWAP-013 ordered B1.7 preimage mismatch: expected {ORDERED_B1_7_SHA256}, got {observed}"
        )
    count = data.count(OLD)
    if count != 1:
        raise ValueError(f"SWAP-013 expected one target block, found {count}")
    corrected = data.replace(OLD, NEW, 1)
    actual = sha256_bytes(corrected)
    if actual != CORRECTED_SHA256:
        raise ValueError(f"SWAP-013 corrected target mismatch: expected {CORRECTED_SHA256}, got {actual}")
    return corrected


def reconstruct(archive: Path, output_dir: Path) -> dict:
    base = reconstruct_b1_7(archive, output_dir)
    if not base.get("qualified_reconstruction"):
        raise ValueError("B1.7 predecessor reconstruction did not qualify")
    if base.get("source_tree", {}).get("manifest_sha256") != "62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba":
        raise ValueError("B1.7 predecessor source identity mismatch")

    patch_sha = sha256_file(PATCH_PATH)
    if patch_sha != PATCH_SHA256:
        raise ValueError(f"SWAP-013 stored patch SHA mismatch: expected {PATCH_SHA256}, got {patch_sha}")

    target = output_dir / TARGET
    corrected = apply_swap013(target.read_bytes())
    target.write_bytes(corrected)

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)

    if member_count != SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1.8 member count mismatch: {member_count}")
    if source_bytes != SOURCE_BYTES:
        raise ValueError(f"B1.8 source byte count mismatch: {source_bytes}")
    if manifest_sha != SOURCE_MANIFEST_SHA256:
        raise ValueError(f"B1.8 source manifest mismatch: expected {SOURCE_MANIFEST_SHA256}, got {manifest_sha}")

    manifest_path = output_dir.parent / "B1.8-source-manifest.sha256"
    manifest_path.write_bytes(manifest)

    return {
        "snapshot": SNAPSHOT,
        "qualified_reconstruction": True,
        "predecessor": {
            "snapshot": "B1.7",
            "source_manifest_sha256": base["source_tree"]["manifest_sha256"],
        },
        "admitted_correction": {
            "id": "SWAP-013",
            "patch_sha256": patch_sha,
            "canonical_b0_target_sha256": CANONICAL_B0_SHA256,
            "ordered_preimage_snapshot": "B1.7",
            "ordered_preimage_sha256": ORDERED_B1_7_SHA256,
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
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.8 source from exact B0")
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

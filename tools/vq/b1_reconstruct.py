#!/usr/bin/env python3
"""Deterministically reconstruct B1.5p1 corrected source from exact B0.

Verification infrastructure only. The adapter never edits the B0 distribution.
It verifies the exact B0 identities, applies five byte-exact transformations,
checks every corrected-target SHA-256, and emits a deterministic 63-member
source manifest for the reconstructed B1.5p1 tree.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

try:
    from .reference_identity import verify_b0_archive
except ImportError:
    from reference_identity import verify_b0_archive

B0_SOURCE_ARCHIVE_SHA256 = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
B1_SOURCE_MANIFEST_SHA256 = "c50da618aef92f99103531390e243144403060b0066e8dc3d827b79085bd9c30"
B1_SOURCE_MEMBER_COUNT = 63
B1_SOURCE_BYTES = 1_860_109


@dataclass(frozen=True)
class Replacement:
    old: bytes
    new: bytes


@dataclass(frozen=True)
class Correction:
    patch_id: str
    target: str
    b0_sha256: str
    corrected_sha256: str
    replacements: tuple[Replacement, ...]


CORRECTIONS = (
    Correction(
        "SWAP-001", "SWAP/macropore.f90",
        "1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b",
        "f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f",
        (Replacement(
            b"      VlMpDm1Cp= VlMpDmCp(1,1:numnod)\r\n",
            b"      VlMpDm1Cp = 0.0d0\r\n"
            b"      VlMpDm1Cp(1:numnod) = VlMpDmCp(1,1:numnod)\r\n",
        ),),
    ),
    Correction(
        "SWAP-005", "SWAP/MOD_cropdevelopment.f90",
        "c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf",
        "aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210",
        (Replacement(
            b"            if ((cropstart(i+1) - cropend(i)) < 0.5d0 .AND. i < ifnd) then\r\n"
            b"               message = 'The begin date of crop '//trim(cropfil(i))//' should be larger than the end date of the former crop!'\r\n"
            b"               call swap_error ('croprotation', message)\r\n",
            b"            if (i < ifnd) then\r\n"
            b"               if ((cropstart(i+1) - cropend(i)) < 0.5d0) then\r\n"
            b"                  message = 'The begin date of crop '//trim(cropfil(i))//' should be larger than the end date of the former crop!'\r\n"
            b"                  call swap_error ('croprotation', message)\r\n"
            b"               end if\r\n",
        ),),
    ),
    Correction(
        "SWAP-006", "SWAP/MOD_meteo.f90",
        "5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822",
        "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f",
        (Replacement(
            b"         i = 1\r\n"
            b"         do while (tend - cropstart(i) > 0.d0)\r\n"
            b"            if (cropstart(i) < 1.d0) exit\r\n"
            b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
            b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
            b"            end if\r\n"
            b"            i = i + 1\r\n"
            b"         end do\r\n",
            b"         do i = 1, ifnd\r\n"
            b"            if (tend - cropstart(i) <= 0.0d0) exit\r\n"
            b"            if (cropstart(i) < 1.0d0) exit\r\n"
            b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
            b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
            b"            end if\r\n"
            b"         end do\r\n",
        ),),
    ),
    Correction(
        "SWAP-007", "SWAP/oxygenstress.f90",
        "2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735",
        "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87",
        (Replacement(
            b"            if (dabs(fi_a) > 0.d0) then\r\n"
            b"                lnew = dabs(l - (fi / fi_a))\r\n"
            b"            end if\r\n",
            b"            if (dabs(fi_a) > dmax1(tiny(1.0d0), dabs(fi)/huge(1.0d0))) then\r\n"
            b"               lnew = dabs(l - (fi / fi_a))\r\n"
            b"            else\r\n"
            b"               ! Force a controlled restart instead of risking overflow in fi/fi_a.\r\n"
            b"               lnew = huge(1.0d0)\r\n"
            b"            end if\r\n",
        ),),
    ),
    Correction(
        "SWAP-008", "SWAP/tridag.f90",
        "6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651",
        "87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a",
        (
            Replacement(
                b"      real(8), intent(out) :: a(np,mp),al(np,mpl)\r\n",
                b"      real(8), intent(inout) :: a(np,mp)\r\n"
                b"      real(8), intent(out)   :: al(np,mpl)\r\n",
            ),
            Replacement(
                b"      real(8), intent(out) :: b(n)\r\n",
                b"      real(8), intent(inout) :: b(n)\r\n",
            ),
        ),
    ),
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def apply_correction(data: bytes, correction: Correction) -> bytes:
    if sha256_bytes(data) != correction.b0_sha256:
        raise ValueError(f"{correction.patch_id}: B0 preimage SHA mismatch")
    result = data
    for replacement in correction.replacements:
        count = result.count(replacement.old)
        if count != 1:
            raise ValueError(
                f"{correction.patch_id}: expected one target sequence, found {count}"
            )
        result = result.replace(replacement.old, replacement.new, 1)
    actual = sha256_bytes(result)
    if actual != correction.corrected_sha256:
        raise ValueError(
            f"{correction.patch_id}: corrected SHA mismatch: expected "
            f"{correction.corrected_sha256}, got {actual}"
        )
    return result


def source_manifest(source_root: Path) -> bytes:
    lines = []
    for path in sorted(source_root.iterdir(), key=lambda item: item.name):
        if path.is_file():
            data = path.read_bytes()
            lines.append(
                f"{sha256_bytes(data)}  {len(data):8d}  SWAP/{path.name}\n"
            )
    return "".join(lines).encode("ascii")


def reconstruct(archive: Path, output_dir: Path) -> dict:
    identity = verify_b0_archive(archive)
    if not identity["qualified_identity"]:
        raise ValueError("B0 distribution identity failed")

    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        with zipfile.ZipFile(archive) as outer:
            outer.extract("SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP", tmp_root)
        source_archive = tmp_root / "SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP"
        observed_source_sha = sha256_file(source_archive)
        if observed_source_sha != B0_SOURCE_ARCHIVE_SHA256:
            raise ValueError("B0 source archive identity failed")
        expanded = tmp_root / "expanded"
        with zipfile.ZipFile(source_archive) as source_zip:
            source_zip.extractall(expanded)
        b0_source = expanded / "SWAP"
        if output_dir.exists():
            shutil.rmtree(output_dir)
        shutil.copytree(b0_source, output_dir)

    results = []
    for correction in CORRECTIONS:
        target = output_dir / Path(correction.target).name
        corrected = apply_correction(target.read_bytes(), correction)
        target.write_bytes(corrected)
        results.append({
            "id": correction.patch_id,
            "target": correction.target,
            "b0_sha256": correction.b0_sha256,
            "corrected_sha256": correction.corrected_sha256,
            "status": "PASS",
        })

    manifest = source_manifest(output_dir)
    member_count = len(manifest.splitlines())
    source_bytes = sum(path.stat().st_size for path in output_dir.iterdir() if path.is_file())
    manifest_sha = sha256_bytes(manifest)
    if member_count != B1_SOURCE_MEMBER_COUNT:
        raise ValueError(f"B1 member count mismatch: {member_count}")
    if source_bytes != B1_SOURCE_BYTES:
        raise ValueError(f"B1 source byte count mismatch: {source_bytes}")
    if manifest_sha != B1_SOURCE_MANIFEST_SHA256:
        raise ValueError(f"B1 manifest SHA mismatch: {manifest_sha}")

    (output_dir.parent / "B1.5p1-source-manifest.sha256").write_bytes(manifest)
    return {
        "snapshot": "B1.5p1",
        "qualified_reconstruction": True,
        "b0_distribution_sha256": identity["observed"]["sha256"],
        "b0_source_archive_sha256": B0_SOURCE_ARCHIVE_SHA256,
        "corrections": results,
        "source_tree": {
            "member_count": member_count,
            "bytes": source_bytes,
            "manifest_sha256": manifest_sha,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconstruct exact B1.5p1 source from exact B0")
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = reconstruct(args.archive, args.output_dir)
    except Exception as exc:
        print(json.dumps({
            "snapshot": "B1.5p1",
            "qualified_reconstruction": False,
            "failure": str(exc),
        }, indent=2))
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

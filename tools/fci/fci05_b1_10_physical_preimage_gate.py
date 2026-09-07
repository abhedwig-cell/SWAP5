#!/usr/bin/env python3
"""F-CI05 fail-closed B1.10 physical-preimage gate.

Static mode verifies that the canonical B1.10 snapshot pins the expected source
archive and does not patch the legacy physical seam files used for the first
canonical adapter port. Archive mode additionally verifies an actual outer
SWAP distribution, the nested SWAP.ZIP identity, source count, and byte-exact
seam file identities.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SNAPSHOT = ROOT / "reference/swap-4.3.1/snapshots/B1.10.yml"
NESTED = "SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP"
SOURCE_ARCHIVE_SHA256 = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
B1_10_MANIFEST = "2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1"
EXPECTED_F90 = 63
SEAMS = {
    "swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
    "variables.f90": "327a064ca74f6c4bebc327a38de367824c7fe535baa1a8611879f9a6a479c856",
    "arrays.f90": "fc16661fceb3c806830e83fb790430dceb375bfbe0b9bbacf54ffa5e0db206a0",
    "headcalc.f90": "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5",
    "fluxes.f90": "b28b163520bc2ed873d98d4e0308d7b02a33577ee81b12a7f4bc1bc4cf746550",
    "soilwater.f90": "027cfefc3ba7a010a256db1e43bd6e9c9facc4bf6edb4984578ddf1ef48acac8",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def static_checks() -> dict[str, bool]:
    text = SNAPSHOT.read_text(encoding="utf-8")
    targets = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("target:"):
            targets.append(stripped.split(":", 1)[1].strip().strip('"'))
    target_names = {Path(item).name.lower() for item in targets}
    checks = {
        "snapshot_exists": SNAPSHOT.is_file(),
        "source_archive_pinned": SOURCE_ARCHIVE_SHA256 in text,
        "b1_10_manifest_pinned": B1_10_MANIFEST in text,
        "source_member_count_pinned": "member_count: 63" in text,
    }
    for seam in SEAMS:
        checks[f"seam_unmodified_by_b1_chain:{seam}"] = seam.lower() not in target_names
    return checks


def archive_checks(archive: Path) -> tuple[dict[str, bool], dict[str, object]]:
    checks: dict[str, bool] = {}
    observed: dict[str, object] = {"outer_archive": str(archive)}
    with zipfile.ZipFile(archive) as outer:
        checks["nested_source_archive_present"] = NESTED in outer.namelist()
        if not checks["nested_source_archive_present"]:
            return checks, observed
        nested_bytes = outer.read(NESTED)
    observed["nested_source_archive_sha256"] = sha256(nested_bytes)
    checks["nested_source_archive_identity"] = observed["nested_source_archive_sha256"] == SOURCE_ARCHIVE_SHA256
    with zipfile.ZipFile(io.BytesIO(nested_bytes)) as source_zip:
        f90_count = sum(name.lower().endswith(".f90") for name in source_zip.namelist())
        observed["source_f90_count"] = f90_count
        checks["source_f90_count"] = f90_count == EXPECTED_F90
        seam_hashes = {}
        for name, expected in SEAMS.items():
            member = f"SWAP/{name}"
            exists = member in source_zip.namelist()
            checks[f"seam_present:{name}"] = exists
            if not exists:
                continue
            actual = sha256(source_zip.read(member))
            seam_hashes[name] = actual
            checks[f"seam_identity:{name}"] = actual == expected
        observed["seam_sha256"] = seam_hashes
    return checks, observed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()

    checks = static_checks()
    observed: dict[str, object] = {}
    if args.archive is not None:
        extra, observed = archive_checks(args.archive)
        checks.update(extra)
    failed = sorted(name for name, ok in checks.items() if not ok)
    result = {
        "work_unit": "F-CI05",
        "status": "PASS" if not failed else "FAIL",
        "b1_oracle": "B1.10",
        "source_archive_sha256": SOURCE_ARCHIVE_SHA256,
        "b1_manifest_sha256": B1_10_MANIFEST,
        "checks": checks,
        "observed": observed,
        "failed": failed,
        "claim": "QUALIFIED_PHYSICAL_PREIMAGE_ONLY_NOT_ADAPTER_ADMISSION",
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())

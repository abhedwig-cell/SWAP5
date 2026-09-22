#!/usr/bin/env python3
"""Inventory the frozen NHI LHM 4.1 groundwater validation archive.

This utility is provenance-only. It never executes archive content and does
not run any hydrological model. It records ZIP member identity, size, CRC32,
compression metadata, and a bounded summary of likely groundwater-validation
files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path, PurePosixPath
import zipfile


TEXT_SUFFIXES = {
    ".csv", ".txt", ".json", ".yaml", ".yml", ".xml", ".ini", ".md",
    ".prj", ".cpg", ".qmd", ".dat",
}
GROUNDWATER_TERMS = (
    "grond", "ground", "dino", "peil", "stijg", "freat", "hydro",
    "ghg", "glg", "recess", "valid", "buis", "well", "meet",
)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("archive", type=Path)
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()

    archive = args.archive
    if not zipfile.is_zipfile(archive):
        raise SystemExit(f"not a ZIP archive: {archive}")

    members = []
    suffix_counts: Counter[str] = Counter()
    top_counts: Counter[str] = Counter()
    groundwater_candidates = []

    with zipfile.ZipFile(archive, "r") as zf:
        bad = zf.testzip()
        if bad is not None:
            raise SystemExit(f"ZIP CRC validation failed first at: {bad}")

        for info in zf.infolist():
            name = info.filename
            pp = PurePosixPath(name)
            suffix = pp.suffix.lower()
            top = pp.parts[0] if pp.parts else ""
            suffix_counts[suffix or "<none>"] += 1
            top_counts[top] += 1
            item = {
                "name": name,
                "is_dir": info.is_dir(),
                "uncompressed_size": info.file_size,
                "compressed_size": info.compress_size,
                "crc32_hex": f"{info.CRC:08x}",
                "compression_type": info.compress_type,
            }
            members.append(item)
            low = name.lower()
            if any(term in low for term in GROUNDWATER_TERMS):
                groundwater_candidates.append(item)

    payload = {
        "schema": "swap5.rom-accept.lhm41-validation-archive-inventory.v1",
        "archive": {
            "filename": archive.name,
            "byte_size": archive.stat().st_size,
            "sha256": sha256_file(archive),
            "zip_crc_test": "PASS",
        },
        "member_count": len(members),
        "top_level_counts": dict(sorted(top_counts.items())),
        "suffix_counts": dict(sorted(suffix_counts.items())),
        "groundwater_candidate_count": len(groundwater_candidates),
        "groundwater_candidates": groundwater_candidates,
        "members": members,
    }
    args.out.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(json.dumps({
        "archive": payload["archive"],
        "member_count": payload["member_count"],
        "top_level_counts": payload["top_level_counts"],
        "suffix_counts": payload["suffix_counts"],
        "groundwater_candidate_count": payload["groundwater_candidate_count"],
        "groundwater_candidate_names": [x["name"] for x in groundwater_candidates],
    }, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

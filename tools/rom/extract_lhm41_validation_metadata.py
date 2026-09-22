#!/usr/bin/env python3
"""Extract only LHM 4.1 groundwater validation metadata from the official ZIP.

The extraction is allowlist-based: IPF population tables and the per-class
TOELICHTING EN METADATA.TXT files only. No archive member is executed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import zipfile


CATEGORIES = {"freatisch", "wvp1", "diep"}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def allowed(name: str) -> bool:
    p = PurePosixPath(name)
    if len(p.parts) != 3 or p.parts[0] != "validatiedata" or p.parts[1] not in CATEGORIES:
        return False
    fn = p.parts[2]
    return fn.lower().endswith(".ipf") or fn.upper() == "TOELICHTING EN METADATA.TXT"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", type=Path)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--manifest", type=Path, required=True)
    args = ap.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    records = []
    with zipfile.ZipFile(args.archive, "r") as zf:
        for info in zf.infolist():
            if info.is_dir() or not allowed(info.filename):
                continue
            data = zf.read(info)
            rel = PurePosixPath(info.filename)
            dst = args.out_dir.joinpath(*rel.parts[1:])
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(data)
            records.append({
                "archive_path": info.filename,
                "extracted_path": str(dst),
                "byte_size": len(data),
                "crc32_hex": f"{info.CRC:08x}",
                "sha256": sha256_bytes(data),
            })

    records.sort(key=lambda x: x["archive_path"])
    payload = {
        "schema": "swap5.rom-accept.lhm41-validation-metadata-manifest.v1",
        "extraction_policy": "ONLY_CLASS_ROOT_IPF_AND_TOELICHTING_METADATA",
        "files": records,
        "file_count": len(records),
    }
    args.manifest.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

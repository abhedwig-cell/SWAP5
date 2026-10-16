#!/usr/bin/env python3
"""Verify checked-in SWAP 4.3.1/B1.11 source authority without redownloading it.

This validates the historical meteo donor used by MC-MET01.
It does not claim that the donor archive is a standalone full SWAP4 executable.
"""
import argparse
import base64
import hashlib
import io
from pathlib import Path
import tarfile

ARCHIVE = "integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
MEMBER = "SWAP/MOD_meteo.f90"
EXPECTED_MEMBER_SHA256 = "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f"


def verify(root: Path) -> dict:
    source = root / ARCHIVE
    if not source.is_file():
        raise ValueError(f"repository authority archive missing: {ARCHIVE}")
    try:
        raw = base64.b64decode(source.read_bytes(), validate=False)
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar:
            info = tar.getmember(MEMBER)
            if not info.isfile():
                raise ValueError(f"not a regular file: {MEMBER}")
            f = tar.extractfile(info)
            if f is None:
                raise ValueError(f"cannot read: {MEMBER}")
            digest = hashlib.sha256(f.read()).hexdigest()
    except (OSError, KeyError, ValueError, tarfile.TarError) as exc:
        raise ValueError(f"authority archive validation failure: {exc}") from exc
    if digest != EXPECTED_MEMBER_SHA256:
        raise ValueError(f"historical member drift: expected {EXPECTED_MEMBER_SHA256}, got {digest}")
    return {"authority": ARCHIVE, "member": MEMBER,
            "member_sha256": digest, "archive_sha256": hashlib.sha256(raw).hexdigest(),
            "status": "PASS"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    try:
        result = verify(args.root)
    except ValueError as exc:
        parser.exit(1, f"SWAP431_AUTHORITY_FAIL {exc}\n")
    for key, value in result.items():
        print(f"{key}={value}")

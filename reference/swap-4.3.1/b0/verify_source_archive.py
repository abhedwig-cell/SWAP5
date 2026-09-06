#!/usr/bin/env python3
"""Verify the canonical SWAP 4.3.1 B0 source archive byte-for-byte.

Usage:
    python verify_source_archive.py /path/to/SWAP.ZIP

The verifier checks the archive SHA-256 and every expanded source member against
file-manifest.sha256. It deliberately hashes raw member bytes: no newline or
text-encoding normalization is allowed for B0.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys
import zipfile

ARCHIVE_SHA256 = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
MANIFEST = Path(__file__).with_name("file-manifest.sha256")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest() -> dict[str, tuple[str, int]]:
    expected: dict[str, tuple[str, int]] = {}
    for raw in MANIFEST.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        digest, size, path = line.split(maxsplit=2)
        expected[path] = (digest, int(size))
    return expected


def fail(message: str) -> None:
    raise SystemExit(f"B0 SOURCE VERIFICATION FAILED: {message}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_source_archive.py /path/to/SWAP.ZIP")

    archive = Path(sys.argv[1])
    if not archive.is_file():
        fail(f"archive not found: {archive}")

    archive_bytes = archive.read_bytes()
    actual_archive_sha = sha256(archive_bytes)
    if actual_archive_sha != ARCHIVE_SHA256:
        fail(
            "archive SHA-256 mismatch: "
            f"expected {ARCHIVE_SHA256}, got {actual_archive_sha}"
        )

    expected = load_manifest()

    with zipfile.ZipFile(archive) as zf:
        actual_files = {
            info.filename
            for info in zf.infolist()
            if not info.is_dir()
        }

        expected_files = set(expected)
        missing = sorted(expected_files - actual_files)
        extra = sorted(actual_files - expected_files)
        if missing:
            fail("missing archive members: " + ", ".join(missing))
        if extra:
            fail("unexpected archive members: " + ", ".join(extra))

        for path in sorted(expected):
            expected_sha, expected_size = expected[path]
            data = zf.read(path)
            if len(data) != expected_size:
                fail(
                    f"size mismatch for {path}: expected {expected_size}, "
                    f"got {len(data)}"
                )
            actual_sha = sha256(data)
            if actual_sha != expected_sha:
                fail(
                    f"SHA-256 mismatch for {path}: expected {expected_sha}, "
                    f"got {actual_sha}"
                )

    print(
        f"B0 SOURCE VERIFIED: archive={ARCHIVE_SHA256}; "
        f"members={len(expected)}; all member hashes and sizes match"
    )


if __name__ == "__main__":
    main()

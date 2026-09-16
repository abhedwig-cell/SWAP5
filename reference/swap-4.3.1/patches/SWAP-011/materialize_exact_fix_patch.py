#!/usr/bin/env python3
"""Materialize the exact F-PE19 ordered SWAP-011 patch from transport chunks."""
from __future__ import annotations

import base64
import gzip
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / "artifacts"
PARTS = [ARTIFACTS / f"ordered_patch.gz.b64.part{i:02d}" for i in range(1, 5)]
OUTPUT = ROOT / "fix.patch"
EXPECTED_SHA256 = "1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238"
EXPECTED_BYTES = 37169


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    encoded = b"".join(path.read_bytes().strip() for path in PARTS)
    raw = gzip.decompress(base64.b64decode(encoded, validate=True))
    if len(raw) != EXPECTED_BYTES:
        raise SystemExit(f"byte-count mismatch: expected {EXPECTED_BYTES}, got {len(raw)}")
    observed = sha256(raw)
    if observed != EXPECTED_SHA256:
        raise SystemExit(f"SHA-256 mismatch: expected {EXPECTED_SHA256}, got {observed}")
    OUTPUT.write_bytes(raw)
    reread = OUTPUT.read_bytes()
    if sha256(reread) != EXPECTED_SHA256:
        raise SystemExit("post-write SHA-256 mismatch")
    print(f"SWAP-011 exact fix.patch materialized: {EXPECTED_SHA256} ({EXPECTED_BYTES} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

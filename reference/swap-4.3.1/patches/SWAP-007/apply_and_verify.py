#!/usr/bin/env python3
"""Apply/verify the SWAP-007 oxygenstress correction without text normalization."""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75"
B1_SHA256 = "8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87"
OLD = (
    b"            if (dabs(fi_a) > 0.d0) then\r\n"
    b"                lnew = dabs(l - (fi / fi_a))\r\n"
    b"            end if\r\n"
)
NEW = (
    b"            if (dabs(fi_a) > dmax1(tiny(1.0d0), dabs(fi)/huge(1.0d0))) then\r\n"
    b"               lnew = dabs(l - (fi / fi_a))\r\n"
    b"            else\r\n"
    b"               ! Force a controlled restart instead of risking overflow in fi/fi_a.\r\n"
    b"               lnew = huge(1.0d0)\r\n"
    b"            end if\r\n"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(msg: str) -> None:
    raise SystemExit("SWAP-007 PATCH VERIFICATION FAILED: " + msg)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_oxygenstress.f90 [output.f90]")

    src = Path(sys.argv[1]).read_bytes()
    if sha(src) != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: got {sha(src)}")
    if src.count(OLD) != 1:
        fail(f"expected exactly one target byte sequence, found {src.count(OLD)}")

    patched = src.replace(OLD, NEW, 1)
    actual = sha(patched)
    if actual != B1_SHA256:
        fail(f"patched SHA mismatch: expected {B1_SHA256}, got {actual}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(patched)

    print(f"SWAP-007 VERIFIED: B0={B0_SHA256}; patched={B1_SHA256}")


if __name__ == "__main__":
    main()

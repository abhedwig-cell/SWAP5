#!/usr/bin/env python3
"""Apply and verify SWAP-007 against the canonical byte-exact B0 source.

This file does not replace the historical verifier stored with B1.4/B1.5. It
records the provenance correction identified by VQ-1c and GitHub issue #19.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735"
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


def fail(message: str) -> None:
    raise SystemExit("SWAP-007 CANONICAL VERIFICATION FAILED: " + message)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify_canonical_b0.py B0_oxygenstress.f90 [output.f90]")

    source = Path(sys.argv[1]).read_bytes()
    observed_b0 = sha(source)
    if observed_b0 != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: expected {B0_SHA256}, got {observed_b0}")

    occurrences = source.count(OLD)
    if occurrences != 1:
        fail(f"expected exactly one target byte sequence, found {occurrences}")

    corrected = source.replace(OLD, NEW, 1)
    observed_b1 = sha(corrected)
    if observed_b1 != B1_SHA256:
        fail(f"corrected SHA mismatch: expected {B1_SHA256}, got {observed_b1}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(corrected)

    print(f"SWAP-007 CANONICAL PASS: B0={B0_SHA256}; corrected={B1_SHA256}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply/verify the SWAP-001 correction without text normalization.

Usage:
    python apply_and_verify.py /path/to/B0/SWAP/macropore.f90 [output.f90]

If output is omitted the script only verifies that the deterministic patched
bytes have the expected SHA-256.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b"
B1_SHA256 = "f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f"
OLD = b"      VlMpDm1Cp= VlMpDmCp(1,1:numnod)\r\n"
NEW = (
    b"      VlMpDm1Cp = 0.0d0\r\n"
    b"      VlMpDm1Cp(1:numnod) = VlMpDmCp(1,1:numnod)\r\n"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(msg: str) -> None:
    raise SystemExit("SWAP-001 PATCH VERIFICATION FAILED: " + msg)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_macropore.f90 [output.f90]")

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

    print(f"SWAP-001 VERIFIED: B0={B0_SHA256}; patched={B1_SHA256}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply and verify SWAP-009 against the exact B0 source bytes.

Usage:
    python apply_and_verify.py /path/to/B0/SWAP/WC_K_models_04_11.f90 [output.f90]
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
B1_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
OLD = b"Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
NEW = b"Kvap = Kvap_func (WC, h, Temp) * Conv"
EXPECTED_COUNT = 4


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(msg: str) -> None:
    raise SystemExit("SWAP-009 PATCH VERIFICATION FAILED: " + msg)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_WC_K_models_04_11.f90 [output.f90]")

    src = Path(sys.argv[1]).read_bytes()
    actual_b0 = sha(src)
    if actual_b0 != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: expected {B0_SHA256}, got {actual_b0}")

    count = src.count(OLD)
    if count != EXPECTED_COUNT:
        fail(f"expected {EXPECTED_COUNT} exact target byte sequences, found {count}")

    patched = src.replace(OLD, NEW)
    actual_b1 = sha(patched)
    if actual_b1 != B1_SHA256:
        fail(f"patched SHA mismatch: expected {B1_SHA256}, got {actual_b1}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(patched)

    print(f"SWAP-009 VERIFIED: B0={B0_SHA256}; corrected={B1_SHA256}; replacements={count}")


if __name__ == "__main__":
    main()

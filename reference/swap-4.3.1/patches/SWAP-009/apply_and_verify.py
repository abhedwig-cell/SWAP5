#!/usr/bin/env python3
"""Apply and verify SWAP-009 against the canonical byte-exact B0 target."""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
CORRECTED_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
OLD = b"Kvap = Kvap_func (WC, dabs(h), Temp) * Conv"
NEW = b"Kvap = Kvap_func (WC, h, Temp) * Conv"
EXPECTED_OCCURRENCES = 4


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise SystemExit("SWAP-009 VERIFICATION FAILED: " + message)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_WC_K_models_04_11.f90 [output.f90]")

    source = Path(sys.argv[1]).read_bytes()
    observed_b0 = sha(source)
    if observed_b0 != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: expected {B0_SHA256}, got {observed_b0}")

    occurrences = source.count(OLD)
    if occurrences != EXPECTED_OCCURRENCES:
        fail(f"expected {EXPECTED_OCCURRENCES} target occurrences, found {occurrences}")

    corrected = source.replace(OLD, NEW)
    observed_corrected = sha(corrected)
    if observed_corrected != CORRECTED_SHA256:
        fail(
            "corrected target SHA mismatch: "
            f"expected {CORRECTED_SHA256}, got {observed_corrected}"
        )

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(corrected)

    print(
        "SWAP-009 PASS: "
        f"B0={B0_SHA256}; corrected={CORRECTED_SHA256}; occurrences={occurrences}"
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply SWAP-010 to the exact ordered B1.6 target and verify B1.7 bytes."""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

CANONICAL_B0_SHA256 = "1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd"
ORDERED_B1_6_SHA256 = "f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7"
CORRECTED_B1_7_SHA256 = "7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e"

OLD = (
    b"   Gam01 = Gamma1 (dabs(h0))\r\n"
    b"   Gam02 = Gamma2 (dabs(h0))\r\n"
    b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h)/(1.0d0-Gam01) + Omega2*C2(h)/(1.0d0-Gam02))\r\n"
)
NEW = (
    b"   Gam01 = Omega1*Gamma1 (dabs(h0))\r\n"
    b"   Gam02 = Omega2*Gamma2 (dabs(h0))\r\n"
    b"   C_MvG_2_s = (WCs-WCr)*(Omega1*C1(h) + Omega2*C2(h))/(1.0d0-Gam01-Gam02)\r\n"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise SystemExit("SWAP-010 VERIFICATION FAILED: " + message)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B1_6_WC_K_models_04_11.f90 [output.f90]")

    source = Path(sys.argv[1]).read_bytes()
    observed = sha(source)
    if observed == CANONICAL_B0_SHA256:
        fail("canonical B0 was supplied directly; SWAP-009 must be applied first because SWAP-010 shares this target file")
    if observed != ORDERED_B1_6_SHA256:
        fail(f"ordered B1.6 preimage SHA mismatch: expected {ORDERED_B1_6_SHA256}, got {observed}")

    count = source.count(OLD)
    if count != 1:
        fail(f"expected one model-7 capacity target sequence, found {count}")

    corrected = source.replace(OLD, NEW, 1)
    observed_corrected = sha(corrected)
    if observed_corrected != CORRECTED_B1_7_SHA256:
        fail(f"corrected target SHA mismatch: expected {CORRECTED_B1_7_SHA256}, got {observed_corrected}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(corrected)

    print(
        "SWAP-010 PASS: "
        f"ordered_preimage={ORDERED_B1_6_SHA256}; corrected={CORRECTED_B1_7_SHA256}; occurrences={count}"
    )


if __name__ == "__main__":
    main()

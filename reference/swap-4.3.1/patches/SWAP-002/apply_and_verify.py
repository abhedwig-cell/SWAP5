#!/usr/bin/env python3
"""Byte-safe verifier/applicator for the isolated SWAP-002 tillage start fix."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

B0_SHA256 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
PATCH_SHA256 = "e6f501f510f0de3599cfb2ef208744862e7ef9173c9cf1bf434f2e3ea450613b"
CORRECTED_SHA256 = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"

OLD = (
    b"   iTill = 1\r\n"
    b"   if (t1900 <= Date_tillage(1)) iTill = 1\r\n"
    b"   do i = 2, Ntill\r\n"
    b"      if (Date_tillage(i) < Date_tillage(i-1)) call swap_error ('set_itill', 'Dates in tabulated tillage events must be sorted')\r\n"
    b"      if (t1900 >= Date_tillage(i-1) .AND. t1900 < Date_tillage(i-1)) iTill = i-1\r\n"
    b"   end do\r\n"
)

NEW = (
    b"   ! iTill points to the next tillage event that still has to be executed.\r\n"
    b"   ! If the simulation starts between events, initialise parameters from the\r\n"
    b"   ! most recent preceding event so consolidation can continue.\r\n"
    b"   iTill = Ntill + 1\r\n"
    b"   do i = 2, Ntill\r\n"
    b"      if (Date_tillage(i) < Date_tillage(i-1)) call swap_error ('set_itill', 'Dates in tabulated tillage events must be sorted')\r\n"
    b"   end do\r\n"
    b"   do i = 1, Ntill\r\n"
    b"      if (t1900 <= Date_tillage(i)) then\r\n"
    b"         iTill = i\r\n"
    b"         exit\r\n"
    b"      end if\r\n"
    b"   end do\r\n"
    b"   if (iTill > 1) call Change_Tillage_Info(iTill-1)\r\n"
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(data: bytes) -> bytes:
    if digest(data) != B0_SHA256:
        raise ValueError("SWAP-002 canonical/ordered preimage SHA mismatch")
    if data.count(OLD) != 1:
        raise ValueError(f"SWAP-002 expected one set_iTill target, found {data.count(OLD)}")
    corrected = data.replace(OLD, NEW, 1)
    if digest(corrected) != CORRECTED_SHA256:
        raise ValueError("SWAP-002 corrected target SHA mismatch")
    return corrected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    patch = Path(__file__).with_name("fix.patch")
    if digest(patch.read_bytes()) != PATCH_SHA256:
        raise SystemExit("stored SWAP-002 fix.patch identity mismatch")
    corrected = apply(args.input.read_bytes())
    if args.output:
        args.output.write_bytes(corrected)
    print(f"SWAP-002 PASS preimage={B0_SHA256} corrected={CORRECTED_SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

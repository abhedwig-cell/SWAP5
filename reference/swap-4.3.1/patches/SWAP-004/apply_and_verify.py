#!/usr/bin/env python3
"""Byte-safe applicator for isolated SWAP-004 after the B1.10 ordered preimage."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

CANONICAL_B0_SHA256 = "731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486"
ORDERED_B1_10_SHA256 = "eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3"
PATCH_SHA256 = "0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818"
CORRECTED_SHA256 = "41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede"

OLD = (
    b"         if (allocated(iTT1)) deallocate(iTT1); allocate(iTT1(Ntill)); iTT1 = 0\r\n"
    b"         if (allocated(iTT2)) deallocate(iTT2); allocate(iTT2(Ntill)); iTT2 = 0\r\n"
    b"         do j = 1, Ntill\r\n"
    b"            do i = 1, Ntypes\r\n"
    b"               if (iTT1(j) == 0 .AND. iType_Tillage(i) == j) iTT1(j) = i\r\n"
    b"               if (iTT1(j) >  0 .AND. iType_Tillage(i) == j) iTT2(j) = i\r\n"
    b"            end do\r\n"
    b"! check if NumLay is exceeded; and if iTT2-iTT1+1 corresponds with number of layer within Z_tillage\r\n"
    b"         end do\r\n"
)

NEW = (
    b"         if (allocated(iTT1)) deallocate(iTT1); allocate(iTT1(tmax)); iTT1 = 0\r\n"
    b"         if (allocated(iTT2)) deallocate(iTT2); allocate(iTT2(tmax)); iTT2 = 0\r\n"
    b"         do j = 1, tmax\r\n"
    b"            do i = 1, Ntypes\r\n"
    b"               if (iTT1(j) == 0 .AND. iType_Tillage(i) == j) iTT1(j) = i\r\n"
    b"               if (iTT1(j) >  0 .AND. iType_Tillage(i) == j) iTT2(j) = i\r\n"
    b"            end do\r\n"
    b"         end do\r\n"
    b"         do i = 1, Ntill\r\n"
    b"            j = Type_Tillage(i)\r\n"
    b"            if (j < 1 .OR. j > tmax) then\r\n"
    b"               call swap_error ('read_tillage', 'TYPE_TILLAGE is outside the range defined by ITYPE_TILLAGE')\r\n"
    b"            else if (iTT1(j) == 0 .OR. iTT2(j) == 0) then\r\n"
    b"               call swap_error ('read_tillage', 'Every TYPE_TILLAGE must have corresponding ITYPE_TILLAGE entries')\r\n"
    b"            end if\r\n"
    b"         end do\r\n"
    b"! check if NumLay is exceeded; and if iTT2-iTT1+1 corresponds with number of layer within Z_tillage\r\n"
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def apply(data: bytes) -> bytes:
    if digest(data) != ORDERED_B1_10_SHA256:
        raise ValueError("SWAP-004 ordered B1.10 preimage SHA mismatch")
    if data.count(OLD) != 1:
        raise ValueError(f"SWAP-004 expected one lookup block, found {data.count(OLD)}")
    corrected = data.replace(OLD, NEW, 1)
    if digest(corrected) != CORRECTED_SHA256:
        raise ValueError("SWAP-004 corrected target SHA mismatch")
    return corrected


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    patch = Path(__file__).with_name("fix.patch")
    if digest(patch.read_bytes()) != PATCH_SHA256:
        raise SystemExit("stored SWAP-004 fix.patch identity mismatch")
    corrected = apply(args.input.read_bytes())
    if args.output:
        args.output.write_bytes(corrected)
    print(f"SWAP-004 PASS ordered_preimage={ORDERED_B1_10_SHA256} corrected={CORRECTED_SHA256}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

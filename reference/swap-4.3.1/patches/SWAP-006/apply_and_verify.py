#!/usr/bin/env python3
"""Apply/verify SWAP-006 without text normalization."""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822"
B1_SHA256 = "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f"
OLD = (
    b"         i = 1\r\n"
    b"         do while (tend - cropstart(i) > 0.d0)\r\n"
    b"            if (cropstart(i) < 1.d0) exit\r\n"
    b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
    b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
    b"            end if\r\n"
    b"            i = i + 1\r\n"
    b"         end do\r\n"
)
NEW = (
    b"         do i = 1, ifnd\r\n"
    b"            if (tend - cropstart(i) <= 0.0d0) exit\r\n"
    b"            if (cropstart(i) < 1.0d0) exit\r\n"
    b"            if (tend + 0.1d0 > cropstart(i) .AND. tstart - 0.1d0 < cropend(i)) then\r\n"
    b"               if (croptype(i) == 2) fl_loadmeteodata = .TRUE.\r\n"
    b"            end if\r\n"
    b"         end do\r\n"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_MOD_meteo.f90 [output.f90]")

    src = Path(sys.argv[1]).read_bytes()
    if sha(src) != B0_SHA256:
        raise SystemExit(f"SWAP-006 FAILED: B0 preimage SHA mismatch: {sha(src)}")
    if src.count(OLD) != 1:
        raise SystemExit(f"SWAP-006 FAILED: expected one target sequence, found {src.count(OLD)}")

    patched = src.replace(OLD, NEW, 1)
    if sha(patched) != B1_SHA256:
        raise SystemExit(f"SWAP-006 FAILED: patched SHA mismatch: {sha(patched)}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(patched)

    print(f"SWAP-006 VERIFIED: B0={B0_SHA256}; patched={B1_SHA256}")


if __name__ == "__main__":
    main()

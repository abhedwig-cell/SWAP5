#!/usr/bin/env python3
"""Apply/verify SWAP-005 to the exact B0 MOD_cropdevelopment.f90.

Usage:
    python apply_and_verify.py /path/to/B0/SWAP/MOD_cropdevelopment.f90 [output.f90]

The script first requires the exact B0 SHA-256. It then performs one textual
replacement while preserving the source file's existing newline convention.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import sys

B0_SHA256 = "c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf"

OLD_LINES = [
    "            if ((cropstart(i+1) - cropend(i)) < 0.5d0 .AND. i < ifnd) then",
    "               message = 'The begin date of crop '//trim(cropfil(i))//' should be larger than the end date of the former crop!'",
    "               call swap_error ('croprotation', message)",
]
NEW_LINES = [
    "            if (i < ifnd) then",
    "               if ((cropstart(i+1) - cropend(i)) < 0.5d0) then",
    "                  message = 'The begin date of crop '//trim(cropfil(i))//' should be larger than the end date of the former crop!'",
    "                  call swap_error ('croprotation', message)",
    "               end if",
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(msg: str) -> None:
    raise SystemExit("SWAP-005 PATCH VERIFICATION FAILED: " + msg)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_MOD_cropdevelopment.f90 [output.f90]")

    src = Path(sys.argv[1]).read_bytes()
    actual_b0 = sha(src)
    if actual_b0 != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: got {actual_b0}")

    newline = b"\r\n" if b"\r\n" in src else b"\n"
    old = newline.join(line.encode("ascii") for line in OLD_LINES) + newline
    new = newline.join(line.encode("ascii") for line in NEW_LINES) + newline

    count = src.count(old)
    if count != 1:
        fail(f"expected exactly one target byte sequence, found {count}")

    patched = src.replace(old, new, 1)
    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(patched)

    print(f"SWAP-005 VERIFIED: B0={B0_SHA256}; patched_sha256={sha(patched)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply and verify SWAP-013 against the exact B1.7/readswap preimage."""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys

CANONICAL_B0_SHA256 = "3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2"
ORDERED_B1_7_SHA256 = CANONICAL_B0_SHA256
CORRECTED_SHA256 = "e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c"

OLD = (
    b"                  call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)\r\n"
    b"                  call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)\r\n"
)
NEW = (
    b"                  call rdfdor ('ha',-1.0d5,0.0d0,ha,maho,numlay);  ha(1:numlay) = -ha(1:numlay)\r\n"
    b"                  do lay = 1, numlay\r\n"
    b"                     if (iHWCKmodel(lay) >= 8 .AND. iHWCKmodel(lay) <= 11) then\r\n"
    b"                        if (ha(lay) <= 0.0d0 .OR. ha(lay) >= h0(lay)) then\r\n"
    b"                           call swap_error ('readswap', 'PDI requires 0 < abs(HA) < abs(H0) for every PDI soil layer')\r\n"
    b"                        end if\r\n"
    b"                     end if\r\n"
    b"                  end do\r\n"
    b"                  call rdfdor ('apar',-5.0d0,0.0d0,apar,maho,numlay)\r\n"
)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def fail(message: str) -> None:
    raise SystemExit("SWAP-013 VERIFICATION FAILED: " + message)


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B1.7_readswap.f90 [output.f90]")

    source = Path(sys.argv[1]).read_bytes()
    observed = sha(source)
    if observed != ORDERED_B1_7_SHA256:
        fail(f"ordered B1.7 preimage SHA mismatch: expected {ORDERED_B1_7_SHA256}, got {observed}")

    count = source.count(OLD)
    if count != 1:
        fail(f"expected exactly one post-HA target block, found {count}")

    corrected = source.replace(OLD, NEW, 1)
    observed_corrected = sha(corrected)
    if observed_corrected != CORRECTED_SHA256:
        fail(f"corrected target SHA mismatch: expected {CORRECTED_SHA256}, got {observed_corrected}")

    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(corrected)

    print(
        "SWAP-013 PASS: "
        f"preimage={ORDERED_B1_7_SHA256}; corrected={CORRECTED_SHA256}; occurrences={count}"
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Apply/verify SWAP-008 without text normalization."""

from __future__ import annotations
import hashlib
from pathlib import Path
import sys

B0_SHA256 = "6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651"
B1_SHA256 = "87b9b1cd6de65e6ee1d7c1775cddff6093c12d4d0744ffcde70844f5f28c6e7a"
OLD1 = b"      real(8), intent(out) :: a(np,mp),al(np,mpl)\r\n"
NEW1 = b"      real(8), intent(inout) :: a(np,mp)\r\n      real(8), intent(out)   :: al(np,mpl)\r\n"
OLD2 = b"      real(8), intent(out) :: b(n)\r\n"
NEW2 = b"      real(8), intent(inout) :: b(n)\r\n"

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def fail(msg: str) -> None:
    raise SystemExit("SWAP-008 PATCH VERIFICATION FAILED: " + msg)

def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_and_verify.py B0_tridag.f90 [output.f90]")
    src = Path(sys.argv[1]).read_bytes()
    if sha(src) != B0_SHA256:
        fail(f"B0 preimage SHA mismatch: got {sha(src)}")
    if src.count(OLD1) != 1 or src.count(OLD2) != 1:
        fail(f"expected one occurrence of each target, got {src.count(OLD1)} and {src.count(OLD2)}")
    patched = src.replace(OLD1, NEW1, 1).replace(OLD2, NEW2, 1)
    actual = sha(patched)
    if actual != B1_SHA256:
        fail(f"patched SHA mismatch: expected {B1_SHA256}, got {actual}")
    if len(sys.argv) == 3:
        Path(sys.argv[2]).write_bytes(patched)
    print(f"SWAP-008 VERIFIED: B0={B0_SHA256}; patched={B1_SHA256}")

if __name__ == "__main__":
    main()

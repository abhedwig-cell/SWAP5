#!/usr/bin/env python3
import base64, io, tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
bundle=root/"integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())),mode="r:gz") as a:
    raw=a.extractfile("SWAP/solute.f90").read()
lines=raw.decode("latin1").splitlines()
for lo,hi in ((90,125),(600,665),(440,515),(530,790)):
    print(f"--- solute.f90 {lo}..{hi} ---")
    for i in range(lo,hi+1):
        print(f"{i:04d}: {lines[i-1]}")

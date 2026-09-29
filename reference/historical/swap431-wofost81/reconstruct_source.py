#!/usr/bin/env python3
from pathlib import Path
import base64, hashlib, sys

ROOT = Path(__file__).resolve().parent
parts = sorted((ROOT / "encoded").glob("SWAP_WOFOST81_SOURCE.zip.b64.part*"))
if not parts:
    raise SystemExit("no encoded source parts found")

encoded = "".join(p.read_text(encoding="ascii").strip() for p in parts)
raw = base64.b64decode(encoded, validate=True)
expected = "965a4908d028ff6a509ddc3d4efcf2e6bce736a7f59a6fc052c8fa2fdd66459b"
actual = hashlib.sha256(raw).hexdigest()
if actual != expected:
    raise SystemExit(f"SHA-256 mismatch: {actual} != {expected}")

out = ROOT / "SWAP_WOFOST81_SOURCE.zip"
out.write_bytes(raw)
print(f"wrote {out} ({len(raw)} bytes)")
print(f"SHA-256 {actual}")
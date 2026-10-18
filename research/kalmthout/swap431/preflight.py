#!/usr/bin/env python3
"""KALM-S431-01: byte-exact B0 verification and Kalmthout input preflight.

No substitution, downloading, modification of original Fortran or synthetic forcing.
Usage: python3 preflight.py --distribution /path/to/SWAP_4.3.1.zip \
    --manifest /path/to/file-manifest.sha256 --case-dir /path/to/case
Exit nonzero on a failed B0 check or missing case inputs.
"""
import argparse
import hashlib
import json
import pathlib
import re
import sys
import zipfile

B0_ZIP = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"
B0_SRC = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"

def digest(data):
    return hashlib.sha256(data).hexdigest()

def verify(distribution, manifest):
    raw = distribution.read_bytes()
    if digest(raw) != B0_ZIP:
        raise ValueError("Distribution SHA256 differs from immutable B0")
    with zipfile.ZipFile(distribution) as z:
        sources = [n for n in z.namelist() if n.replace("\\", "/").lower().endswith("tools/swap/source/swap.zip")]
        if len(sources) != 1:
            raise ValueError("Expected exactly one nested tools/SWAP/source/SWAP.ZIP")
        src = z.read(sources[0])
    if digest(src) != B0_SRC:
        raise ValueError("Nested source SHA256 differs from immutable B0")
    checks = []
    for line in manifest.read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        m = re.fullmatch(r"([0-9a-f]{64})\s+(\d+)\s+(SWAP/\S+)", line)
        if not m:
            raise ValueError("Invalid manifest record: " + line)
        checks.append((m.group(1), int(m.group(2)), m.group(3)))
    if len(checks) != 63:
        raise ValueError(f"Expected 63 source members; got {len(checks)}")
    with zipfile.ZipFile(__import__("io").BytesIO(src)) as archive:
        records = {n.replace("\\", "/").lstrip("./"): n for n in archive.namelist() if not n.endswith("/")}
        for hash_expected, size, member in checks:
            matches = [original for normalized, original in records.items() if normalized == member or normalized.endswith("/" + member)]
            if len(matches) != 1:
                raise ValueError(f"Missing or ambiguous source member: {member}")
            data = archive.read(matches[0])
            if len(data) != size or digest(data) != hash_expected:
                raise ValueError(f"Source member checksum mismatch: {member}")
    return {"distribution_sha256": digest(raw), "source_sha256": digest(src), "source_members": len(checks)}

def case_inventory(case_dir):
    if not case_dir:
        return {"case_present": False, "case_status": "NOT_SUPPLIED"}
    if not case_dir.is_dir():
        raise ValueError("Case directory missing: " + str(case_dir))
    files = sorted(p for p in case_dir.rglob("*") if p.is_file())
    if not files:
        raise ValueError("Case directory is empty")
    return {"case_present": True, "case_status": "INVENTORY_ONLY_NOT_RUN", "files": [
        {"path": str(p.relative_to(case_dir)), "bytes": p.stat().st_size, "sha256": digest(p.read_bytes())}
        for p in files
    ]}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--distribution", required=True, type=pathlib.Path)
    ap.add_argument("--manifest", required=True, type=pathlib.Path)
    ap.add_argument("--case-dir", type=pathlib.Path)
    ap.add_argument("--report", type=pathlib.Path)
    a = ap.parse_args()
    try:
        result = {"model": "SWAP4.3.1-B0", "verification": verify(a.distribution, a.manifest),
                  "inputs": case_inventory(a.case_dir), "compiled": False, "executed": False}
        output = json.dumps(result, indent=2)
        if a.report:
            a.report.write_text(output + "\n")
        print(output)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print("PREFLIGHT FAILED: " + str(exc), file=sys.stderr)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())

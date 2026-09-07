#!/usr/bin/env python3
"""Apply the F-CI11 interval + trial-mass port to an exact F-CI06 source tree.

This is a fail-closed source materializer. It does not transform physics. The
input must already be the exact F-CI06 controlled B1.10 postimage; four legacy
files are then replaced by complete F-CI11 postimages. Repository LF text is
normalized to legacy CRLF when written so byte identities remain deterministic.
"""
from __future__ import annotations
import argparse, hashlib, json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / "src" / "legacy" / "b1_10_fci11_port"
PREIMAGE_SHA256 = {
    "integral.f90": "bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174",
    "timecontrol.f90": "6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8",
    "swap.f90": "484b0b2d8aabead8efdbcfe01948b5fcc6b2a8be81980eec8b6214cff2c4a7e3",
    "swap_main.f90": "9922e06c085030f36527eefc3be0bbaa43e4c0cd7df1973cdb6e0a5fc214b043"
}
POSTIMAGE_SHA256 = {
    "integral.f90": "ba5edbde07a478ca4ea5454d9dcc7243f0f06d3f3de59ddc51acfcc2949ac36e",
    "timecontrol.f90": "7f1a34348d758db2c095491bcb55df756ae78ab2b7269e313a2d9b90e600f619",
    "swap.f90": "ec5d44d871c8e5a65e76ead8c698fcc27cef643c9c0f806ab0a9bfd7a938a7a0",
    "swap_main.f90": "100aa651a2c1b13094cc56781404601b2c7efdf3934aa6d280b719874095c76a"
}
PARTS = {
    "integral.f90": tuple(PORT / f"integral_part0{i}.inc" for i in range(1,7)),
    "timecontrol.f90": tuple(PORT / f"timecontrol_part0{i}.inc" for i in range(1,7)),
    "swap.f90": tuple(PORT / f"swap_part0{i}.inc" for i in range(1,9)),
    "swap_main.f90": tuple(PORT / f"swap_main_part0{i}.inc" for i in range(1,5))
}

def sha256(data: bytes) -> str: return hashlib.sha256(data).hexdigest()
def normalized_lf(data: bytes) -> bytes: return data.replace(b"\r\n",b"\n").replace(b"\r",b"\n")
def legacy_crlf(data: bytes) -> bytes: return normalized_lf(data).replace(b"\n",b"\r\n")
def postimage(name: str) -> bytes:
    return legacy_crlf(b"".join(p.read_bytes() for p in PARTS[name]))

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument('--source',required=True,type=Path); ap.add_argument('--output',required=True,type=Path); a=ap.parse_args()
    checks={}; observed_pre={}; observed_post={}
    for name,expected in PREIMAGE_SHA256.items():
        p=a.source/name; obs=sha256(p.read_bytes()) if p.is_file() else 'MISSING'; observed_pre[name]=obs; checks[f'exact_fci06_preimage:{name}']=obs==expected
    if not all(checks.values()):
        print(json.dumps({'status':'FAIL_PREIMAGE','checks':checks,'observed_pre':observed_pre},indent=2,sort_keys=True)); return 2
    if a.output.exists(): shutil.rmtree(a.output)
    shutil.copytree(a.source,a.output)
    for name,expected in POSTIMAGE_SHA256.items():
        data=postimage(name); obs=sha256(data); observed_post[name]=obs; checks[f'exact_fci11_postimage:{name}']=obs==expected
        if obs != expected:
            print(json.dumps({'status':'FAIL_POSTIMAGE','checks':checks,'observed_post':observed_post},indent=2,sort_keys=True)); return 2
        (a.output/name).write_bytes(data)
    print(json.dumps({'work_unit':'F-CI11','status':'PASS','source_contract':'EXACT_FCI06_POSTIMAGE_TO_FCI11_INTERVAL_MASS_POSTIMAGE','preimage_sha256':observed_pre,'postimage_sha256':observed_post,'checks':checks},indent=2,sort_keys=True))
    return 0
if __name__=='__main__': raise SystemExit(main())

#!/usr/bin/env python3
"""Apply the materialized F-CI06 source port to an exact B1.10 source tree.

This is a source materialization tool, not a physics transformer.  It fails
closed unless the four edited legacy files have their exact B1.10 preimage
identity.  Repository postimages are normalized back to legacy CRLF before
writing so the resulting byte identities are deterministic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PORT = ROOT / "src" / "legacy" / "b1_10_port"

PREIMAGE_SHA256 = {
    "headcalc.f90": "db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5",
    "soilwater.f90": "027cfefc3ba7a010a256db1e43bd6e9c9facc4bf6edb4984578ddf1ef48acac8",
    "swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
    "swap_main.f90": "6cb51432fb86299438e0a244939a045673574dd605f2b1125c79ca977f935be5",
}

POSTIMAGE_SHA256 = {
    "headcalc.f90": "aa28f711503230e44cdfda23a3c5ae595ad8181d9a3c232df41b0f0172b98f2f",
    "soilwater.f90": "e776b9bef89937483753ba9df21dede01abe01f7d699e74315446314d8e8a1fe",
    "swap.f90": "df8828845cb6a1f1bc48bddb02b2131542108897243fcd73d2d71d75b4ee839f",
    "swap_main.f90": "f032b83b8b7b9ca6835705819a665c9a909b56d1b5c0e0d5c74bcc34f704f9e9",
}

SWAP_PARTS = tuple(PORT / f"swap_part0{i}.inc" for i in range(1, 5))


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized_lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def legacy_crlf(data: bytes) -> bytes:
    return normalized_lf(data).replace(b"\n", b"\r\n")


def materialized_postimage(name: str) -> bytes:
    if name == "swap.f90":
        data = b"".join(part.read_bytes() for part in SWAP_PARTS)
    else:
        data = (PORT / name).read_bytes()
    return legacy_crlf(data)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True, type=Path, help="exact reconstructed B1.10 source root")
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()

    checks: dict[str, bool] = {}
    observed_pre: dict[str, str] = {}
    observed_post: dict[str, str] = {}

    for name, expected in PREIMAGE_SHA256.items():
        path = args.source / name
        observed = sha256(path.read_bytes()) if path.is_file() else "MISSING"
        observed_pre[name] = observed
        checks[f"exact_b1_10_preimage:{name}"] = observed == expected

    if not all(checks.values()):
        print(json.dumps({"status": "FAIL_PREIMAGE", "checks": checks, "observed": observed_pre}, indent=2, sort_keys=True))
        return 2

    if args.output.exists():
        shutil.rmtree(args.output)
    shutil.copytree(args.source, args.output)

    for name, expected in POSTIMAGE_SHA256.items():
        data = materialized_postimage(name)
        observed = sha256(data)
        observed_post[name] = observed
        checks[f"exact_fci06_postimage:{name}"] = observed == expected
        if observed != expected:
            print(json.dumps({"status": "FAIL_POSTIMAGE", "checks": checks, "observed_post": observed_post}, indent=2, sort_keys=True))
            return 2
        (args.output / name).write_bytes(data)

    result = {
        "work_unit": "F-CI06",
        "status": "PASS",
        "source_contract": "EXACT_B1_10_PREIMAGE_TO_MATERIALIZED_POSTIMAGE",
        "preimage_sha256": observed_pre,
        "postimage_sha256": observed_post,
        "checks": checks,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

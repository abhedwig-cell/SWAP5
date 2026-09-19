#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re

EXPECTED_DISTRIBUTION_SHA256 = "2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360"


def replace_active_scalar(text: str, key: str, value: str) -> tuple[str, str]:
    pattern = re.compile(rf"(?im)^(\s*{re.escape(key)}\s*=\s*)([^!\r\n]+)(.*)$")
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one active {key}, found {len(matches)}")
    old = matches[0].group(2).strip()
    text = pattern.sub(lambda m: m.group(1) + value + m.group(3), text, count=1)
    return text, old


def uncomment_scalar(text: str, key: str, value: str) -> tuple[str, str]:
    active = re.findall(rf"(?im)^\s*{re.escape(key)}\s*=", text)
    if active:
        return replace_active_scalar(text, key, value)
    pattern = re.compile(rf"(?im)^\s*\*\s*({re.escape(key)}\s*=\s*)([^!\r\n]+)(.*)$")
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one commented {key}, found {len(matches)}")
    old = matches[0].group(2).strip()
    text = pattern.sub(lambda m: "  " + m.group(1) + value + m.group(3), text, count=1)
    return text, old


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--manifest", required=True, type=pathlib.Path)
    parser.add_argument("--distribution-sha256", default=EXPECTED_DISTRIBUTION_SHA256)
    args = parser.parse_args()

    if args.distribution_sha256 != EXPECTED_DISTRIBUTION_SHA256:
        raise SystemExit("wrong SWAP 4.3.1 distribution authority")

    original = args.input.read_text()
    modified = original
    changes = {}

    modified, old = replace_active_scalar(modified, "SWMONTH", "0")
    changes["SWMONTH"] = {"from": old, "to": "0"}

    modified, old = uncomment_scalar(modified, "PERIOD", "1")
    changes["PERIOD"] = {"from": old, "to": "1"}

    modified, old = uncomment_scalar(modified, "SWRES", "0")
    changes["SWRES"] = {"from": old, "to": "0"}

    modified, old = uncomment_scalar(modified, "SWODAT", "0")
    changes["SWODAT"] = {"from": old, "to": "0"}

    modified, old = replace_active_scalar(modified, "SWVAP", "1")
    changes["SWVAP"] = {"from": old, "to": "1"}

    # Preserve the already-qualified GNU execution adjustment used by F-APP03/M1-C3:
    # SWCSV=0 bypasses only the optional CSV output layer.
    modified, old = replace_active_scalar(modified, "SWCSV", "0")
    changes["SWCSV"] = {"from": old, "to": "0"}

    forbidden = [
        "TSTART", "TEND", "SWETR", "SWDIVIDE", "SWMETDETAIL", "SWRAIN",
        "SWCROP", "SWINCO", "GWLI", "SWBOTB", "DTMIN", "DTMAX", "MAXIT",
        "SWSOPHY", "SWDRA"
    ]
    for key in forbidden:
        before = re.findall(rf"(?im)^\s*{re.escape(key)}\s*=\s*([^!\r\n]+)", original)
        after = re.findall(rf"(?im)^\s*{re.escape(key)}\s*=\s*([^!\r\n]+)", modified)
        if before != after:
            raise SystemExit(f"forbidden scientific/numerical input changed: {key}")

    args.output.write_text(modified)
    manifest = {
        "schema": "swap5.lare.rs1.hupsel-output-preparation.v1",
        "distribution_sha256_required": EXPECTED_DISTRIBUTION_SHA256,
        "input_swap_swp_sha256": hashlib.sha256(original.encode()).hexdigest(),
        "output_swap_swp_sha256": hashlib.sha256(modified.encode()).hexdigest(),
        "changes": changes,
        "scientific_semantics_changed": False,
        "numerical_semantics_changed": False,
        "forcing_changed": False,
        "process_composition_changed": False,
        "purpose": "Daily profile observation only: SWMONTH=0/PERIOD=1 with VAP retained; SWCSV=0 preserves the already-qualified GNU output-layer adjustment.",
        "post_run_identity_gate": {
            "normalized_result_bal_sha256": "a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7",
            "normalized_result_blc_sha256": "1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c"
        }
    }
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps(manifest, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

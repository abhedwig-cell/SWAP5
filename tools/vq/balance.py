#!/usr/bin/env python3
"""Canonical extraction of legacy SWAP water-balance reports.

The legacy .BAL/.BLC files print values at 0.01 cm precision. They are useful
for B0/B1 regression evidence but are not sufficiently precise to be the final
SWAP5 hard mass-conservation oracle.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

_PERIOD = re.compile(r"Period\s*:\s*(\d{4}-\d{2}-\d{2})\s+until\s+(\d{4}-\d{2}-\d{2})")
_FLOAT = r"[-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?"
_STORAGE = re.compile(rf"^(Final|Initial)\s*:\s*({_FLOAT})\s+cm|^(Change)\s+({_FLOAT})\s+cm", re.M)
_SUM = re.compile(rf"^Sum\s*:\s*({_FLOAT})\s+Sum\s*:\s*({_FLOAT})\s*$", re.M)
_COMPONENT = re.compile(rf"([A-Za-z][A-Za-z +0-9_-]*?)\s*:\s*({_FLOAT})")
_DEVIATION = re.compile(rf"^Balance Deviation\s+({_FLOAT})\s+({_FLOAT})\s+({_FLOAT})\s+({_FLOAT})\s*$", re.M)


def _period_blocks(text: str) -> list[tuple[str, str, str]]:
    matches = list(_PERIOD.finditer(text))
    blocks = []
    for i, match in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        blocks.append((match.group(1), match.group(2), text[match.start():end]))
    return blocks


def parse_bal(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    periods: list[dict[str, Any]] = []
    for start, end, block in _period_blocks(text):
        water_marker = block.find("Water balance components (cm)")
        solute_marker = block.find("Solute balance components")
        water_block = block[water_marker:solute_marker if solute_marker >= 0 else None]
        storage = {}
        for a, av, b, bv in _STORAGE.findall(block):
            key = (a or b).lower()
            storage[key] = float(av or bv)
        sums = _SUM.search(water_block)
        if not sums:
            raise ValueError(f"water-balance sums not found for {start}..{end}")
        input_sum, output_sum = map(float, sums.groups())
        components: dict[str, float] = {}
        for line in water_block.splitlines():
            if line.startswith("Sum"):
                continue
            for name, value in _COMPONENT.findall(line):
                components[" ".join(name.split()).lower()] = float(value)
        change = storage.get("change")
        residual = None if change is None else input_sum - output_sum - change
        periods.append({
            "start": start,
            "end": end,
            "storage_cm": storage,
            "input_sum_cm": input_sum,
            "output_sum_cm": output_sum,
            "rounded_residual_cm": residual,
            "components_cm": components,
        })
    if not periods:
        raise ValueError("no periods found in BAL report")
    return {
        "source": str(path),
        "legacy_report_precision_cm": 0.01,
        "periods": periods,
    }


def parse_blc(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    periods = []
    for start, end, block in _period_blocks(text):
        m = _DEVIATION.search(block)
        if not m:
            raise ValueError(f"balance deviation not found for {start}..{end}")
        values = list(map(float, m.groups()))
        periods.append({
            "start": start,
            "end": end,
            "balance_deviation_cm": {
                "plant": values[0], "snow": values[1], "pond": values[2], "soil": values[3]
            },
        })
    if not periods:
        raise ValueError("no periods found in BLC report")
    return {"source": str(path), "legacy_report_precision_cm": 0.01, "periods": periods}


def canonical_balance(bal_path: Path, blc_path: Path | None = None) -> dict[str, Any]:
    result = {"bal": parse_bal(bal_path)}
    if blc_path is not None:
        result["blc"] = parse_blc(blc_path)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bal", required=True, type=Path)
    parser.add_argument("--blc", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = canonical_balance(args.bal, args.blc)
    payload = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(payload, encoding="utf-8")
    else:
        print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

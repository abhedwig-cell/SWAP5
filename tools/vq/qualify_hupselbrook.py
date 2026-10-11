#!/usr/bin/env python3
"""Qualify the B0 Hupselbrook README smoke case at legacy report precision."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .balance import canonical_balance
except ImportError:
    from balance import canonical_balance

DEFAULT_MANIFEST = Path(__file__).with_name("cases") / "b0-hupselbrook-readme-smoke.json"


def qualify(bal: Path, blc: Path, manifest: Path = DEFAULT_MANIFEST) -> dict:
    spec = json.loads(manifest.read_text())
    observed = canonical_balance(bal, blc)
    expected = spec["published_oracle"]
    target = next(
        period
        for period in observed["bal"]["periods"]
        if [period["start"], period["end"]] == expected["period"]
    )
    checks = {
        "storage_change": target["storage_cm"]["change"] == expected["water_storage_change_cm"],
        "input_sum": target["input_sum_cm"] == expected["input_sum_cm"],
        "output_sum": target["output_sum_cm"] == expected["output_sum_cm"],
    }
    for name, value in expected["components_cm"].items():
        checks[f"component:{name}"] = target["components_cm"].get(name) == value
    for period in observed["blc"]["periods"]:
        checks[f"blc_zero:{period['start']}"] = all(
            abs(value) == 0.0 for value in period["balance_deviation_cm"].values()
        )
    return {
        "case_id": spec["case_id"],
        "qualified_at_legacy_report_precision": all(checks.values()),
        "hard_mass_gate_eligible": False,
        "legacy_report_resolution_cm": spec["legacy_balance_reporting"]["resolution_cm"],
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bal", required=True, type=Path)
    parser.add_argument("--blc", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    result = qualify(args.bal, args.blc, args.manifest)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["qualified_at_legacy_report_precision"] else 2


if __name__ == "__main__":
    raise SystemExit(main())

"""Measure the stock discontinuity in an original Andelst .end restart."""

import argparse
import gzip
import json
import re
import shutil
import subprocess
from pathlib import Path

from run_day_return import ROOT, records, sha


def launch(case, executable, output, settings, extra, days=2):
    shutil.copytree(case, output)
    control = output / "swap.swp"
    text = control.read_text(encoding="cp1252")
    for key, value in settings.items():
        pattern = rf"^([ \t]*{key}[ \t]*=)[^\n!]*"
        text, count = re.subn(pattern, lambda match: f"{match[1]} {value} ", text,
                              flags=re.IGNORECASE | re.MULTILINE)
        if count != 1:
            raise ValueError(f"Expected one {key} setting, found {count}")
    control.write_text(text + "\n" + extra + "\n", encoding="cp1252")
    run = subprocess.run([executable, "./swap.swp"], cwd=output, capture_output=True,
                         text=True, timeout=60)
    (output / "stdout").write_text(run.stdout)
    (output / "stderr").write_text(run.stderr)
    if run.returncode != 100 or not (output / "swap.ok").is_file():
        raise RuntimeError(f"Original run refused {output.name}: {run.returncode}")
    rows = records((output / "result_output.csv").read_text().splitlines())
    stock = [[float(value) for value in line.split()[1:7]]
             for line in run.stdout.splitlines() if line.startswith("HYBRID_STOCK_FLUX ")]
    if len(stock) != days + 1:
        raise RuntimeError(f"Unexpected number of daily stock records: {output.name}")
    return rows, stock


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", required=True, type=Path)
    parser.add_argument("--day-return-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    reference = args.reference_work.resolve()
    build = reference / "build"
    audited_csv = args.day_return_work.resolve() / "swap_csv_output.o"
    output = args.output.resolve()
    output.mkdir()
    executable = output / "swap431_restart_audit"
    objects = [str(audited_csv if path.name == audited_csv.name else path)
               for path in sorted((build / "swap-obj").glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *objects,
                    str(build / "ttutil-obj/libttutil.a")], check=True)
    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    first, first_stock = launch(case, executable, output / "first",
                                {"TEND": "1998-01-02", "SWEND": "1"}, "SWENDTYPE = 2")
    checkpoint = output / "first/result.end"
    resumed, resumed_stock = launch(
        case, executable, output / "resumed",
        {"TSTART": "1998-01-03", "TEND": "1998-01-04", "SWINCO": "3"},
        "SWINITYPE = 2\nSWENDTYPE = 2\nINIFIL = '../first/result.end'",
    )
    frozen = ROOT / "tests/qualification/ppa-wu05-migmac10-canonical-20261006/b0-comparison-output.csv.gz"
    with gzip.open(frozen, "rt") as file:
        expected = records(file.read().splitlines())
    full = reference / "run/3.macroporeflow"
    fresh = records((full / "result_output.csv").read_text().splitlines())
    if not (full / "swap.ok").is_file() or len(fresh) != 483 or fresh != expected:
        raise RuntimeError("The fresh 481-day B0 control must match the archived series")
    if first != expected[:4] or [r.split(",")[0] for r in resumed[2:]] != ["1998-01-03", "1998-01-04"]:
        raise RuntimeError("Incorrect split-run dates or trajectory before the checkpoint")
    result = {
        "scope": "B0_LEGACY_END_RESTART_CONTROL",
        "full_b0_days": len(fresh) - 2,
        "full_b0_series_exact": True,
        "full_b0_executable_sha256": sha(build / "swap_b0_gfortran"),
        "restart_audit_executable_sha256": sha(executable),
        "legacy_checkpoint_sha256": sha(checkpoint),
        "stock_order": ["matrix", "pond", "snow", "canopy", "macro_domain_1", "macro_other_domains"],
        "day2_end_stock_cm": first_stock[-1],
        "resumed_initial_stock_cm": resumed_stock[0],
        "resumed_minus_day2_end_stock_cm": [
            new - old for old, new in zip(first_stock[-1], resumed_stock[0])
        ],
        "series_columns": expected[0].split(","),
        "continuous_day3_4": expected[4:6],
        "resumed_day3_4": resumed[2:],
        "legacy_restart_exact": expected[4:6] == resumed[2:] and first_stock[-1] == resumed_stock[0],
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

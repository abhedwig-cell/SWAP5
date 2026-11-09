"""Replay four original Andelst days with control returned at each day end.

Requires the verified distribution and compiler outputs from b0_source_runner.py.
This checks the donor call boundary. The donor still owns its live process state.
"""

import argparse
import gzip
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/vq"))
from reference_identity import verify_b0_archive


sys.path.insert(0, str(ROOT / "app/hybrid_water"))
from donor_sources import records, render_day_return as render, replace, sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not verify_b0_archive(args.archive)["qualified_identity"]:
        raise ValueError("Expected the immutable B0 distribution")

    output = args.output.resolve()
    output.mkdir()
    reference = args.reference_work.resolve()
    build = reference / "build"
    obj = build / "swap-obj"
    tt = build / "ttutil-obj"
    render(build / "swap-selected", output)
    common = ["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
              "-ffree-line-length-none", "-fallow-argument-mismatch",
              "-I", str(obj), "-I", str(tt)]
    replacements = ["swap.o", "swap_main.o", "swap_csv_output.o"]
    for name in replacements:
        subprocess.run([*common, "-c", str(output / Path(name).with_suffix(".f90"))],
                       cwd=output, check=True)
    executable = output / "andelst_day_return"
    objects = [str(output / path.name if path.name in replacements else path)
               for path in sorted(obj.glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *objects, str(tt / "libttutil.a")], check=True)

    case = output / "case"
    shutil.copytree(reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow", case)
    inputs = {str(path.relative_to(case)): sha(path) for path in sorted(case.rglob("*")) if path.is_file()}
    run = subprocess.run([str(executable), "./swap.swp"], cwd=case, text=True,
                         capture_output=True, timeout=90)
    (output / "stdout").write_text(run.stdout)
    (output / "stderr").write_text(run.stderr)
    if run.returncode != 100 or not (case / "swap.ok").is_file():
        raise RuntimeError(f"Donor window driver failed: {run.returncode}")
    markers = [line.split()[1] for line in run.stdout.splitlines() if line.startswith("HYBRID_DAY_RETURN ")]
    if markers != ["1", "2", "3", "4"]:
        raise RuntimeError(f"Expected four day returns, got {markers}")
    observed = records((case / "result_output.csv").read_text().splitlines())
    frozen = ROOT / "tests/qualification/ppa-wu05-migmac10-canonical-20261006/b0-comparison-output.csv.gz"
    with gzip.open(frozen, "rt") as file:
        expected = records(file.read().splitlines())
    if len(observed) != 6 or observed != expected[:6]:
        raise RuntimeError(f"Four-day output differs from B0: {observed!r}")

    stock = [[float(value) for value in line.split()[1:]]
             for line in run.stdout.splitlines() if line.startswith("HYBRID_STOCK_FLUX ")]
    flux = [[float(value) for value in line.split()[1:]]
            for line in run.stdout.splitlines() if line.startswith("HYBRID_EXTERNAL_FLUX ")]
    if len(stock) != 5 or len(flux) != 5:
        raise RuntimeError(f"Expected initial and four daily inventories: {len(stock)}, {len(flux)}")
    balances = [math.fsum([*flow[:7], *(-q for q in flow[7:]),
                           *levels[6:], *(-q for q in levels[:6])])
                for levels, flow in zip(stock[1:], flux[1:])]
    result = {
        "scope": "DONOR_DAY_RETURN_ONLY",
        "archive_sha256": sha(args.archive),
        "executable_sha256": sha(executable),
        "inputs_sha256": inputs,
        "original_daily_series": observed,
        "frozen_reference_sha256": sha(frozen),
        "day_returns": len(markers),
        "daily_water_residual_cm": balances,
        "daily_water_residual_pass": all(abs(value) <= 1e-6 for value in balances),
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

"""Compare two in-process calls to the original Andelst donor with one call."""

import argparse
import json
from pathlib import Path

from probe_head_transaction import build_worker, run_worker
from probe_macro_checkpoint import compare_daily_ledger
from run_day_return import sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", required=True, type=Path)
    parser.add_argument("--day-return-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    reference, audit, output = (p.resolve() for p in
                                (args.reference_work, args.day_return_work, args.output))
    output.mkdir()
    executable = build_worker(reference, audit, output, handoff=True)
    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    origin = output / "origin"
    run_worker(case, executable, origin)
    day4 = output / "day4/resumed"
    run_worker(case, executable, day4, origin, -50.0)
    names = ("result.end", "macro.bin")
    checkpoint = {name: sha(day4 / name) for name in names}
    fixed = run_worker(case, executable, output / "fixed/resumed", day4, -50.0,
                       start="1998-01-05", end="1998-01-06")
    control = output / "continuous/resumed"
    split = output / "split/resumed"
    runs = [
        run_worker(case, executable, folder, day4, -50.0,
                   start="1998-01-05", end="1998-01-06", handoff=handoff, afternoon_head=-90.0)
        for folder, handoff in ((control, False), (split, True))
    ]

    def audit_lines(folder, prefix):
        return [line for line in (folder / "stdout").read_text().splitlines()
                if line.startswith(prefix)]

    noon = "HYBRID_NOON_BOUNDARY "
    resumed = "HYBRID_DRIVER_RESUME "
    for folder in (control, split):
        if [float(line.split()[1]) for line in audit_lines(folder, noon)] != [35799.5]:
            raise RuntimeError("Both runs must reach the exact same noon boundary")
    if audit_lines(control, resumed) or [float(line.split()[1]) for line in audit_lines(split, resumed)] != [35799.5]:
        raise RuntimeError("Expected exactly one driver re-entry, only in the split run")
    if checkpoint != {name: sha(day4 / name) for name in names}:
        raise RuntimeError("The day-4 input checkpoint changed")
    step_prefix = "HYBRID_ACCEPTED_TRAJECTORY "
    steps = audit_lines(split, step_prefix)
    if not steps or not any(float(step.split()[1]) >= 35799.5 for step in steps):
        raise RuntimeError("The worker must advance both before and after noon")
    comparisons = {
        "first_half_matches_fixed_head": (
            [line for line in steps if float(line.split()[1]) < 35799.5]
            == [line for line in audit_lines(output / "fixed/resumed", step_prefix)
                if float(line.split()[1]) < 35799.5]
        ),
        "lower_afternoon_head_reduces_inward_flux": (
            runs[1]["bottom_inward_cm"][0] < fixed["bottom_inward_cm"][0]
        ),
        "steps_exact": steps == audit_lines(control, step_prefix),
        "daily_records_and_bottom_flux_exact": runs[0] == runs[1],
        "external_fluxes_exact": audit_lines(control, "HYBRID_EXTERNAL_FLUX ")
                                == audit_lines(split, "HYBRID_EXTERNAL_FLUX "),
        "stocks_exact": audit_lines(control, "HYBRID_STOCK_FLUX ")
                        == audit_lines(split, "HYBRID_STOCK_FLUX "),
        "endpoint_files_exact": all(sha(control / name) == sha(split / name) for name in names),
    }
    comparison = output / "ledger"
    comparison.mkdir()
    (comparison / "first").symlink_to(control, target_is_directory=True)
    (comparison / "resumed").symlink_to(split, target_is_directory=True)
    ledger = compare_daily_ledger(comparison)
    comparisons["water_balance_pass"] = all(
        abs(value) <= 1e-6 for value in ledger["resumed_daily_residual_cm"]
    )
    receipt = {
        "scope": "ONE_LIVE_DONOR_WITH_NOON_DRIVER_REENTRY",
        "noon_clock": 35799.5,
        "head_before_noon_cm": -50.0,
        "head_after_noon_cm": -90.0,
        "switched_day5_bottom_inward_cm": runs[1]["bottom_inward_cm"][0],
        "fixed_day5_bottom_inward_cm": fixed["bottom_inward_cm"][0],
        "executable_sha256": sha(executable),
        "day4_checkpoint": checkpoint,
        "steps_before_noon": sum(float(step.split()[1]) < 35799.5 for step in steps),
        "steps_after_noon_through_day6": sum(float(step.split()[1]) >= 35799.5 for step in steps),
        "daily_residual_cm": ledger["resumed_daily_residual_cm"],
        **comparisons,
    }
    (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    if not all(comparisons.values()):
        raise RuntimeError("The driver handoff changed the donor result")


if __name__ == "__main__":
    main()

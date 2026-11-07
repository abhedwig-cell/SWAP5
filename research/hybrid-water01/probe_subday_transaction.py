"""Drive a half-day Andelst trial, discard it and publish an alternative."""

import argparse
import json
import os
from pathlib import Path

from probe_head_transaction import build_worker, run_worker
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
    executable = build_worker(reference, audit, output, subday=True)
    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    origin = output / "origin"
    run_worker(case, executable, origin)
    day4 = output / "day4/resumed"
    run_worker(case, executable, day4, origin, -50.0)
    names = ("result.end", "macro.bin")
    checkpoint = {name: sha(day4 / name) for name in names}
    committed = output / "committed"
    results = {}
    for label, head in (("clean", -50.0), ("discarded", -90.0), ("selected", -50.0)):
        results[label] = run_worker(case, executable, output / label / "resumed",
                                    day4, head, start="1998-01-05", end="1998-01-06", subday=True)
        if committed.exists() or checkpoint != {name: sha(day4 / name) for name in names}:
            raise RuntimeError(f"Trial {label} modified the committed state")
    if results["clean"] != results["selected"]:
        raise RuntimeError("The discarded trial affected the selected trajectory")
    if results["selected"]["bottom_inward_cm"] <= results["discarded"]["bottom_inward_cm"]:
        raise RuntimeError("External Cauchy forcing did not increase inward exchange")
    receipt = {
        "scope": "PROCESS_ISOLATED_ANDELST_HALF_DAY",
        "start_clock": 35799.0,
        "duration_days": 0.5,
        "executable_sha256": sha(executable),
        "origin_day4": checkpoint,
        "trials": results,
        "selected_matches_clean": True,
    }
    candidate = output / "selected/resumed"
    (candidate / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
    os.replace(candidate, committed)
    if results["selected"]["endpoint_files"] != {name: sha(committed / name) for name in names}:
        raise RuntimeError("Selected endpoint changed during publication")
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()

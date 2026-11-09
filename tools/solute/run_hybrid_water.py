#!/usr/bin/env python3
"""Run the explicitly selected, checkpointable SWAP5 hybrid water application."""

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "app/hybrid_water"))
from daily_host import APPLICATION_MODEL, build, checkpoint_identity, run, sha, verify_checkpoint


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True, choices=[APPLICATION_MODEL])
    parser.add_argument("--reference-work", type=Path, required=True, help="Prepared original SWAP 4.3.1 distribution")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--days", type=int, default=481, help="Last requested Andelst day")
    parser.add_argument("--checkpoint-at", type=int, help="Publish a checkpoint after this day is accepted")
    parser.add_argument("--restart", type=Path, help="Previously published checkpoint ZIP")
    parser.add_argument("--restart-day", type=int)
    parser.add_argument("--kernel-opt", choices=["O0", "O2"], default="O2")
    args = parser.parse_args()
    if (args.restart is None) != (args.restart_day is None):
        parser.error("--restart and --restart-day must be supplied together")
    first = args.restart_day if args.restart is not None else 0
    if not 0 <= first < args.days <= 481 or (args.restart is not None and first == 0):
        parser.error("The last day must follow the origin and be within the original 481-day period")
    if args.checkpoint_at is not None and not first < args.checkpoint_at <= args.days:
        parser.error("The checkpoint day must belong to the requested run")

    output = args.output.resolve()
    output.mkdir(parents=True)
    profile = dict(budget_retry=True, shared_pond_transfer=True, refresh_macro_final=True)
    donor, kernel, case, inputs, build_id = build(
        args.reference_work.resolve(), output, **profile, runtime_checkpoint=True, kernel_opt=args.kernel_opt,
    )
    binding = checkpoint_identity(inputs, build_id, **profile)
    origin = None
    receipt = None
    if args.restart is not None:
        origin = output / "verified-origin"
        receipt = verify_checkpoint(args.restart.resolve(), first, binding, origin)
    result = run(donor, kernel, case, output, args.days, checkpoint_day=first, origin=origin,
                 origin_receipt=receipt, runtime=True, publish_day=args.checkpoint_at,
                 checkpoint_binding=binding if args.checkpoint_at is not None else None, model=args.model)
    report = {
        "model": args.model, "kernel_optimization": args.kernel_opt,
        "input_sha256": inputs, "source_sha256": {"SWAP.ZIP": binding["swap_source"], "TTUTIL.ZIP": binding["ttutil_source"]},
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "origin_day": args.restart_day, "requested_days": args.days, **result,
    }
    (output / "RESULT.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(result["first_refusal"] is not None)


if __name__ == "__main__":
    raise SystemExit(main())

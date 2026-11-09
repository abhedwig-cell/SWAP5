"""Research diagnostics and compatibility modes for the hybrid daily host."""

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "app/hybrid_water"))
from daily_host import (
    DONOR_SOURCE_SHA, TTUTIL_SOURCE_SHA, RESTART_WINDOWS, build, checkpoint_identity,
    isolation, prepare_reference, restart, run, sha, verify_checkpoint,
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prepare-archive", type=Path, help="Build and run the unmodified nested-source reference")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--isolation", action="store_true")
    mode.add_argument("--restart", dest="restart_at", action="store_const", const=2)
    mode.add_argument("--restart-at", type=int, choices=RESTART_WINDOWS)
    parser.add_argument("--checkpoint-at", type=int, choices=range(1, 482), metavar="1..481",
                      help="Publish a checkpoint after the selected day is accepted")
    parser.add_argument("--budget-retry", action="store_true")
    parser.add_argument("--shared-pond-transfer", action="store_true")
    parser.add_argument("--refresh-macro-final", action="store_true",
                        help="Recompute macro rates in the final day-458 window")
    parser.add_argument("--origin", type=Path, help="Start from a raw donor directory or a strict accepted ZIP")
    parser.add_argument("--origin-day", type=int, choices=range(1, 481), metavar="1..480")
    parser.add_argument("--require-accepted-origin", action="store_true",
                        help="Require a checkpoint package published by the kernel host")
    parser.add_argument("--trace-richards", action="store_true", help="Trace the donor residuals and step water ledger")
    parser.add_argument("--trace-day", type=int, default=15)
    parser.add_argument("--days", type=int, choices=range(1, 482), default=481, metavar="1..481")
    args = parser.parse_args()
    if args.prepare_archive is not None:
        prepare_reference(args.prepare_archive.resolve(), args.reference_work.resolve())
        return 0
    if args.output is None:
        parser.error("--output is required for a kernel run")
    if args.shared_pond_transfer and not args.budget_retry:
        parser.error("--shared-pond-transfer requires --budget-retry")
    if args.refresh_macro_final and not args.budget_retry:
        parser.error("--refresh-macro-final requires --budget-retry")
    if (args.origin is None) != (args.origin_day is None):
        parser.error("--origin and --origin-day must be supplied together")
    if args.origin is not None and (args.restart_at is not None or args.days <= args.origin_day):
        parser.error("A checkpoint continuation needs an end day after its origin and no --restart-at")
    if args.checkpoint_at is not None and (
            args.restart_at is not None or args.isolation
            or not (args.origin_day or 0) < args.checkpoint_at <= args.days):
        parser.error("--checkpoint-at requires a cut in the requested single-column run")
    if args.require_accepted_origin and args.origin is None:
        parser.error("--require-accepted-origin requires --origin")
    if args.checkpoint_at is not None and args.origin is not None and not args.require_accepted_origin:
        parser.error("Publishing from an origin requires a verified checkpoint")
    origin = args.origin.resolve() if args.origin is not None else None
    runtime = args.checkpoint_at is not None or args.require_accepted_origin
    cut = args.restart_at or args.origin_day
    output = args.output.resolve()
    output.mkdir()
    donor, kernel, case, inputs, build_identity = build(
        args.reference_work.resolve(), output, args.trace_richards, cut,
        args.budget_retry, args.trace_day, args.shared_pond_transfer, args.refresh_macro_final,
        runtime_checkpoint=runtime,
    )
    binding = checkpoint_identity(inputs, build_identity, budget_retry=args.budget_retry,
                                  shared_pond_transfer=args.shared_pond_transfer,
                                  refresh_macro_final=args.refresh_macro_final)
    origin_receipt = None
    if args.require_accepted_origin:
        unpacked = output / "verified-origin"
        origin_receipt = verify_checkpoint(origin, cut, binding, unpacked)
        origin = unpacked
    if args.restart_at is not None:
        measurements = restart(donor, kernel, case, output, args.restart_at)
    elif args.isolation:
        measurements = isolation(donor, kernel, case, output, args.days, cut, origin,
                                 runtime=runtime, origin_receipt=origin_receipt)
    else:
        measurements = run(donor, kernel, case, output, args.days, checkpoint_day=cut, origin=origin,
                           checkpoint_binding=binding if args.checkpoint_at is not None else None,
                           origin_receipt=origin_receipt, runtime=runtime, publish_day=args.checkpoint_at)
    result = {
        "compiler": build_identity["compiler"],
        "source_sha256": {"SWAP.ZIP": DONOR_SOURCE_SHA, "TTUTIL.ZIP": TTUTIL_SOURCE_SHA},
        "input_sha256": inputs,
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "requested_days": args.restart_at + RESTART_WINDOWS[args.restart_at] if args.restart_at else args.days,
        "budget_retry": args.budget_retry,
        "shared_pond_transfer": args.shared_pond_transfer,
        "refresh_macro_final": args.refresh_macro_final,
        "origin_day": args.origin_day,
        **measurements,
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    return 1 if result.get("first_refusal") is not None else 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Run a real Andelst donor through the SWAP5 reference-floor transaction API."""

import argparse
import json
import math
import shlex
import subprocess
import sys
from pathlib import Path

from probe_head_transaction import build_worker, run_worker
from run_day_return import ROOT, sha


def audit(directory, prefix):
    return [line for line in (directory / "stdout").read_text().splitlines() if line.startswith(prefix)]


def ledger(directory):
    stocks = [[float(v) for v in row.split()[1:]] for row in audit(directory, "HYBRID_STOCK_FLUX ")]
    flows = [[float(v) for v in row.split()[1:]] for row in audit(directory, "HYBRID_EXTERNAL_FLUX ")]
    return [(math.fsum(stock[:6]), math.fsum(flow[:7]), math.fsum(flow[7:]), flow[15]-flow[6])
            for stock, flow in zip(stocks, flows, strict=True)]


def steps(directory, before_noon=False):
    lines = audit(directory, "HYBRID_ACCEPTED_TRAJECTORY ")
    return [line for line in lines if float(line.split()[1]) < 35799.5] if before_noon else lines


def worker():
    root = Path.cwd()
    configuration = json.loads((root / "worker.json").read_text())
    column, origin_ticket, t0, t1, head = (root / "request").read_text().split()
    origin_ticket, t0, t1, head = int(origin_ticket), float(t0), float(t1), float(head)
    paths = sorted(root.glob("job_*"))
    ticket = len(paths) + 1
    job = root / f"job_{ticket:03}"
    destination = job / "resumed"
    origin, case, half, full = (Path(configuration[key]) for key in ("origin", "case", "half", "full"))
    prior = None
    if (t0, t1, origin_ticket) == (35799.0, 35799.5, 0):
        run_worker(case, half, destination, origin, head, start="1998-01-05", end="1998-01-06", subday=True)
    elif (t0, t1) == (35799.5, 35800.0) and origin_ticket > 0:
        previous = root / f"job_{origin_ticket:03}"
        prior = json.loads((previous / "job.json").read_text())
        if prior["column"] != column or prior["t1"] != t0:
            raise RuntimeError("Wrong committed origin")
        run_worker(case, full, destination, origin, prior["head"], start="1998-01-05",
                   end="1998-01-05", handoff=True, afternoon_head=head)
        prefix = steps(destination, before_noon=True)
        if not prefix or prefix != steps(previous / "resumed"):
            raise RuntimeError("Replay did not reproduce the committed first half")
    else:
        raise RuntimeError("Unsupported trial window")
    observed = ledger(destination)
    if len(observed) != 2:
        raise RuntimeError("Expected exactly one endpoint ledger in addition to initialization")
    ending, incoming, outgoing, bottom = observed[-1]
    if prior is not None:
        _, old_in, old_out, old_bottom = ledger(previous / "resumed")[-1]
        incoming, outgoing, bottom = incoming-old_in, outgoing-old_out, bottom-old_bottom
    (job / "job.json").write_text(json.dumps({"column": column, "head": head, "t1": t1,
                                            "previous": origin_ticket}))
    terminal = -float(audit(destination, "HYBRID_TERMINAL_BOTTOM_INWARD ")[-1].split()[1])
    (root / "reply").write_text(
        f"{ticket} {ending:.17g} {incoming:.17g} {outgoing:.17g} {bottom:.17g} {terminal:.17g}\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--day-return-work", type=Path, required=True)
    parser.add_argument("--noon-work", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference, audit_work, noon, output = (p.resolve() for p in (
        args.reference_work, args.day_return_work, args.noon_work, args.output))
    output.mkdir()
    for name in ("half", "full"):
        (output / name).mkdir()
    half = build_worker(reference, audit_work, output / "half", subday=True, kernel_flux=True)
    full = build_worker(reference, audit_work, output / "full", handoff=True, kernel_flux=True)
    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    origin = noon / "day4/resumed"
    names = ("result.end", "macro.bin")
    hashes = {name: sha(origin / name) for name in names}
    if hashes != json.loads((noon / "RESULT.json").read_text())["day4_checkpoint"]:
        raise RuntimeError("Unexpected day-4 checkpoint")
    stock = ledger(noon / "fixed/resumed")[0][0]
    configuration = {"origin": str(origin), "case": str(case), "half": str(half), "full": str(full)}
    (output / "worker.json").write_text(json.dumps(configuration))
    shell = output / "worker"
    shell.write_text("#!/bin/sh\nexec " + shlex.join([sys.executable, str(Path(__file__).resolve()), "--worker"]) + "\n")
    shell.chmod(0o700)

    source_list = (ROOT / "tests/fgc/run_fgc43_production_swap_participant.sh").read_text()
    sources = source_list.split("SOURCES=(\n", 1)[1].split("\n)", 1)[0].split()[:7]
    executable = output / "kernel_donor"
    subprocess.run(["gfortran", "-O2", "-ffree-line-length-none", "-fcheck=all",
                    *[str(ROOT / source) for source in sources],
                    str(Path(__file__).with_suffix(".f90").resolve()), "-o", str(executable)],
                   cwd=output, check=True)
    run = subprocess.run([executable], cwd=output, input=f"{stock:.17g}\n",
                         capture_output=True, text=True, timeout=240)
    (output / "kernel.stdout").write_text(run.stdout)
    (output / "kernel.stderr").write_text(run.stderr)
    if run.returncode:
        raise RuntimeError(run.stdout + run.stderr)
    decisions = [row.split()[1:] for row in run.stdout.splitlines() if row.startswith("DONOR ")]
    if [row[:4] for row in decisions] != [
        ["1", "1", "F", "0"], ["2", "2", "T", "1"], ["1", "3", "T", "1"],
        ["1", "4", "T", "2"], ["2", "5", "T", "2"],
    ]:
        raise RuntimeError("Unexpected SWAP5 transaction decisions")
    if hashes != {name: sha(origin / name) for name in names}:
        raise RuntimeError("Day-4 checkpoint mutated")
    discarded = output / "job_001/resumed"
    accepted_b = output / "job_002/resumed"
    accepted_a = output / "job_003/resumed"
    if not all(sha(discarded / name) == sha(accepted_b / name) for name in names):
        raise RuntimeError("Different column did not reproduce the discarded forcing")
    if steps(accepted_a) != steps(noon / "fixed/resumed", before_noon=True):
        raise RuntimeError("Column A diverged from its clean half-day control")
    restarts = []
    for column, ticket, before, after in ((1, 4, -50.0, -90.0), (2, 5, -90.0, -50.0)):
        committed = output / f"job_{ticket:03}/resumed"
        continuous = output / f"column{column}_continuous/resumed"
        restarted = output / f"column{column}_restart/resumed"
        run_worker(case, full, continuous, origin, before, start="1998-01-05",
                   end="1998-01-06", handoff=True, afternoon_head=after)
        run_worker(case, full, restarted, committed, after, start="1998-01-06", end="1998-01-06")
        expected = [line for line in steps(continuous) if float(line.split()[1]) >= 35800.0]
        if not expected or expected != steps(restarted):
            raise RuntimeError(f"Day-6 accepted trajectory diverged for column {column}")
        same = {name: sha(continuous / name) == sha(restarted / name) for name in names}
        if not all(same.values()) or ledger(continuous)[-1] != ledger(restarted)[-1]:
            raise RuntimeError(f"Day-6 physical checkpoint or ledger diverged for column {column}")
        restarts.append({"column": column, "day6_steps_exact": len(expected),
                         "day6_ledger_exact": True, "endpoint_file_exact": same})
    result = {"scope": "SWAP5_REFERENCE_FLOOR_WITH_ISOLATED_REPLAY_DONORS",
              "origin_checkpoint": hashes, "decisions": decisions, "next_day_restarts": restarts}
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    if sys.argv[1:] == ["--worker"]:
        worker()
    else:
        main()

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
    request = (root / "request").read_text().split()
    if request[0] == "GW":
        from probe_modflow_cell import solve_cell
        _, iteration, initial, exchange = request
        result = solve_cell(root / f"gw_{int(iteration):03}", configuration["mf6"],
                            float(initial), float(exchange))
        (root / "reply").write_text(" ".join(f"{value:.17g}" for value in result) + "\n")
        return
    column, origin_ticket, t0, t1, head = request
    origin_ticket, t0, t1, head = int(origin_ticket), float(t0), float(t1), float(head)
    paths = sorted(root.glob("job_*"))
    ticket = len(paths) + 1
    job = root / f"job_{ticket:03}"
    destination = job / "resumed"
    origin, case, half, full = (Path(configuration[key]) for key in ("origin", "case", "half", "full"))
    max_step = configuration.get("max_step_days")
    prior = None
    if t0 == 35799.0 and t0 < t1 <= 35799.5 and origin_ticket == 0:
        run_worker(case, half, destination, origin, head, start="1998-01-05", end="1998-01-06", subday=True, fraction=t1, max_step_days=max_step)
    elif 35799.0 < t0 < t1 <= 35799.5 and origin_ticket > 0:
        previous = root / f"job_{origin_ticket:03}"
        prior = json.loads((previous / "job.json").read_text())
        if prior["column"] != column or prior["t1"] != t0 or prior["head"] != head:
            raise RuntimeError("Wrong quarter-day origin")
        run_worker(case, half, destination, origin, head, start="1998-01-05",
                   end="1998-01-06", subday=True, fraction=t1, split_clock=t0, max_step_days=max_step)
        prefix = [line for line in steps(destination) if float(line.split()[1]) < t0]
        if not prefix or prefix != steps(previous / "resumed"):
            raise RuntimeError("Quarter replay did not reproduce its origin")
    elif (t0, t1) == (35799.5, 35800.0) and origin_ticket > 0:
        previous = root / f"job_{origin_ticket:03}"
        prior = json.loads((previous / "job.json").read_text())
        if prior["column"] != column or prior["t1"] != t0:
            raise RuntimeError("Wrong committed origin")
        run_worker(case, full, destination, origin, prior["head"], start="1998-01-05",
                   end="1998-01-05", handoff=True, afternoon_head=head, max_step_days=max_step)
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
    pressure = audit(destination, "HYBRID_ENDPOINT_HEAD ")
    values = pressure[-1].split()[1:] if pressure else steps(destination)[-1].split()[6:118]
    if len(values) != 112:
        raise RuntimeError("Missing pressure state for the kernel")
    components = audit(destination, "HYBRID_STOCK_FLUX ")[-1].split()[1:7]
    (root / "reply").write_text(
        f"{ticket} {ending:.17g} {incoming:.17g} {outgoing:.17g} {bottom:.17g} {terminal:.17g}\n" + " ".join(values + components) + "\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--day-return-work", type=Path, required=True)
    parser.add_argument("--noon-work", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--temporal", action="store_true")
    mode.add_argument("--water-metric", action="store_true")
    mode.add_argument("--mf6", type=Path)
    predictor = parser.add_mutually_exclusive_group()
    predictor.add_argument("--origin-predictor", action="store_true", help="Try one volume handoff from the initial MODFLOW head")
    predictor.add_argument("--bracketed", action="store_true", help="Safeguard the live corrector with a sign bracket")
    parser.add_argument("--max-step-days", type=float, help="Diagnostic DTMAX override for coupled runs")
    args = parser.parse_args()
    if (args.bracketed or args.origin_predictor) and args.mf6 is None:
        parser.error("--bracketed and --origin-predictor require --mf6")
    if args.max_step_days is not None and (
            args.mf6 is None or not 0.0001 <= args.max_step_days <= 0.002):
        parser.error("--max-step-days requires --mf6 and must be in [0.0001, 0.002]")
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
    if args.mf6 is not None:
        configuration["max_step_days"] = args.max_step_days
        configuration["mf6"] = str(args.mf6.resolve())
    (output / "worker.json").write_text(json.dumps(configuration))
    shell = output / "worker"
    shell.write_text("#!/bin/sh\nexec " + shlex.join([sys.executable, str(Path(__file__).resolve()), "--worker"]) + "\n")
    shell.chmod(0o700)

    source_list = (ROOT / "tests/fgc/run_fgc43_production_swap_participant.sh").read_text()
    sources = source_list.split("SOURCES=(\n", 1)[1].split("\n)", 1)[0].split()[:-1] + ["src/runtime/mod_groundwater_interface_mass_ledger.f90"]
    executable = output / "kernel_donor"
    subprocess.run(["gfortran", "-O2", "-ffree-line-length-none", "-fcheck=all",
                    *[str(ROOT / source) for source in sources],
                    str(Path(__file__).with_suffix(".f90").resolve()), "-o", str(executable)],
                   cwd=output, check=True)
    command = [executable]
    if args.mf6 is not None:
        corrector = "origin-predictor" if args.origin_predictor else "bracketed" if args.bracketed else "coupled"
        command.append(corrector)
    if args.temporal:
        command.append("temporal")
    if args.water_metric:
        command.append("water-metric")
    run = subprocess.run(command, cwd=output, input=f"{stock:.17g}\n",
                         capture_output=True, text=True, timeout=240)
    (output / "kernel.stdout").write_text(run.stdout)
    (output / "kernel.stderr").write_text(run.stderr)
    if run.returncode:
        raise RuntimeError(run.stdout + run.stderr)
    if args.mf6 is not None:
        if hashes != {name: sha(origin / name) for name in names}:
            raise RuntimeError("Coupling mutated the day-4 checkpoint")
        rows = run.stdout.splitlines()
        correctors = [[float(v) for v in line.split()[2:]] for line in rows
                      if line.startswith("COUPLED_CORRECTOR ")]
        rejected = [line.split()[1:] for line in rows if line.startswith("COUPLED_TEMPORAL_REJECTION ")]
        defects = [[float(v) for v in line.split()[1:]] for line in rows
                   if line.strip().startswith("TEMPORAL_WATER_DEFECTS_CM ")]
        if len(defects) != len(correctors) + len(rejected):
            raise RuntimeError("Missing temporal results for coupled trials")
        evidence = {
            "scope": "LIVE_MODFLOW6_SINGLE_CELL_AND_ANDELST_HALF_DAY",
            "mf6_sha256": sha(args.mf6.resolve()), "origin_checkpoint": hashes,
            "corrector": corrector if corrector != "coupled" else "fixed_point",
            "max_step_days": args.max_step_days if args.max_step_days is not None else 0.002,
            "head_tolerance_m": 1e-8, "water_metric_tolerance_cm": 1e-4,
            "columns": ["swap_head_m", "modflow_head_m", "modflow_inward_m3", "modflow_storage_outward_m3"],
            "correctors": correctors, "temporal_rejections": rejected,
            "temporal_water_defects_cm": defects,
            "best_head_mismatch_m": min((abs(row[0]-row[1]) for row in correctors), default=None),
            "max_modflow_balance_residual_m3": max((abs(row[2]+row[3]) for row in correctors), default=None),
        }
        if "COUPLED_NO_COMMIT" in rows:
            receipt = {**evidence, "committed": False, "accepted_revision": 0}
            (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
            print(json.dumps(receipt, indent=2))
            return
        commit = next(line.split()[1:] for line in rows if line.startswith("COUPLED_COMMITTED "))
        iterations, ticket, residual = int(commit[0]), int(commit[1]), float(commit[2])
        if iterations != len(correctors) + len(rejected) or ticket != 3*iterations:
            raise RuntimeError("Unexpected accepted trial lineage")
        selected = output / f"job_{ticket:03}/resumed"
        selected_gw = output / f"gw_{iterations:03}"
        receipt = {**evidence, "committed": True, "accepted_revision": 1, "selected_ticket": ticket,
                   "interface_residual_m": residual,
                   "swap_endpoint": {name: sha(selected / name) for name in names},
                   "modflow_endpoint": {name: sha(selected_gw / name) for name in ("cell.hds", "cell.cbc")}}
        (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(json.dumps(receipt, indent=2))
        return
    if args.water_metric:
        if hashes != {name: sha(origin / name) for name in names}:
            raise RuntimeError("Water-metric trials mutated the day-4 checkpoint")
        lines = run.stdout.splitlines()
        defects = [[float(value) for value in line.split()[1:]] for line in lines
                   if line.strip().startswith("TEMPORAL_WATER_DEFECTS_CM ")]
        committed = next(line.split()[1:] for line in lines if line.startswith("WATER_COMMITTED "))
        ticket, exchange, interface_flux = int(committed[0]), float(committed[1]), float(committed[2])
        selected = output / f"job_{ticket:03}/resumed"
        if ticket != 6 or len(defects) != 2 or max(defects[0]) <= 1e-4 or max(defects[1]) > 1e-4:
            raise RuntimeError("Unexpected water-metric acceptance results")
        if not math.isclose(exchange, ledger(selected)[-1][3], abs_tol=1e-13):
            raise RuntimeError("Kernel did not publish the selected donor exchange")
        if not math.isclose(interface_flux, exchange*0.01/(0.5*86400), abs_tol=1e-15):
            raise RuntimeError("Groundwater interface flux conversion is inconsistent")
        receipt = {"scope": "EXPERIMENTAL_WATER_METRIC_VIA_NORMAL_GROUNDWATER_PARTICIPANT",
                   "tolerance_cm": 1e-4, "imposed_head_cm": -50.0,
                   "defect_columns": ["whole_column_stock", "max_component_stock", "bottom_exchange"],
                   "rejected_0_0625_day_cm": defects[0], "accepted_0_5_day_cm": defects[1],
                   "selected_ticket": ticket, "bottom_outward_cm": exchange,
                   "interface_outward_m_per_s": interface_flux,
                   "selected_endpoint": {name: sha(selected / name) for name in names},
                   "origin_checkpoint": hashes}
        (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(json.dumps(receipt, indent=2))
        return
    if args.temporal:
        if hashes != {name: sha(origin / name) for name in names}:
            raise RuntimeError("Temporal trials mutated the day-4 checkpoint")
        defects = [float(line.split()[1]) for line in run.stdout.splitlines()
                   if line.strip().startswith("TEMPORAL_HEAD_DEFECT_CM ")]
        rejections = [line.split()[1:] for line in run.stdout.splitlines()
                      if line.startswith("TEMPORAL_REJECTED ")]
        if len(defects) != 3 or len(rejections) != 3:
            raise RuntimeError("Missing full-versus-two-half evidence")
        windows = []
        for i, (defect, rejection) in enumerate(zip(defects, rejections, strict=True)):
            first, quarter, split = [output / f"job_{i*3+j:03}/resumed" for j in (1, 2, 3)]
            stock0, *_ = ledger(first)[0]
            balances = []
            for candidate in (first, quarter, split):
                ending, incoming, outgoing, bottom = ledger(candidate)[-1]
                balances.append({"residual_cm": ending-stock0-incoming+outgoing, "bottom_outward_cm": bottom})
            if any(abs(row["residual_cm"]) > 1e-6 for row in balances):
                raise RuntimeError("Temporal probe also failed mass closure")
            windows.append({"duration_days": float(rejection[0]), "head_defect_cm": defect,
                            "participant_status": int(rejection[1]), "committed_revision": 0,
                            "full": balances[0], "first_half": balances[1], "split": balances[2]})
        receipt = {"scope": "NORMAL_SWAP5_GROUNDWATER_PARTICIPANT_TEMPORAL_REJECTION",
                   "imposed_head_cm": -50.0, "probe_head_tolerance_cm": 0.05,
                   "origin_checkpoint": hashes, "windows": windows}
        (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(json.dumps(receipt, indent=2))
        return
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

"""Test an experimental B0 macropore continuation sidecar in a fresh process."""

import argparse
from datetime import date, timedelta
import json
import math
import os
import re
import shutil
import subprocess
from pathlib import Path

from probe_legacy_restart import launch
from run_day_return import records, replace, sha


from donor_sources import render_checkpoint as render


def domain_bits(path):
    rows = [line.split()[1:] for line in path.read_text().splitlines()
            if line.startswith("HYBRID_MACRO_DOMAIN_BITS ")]
    if len(rows) != 1 or len(rows[0]) != 5:
        raise ValueError(f"Missing five-domain checkpoint receipt: {path}")
    return rows[0]



def verify_rejected_checkpoints(case, executable, output, control):
    """Require malformed sidecars to fail before normal output is opened."""
    original = output / "first/macro.bin"
    mutations = {
        "bad_magic": lambda data: b"INVALID!" + data[8:],
        "truncated": lambda data: data[:-1],
        "trailing": lambda data: data + b"X",
    }
    payload = original.read_bytes()
    for name, mutate in mutations.items():
        scenario = output / name
        first = scenario / "first"
        first.mkdir(parents=True)
        shutil.copyfile(output / "first/result.end", first / "result.end")
        (first / "macro.bin").write_bytes(mutate(payload))
        resumed = scenario / "resumed"
        shutil.copytree(case, resumed)
        shutil.copyfile(control, resumed / "swap.swp")
        run = subprocess.run([executable, "./swap.swp"], cwd=resumed,
                             capture_output=True, text=True, timeout=60)
        (resumed / "stdout").write_text(run.stdout)
        (resumed / "stderr").write_text(run.stderr)
        if run.returncode in (0, 100) or (resumed / "result_output.csv").exists() or (resumed / "swap.ok").exists():
            raise RuntimeError(f"Malformed checkpoint did not fail before output: {name}")
    return list(mutations)


def compare_daily_ledger(output, days=2):
    ledgers = []
    for directory in ("first", "resumed"):
        lines = (output / directory / "stdout").read_text().splitlines()
        stock = [line for line in lines if line.startswith("HYBRID_STOCK_FLUX ")][-days:]
        flux = [line for line in lines if line.startswith("HYBRID_EXTERNAL_FLUX ")][-days:]
        if len(stock) != days or len(flux) != days:
            raise RuntimeError(f"Missing daily water ledger: {directory}")
        ledgers.append((stock, flux))
    residual = []
    for levels, flows in zip(*ledgers[1]):
        values = list(map(float, levels.split()[1:]))
        fluxes = list(map(float, flows.split()[1:]))
        residual.append(math.fsum([*fluxes[:7], *(-v for v in fluxes[7:]),
                                   *values[6:], *(-v for v in values[:6])]))
    return {"daily_ledger_exact": ledgers[0] == ledgers[1], "resumed_daily_residual_cm": residual}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", required=True, type=Path)
    parser.add_argument("--day-return-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--year-boundary", action="store_true")
    parser.add_argument("--dry-window", action="store_true")
    parser.add_argument("--reuse-continuous", type=Path)
    args = parser.parse_args()
    if args.dry_window and args.year_boundary:
        parser.error("Select a single restart window")
    checkpoint_day = 453 if args.dry_window else 365 if args.year_boundary else 2
    days = 4 if args.dry_window else 2
    start = date(1998, 1, 1) + timedelta(days=checkpoint_day)
    end = start + timedelta(days=days - 1)
    reference = args.reference_work.resolve()
    output = args.output.resolve()
    output.mkdir()
    build = reference / "build"
    obj = build / "swap-obj"
    tt = build / "ttutil-obj"
    fields = render(build, output, checkpoint_day, days)
    common = ["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
              "-ffree-line-length-none", "-fallow-argument-mismatch",
              "-I", str(output), "-I", str(obj), "-I", str(tt)]
    patched = ["macropore.f90", "swap.f90"]
    if checkpoint_day >= 365:
        patched.append("swapoutput.f90")
    for name in patched:
        subprocess.run([*common, "-c", name], cwd=output, check=True)
    replacements = {Path(name).with_suffix(".o").name: output / Path(name).with_suffix(".o") for name in patched}
    replacements["swap_csv_output.o"] = args.day_return_work.resolve() / "swap_csv_output.o"
    executable = output / ("swap431_macro_checkpoint.exe" if os.name == "nt" else "swap431_macro_checkpoint")
    objects = [str(replacements.get(path.name, path)) for path in sorted(obj.glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *objects, str(tt / "libttutil.a")], check=True)

    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    first = output / "first"
    if args.reuse_continuous:
        source = args.reuse_continuous.resolve()
        if sha(source / executable.name) != sha(executable) or not (source / "first/swap.ok").is_file():
            raise ValueError("Reuse requires a successful continuous run from the identical executable")
        shutil.copytree(source / "first", first)
    else:
        shutil.copytree(case, first)
        control = first / "swap.swp"
        control.write_text(control.read_text(encoding="cp1252").replace("TEND = 1999-04-26", f"TEND = {end}")
                           + "\nSWENDTYPE = 2\n", encoding="cp1252")
        with (first / "stdout").open("w") as stdout, (first / "stderr").open("w") as stderr:
            run = subprocess.run([executable, "./swap.swp"], cwd=first, stdout=stdout, stderr=stderr,
                                 timeout=1200 if checkpoint_day >= 365 else 60)
        if run.returncode != 100 or not (first / "swap.ok").is_file():
            raise RuntimeError(f"Continuous donor refused: {run.returncode}")
    first_stock = [[float(v) for v in row.split()[1:7]] for row in (first / "stdout").read_text().splitlines()
                   if row.startswith("HYBRID_STOCK_FLUX ")]
    resumed_case = case
    if checkpoint_day >= 365:
        resumed_case = output / "year_boundary_input"
        shutil.copytree(case, resumed_case)
        bbc = resumed_case / "swap.bbc"
        text = bbc.read_text(encoding="cp1252")
        match = re.search(r"(?m)^([ \t]*1998-12-31[ \t]+)(-?\d+(?:\.\d+)?)[ \t]*$", text)
        if not match:
            raise ValueError("Missing terminal Cauchy head in the Andelst table")
        text = replace(text, match[0], match[0] + f"\n {start}  {match[2]}")
        bbc.write_text(text, encoding="cp1252")
    resumed, resumed_stock = launch(
        resumed_case, executable, output / "resumed",
        {"TSTART": str(start), "TEND": str(end), "SWINCO": "3"},
        "SWINITYPE = 2\nSWENDTYPE = 2\nINIFIL = '../first/result.end'", days=days,
    )
    expected_bits = domain_bits(output / "first/stdout")
    actual_bits = domain_bits(output / "resumed/stdout")
    stock_exact = expected_bits == actual_bits and first_stock[checkpoint_day] == resumed_stock[0]
    expected = records((reference / "run/3.macroporeflow/result_output.csv").read_text().splitlines())
    expected = expected[:checkpoint_day + days + 2]
    if records((first / "result_output.csv").read_text().splitlines()) != expected:
        raise RuntimeError("Writing the checkpoint changed the continuous reference")
    expected = expected[-days:]
    accepted = []
    for directory in ("first", "resumed"):
        rows = [line.split()[1:] for line in (output / directory / "stdout").read_text().splitlines()
                if line.startswith("HYBRID_FIRST_ACCEPTED ")]
        if len(rows) != 1:
            raise RuntimeError(f"Expected one first-step record in {directory}")
        accepted.append(rows[0])
    inputs = []
    for directory in ("first", "resumed"):
        line = next(line for line in (output / directory / "stdout").read_text().splitlines()
                    if line.startswith("HYBRID_FIRST_INPUT "))
        inputs.append([float(value) for value in line.split()[1:]])
    if any(len(row) != 449 for row in inputs):
        raise RuntimeError("Unexpected Andelst first-input dimensions")
    input_delta = {"rain_cm": inputs[1][0] - inputs[0][0]}
    for i, name in enumerate(("head", "theta", "root_sink", "drainage_sink")):
        start = 1 + i * 112
        input_delta[name] = max(abs(a - b) for a, b in
                                zip(inputs[0][start:start+112], inputs[1][start:start+112]))
    trajectories = [
        [line for line in (output / directory / "stdout").read_text().splitlines()
         if line.startswith("HYBRID_ACCEPTED_TRAJECTORY ")]
        for directory in ("first", "resumed")
    ]
    if not trajectories[0] or not trajectories[1]:
        raise RuntimeError("Missing accepted-step audit")
    rejected = verify_rejected_checkpoints(resumed_case, executable, output, output / "resumed/swap.swp")
    result = {
        "scope": "EXPERIMENTAL_MACROPORE_SIDECAR_ONLY",
        "executable_sha256": sha(executable),
        "sidecar_sha256": sha(output / "first/macro.bin"),
        "fields": fields,
        "domain_stock_bits_at_write_and_restore": actual_bits,
        "checkpoint_day": checkpoint_day,
        "rejected_before_output": rejected,
        "stock_exact_before_first_step": stock_exact,
        "first_trial_input_max_abs_delta": input_delta,
        "first_accepted_columns": ["clock", "dt", "dtold", "pond", "gwl", "epond", "peva", "ptra", "ptra_dry", "ptra_wet", "wfrac"],
        "first_accepted_continuous": accepted[0][:11],
        "first_accepted_resumed": accepted[1][:11],
        "first_accepted_head_max_delta_cm": max(abs(float(a)-float(b)) for a,b in zip(accepted[0][11:123], accepted[1][11:123])),
        **compare_daily_ledger(output, days),
        "accepted_step_counts": [len(rows) for rows in trajectories],
        "accepted_step_audit_exact": trajectories[0] == trajectories[1],
        "continuous_resumed_window": expected,
        "restart_resumed_window": resumed[2:],
        "published_window_exact": expected == resumed[2:],
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

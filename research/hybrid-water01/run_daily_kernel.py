"""Drive the original Andelst donor one day per SWAP5 transaction."""

import argparse
import contextlib
import json
import math
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

from probe_macro_checkpoint import render as render_checkpoint
from run_day_return import ROOT, records, render, replace, sha

CASE = "3.macroporeflow"
START_CLOCK = 35795
DONOR_SOURCE_SHA = "1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151"
TTUTIL_SOURCE_SHA = "ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193"


def executable(directory, name):
    return directory / (name + (".exe" if os.name == "nt" else ""))


def prepare_reference(archive, reference):
    sys.path.insert(0, str(ROOT / "tools/vq"))
    from b0_source_runner import build_gfortran

    reference.mkdir()
    with zipfile.ZipFile(archive) as distribution:
        distribution.extractall(reference / "distribution")
    root = reference / "distribution/SWAP_4.3.1"
    verify_source(root)
    donor, logs = build_gfortran(root, reference / "build")
    (reference / "compile.log").write_text("".join(logs))
    if not donor.is_file():
        donor = executable(donor.parent, donor.name)
    case = reference / "run" / CASE
    shutil.copytree(root / "cases" / CASE, case)
    with (case / "stdout").open("wb") as log:
        run = subprocess.run([donor, "./swap.swp"], cwd=case, stdout=log, stderr=subprocess.STDOUT)
    error_log = case / "swap.err"
    has_model_error = error_log.is_file() and bool(error_log.read_bytes().strip())
    if run.returncode != 100 or not (case / "swap.ok").is_file() or has_model_error:
        raise RuntimeError(f"Unmodified reference refused: {run.returncode}")


def verify_source(distribution):
    for name, digest in [("SWAP.ZIP", DONOR_SOURCE_SHA), ("TTUTIL.ZIP", TTUTIL_SOURCE_SHA)]:
        if sha(distribution / "tools/SWAP/source" / name) != digest:
            raise ValueError(f"Unverified donor archive: {name}")


def build(reference, output, trace_richards=False, checkpoint=False):
    distribution = reference / "distribution/SWAP_4.3.1"
    verify_source(distribution)
    case = distribution / "cases" / CASE
    pinned = ROOT / "reference/swap-4.3.1/projects" / CASE
    inputs = {p.relative_to(case).as_posix(): sha(p) for p in sorted(case.rglob("*")) if p.is_file()}
    expected = {p.relative_to(pinned).as_posix() for p in pinned.rglob("*") if p.is_file()}
    if set(inputs) != expected:
        raise ValueError("Andelst project file sets differ")
    for name in inputs:
        if (case / name).read_bytes().replace(b"\r\n", b"\n") != (pinned / name).read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError(f"Andelst input differs: {name}")
    donor_build = reference / "build"
    objects = donor_build / "swap-obj"
    ttutil = donor_build / "ttutil-obj"
    render(donor_build / "swap-selected", output)
    main = output / "swap_main.f90"
    source = main.read_text(encoding="cp1252")
    source = replace(source, "use Variables, only: t1900, flrunend",
                     "use iso_fortran_env, only: output_unit\n"
                     "use MOD_grid, only: numnod\n"
                     "use Variables, only: t1900, flrunend, h, gwl, qbot")
    source = replace(source, "   do window = 1, 4", """   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)
   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900
   flush(output_unit)
   do
      read(*,*) window
      if (window == 0) exit""")
    source = replace(source, "      if (flrunend) error stop 'Donor ended before requested day'",
                     "      if (flrunend .or. window_start /= 35794d0+window) error stop 'Invalid requested day'")
    source = replace(source, "      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900",
                     """      write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)
      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900
      flush(output_unit)""")
    main.write_text(source, encoding="cp1252")
    common = ["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
              "-ffree-line-length-none", "-fallow-argument-mismatch", "-I", str(objects), "-I", str(ttutil)]
    patched = ["swap", "swap_main", "swap_csv_output"]
    if checkpoint:
        swap = output / "swap.f90"
        day_source = swap.read_text(encoding="cp1252")
        module = day_source[:day_source.index("end module hybrid_day_window") + len("end module hybrid_day_window")]
        render_checkpoint(donor_build, output, 2)
        source = module + "\n\n" + swap.read_text(encoding="cp1252")
        source = replace(source, "use MOD_swap_base,       only: pathwork,",
                         "use hybrid_day_window, only: return_at_day_end\nuse MOD_swap_base,       only: pathwork,")
        anchor = "   end do\n\n!  Specific for exchange when called as DLL"
        source = replace(source, anchor, "      if (return_at_day_end .and. flDayEnd) return\n\n" + anchor)
        swap.write_text(source, encoding="cp1252")
        patched.insert(0, "macropore")

    if trace_richards:
        source = (donor_build / "swap-selected/headcalc.f90").read_text(encoding="cp1252")
        source = replace(source, "      if (.NOT.flnonconv) then      ! convergence has been reached",
                         "      if (.NOT.flnonconv) then      ! convergence has been reached\n"
                         "         if (t1900 >= 35809d0 .and. t1900 < 35810d0) &\n"
                         "           write(*,'(a,4(1x,es25.17e3))') 'HYBRID_RICHARDS', t1900, dt, sum1, Fmax")
        (output / "headcalc.f90").write_text(source, encoding="cp1252")
        patched.append("headcalc")

    for name in patched:
        subprocess.run([*common, "-c", name + ".f90"], cwd=output, check=True)
    donor = executable(output, "day_donor")
    replacements = {name + ".o": output / (name + ".o") for name in patched}
    subprocess.run(["gfortran", "-o", str(donor),
                    *(str(replacements.get(p.name, p)) for p in sorted(objects.glob("*.o"))),
                    str(ttutil / "libttutil.a")], cwd=output, check=True)
    probe = Path(__file__).with_name("probe_kernel_donor.f90").read_text()
    module, separator, _ = probe.partition("\nprogram run_kernel_donor\n")
    if not separator:
        raise ValueError("Missing donor adapter module boundary")
    adapter = output / "adapter.f90"
    adapter.write_text(module)
    source_list = (ROOT / "tests/fgc/run_fgc43_production_swap_participant.sh").read_text()
    sources = source_list.split("SOURCES=(\n", 1)[1].split("\n)", 1)[0].split()[:-1]
    sources.append("src/runtime/mod_groundwater_interface_mass_ledger.f90")
    kernel = executable(output, "day_kernel")
    subprocess.run(["gfortran", "-O2", "-ffree-line-length-none", "-fcheck=all",
                    *(str(ROOT / s) for s in sources), str(adapter),
                    str(Path(__file__).with_suffix(".f90")), "-o", str(kernel)],
                   cwd=output, check=True)
    return donor, kernel, case, inputs


def start_process(stack, command, directory, name):
    stderr = stack.enter_context((directory / (name + ".stderr")).open("w"))
    process = stack.enter_context(subprocess.Popen(
        command, cwd=directory, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=stderr, text=True, encoding="cp1252", errors="replace",
    ))
    stack.callback(stop_process, process)
    transcript = stack.enter_context((directory / (name + ".stdout")).open("w", encoding="utf8"))
    return process, transcript


def stop_process(process):
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=10)


def send(process, text):
    process.stdin.write(text + "\n")
    process.stdin.flush()


def receive(process, transcript, prefixes):
    rows = {}
    for line in process.stdout:
        transcript.write(line)
        transcript.flush()
        key, _, values = line.strip().partition(" ")
        if key.startswith(("DAILY_", "HYBRID_")):
            rows[key] = values.split()
        if key in prefixes:
            return key, rows
    raise RuntimeError(f"Missing {prefixes}, process exited with {process.wait()}")


def run(donor, kernel, case, output, days, variants=("original",), checkpoint=False, origin=None):
    first = 2 if origin is not None else 0
    accepted = []
    refusal = None
    with contextlib.ExitStack() as stack:
        workers = []
        previous = []
        initial_pressure = []
        for variant in variants:
            directory = output / variant
            shutil.copytree(case, directory)
            if checkpoint:
                control = directory / "swap.swp"
                source = control.read_text(encoding="cp1252") + "\nSWENDTYPE = 2\n"
                if origin is not None:
                    source = replace(source, "TSTART = 1998-01-01", "TSTART = 1998-01-03")
                    source, count = re.subn(r"(?m)^([ \t]*SWINCO[ \t]*=[ \t]*)2", r"\g<1>3", source)
                    if count != 1:
                        raise ValueError("Missing restart setting")
                    source += "SWINITYPE = 2\nINIFIL = '../first/result.end'\n"
                    checkpoint_dir = output / "first"
                    checkpoint_dir.mkdir()
                    for name in ("macro.bin", "result.end"):
                        shutil.copyfile(origin / name, checkpoint_dir / name)
                control.write_text(source, encoding="cp1252")

            if variant == "shifted":
                bbc = directory / "swap.bbc"
                source = bbc.read_text(encoding="cp1252")
                source, count = re.subn(
                    r"(?m)^([ \t]*1998-01-02[ \t]+)(-?\d+(?:\.\d+)?)([ \t]*)$",
                    lambda match: f"{match[1]}{float(match[2])+0.001:.6f}{match[3]}",
                    source,
                )
                if count != 1:
                    raise ValueError("Expected one Cauchy head at 1998-01-02")
                bbc.write_text(source, encoding="cp1252")
            worker, worker_log = start_process(stack, [donor, "./swap.swp"], directory, "donor")
            _, initial = receive(worker, worker_log, {"HYBRID_READY"})
            if list(map(float, initial["HYBRID_READY"])) != [START_CLOCK + first]:
                raise ValueError("Incorrect donor initialization clock")
            previous.append(list(map(float, initial["HYBRID_STOCK_FLUX"][:6])))
            initial_pressure.append(list(map(float, initial["HYBRID_HYDRAULIC"][2:])))
            workers.append((worker, worker_log))
        host, host_log = start_process(stack, [kernel], output, "kernel")
        send(host, str(len(workers)))
        for stocks, pressure in zip(previous, initial_pressure):
            send(host, " ".join(map(str, [first, math.fsum(stocks), *stocks, *pressure])))
        with (output / "daily.jsonl").open("w") as receipts:
            for day in range(first + 1, days + 1):
                for column, (worker, worker_log) in enumerate(workers, 1):
                    send(host, f"{column} {day}")
                    _, request = receive(host, host_log, {"DAILY_REQUEST"})
                    if list(map(float, request["DAILY_REQUEST"])) != [column, day-1, START_CLOCK+day-1, START_CLOCK+day]:
                        raise ValueError("Kernel request has incorrect ownership or clock")
                    send(worker, str(day))
                    _, response = receive(worker, worker_log, {"HYBRID_DAY_RETURN"})
                    if list(map(float, response["HYBRID_DAY_RETURN"])) != [day, START_CLOCK+day]:
                        raise ValueError("Incorrect donor return clock")
                    stocks = list(map(float, response["HYBRID_STOCK_FLUX"]))
                    flow = list(map(float, response["HYBRID_EXTERNAL_FLUX"]))
                    hydraulic = list(map(float, response["HYBRID_HYDRAULIC"]))
                    if len(stocks) != 12 or len(flow) != 16 or len(hydraulic) != 114:
                        raise ValueError("Incomplete donor water budget")
                    if not all(map(math.isfinite, stocks + flow + hydraulic)):
                        raise ValueError("Nonfinite donor water budget")
                    if stocks[6:] != previous[column-1]:
                        raise ValueError(f"Day {day} donor origin differs from committed stocks")
                    bottom_out = flow[15] - flow[6]
                    reply = [day, math.fsum(stocks[:6]), math.fsum(flow[:7]), math.fsum(flow[7:]),
                             bottom_out, -hydraulic[1], *hydraulic[2:], *stocks[:6]]
                    send(host, " ".join(map(str, reply)))
                    disposition, result = receive(host, host_log, {"DAILY_ACCEPTED", "DAILY_REFUSED"})
                    reported_column, reported_day, revision = map(int, result[disposition][:3])
                    committed = disposition == "DAILY_ACCEPTED"
                    if (reported_column, reported_day, revision) != (column, day, day-first if committed else day-first-1):
                        raise ValueError("Kernel disposition has incorrect ownership or revision")
                    budget = {
                        "column": column, "day": day, "committed": committed, "revision": revision,
                        "stock_end_cm": stocks[:6], "stock_start_cm": stocks[6:],
                        "external_flux_cm": flow, "pressure_head_cm": hydraulic[2:],
                        "groundwater_cm": hydraulic[0], "drainage_outward_cm": flow[13] + flow[14],
                        "bottom_outward_cm": bottom_out,
                        "independent_residual_cm": math.fsum([*flow[:7], *(-q for q in flow[7:]),
                                                               *stocks[6:], *(-q for q in stocks[:6])]),
                        "kernel_residual_cm": float(result[disposition][3]),
                    }
                    receipts.write(json.dumps(budget) + "\n")
                    receipts.flush()
                    if not committed:
                        refusal = budget
                        if host.wait(timeout=10) == 0:
                            raise RuntimeError("Kernel returned success after refusal")
                        break
                    accepted.append(budget)
                    previous[column-1] = stocks[:6]
                if refusal is not None:
                    break
        if refusal is None:
            send(host, "0 0")
            for worker, worker_log in workers:
                send(worker, "0")
                for line in worker.stdout:
                    worker_log.write(line)
                if worker.wait(timeout=10) != 100:
                    raise RuntimeError("Donor did not close normally")
            if host.wait(timeout=10) != 0:
                raise RuntimeError("Kernel did not close normally")
    return {
        "committed_days": len(accepted),
        "maximum_accepted_residual_cm": max((abs(row["kernel_residual_cm"]) for row in accepted), default=None),
        "first_refusal": refusal,
    }


def restart(donor, kernel, case, output):
    for name in ("continuous", "prefix", "resumed"):
        (output / name).mkdir()
    continuous = run(donor, kernel, case, output / "continuous", 4, checkpoint=True)
    prefix = run(donor, kernel, case, output / "prefix", 2, checkpoint=True)
    if continuous["committed_days"] != 4 or prefix["committed_days"] != 2:
        raise RuntimeError("Restart control refused before the comparison window")
    origin = output / "prefix/original"
    checkpoint = {name: sha(origin / name) for name in ("result.end", "macro.bin")}
    if checkpoint != {name: sha(output / "continuous/original" / name) for name in checkpoint}:
        raise RuntimeError("Selected checkpoint differs from continuous checkpoint")
    resumed = run(donor, kernel, case, output / "resumed", 4, checkpoint=True, origin=origin)
    if resumed["committed_days"] != 2:
        raise RuntimeError("Fresh kernel or donor refused the restored days")
    actual = [json.loads(row) for row in (output / "resumed/daily.jsonl").read_text().splitlines()]
    expected = [json.loads(row) for row in (output / "continuous/daily.jsonl").read_text().splitlines()][2:]
    if [dict(row, revision=row["revision"] + 2) for row in actual] != expected:
        raise RuntimeError("Fresh kernel/donor continuation differs from its continuous control")
    if checkpoint != {name: sha(origin / name) for name in checkpoint}:
        raise RuntimeError("Continuation mutated its accepted checkpoint")
    return {"checkpoint_day": 2, "end_day": 4, "checkpoint_sha256": checkpoint,
            "fresh_kernel_and_donor_exact": True, "committed_days": 2}


def isolation(donor, kernel, case, output, days):
    order = ("original", "shifted")
    datasets = {}
    for name, variants in [("alternating", order), ("control_a", order[:1]), ("control_b", order[1:])]:
        directory = output / name
        directory.mkdir()
        result = run(donor, kernel, case, directory, days, variants)
        if result["first_refusal"] is not None:
            raise RuntimeError(f"Isolation trial {name} refused: {result['first_refusal']['day']}")
        datasets[name] = [json.loads(row) for row in (directory / "daily.jsonl").read_text().splitlines()]
    for column, (variant, name) in enumerate(zip(order, ("control_a", "control_b")), 1):
        rows = [dict(row, column=1) for row in datasets["alternating"] if row["column"] == column]
        if rows != datasets[name]:
            raise RuntimeError(f"Alternating {variant} differs from its control")
        alternating = output / "alternating" / variant / "result_output.csv"
        control = output / name / variant / "result_output.csv"
        if records(alternating.read_text().splitlines()) != records(control.read_text().splitlines()):
            raise RuntimeError(f"Published records differ for {variant}")
    if datasets["control_a"] == datasets["control_b"]:
        raise RuntimeError("The isolation inputs did not exercise different trajectories")
    return {
        "days_per_column": days,
        "distinct_trajectories": True,
        "exact_against_each_separate_control": True,
        "shifted_cauchy_input_sha256": sha(output / "control_b/shifted/swap.bbc"),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--prepare-archive", type=Path, help="Build and run the unmodified nested-source reference")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--isolation", action="store_true")
    mode.add_argument("--restart", action="store_true")
    parser.add_argument("--trace-richards", action="store_true", help="Trace original HeadCalc residuals on day 15")
    parser.add_argument("--days", type=int, choices=range(1, 482), default=481, metavar="1..481")
    args = parser.parse_args()
    if args.prepare_archive is not None:
        prepare_reference(args.prepare_archive.resolve(), args.reference_work.resolve())
        return 0
    if args.output is None:
        parser.error("--output is required for a kernel run")
    output = args.output.resolve()
    output.mkdir()
    donor, kernel, case, inputs = build(args.reference_work.resolve(), output, args.trace_richards, args.restart)
    if args.restart:
        measurements = restart(donor, kernel, case, output)
    elif args.isolation:
        measurements = isolation(donor, kernel, case, output, args.days)
    else:
        measurements = run(donor, kernel, case, output, args.days)
    result = {
        "compiler": subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
        "source_sha256": {"SWAP.ZIP": DONOR_SOURCE_SHA, "TTUTIL.ZIP": TTUTIL_SOURCE_SHA},
        "input_sha256": inputs,
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "requested_days": 4 if args.restart else args.days,
        **measurements,
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    return 1 if result.get("first_refusal") is not None else 0


if __name__ == "__main__":
    raise SystemExit(main())

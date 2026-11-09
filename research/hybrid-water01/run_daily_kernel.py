"""Drive the original Andelst donor one day per SWAP5 transaction."""

import argparse
import contextlib
from datetime import date, timedelta
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
RESTART_WINDOWS = {2: 2, 20: 2, 256: 2, 365: 2, 453: 4}
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


def build(reference, output, trace_richards=False, checkpoint_day=None, budget_retry=False, trace_day=15, shared_pond_transfer=False):
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
    if checkpoint_day is not None:
        swap = output / "swap.f90"
        day_source = swap.read_text(encoding="cp1252")
        module = day_source[:day_source.index("end module hybrid_day_window") + len("end module hybrid_day_window")]
        render_checkpoint(donor_build, output, checkpoint_day, RESTART_WINDOWS[checkpoint_day])
        source = module + "\n\n" + swap.read_text(encoding="cp1252")
        source = replace(source, "use MOD_swap_base,       only: pathwork,",
                         "use hybrid_day_window, only: return_at_day_end\nuse MOD_swap_base,       only: pathwork,")
        anchor = "   end do\n\n!  Specific for exchange when called as DLL"
        source = replace(source, anchor, "      if (return_at_day_end .and. flDayEnd) return\n\n" + anchor)
        swap.write_text(source, encoding="cp1252")
        patched.insert(0, "macropore")
        if checkpoint_day >= 365:
            patched.append("swapoutput")

    if budget_retry:
        swap = output / "swap.f90"
        source = swap.read_text(encoding="cp1252")
        source = replace(source, "  logical :: return_at_day_end = .false.",
                         "  logical :: return_at_day_end = .false., budget_enabled = .false.\n"
                         "  real(8) :: budget_step = 0d0, budget_total = 0d0, budget_start = 0d0\n"
                         "  integer :: budget_retries = 0")
        source = replace(source, "only: return_at_day_end",
                         "only: return_at_day_end, budget_step, budget_total")
        source = replace(source, "         if (.NOT.fldecdt) call SoilWater(2)",
                         "         budget_step = 0d0\n         if (.NOT.fldecdt) call SoilWater(2)")
        source = replace(source, "      call SoilWater(3)",
                         "      budget_total = budget_total + budget_step\n      call SoilWater(3)")
        swap.write_text(source, encoding="cp1252")
        source = main.read_text(encoding="cp1252")
        source = replace(source, "only: return_at_day_end",
                         "only: return_at_day_end, budget_enabled, budget_total, budget_start, budget_retries")
        source = replace(source, "      window_start = t1900", """      window_start = t1900
      budget_enabled = window >= 15
      budget_start = t1900
      budget_total = 0d0
      budget_retries = 0""")
        source = replace(source, "      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900",
                         "      write(*,'(a,1x,i0,1x,es25.17e3)') 'HYBRID_BUDGET_RETRIES', budget_retries, budget_total\n"
                         "      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900")
        main.write_text(source, encoding="cp1252")
    if trace_richards:
        clock = START_CLOCK + trace_day - 1
        swap = output / "swap.f90"
        source = swap.read_text(encoding="cp1252")
        source = replace(source, "only: integral\n",
                         "only: integral, igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &\n"
                         "    iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo\n")
        source = replace(source, "only: fldecmprat\n", "only: fldecmprat, wasrdm1, wasrdm2, iQMpOutDrRap\n")
        source = replace(source, "only: snow\n", "only: snow, ssnow\n")
        if checkpoint_day is None:
            source = replace(source, "fl_cropharvest, fl_cropharvestday\n", "fl_cropharvest, fl_cropharvestday, sicact\n")
            source = replace(source, "gwl, gwlm1, dt, t1900", "gwl, gwlm1, dt, t1900, pond")
        source = replace(source, "outfil, tstart, tend,", "volact, outfil, tstart, tend,")
        source = replace(source, "      call integral(3)", f"""      call integral(3)
      if (t1900 >= {clock}d0 .and. t1900 < {clock+1}d0) then
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_STEP_LEDGER', t1900, dt, volact, pond, ssnow, sicact, wasrdm1, wasrdm2, &
          igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup,iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iQMpOutDrRap,iqbdo
      end if""")
        swap.write_text(source, encoding="cp1252")
        macro = output / "macropore.f90"
        source = (macro if macro.is_file() else donor_build / "swap-selected/macropore.f90").read_text(encoding="cp1252")
        marker = "WaSrMpDm(id) = dmax1(0.d0,WaSrMpDm(id))"
        a = source.lower().index("subroutine macrostate ()")
        b = source.lower().index("end subroutine macrostate", a)
        before, after = source[:a], source[a:b]
        after = replace(after, "use variables,     only: dt\n", "use variables,     only: dt, t1900\n")
        source = before + after + source[b:]
        source = replace(source, marker, f"""if (WaSrMpDm(id) < 0d0 .and. t1900 >= {clock}d0 .and. t1900 < {clock+1}d0) &
               write(*,'(a,1x,i0,2(1x,es25.17e3))') 'HYBRID_MACRO_CLAMP', id, t1900, WaSrMpDm(id)
            {marker}""")
        macro.write_text(source, encoding="cp1252")
        if "macropore" not in patched:
            patched.insert(0, "macropore")
    if trace_richards or budget_retry:
        source = (donor_build / "swap-selected/headcalc.f90").read_text(encoding="cp1252")
        anchor = "      if (.NOT.flnonconv) then      ! convergence has been reached"
        if trace_richards:
            source = replace(source, "!     test for waterbalance of ponding layer\n",
                             "!     test for waterbalance of ponding layer\n      deviat = 0d0\n")
            source = replace(source, anchor, anchor + "\n"
                             f"         if (t1900 >= {clock}d0 .and. t1900 < {clock+1}d0) &\n"
                             "           write(*,'(a,5(1x,es25.17e3))') 'HYBRID_RICHARDS', t1900, dt, sum1, Fmax, deviat")
        if budget_retry:
            source = replace(source, "subroutine headcalc \n", """subroutine headcalc
   use hybrid_day_window, only: budget_enabled, budget_step, budget_total, budget_start, budget_retries
   use hybrid_step_budget, only: projected_water_residual
""")
            source = replace(source, anchor, anchor + """
         ! Let the caller use the donor rollback before recording convergence.
         if (budget_enabled) then
            budget_step = projected_water_residual()
            if (dt > dtmin .and. abs(budget_total + budget_step) > 1d-6 * (t1900-budget_start+dt)) then
               fldecdt = .true.
               FlDecMpRat = .false.
               budget_retries = budget_retries + 1
               return
            end if
         end if""")
        if shared_pond_transfer:
            source = replace(source, "only: projected_water_residual",
                             "only: projected_water_residual, apply_surface_lateral_limit")
            source = replace(source, "   real(8)                          :: QMpLatSsSav",
                             "   real(8)                          :: QMpLatSsSav, lateral_before_pond")
            source = replace(source, "   if (FlRunoff .OR. ArMpSs > 0.0d0) call pondrunoff ()", """   lateral_before_pond = QMpLatSs
   if (FlRunoff .OR. ArMpSs > 0.0d0) call pondrunoff ()
   if (budget_enabled .and. swmacro == 1 .and. QMpLatSs < lateral_before_pond) &
     call apply_surface_lateral_limit(QMpLatSs)""")
        (output / "headcalc.f90").write_text(source, encoding="cp1252")
        patched.append("headcalc")

    if budget_retry:
        budget_source = Path(__file__).with_name("hybrid_step_budget.f90")
        subprocess.run([*common, "-c", str(budget_source)], cwd=output, check=True)
    for name in patched:
        subprocess.run([*common, "-c", name + ".f90"], cwd=output, check=True)
    donor = executable(output, "day_donor")
    replacements = {name + ".o": output / (name + ".o") for name in patched}
    subprocess.run(["gfortran", "-o", str(donor),
                    *(str(replacements.get(p.name, p)) for p in sorted(objects.glob("*.o"))),
                    *([str(output / "hybrid_step_budget.o")] if budget_retry else []),
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


def run(donor, kernel, case, output, days, variants=("original",), checkpoint_day=None, origin=None):
    first = checkpoint_day if origin is not None else 0
    accepted = []
    refusal = None
    with contextlib.ExitStack() as stack:
        workers = []
        previous = []
        initial_pressure = []
        for variant in variants:
            directory = output / variant
            shutil.copytree(case, directory)
            if checkpoint_day is not None:
                control = directory / "swap.swp"
                source = control.read_text(encoding="cp1252") + "\nSWENDTYPE = 2\n"
                if origin is not None:
                    start_date = date(1998, 1, 1) + timedelta(days=first)
                    source = replace(source, "TSTART = 1998-01-01", f"TSTART = {start_date}")
                    if first >= 365:
                        bbc = directory / "swap.bbc"
                        table = bbc.read_text(encoding="cp1252")
                        terminal = re.search(r"(?m)^([ \t]*1998-12-31[ \t]+)(-?\d+(?:\.\d+)?)[ \t]*$", table)
                        if terminal is None:
                            raise ValueError("Missing original terminal Cauchy head")
                        table = replace(table, terminal[0], terminal[0] + f"\n {start_date}  {terminal[2]}")
                        bbc.write_text(table, encoding="cp1252")
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
                    if "HYBRID_BUDGET_RETRIES" in response:
                        count, residual = response["HYBRID_BUDGET_RETRIES"]
                        budget["budget_step_retries"] = int(count)
                        budget["integrated_guard_residual_cm"] = float(residual)
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


def restart(donor, kernel, case, output, cut):
    end = cut + RESTART_WINDOWS[cut]
    for name in ("continuous", "resumed"):
        (output / name).mkdir()
    continuous = run(donor, kernel, case, output / "continuous", end, checkpoint_day=cut)
    if continuous["committed_days"] < cut:
        return dict(continuous, checkpoint_day=cut, fresh_kernel_and_donor_exact=False)
    refusal = continuous["first_refusal"]
    target = refusal["day"] if refusal is not None else end
    origin = output / "continuous/original"
    checkpoint = {name: sha(origin / name) for name in ("result.end", "macro.bin")}
    resumed = run(donor, kernel, case, output / "resumed", target, checkpoint_day=cut, origin=origin)
    if resumed["committed_days"] != continuous["committed_days"]-cut:
        raise RuntimeError("Fresh continuation accepted a different number of days")
    actual = [json.loads(row) for row in (output / "resumed/daily.jsonl").read_text().splitlines()]
    expected = [json.loads(row) for row in (output / "continuous/daily.jsonl").read_text().splitlines()][cut:]
    for a, e in zip(actual, expected, strict=True):
        if dict(a, revision=a["revision"] + cut) != e:
            fields = [k for k in e if k != "revision" and e[k] != a[k]]
            raise RuntimeError(f"Fresh continuation differs on day {e['day']}: {fields}")
    if checkpoint != {name: sha(origin / name) for name in checkpoint}:
        raise RuntimeError("Continuation mutated its accepted checkpoint")
    if refusal is not None:
        return dict(continuous, checkpoint_day=cut, end_day=target, checkpoint_sha256=checkpoint,
                    fresh_kernel_and_donor_exact=False, fresh_refusal_exact=True)
    expected_output = records((origin / "result_output.csv").read_text().splitlines())[-(end-cut):]
    resumed_output = output / "resumed/original/result_output.csv"
    if records(resumed_output.read_text().splitlines())[-(end-cut):] != expected_output:
        raise RuntimeError("Fresh continuation differs in its published daily records")
    return {"checkpoint_day": cut, "end_day": end, "checkpoint_sha256": checkpoint,
            "fresh_kernel_and_donor_exact": True, "committed_days": end-cut}


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
    mode.add_argument("--restart", dest="restart_at", action="store_const", const=2)
    mode.add_argument("--restart-at", type=int, choices=RESTART_WINDOWS)
    parser.add_argument("--budget-retry", action="store_true")
    parser.add_argument("--shared-pond-transfer", action="store_true")
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
    output = args.output.resolve()
    output.mkdir()
    donor, kernel, case, inputs = build(args.reference_work.resolve(), output, args.trace_richards, args.restart_at, args.budget_retry, args.trace_day, args.shared_pond_transfer)
    if args.restart_at is not None:
        measurements = restart(donor, kernel, case, output, args.restart_at)
    elif args.isolation:
        measurements = isolation(donor, kernel, case, output, args.days)
    else:
        measurements = run(donor, kernel, case, output, args.days)
    result = {
        "compiler": subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
        "source_sha256": {"SWAP.ZIP": DONOR_SOURCE_SHA, "TTUTIL.ZIP": TTUTIL_SOURCE_SHA},
        "input_sha256": inputs,
        "donor_executable_sha256": sha(donor), "kernel_executable_sha256": sha(kernel),
        "requested_days": args.restart_at + RESTART_WINDOWS[args.restart_at] if args.restart_at else args.days,
        "budget_retry": args.budget_retry,
        "shared_pond_transfer": args.shared_pond_transfer,
        **measurements,
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    return 1 if result.get("first_refusal") is not None else 0


if __name__ == "__main__":
    raise SystemExit(main())

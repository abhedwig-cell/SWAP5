"""Exercise external Cauchy head trials in isolated donor worker processes."""

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
from pathlib import Path

from probe_macro_checkpoint import compare_daily_ledger, render
from run_day_return import records, replace, sha


def build_worker(reference, audit, output, subday=False, handoff=False, kernel_flux=False):
    build = reference / "build"
    objects = build / "swap-obj"
    ttutil = build / "ttutil-obj"
    render(build, output, 2)
    swap = output / "swap.f90"
    anchor = "   if (sw_end == 1) call SoilWaterOutput(3)"
    source = replace(swap.read_text(encoding="cp1252"), "t1900 < 35799d0", "t1900 < 35801d0")
    source = replace(source, anchor, anchor +
                     "\n   if (swinco == 3 .and. sw_end == 1) call hybrid_macro_checkpoint(.false., t1900, dtold, sicact)")
    source = replace(source, "floutputshort, flzerointr,", "floutputshort, flzerointr, flZeroCumu,")
    source = source.replace("dtold, checkpoint_canopy)", "dtold, checkpoint_canopy, flZeroCumu)")
    source = source.replace("dtold, sicact)", "dtold, sicact, flZeroCumu)")
    if subday:
        source = replace(source, "      do while(fldtreduce)", """      do while(fldtreduce)
         if (swinco == 3 .and. tstart == 35799d0) dt = min(dt, 35799.5d0-t1900)""")
        source = replace(source, "      call TimeControl(3)", """      call TimeControl(3)
      if (swinco == 3 .and. tstart == 35799d0 .and. t1900 >= 35799.5d0) then
        if (t1900 /= 35799.5d0 .or. flDayEnd) error stop 'Invalid subday endpoint'
        call SoilWaterOutput(2)
        write(*,'(a,1x,f24.15)') 'HYBRID_SUBDAY_ENDPOINT', t1900
        return
      end if""")
    if handoff:
        source = """module andelst_noon_forcing
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  logical :: afternoon_active = .false.
  real(8) :: afternoon_head_cm = 0d0
contains
  subroutine set_afternoon_head()
    character(len=40) :: text
    integer :: status
    call get_environment_variable('SWAP_TRIAL_AFTERNOON_HEAD_CM',text,status=status)
    if (status == 1) return
    if (status /= 0) error stop 'Cannot read afternoon head'
    read(text,*,iostat=status) afternoon_head_cm
    if (status /= 0) error stop 'Invalid afternoon head'
    if (.not. ieee_is_finite(afternoon_head_cm)) error stop 'Nonfinite afternoon head'
    afternoon_active = .true.
  end subroutine
end module

""" + source
        source = replace(source, "use MOD_swap_base,       only: pathwork",
                         "use andelst_noon_forcing, only: set_afternoon_head\nuse MOD_swap_base,       only: pathwork")
        source = replace(source, "logical :: flError", "logical :: flError\ninteger :: handoff_status")
        source = replace(source, "      do while(fldtreduce)", """      do while(fldtreduce)
         if (swinco == 3 .and. tstart == 35799d0 .and. t1900 < 35799.5d0) &
           dt = min(dt, 35799.5d0-t1900)""")
        source = replace(source, "      call TimeControl(3)", """      call TimeControl(3)
      if (swinco == 3 .and. tstart == 35799d0 .and. t1900 == 35799.5d0) then
        if (flDayEnd) error stop 'Noon executed a day-end transition'
        write(*,'(a,1x,f16.6)') 'HYBRID_NOON_BOUNDARY', t1900
        call get_environment_variable('SWAP_TRIAL_NOON_HANDOFF',status=handoff_status)
        if (handoff_status == 0) return
        if (handoff_status /= 1) error stop 'Cannot read handoff control'
        call set_afternoon_head()
      end if""")
        main = (build / "swap-selected/swap_main.f90").read_text(encoding="cp1252")
        main = replace(main, "use MOD_swap_base, only:", "use andelst_noon_forcing, only: set_afternoon_head\nuse variables, only: t1900\nuse MOD_swap_base, only:")
        main = replace(main, "!  Close swap", """   if (iCaller == 0 .and. t1900 == 35799.5d0) then
      write(*,'(a,1x,f16.6)') 'HYBRID_DRIVER_RESUME', t1900
      call set_afternoon_head()
      call swap(iCaller, iTask, tstart_in, tend_in)
      if (t1900 <= 35799.5d0) error stop 'Driver did not advance after noon'
   end if

!  Close swap""")
        (output / "swap_main.f90").write_text(main, encoding="cp1252")
    if subday and kernel_flux:
        source = replace(source, "logical :: flError", """logical :: flError
integer :: trial_status
real(8), save :: stop_clock = 35799.5d0
real(8), save :: split_clock = 35799d0
character(len=32) :: trial_text""")
        source = replace(source, "if (iTask == 1) then", """if (iTask == 1) then
   call get_environment_variable('SWAP_TRIAL_FRACTION',trial_text,status=trial_status)
   if (trial_status == 0) then
      read(trial_text,*,iostat=trial_status) stop_clock
      if (trial_status /= 0) error stop 'Invalid probe stop clock'
      if (stop_clock <= 35799d0 .or. stop_clock > 35799.5d0) error stop 'Unsupported probe clock'
   end if
   call get_environment_variable('SWAP_TRIAL_SPLIT_CLOCK',trial_text,status=trial_status)
   if (trial_status == 0) then
      read(trial_text,*,iostat=trial_status) split_clock
      if (trial_status /= 0) error stop 'Invalid split clock'
      if (split_clock <= 35799d0 .or. split_clock >= stop_clock) error stop 'Unsupported split clock'
   end if""")
        source = replace(source, "dt = min(dt, 35799.5d0-t1900)", """dt = min(dt, stop_clock-t1900)
         if (swinco == 3 .and. tstart == 35799d0 .and. t1900 < split_clock) &
           dt = min(dt, split_clock-t1900)""")
        source = replace(source, "t1900 >= 35799.5d0", "t1900 >= stop_clock")
        source = replace(source, "t1900 /= 35799.5d0", "t1900 /= stop_clock")
        source = replace(source, "\n        call SoilWaterOutput(2)\n", """
        call SoilWaterOutput(2)
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_ENDPOINT_HEAD', h(1:numnod)
""")
    if kernel_flux:
        source = replace(source, "dtold, h, theta, pond, qrot", "dtold, h, theta, pond, qrot, qbot")
        source = replace(source, "      call SoilWater(3)", """      call SoilWater(3)
      if (t1900 >= 35799d0 .and. t1900 < 35801d0) &
        write(*,'(a,1x,es25.17e3)') 'HYBRID_TERMINAL_BOTTOM_INWARD', qbot""")
    swap.write_text(source, encoding="cp1252")
    macro = output / "macropore.f90"
    source = macro.read_text(encoding="cp1252")
    source = replace(source, "clock, old_step, canopy_stock)",
                     "clock, old_step, canopy_stock, zero_cumu)")
    source = replace(source, "intent(inout) :: old_step, canopy_stock",
                     "intent(inout) :: old_step, canopy_stock\n      logical, intent(inout) :: zero_cumu")
    source = replace(source, "stored_clock, old_step, canopy_stock",
                     "stored_clock, old_step, canopy_stock, zero_cumu")
    source = replace(source, "NumDm, clock, old_step, canopy_stock",
                     "NumDm, clock, old_step, canopy_stock, zero_cumu")
    if kernel_flux:
        source = replace(source, "      real(8) FrMpWalWetOld(MaDm,MaCp) \n", "")
    macro.write_text(source.replace("S5MAC003", "S5MAC004"), encoding="cp1252")
    source = (build / "swap-selected/boundbottom.f90").read_text(encoding="cp1252")
    source = replace(source, "      integer node, nodnumgwl", """      integer node, nodnumgwl
      integer, save :: head_mode = -1
      integer :: status
      character(len=40) :: external_head
      real(8), save :: forced_head""")
    source = replace(source, "        gwlmean = hdrain + shape_3*(gwl - hdrain)", """        if (head_mode == -1) then
          call get_environment_variable('SWAP_TRIAL_CAUCHY_HEAD_CM',external_head,status=status)
          head_mode = 0
          if (status == 0) then
            read(external_head,*,iostat=status) forced_head
            if (status /= 0) error stop 'Invalid external Cauchy head'
            head_mode = 1
          else if (status /= 1) then
            error stop 'Cannot read external Cauchy head'
          end if
        end if
        gwlmean = hdrain + shape_3*(gwl - hdrain)""")
    source = replace(source, "! ---   determine C-value (vertical resistance)",
                     "        if (head_mode == 1) deepgw = forced_head\n\n! ---   determine C-value (vertical resistance)")
    if handoff:
        source = replace(source, "      use MOD_grid,",
                         "      use andelst_noon_forcing, only: afternoon_active, afternoon_head_cm\n      use MOD_grid,")
        source = replace(source, "        if (head_mode == 1) deepgw = forced_head",
                         "        if (head_mode == 1) deepgw = forced_head\n"
                         "        if (afternoon_active) deepgw = afternoon_head_cm")
    (output / "boundbottom.f90").write_text(source, encoding="cp1252")
    patched = ("macropore", "swap", "boundbottom")
    if handoff:
        patched += ("swap_main",)
    for name in patched:
        subprocess.run(["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
                        "-ffree-line-length-none", "-fallow-argument-mismatch",
                        "-I", str(objects), "-I", str(ttutil), "-c", name + ".f90"],
                       cwd=output, check=True)
    replacements = {name + ".o": output / (name + ".o") for name in patched}
    replacements["swap_csv_output.o"] = audit / "swap_csv_output.o"
    executable = output / "andelst_transaction_worker"
    link = [str(replacements.get(path.name, path)) for path in sorted(objects.glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *link, str(ttutil / "libttutil.a")], check=True)
    return executable


def run_worker(case, executable, directory, origin=None, head=None,
               start="1998-01-03", end="1998-01-04", subday=False, handoff=False, afternoon_head=None, fraction=None, split_clock=None):
    if start not in ("1998-01-03", "1998-01-05", "1998-01-06") or end not in ("1998-01-04", "1998-01-05", "1998-01-06"):
        raise ValueError("Unsupported experimental window")
    shutil.copytree(case, directory)
    control = directory / "swap.swp"
    text = replace(control.read_text(encoding="cp1252"), "TEND = 1999-04-26", f"TEND = {end}")
    text += "\nSWENDTYPE = 2\n"
    environment = os.environ.copy()
    environment.pop("SWAP_TRIAL_CAUCHY_HEAD_CM", None)
    environment.pop("SWAP_TRIAL_NOON_HANDOFF", None)
    if handoff:
        environment["SWAP_TRIAL_NOON_HANDOFF"] = "1"
    environment.pop("SWAP_TRIAL_AFTERNOON_HEAD_CM", None)
    environment.pop("SWAP_TRIAL_FRACTION", None)
    environment.pop("SWAP_TRIAL_SPLIT_CLOCK", None)
    if fraction is not None:
        environment["SWAP_TRIAL_FRACTION"] = str(fraction)
    if split_clock is not None:
        environment["SWAP_TRIAL_SPLIT_CLOCK"] = str(split_clock)
    if afternoon_head is not None:
        if not math.isfinite(afternoon_head):
            raise ValueError("Afternoon head must be finite")
        environment["SWAP_TRIAL_AFTERNOON_HEAD_CM"] = str(afternoon_head)
    if origin is not None:
        (directory.parent / "first").symlink_to(origin, target_is_directory=True)
        text = replace(text, "TSTART = 1998-01-01", f"TSTART = {start}")
        text, count = re.subn(r"(?im)^(\s*SWINCO\s*=)\s*\d", r"\1 3", text)
        if count != 1:
            raise ValueError("Expected one SWINCO entry")
        text = replace(text, "SWEND = 0", "SWEND = 1")
        text += "SWINITYPE = 2\nINIFIL = '../first/result.end'\n"
    if head is not None:
        if not math.isfinite(head):
            raise ValueError("Cauchy head must be finite")
        environment["SWAP_TRIAL_CAUCHY_HEAD_CM"] = str(head)
    control.write_text(text, encoding="cp1252")
    run = subprocess.run([executable, "./swap.swp"], cwd=directory, env=environment,
                         capture_output=True, text=True, timeout=60)
    (directory / "stdout").write_text(run.stdout)
    (directory / "stderr").write_text(run.stderr)
    if run.returncode != 100 or not (directory / "swap.ok").is_file():
        raise RuntimeError(f"Worker failed: {directory}")
    if subday:
        lines = run.stdout.splitlines()
        endpoints = [float(line.split()[1]) for line in lines if line.startswith("HYBRID_SUBDAY_ENDPOINT ")]
        if endpoints != [35799.5 if fraction is None else fraction]:
            raise RuntimeError(f"Invalid worker end time: {endpoints}")
        def last_values(prefix):
            return next([float(value) for value in line.split()[1:]]
                        for line in reversed(lines) if line.startswith(prefix))
        levels = last_values("HYBRID_STOCK_FLUX ")
        fluxes = last_values("HYBRID_EXTERNAL_FLUX ")
        residual = math.fsum([*fluxes[:7], *(-v for v in fluxes[7:]),
                              *levels[6:], *(-v for v in levels[:6])])
        if not math.isfinite(residual) or abs(residual) > 1e-6:
            raise RuntimeError(f"Subday ledger does not close: {residual}")
        steps = [line for line in lines if line.startswith("HYBRID_ACCEPTED_TRAJECTORY ")]
        if not steps:
            raise RuntimeError("Missing subday accepted-step audit")
        return {
            "head_cm": head,
            "end_clock": endpoints[0],
            "accepted_steps": len(steps),
            "trajectory_sha256": hashlib.sha256("\n".join(steps).encode()).hexdigest(),
            "bottom_inward_cm": fluxes[6] - fluxes[15],
            "water_residual_cm": residual,
            "endpoint_files": {name: sha(directory / name) for name in ("result.end", "macro.bin")},
        }
    rows = records((directory / "result_output.csv").read_text().splitlines())
    if [line.split(",")[0] for line in rows[-2:]] != [end[:-2] + f"{int(end[-2:])-1:02}", end]:
        raise RuntimeError("Worker did not reach both requested days")
    flux = [line.split()[1:] for line in run.stdout.splitlines()
            if line.startswith("HYBRID_EXTERNAL_FLUX ")][-2:]
    trajectory = "\n".join(line for line in run.stdout.splitlines()
                           if line.startswith("HYBRID_ACCEPTED_TRAJECTORY "))
    if len(flux) != 2 or not trajectory:
        raise RuntimeError("Missing donor step or boundary-flux evidence")
    return {
        "head_cm": head,
        "accepted_trajectory_sha256": hashlib.sha256(trajectory.encode()).hexdigest(),
        "daily_records": rows[-2:],
        "bottom_inward_cm": [float(day[6]) - float(day[15]) for day in flux],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", required=True, type=Path)
    parser.add_argument("--day-return-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    reference, audit, output = (p.resolve() for p in
                                (args.reference_work, args.day_return_work, args.output))
    output.mkdir()
    executable = build_worker(reference, audit, output)
    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    origin = output / "origin"
    control = run_worker(case, executable, origin)
    checkpoint = {name: sha(origin / name) for name in ("result.end", "macro.bin")}

    verification = run_worker(case, executable, output / "control/resumed", origin)
    historical = records((reference / "run/3.macroporeflow/result_output.csv").read_text().splitlines())
    if verification != control or control["daily_records"] != historical[4:6]:
        raise RuntimeError("Inactive external control did not reproduce the donor")
    trials = {}
    for label, head in (("A", -50.0), ("B", -90.0), ("A_repeat", -50.0)):
        folder = output / label
        trials[label] = run_worker(case, executable, folder / "resumed", origin, head)
        ledger = compare_daily_ledger(folder)
        trials[label]["resumed_daily_residual_cm"] = ledger["resumed_daily_residual_cm"]
        trials[label]["endpoint_checkpoint"] = {
            name: sha(folder / "resumed" / name) for name in checkpoint
        }
        if not all(abs(value) <= 1e-6 for value in trials[label]["resumed_daily_residual_cm"]):
            raise RuntimeError(f"Unclosed worker ledger: {label}")
        if checkpoint != {name: sha(origin / name) for name in checkpoint}:
            raise RuntimeError(f"Committed origin changed in trial {label}")

    if trials["A"] != trials["A_repeat"]:
        raise RuntimeError("Interleaving another worker changed the repeated A trial")
    if not all(a > b for a, b in zip(trials["A"]["bottom_inward_cm"], trials["B"]["bottom_inward_cm"])):
        raise RuntimeError("Higher external head failed to increase inward water exchange")
    receipt = {
        "scope": "PROCESS_ISOLATED_DONOR_TRIALS_DAYS_3_AND_4",
        "executable_sha256": sha(executable),
        "origin_checkpoint": checkpoint,
        "inactive_control_exact": True,
        "trial_A": trials["A"],
        "trial_B": trials["B"],
        "repeat_A_after_B_exact": True,
        "selected": "A",
    }
    if (output / "committed").exists():
        raise RuntimeError("A trial was published before selection")
    candidate = output / "A/resumed"
    (candidate / "TRANSACTION.json").write_text(json.dumps(receipt, indent=2) + "\n")
    os.replace(candidate, output / "committed")
    if trials["A"]["endpoint_checkpoint"] != {
        name: sha(output / "committed" / name) for name in checkpoint
    }:
        raise RuntimeError("Published endpoint does not match selected trial")
    published = output / "committed"
    extended = output / "extended"
    replay = output / "reopened"
    run_worker(case, executable, extended / "resumed", origin, -50.0, end="1998-01-06")
    followup = run_worker(case, executable, replay / "resumed", published, -50.0,
                          start="1998-01-05", end="1998-01-06")
    def audit(folder, prefix, tail=None):
        lines = [line for line in (folder / "resumed/stdout").read_text().splitlines()
                 if line.startswith(prefix)]
        return lines if tail is None else lines[-tail:]
    continuous_steps = [line for line in audit(extended, "HYBRID_ACCEPTED_TRAJECTORY ")
                        if float(line.split()[1]) >= 35799.0]
    restarted_steps = audit(replay, "HYBRID_ACCEPTED_TRAJECTORY ")
    continuous_rows = records((extended / "resumed/result_output.csv").read_text().splitlines())[-2:]
    followup.update({
        "continuous_step_count": len(continuous_steps),
        "reopened_step_count": len(restarted_steps),
        "trajectory_exact": continuous_steps == restarted_steps,
        "published_days_exact": continuous_rows == followup["daily_records"],
        "daily_external_fluxes_exact": audit(extended, "HYBRID_EXTERNAL_FLUX ", 2)
                                      == audit(replay, "HYBRID_EXTERNAL_FLUX ", 2),
        "daily_stocks_exact": audit(extended, "HYBRID_STOCK_FLUX ", 2)
                             == audit(replay, "HYBRID_STOCK_FLUX ", 2),
        "continuous_daily_records": continuous_rows,
        "endpoint_checkpoint_exact": {
            name: sha(extended / "resumed" / name) == sha(replay / "resumed" / name)
            for name in checkpoint
        },
    })
    if trials["A"]["endpoint_checkpoint"] != {name: sha(published / name) for name in checkpoint}:
        raise RuntimeError("Reopening changed the published checkpoint")
    receipt["reopened_day4"] = followup
    receipt["followup_exact"] = (
        all(followup[key] for key in ("trajectory_exact", "published_days_exact",
                                      "daily_external_fluxes_exact", "daily_stocks_exact"))
        and all(followup["endpoint_checkpoint_exact"].values())
    )
    (output / "RESULT.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt, indent=2))
    if not receipt["followup_exact"]:
        raise RuntimeError("Reopening diverged from the continuous external-head window")


if __name__ == "__main__":
    main()

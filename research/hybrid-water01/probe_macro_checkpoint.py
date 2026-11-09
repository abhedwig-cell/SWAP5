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


def saved_names(text):
    return re.findall(r"^\s*[^!\n]+,\s*save\s*::\s*(\w+)\s*=", text,
                      flags=re.MULTILINE | re.IGNORECASE)


def render(build, output, checkpoint_day, days=2, *, runtime=False):
    selected = build / "swap-selected"
    macro = (selected / "macropore.f90").read_text(encoding="cp1252")
    variables = (selected / "variables.f90").read_text(encoding="cp1252")
    fields = saved_names(macro.split("! --- Macropore variables", 1)[1].split("contains", 1)[0])
    fields.remove("bma")  # Fortran output unit belongs to the new process.
    shared = saved_names(variables.split("module MOD_swap_mp\n", 1)[1].split("end module", 1)[0])
    fields.remove("NumDm")  # Geometry from initialization is the header authority.
    fields += shared
    if len(fields) != len(set(name.lower() for name in fields)):
        raise ValueError("Duplicate macropore checkpoint fields")
    payload = ", &\n      ".join(", ".join(fields[i:i+4]) for i in range(0, len(fields), 4))
    codec = f"""
    subroutine hybrid_macro_checkpoint(restoring, clock, old_step, canopy_stock)
      use MOD_swap_mp
      use MOD_grid, only: numnod
      implicit none
      logical, intent(in) :: restoring
      real(8), intent(in) :: clock
      real(8), intent(inout) :: old_step, canopy_stock
      integer :: unit, ios, nodes, domains
      real(8) :: stored_clock
      character(8) :: magic
      character :: trailing

      if (restoring) then
        open(newunit=unit,file='../first/macro.bin',access='stream',form='unformatted', &
             status='old',action='read',iostat=ios)
        if (ios /= 0) error stop 'Missing macro checkpoint'
        read(unit,iostat=ios) magic, nodes, domains, stored_clock, old_step, canopy_stock
        if (ios /= 0) error stop 'Incomplete macro checkpoint header'
        if (magic /= 'S5MAC003' .or. nodes /= numnod .or. domains /= NumDm .or. &
            stored_clock /= clock) error stop 'Incompatible macro checkpoint'
        read(unit,iostat=ios) &
      {payload}
        if (ios /= 0) error stop 'Incomplete macro checkpoint payload'
        read(unit,iostat=ios) trailing
        if (.not. is_iostat_end(ios)) error stop 'Trailing macro checkpoint bytes'
      else
        open(newunit=unit,file='macro.bin',access='stream',form='unformatted', &
             status='new',action='write')
        write(unit) 'S5MAC003', numnod, NumDm, clock, old_step, canopy_stock
        write(unit) &
      {payload}
      end if
      close(unit)
      write(*,'(a,*(1x,z16.16))') 'HYBRID_MACRO_DOMAIN_BITS', &
        transfer(WaUnMpDm(1:NumDm), [0_8], NumDm)
    end subroutine hybrid_macro_checkpoint
"""
    if runtime:
        codec = replace(codec, "../first/macro.bin", "macro-origin.bin")
    macro = replace(macro, "   contains\n", "   contains\n" + codec)
    (output / "macropore.f90").write_text(macro, encoding="cp1252")
    swap = (selected / "swap.f90").read_text(encoding="cp1252")
    swap = replace(swap, "only: macrostatevar, macropore",
                   "only: macrostatevar, macropore, hybrid_macro_checkpoint")
    swap = replace(swap, "logical :: flError", "logical :: flError\nreal(8), save :: checkpoint_canopy = -1d0")
    swap = replace(swap, "         if (swcrop == 1) call croprotation(2)",
                   """         if (swcrop == 1) call croprotation(2)
         if (checkpoint_canopy >= 0d0) then
           sicact = checkpoint_canopy
           checkpoint_canopy = -1d0
         end if""")
    swap = replace(swap, "   if (swmacro == 1) call MacroPore(1)",
                   "   if (swmacro == 1) call MacroPore(1)\n"
                   "   if (swmacro == 1 .and. fl_initialize) call hybrid_macro_checkpoint(.true., t1900, dtold, checkpoint_canopy)")
    swap = replace(swap, "gwl, gwlm1, dt, t1900", "gwl, gwlm1, dt, t1900, dtold, h, theta, pond, qrot")
    if runtime:
        swap = replace(swap, "fl_cropharvest, fl_cropharvestday",
                       "fl_cropharvest, fl_cropharvestday, sicact")
    else:
        swap = replace(swap, "only: meteo, interception_daily, peva, empreva, epond",
                       "only: meteo, interception_daily, peva, empreva, epond, nraidt, ptra, ptra_dry, ptra_wet, wfrac")
        swap = replace(swap, "fl_cropharvest, fl_cropharvestday", "fl_cropharvest, fl_cropharvestday, sicact, siccap, sw_inter")
        swap = replace(swap, "         call Meteo(3)", """         if (flDayStart .and. nint(t1900) == 35797) then
           write(*,*) "HYBRID_CANOPY", sicact, siccap, sw_inter
         end if
         call Meteo(3)""")
        swap = replace(swap, "use MOD_drain,           only: drain", "use MOD_drain,           only: drain, qdra")
        swap = replace(swap, "         if (.NOT.fldecdt) call SoilWater(2)", """         if (flDayStart .and. nint(t1900) == 35797 .and. .not. fldecdt) then
           write(*,'(a,*(1x,es25.17e3))') 'HYBRID_FIRST_INPUT', &
             nraidt, h(1:numnod), theta(1:numnod), qrot(1:numnod), sum(qdra(:,1:numnod), dim=1)
         end if
         if (.NOT.fldecdt) call SoilWater(2)""")
        swap = replace(swap, "!     calculate SoilWater rate/state variables",
                       """      if (t1900 >= 35797d0 .and. t1900 < 35799d0) then
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_ACCEPTED_TRAJECTORY', &
          t1900, dt, ptra, sicact, pond, h(1:numnod), theta(1:numnod), tsoil(1:numnod)
      end if
      if (flDayStart .and. nint(t1900) == 35797) then
        write(*,'(a,*(1x,es25.17e3))') 'HYBRID_FIRST_ACCEPTED', &
          t1900, dt, dtold, pond, gwl, epond, peva, ptra, ptra_dry, ptra_wet, wfrac, h(1:numnod), theta(1:numnod)
      end if
!     calculate SoilWater rate/state variables""")
    anchor = "   end do\n\n!  Specific for exchange when called as DLL"
    swap = replace(swap, anchor, """      if (swinco /= 3 .and. flDayEnd .and. t1900 == tstart + 2d0) then
        sw_end = 1
        call SoilWaterOutput(3)
        call hybrid_macro_checkpoint(.false., t1900, dtold, sicact)
        sw_end = 0
      end if
""" + anchor)
    if runtime:
        swap = replace(swap, "swinco /= 3 .and. flDayEnd .and. t1900 == tstart + 2d0",
                       "flDayEnd .and. t1900 == checkpoint_clock")
    else:
        clock = 35795 + checkpoint_day
        swap = swap.replace("35797", str(clock)).replace("35799", str(clock + days))
        swap = swap.replace("tstart + 2d0", f"tstart + {checkpoint_day}d0")
    (output / "swap.f90").write_text(swap, encoding="cp1252")
    if runtime or checkpoint_day >= 365:
        source = (selected / "swapoutput.f90").read_text(encoding="cp1252")
        source = replace(source,
                         "                  if (.NOT. fl_cropcalendar) call swap_error ('read_ini', 'no crop information in ini-file')",
                         ("                  if (.NOT. fl_cropcalendar .and. rw == 1 .and. tstart >= 36160d0) exit\n"
                          "                  if (.NOT. fl_cropcalendar) call swap_error ('read_ini', 'no crop information in ini-file')"
                          if runtime else "                  if (.NOT. fl_cropcalendar .and. rw == 1) exit"))
        (output / "swapoutput.f90").write_text(source, encoding="cp1252")
    return fields


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

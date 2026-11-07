"""Test an experimental B0 macropore continuation sidecar in a fresh process."""

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

from probe_legacy_restart import launch
from run_day_return import records, replace, sha


def saved_names(text):
    return re.findall(r"^\s*[^!\n]+,\s*save\s*::\s*(\w+)\s*=", text,
                      flags=re.MULTILINE | re.IGNORECASE)


def render(build, output):
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
    (output / "swap.f90").write_text(swap, encoding="cp1252")
    return fields


def domain_bits(path):
    rows = [line.split()[1:] for line in path.read_text().splitlines()
            if line.startswith("HYBRID_MACRO_DOMAIN_BITS ")]
    if len(rows) != 1 or len(rows[0]) != 5:
        raise ValueError(f"Missing five-domain checkpoint receipt: {path}")
    return rows[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", required=True, type=Path)
    parser.add_argument("--day-return-work", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    reference = args.reference_work.resolve()
    output = args.output.resolve()
    output.mkdir()
    build = reference / "build"
    obj = build / "swap-obj"
    tt = build / "ttutil-obj"
    fields = render(build, output)
    common = ["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
              "-ffree-line-length-none", "-fallow-argument-mismatch",
              "-I", str(output), "-I", str(obj), "-I", str(tt)]
    for name in ("macropore.f90", "swap.f90"):
        subprocess.run([*common, "-c", name], cwd=output, check=True)
    replacements = {name: output / name for name in ("macropore.o", "swap.o")}
    replacements["swap_csv_output.o"] = args.day_return_work.resolve() / "swap_csv_output.o"
    executable = output / "swap431_macro_checkpoint"
    objects = [str(replacements.get(path.name, path)) for path in sorted(obj.glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *objects, str(tt / "libttutil.a")], check=True)

    case = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
    first = output / "first"
    shutil.copytree(case, first)
    control = first / "swap.swp"
    control.write_text(control.read_text(encoding="cp1252").replace("TEND = 1999-04-26", "TEND = 1998-01-04")
                       + "\nSWENDTYPE = 2\n", encoding="cp1252")
    run = subprocess.run([executable, "./swap.swp"], cwd=first, capture_output=True, text=True, timeout=60)
    (first / "stdout").write_text(run.stdout)
    (first / "stderr").write_text(run.stderr)
    if run.returncode != 100 or not (first / "swap.ok").is_file():
        raise RuntimeError(f"Continuous donor refused: {run.returncode}")
    first_stock = [[float(v) for v in row.split()[1:7]] for row in run.stdout.splitlines()
                   if row.startswith("HYBRID_STOCK_FLUX ")]
    resumed, resumed_stock = launch(
        case, executable, output / "resumed",
        {"TSTART": "1998-01-03", "TEND": "1998-01-04", "SWINCO": "3"},
        "SWINITYPE = 2\nSWENDTYPE = 2\nINIFIL = '../first/result.end'",
    )
    expected_bits = domain_bits(output / "first/stdout")
    actual_bits = domain_bits(output / "resumed/stdout")
    if expected_bits != actual_bits or first_stock[2] != resumed_stock[0]:
        raise RuntimeError("Macropore checkpoint stock did not restore exactly")
    expected = json.loads((args.day_return_work / "RESULT.json").read_text())["original_daily_series"][4:6]
    if records((first / "result_output.csv").read_text().splitlines())[4:6] != expected:
        raise RuntimeError("Writing the checkpoint changed the continuous reference")
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
    result = {
        "scope": "EXPERIMENTAL_MACROPORE_SIDECAR_ONLY",
        "executable_sha256": sha(executable),
        "sidecar_sha256": sha(output / "first/macro.bin"),
        "fields": fields,
        "domain_stock_bits_at_write_and_restore": actual_bits,
        "stock_exact_before_first_step": True,
        "first_trial_input_max_abs_delta": input_delta,
        "first_accepted_columns": ["clock", "dt", "dtold", "pond", "gwl", "epond", "peva", "ptra", "ptra_dry", "ptra_wet", "wfrac"],
        "first_accepted_continuous": accepted[0][:11],
        "first_accepted_resumed": accepted[1][:11],
        "first_accepted_head_max_delta_cm": max(abs(float(a)-float(b)) for a,b in zip(accepted[0][11:123], accepted[1][11:123])),
        "accepted_step_counts": [len(rows) for rows in trajectories],
        "accepted_step_audit_exact": trajectories[0] == trajectories[1],
        "continuous_day3_4": expected,
        "resumed_day3_4": resumed[2:],
        "published_day3_4_exact": expected == resumed[2:],
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

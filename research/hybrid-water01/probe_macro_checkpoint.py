"""Test an experimental B0 macropore continuation sidecar in a fresh process."""

import argparse
import json
import re
import subprocess
from pathlib import Path

from probe_legacy_restart import launch
from run_day_return import replace, sha


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
    subroutine hybrid_macro_checkpoint(restoring, clock)
      use MOD_swap_mp
      use MOD_grid, only: numnod
      implicit none
      logical, intent(in) :: restoring
      real(8), intent(in) :: clock
      integer :: unit, ios, nodes, domains
      real(8) :: stored_clock
      character(8) :: magic
      character :: trailing

      if (restoring) then
        open(newunit=unit,file='../first/macro.bin',access='stream',form='unformatted', &
             status='old',action='read',iostat=ios)
        if (ios /= 0) error stop 'Missing macro checkpoint'
        read(unit,iostat=ios) magic, nodes, domains, stored_clock
        if (ios /= 0) error stop 'Incomplete macro checkpoint header'
        if (magic /= 'S5MAC001' .or. nodes /= numnod .or. domains /= NumDm .or. &
            stored_clock /= clock) error stop 'Incompatible macro checkpoint'
        read(unit,iostat=ios) &
      {payload}
        if (ios /= 0) error stop 'Incomplete macro checkpoint payload'
        read(unit,iostat=ios) trailing
        if (.not. is_iostat_end(ios)) error stop 'Trailing macro checkpoint bytes'
      else
        open(newunit=unit,file='macro.bin',access='stream',form='unformatted', &
             status='new',action='write')
        write(unit) 'S5MAC001', numnod, NumDm, clock
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
    swap = replace(swap, "   if (swmacro == 1) call MacroPore(1)",
                   "   if (swmacro == 1) call MacroPore(1)\n"
                   "   if (swmacro == 1 .and. fl_initialize) call hybrid_macro_checkpoint(.true., t1900)")
    swap = replace(swap, "   if (sw_end == 1) call SoilWaterOutput(3)",
                   "   if (sw_end == 1) call SoilWaterOutput(3)\n"
                   "   if (swmacro == 1 .and. sw_end == 1) call hybrid_macro_checkpoint(.false., t1900)")
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
    _, first_stock = launch(case, executable, output / "first",
                            {"TEND": "1998-01-02", "SWEND": "1"}, "SWENDTYPE = 2")
    resumed, resumed_stock = launch(
        case, executable, output / "resumed",
        {"TSTART": "1998-01-03", "TEND": "1998-01-04", "SWINCO": "3"},
        "SWINITYPE = 2\nSWENDTYPE = 2\nINIFIL = '../first/result.end'",
    )
    expected_bits = domain_bits(output / "first/stdout")
    actual_bits = domain_bits(output / "resumed/stdout")
    if expected_bits != actual_bits or first_stock[-1] != resumed_stock[0]:
        raise RuntimeError("Macropore checkpoint stock did not restore exactly")
    expected = json.loads((args.day_return_work / "RESULT.json").read_text())["original_daily_series"][4:6]
    result = {
        "scope": "EXPERIMENTAL_MACROPORE_SIDECAR_ONLY",
        "executable_sha256": sha(executable),
        "sidecar_sha256": sha(output / "first/macro.bin"),
        "fields": fields,
        "domain_stock_bits_at_write_and_restore": actual_bits,
        "stock_exact_before_first_step": True,
        "continuous_day3_4": expected,
        "resumed_day3_4": resumed[2:],
        "published_day3_4_exact": expected == resumed[2:],
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

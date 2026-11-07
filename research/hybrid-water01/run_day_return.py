"""Replay four original Andelst days with control returned at each day end.

Requires the verified distribution and compiler outputs from b0_source_runner.py.
This checks the donor call boundary. The donor still owns its live process state.
"""

import argparse
import gzip
import hashlib
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/vq"))
from reference_identity import verify_b0_archive


def replace(text, anchor, replacement):
    if text.count(anchor) != 1:
        raise ValueError(f"Expected a unique donor anchor: {anchor!r}")
    return text.replace(anchor, replacement)


def render(selected, out):
    swap = (selected / "swap.f90").read_text(encoding="cp1252")
    swap = """module hybrid_day_window
  implicit none
  logical :: return_at_day_end = .false.
end module hybrid_day_window

""" + swap
    swap = replace(swap, "use MOD_swap_base,       only: pathwork,",
                   "use hybrid_day_window, only: return_at_day_end\n"
                   "use MOD_swap_base,       only: pathwork,")
    anchor = ("   end do\n\n!  Specific for exchange when called as DLL\n"
              "   if (iCaller == 2) call handle_exchange(29, flError)")
    swap = replace(swap, anchor, "      if (return_at_day_end .and. flDayEnd) return\n\n" + anchor)
    (out / "swap.f90").write_text(swap, encoding="cp1252")

    main = (selected / "swap_main.f90").read_text(encoding="cp1252")
    main = replace(main, "use MOD_swap_base, only: unit_log",
                   "use hybrid_day_window, only: return_at_day_end\n"
                   "use Variables, only: t1900, flrunend\n"
                   "use MOD_swap_base, only: unit_log")
    main = replace(main, "integer              :: iTask",
                   "integer              :: iTask, window\nreal(8)              :: window_start")
    anchor = ("   if (iCaller == 0) call swap(iCaller, iTask, tstart_in, tend_in)\n"
              "   !!!if (iCaller /= 0) call dummy(iTask)\n\n!  Close swap")
    main = replace(main, anchor, """   return_at_day_end = .true.
   do window = 1, 4
      window_start = t1900
      if (flrunend) error stop 'Donor ended before requested day'
      call swap(iCaller, iTask, tstart_in, tend_in)
      if (abs(t1900 - window_start - 1d0) > 1d-8) error stop 'Unexpected day boundary'
      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900
   end do

!  Close swap""")
    (out / "swap_main.f90").write_text(main, encoding="cp1252")

    csv_source = (selected / "swap_csv_output.f90").read_text(encoding="cp1252")
    anchor = "   dstor_1    = wasrdm1 - iwasrdm1beg"
    csv_source = replace(csv_source, anchor, """   write(*,'(a,12(1x,es25.17e3))') 'HYBRID_STOCK_FLUX', &
      volact, pond, ssnow, sicact, wasrdm1, wasrdm2, &
      ivolbeg, ipondbeg, issnowbeg, isicbeg, iwasrdm1beg, iwasrdm2beg
   write(*,'(a,16(1x,es25.17e3))') 'HYBRID_EXTERNAL_FLUX', &
      igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &
      iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iQMpOutDrRap,iqbdo
""" + anchor)
    (out / "swap_csv_output.f90").write_text(csv_source, encoding="cp1252")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def records(lines):
    return [line for line in lines if line.strip() and not line.startswith("*")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not verify_b0_archive(args.archive)["qualified_identity"]:
        raise ValueError("Expected the immutable B0 distribution")

    output = args.output.resolve()
    output.mkdir()
    reference = args.reference_work.resolve()
    build = reference / "build"
    obj = build / "swap-obj"
    tt = build / "ttutil-obj"
    render(build / "swap-selected", output)
    common = ["gfortran", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
              "-ffree-line-length-none", "-fallow-argument-mismatch",
              "-I", str(obj), "-I", str(tt)]
    replacements = ["swap.o", "swap_main.o", "swap_csv_output.o"]
    for name in replacements:
        subprocess.run([*common, "-c", str(output / Path(name).with_suffix(".f90"))],
                       cwd=output, check=True)
    executable = output / "andelst_day_return"
    objects = [str(output / path.name if path.name in replacements else path)
               for path in sorted(obj.glob("*.o"))]
    subprocess.run(["gfortran", "-o", str(executable), *objects, str(tt / "libttutil.a")], check=True)

    case = output / "case"
    shutil.copytree(reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow", case)
    inputs = {str(path.relative_to(case)): sha(path) for path in sorted(case.rglob("*")) if path.is_file()}
    run = subprocess.run([str(executable), "./swap.swp"], cwd=case, text=True,
                         capture_output=True, timeout=90)
    (output / "stdout").write_text(run.stdout)
    (output / "stderr").write_text(run.stderr)
    if run.returncode != 100 or not (case / "swap.ok").is_file():
        raise RuntimeError(f"Donor window driver failed: {run.returncode}")
    markers = [line.split()[1] for line in run.stdout.splitlines() if line.startswith("HYBRID_DAY_RETURN ")]
    if markers != ["1", "2", "3", "4"]:
        raise RuntimeError(f"Expected four day returns, got {markers}")
    observed = records((case / "result_output.csv").read_text().splitlines())
    frozen = ROOT / "tests/qualification/ppa-wu05-migmac10-canonical-20261006/b0-comparison-output.csv.gz"
    with gzip.open(frozen, "rt") as file:
        expected = records(file.read().splitlines())
    if len(observed) != 6 or observed != expected[:6]:
        raise RuntimeError(f"Four-day output differs from B0: {observed!r}")

    stock = [[float(value) for value in line.split()[1:]]
             for line in run.stdout.splitlines() if line.startswith("HYBRID_STOCK_FLUX ")]
    flux = [[float(value) for value in line.split()[1:]]
            for line in run.stdout.splitlines() if line.startswith("HYBRID_EXTERNAL_FLUX ")]
    if len(stock) != 5 or len(flux) != 5:
        raise RuntimeError(f"Expected initial and four daily inventories: {len(stock)}, {len(flux)}")
    balances = [math.fsum([*flow[:7], *(-q for q in flow[7:]),
                           *levels[6:], *(-q for q in levels[:6])])
                for levels, flow in zip(stock[1:], flux[1:])]
    result = {
        "scope": "DONOR_DAY_RETURN_ONLY",
        "archive_sha256": sha(args.archive),
        "executable_sha256": sha(executable),
        "inputs_sha256": inputs,
        "original_daily_series": observed,
        "frozen_reference_sha256": sha(frozen),
        "day_returns": len(markers),
        "daily_water_residual_cm": balances,
        "daily_water_residual_pass": all(abs(value) <= 1e-6 for value in balances),
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

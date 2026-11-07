"""Test two serially interleaved B0 donors in separate GNU loader namespaces."""

import argparse
import ctypes as C
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

from probe_head_transaction import build_worker
from run_day_return import replace, sha

# One runtime namespace per donor isolates Fortran units, SAVE data and COMMON.
# Changing the current directory and stdout confines this experiment to serial calls.
def drive(library, directories):
    libdl = C.CDLL(None)
    libdl.dlmopen.argtypes = (C.c_long, C.c_char_p, C.c_int)
    libdl.dlmopen.restype = C.c_void_p
    libdl.dlsym.argtypes = (C.c_void_p, C.c_char_p)
    libdl.dlsym.restype = C.c_void_p
    libdl.dlerror.restype = C.c_char_p
    libdl.dlinfo.argtypes = (C.c_void_p, C.c_int, C.c_void_p)
    libdl.dlinfo.restype = C.c_int
    invoke_type = C.CFUNCTYPE(None, C.c_int, C.c_double, C.POINTER(C.c_double))
    donors = []
    for directory in directories:
        handle = libdl.dlmopen(-1, os.fsencode(library), os.RTLD_NOW | os.RTLD_LOCAL)
        if not handle:
            raise RuntimeError(libdl.dlerror())
        symbol = libdl.dlsym(handle, b"resident_swap")
        if not symbol:
            raise RuntimeError(libdl.dlerror())
        namespace = C.c_long()
        if libdl.dlinfo(handle, 1, C.byref(namespace)) != 0:  # RTLD_DI_LMID
            raise RuntimeError(libdl.dlerror())
        donors.append((Path(directory), invoke_type(symbol), namespace.value))
    if len({namespace for _, _, namespace in donors}) != len(donors):
        raise RuntimeError("Donors share a loader namespace")
    with os.fdopen(os.dup(1), "w") as stdout:
        for task, expected_clock in ((1, 35799.0), (2, 35799.5), (2, 35801.0), (3, 35801.0)):
            for directory, invoke, namespace in donors:
                head = float((directory / "head.txt").read_text())
                clock = C.c_double()
                os.chdir(directory)
                with (directory / "stdout").open("a") as trace:
                    os.dup2(trace.fileno(), 1)
                    invoke(task, head, C.byref(clock))
                os.dup2(stdout.fileno(), 1)
                if clock.value != expected_clock:
                    raise RuntimeError(f"Unexpected driver clock: {clock.value}")
                print(json.dumps({"pid": os.getpid(), "column": str(directory), "task": task,
                                  "clock": clock.value, "namespace": namespace}), flush=True)


def compile_library(reference, audit, output):
    objects = reference / "build/swap-obj"
    ttutil = reference / "build/ttutil-obj"
    selected = reference / "build/swap-selected"
    options = ["gfortran", "-fPIC", "-O2", "-cpp", "-Dlinux", "-finit-local-zero",
               "-ffree-line-length-none", "-fallow-argument-mismatch", "-I", str(objects), "-I", str(ttutil)]
    audited = output / "audit"
    audited.mkdir()
    subprocess.run([*options, "-c", str(audit / "swap_csv_output.f90")], cwd=audited, check=True)
    build_worker(reference, audited, output, handoff=True)
    swap = output / "swap.f90"
    source = swap.read_text(encoding="cp1252")
    start = source.index("        call get_environment_variable('SWAP_TRIAL_NOON_HANDOFF'")
    end = source.index("        call set_afternoon_head()", start) + len("        call set_afternoon_head()")
    swap.write_text(source[:start] + "        return" + source[end:], encoding="cp1252")
    driver = (selected / "swap_main.f90").read_text(encoding="cp1252")
    interface = driver.split("\ninterface\n", 1)[1].split("\nend interface", 1)[0]
    wrapper = f"""
subroutine resident_swap(task, head, clock) bind(c)
  use iso_c_binding, only: c_int, c_double
  use iso_fortran_env, only: output_unit
  use andelst_noon_forcing, only: afternoon_active, afternoon_head_cm
  use variables, only: t1900
  use MOD_swap_base, only: sw_animo, unit_log, unit_wrn
  implicit none
  integer(c_int), value :: task
  real(c_double), value :: head
  real(c_double), intent(out) :: clock
  real(8), save :: start_time = 0d0, end_time = 0d0
  integer, save :: input_unit
  integer :: log_unit, count
  integer, external :: getun
  interface
{interface}
  end interface
  if (task == 1) then
    sw_animo = 1
    log_unit = getun(400,900)
    input_unit = getun(log_unit+1,900)
    call fopens(log_unit,'reruns.log','new','del')
    call rdsets(input_unit,log_unit,'reruns.dat',count)
    if (count /= 0) error stop 'Rerun sets not supported by resident probe'
    close(log_unit,status='delete')
    call rdfrom(0,.true.)
  end if
  afternoon_active = .true.
  afternoon_head_cm = head
  call swap(0,task,start_time,end_time)
  clock = t1900
  if (task == 3) then
    close(input_unit)
    call CloseTempFil
    close(unit_log)
    close(unit_wrn)
  end if
  flush(output_unit)
end subroutine
"""
    (output / "resident.f90").write_text(wrapper)
    for name in ("swap.f90", "resident.f90"):
        subprocess.run([*options, "-c", name], cwd=output, check=True)
    replacements = {name + ".o": output / (name + ".o") for name in ("macropore", "swap", "boundbottom")}
    replacements["swap_csv_output.o"] = audited / "swap_csv_output.o"
    link = [str(replacements.get(path.name, path)) for path in sorted(objects.glob("*.o"))
            if path.name != "swap_main.o"]
    library = output / "andelst_resident.so"
    subprocess.run(["gfortran", "-shared", "-Wl,-z,defs", "-o", str(library),
                    str(output / "resident.o"), *link, str(ttutil / "libttutil.a")], check=True)
    return library


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-work", type=Path, required=True)
    parser.add_argument("--day-return-work", type=Path, required=True)
    parser.add_argument("--noon-work", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference, audit, noon, output = (path.resolve() for path in
                                       (args.reference_work, args.day_return_work, args.noon_work, args.output))
    output.mkdir()
    library = compile_library(reference, audit, output)
    case = noon / "fixed/resumed"
    origin = noon / "day4/resumed"
    checkpoint = {name: sha(origin / name) for name in ("result.end", "macro.bin")}
    if checkpoint != json.loads((noon / "RESULT.json").read_text())["day4_checkpoint"]:
        raise RuntimeError("The starting files do not match the verified noon case")

    def prepare(label, head):
        root = output / label
        directory = root / "resumed"
        if not (case / "swap.swp").is_file():
            raise ValueError(f"Missing reference case: {case}")
        original = reference / "distribution/SWAP_4.3.1/cases/3.macroporeflow"
        shutil.copytree(original, directory)
        (root / "first").symlink_to(origin, target_is_directory=True)
        shutil.copyfile(case / "swap.swp", directory / "swap.swp")
        (directory / "head.txt").write_text(str(head))
        return directory

    a = prepare("a_single", -50)
    b = prepare("b_single", -90)
    ab = prepare("a_interleaved", -50)
    ba = prepare("b_interleaved", -90)
    for label, columns in (("a", [a]), ("b", [b]), ("interleaved", [ab, ba])):
        driver = subprocess.run([sys.executable, __file__, "--drive", library, *columns],
                                capture_output=True, text=True, timeout=120)
        (output / (label + ".driver")).write_text(driver.stdout)
        if driver.returncode:
            raise RuntimeError(f"Resident driver failed: {label}: {driver.returncode}: {driver.stderr}")

    def summary(directory):
        if not (directory / "swap.ok").is_file():
            raise RuntimeError(f"Donor did not finish: {directory}")
        lines = (directory / "stdout").read_text().splitlines()
        selected = [line for line in lines if line.startswith(
            ("HYBRID_ACCEPTED_TRAJECTORY ", "HYBRID_STOCK_FLUX ", "HYBRID_EXTERNAL_FLUX "))]
        if not selected:
            raise RuntimeError("No observed donor trajectory")
        return selected, {name: sha(directory / name) for name in checkpoint}

    single_a, single_b = summary(a), summary(b)
    if single_a != summary(ab) or single_b != summary(ba) or single_a == single_b:
        raise RuntimeError("Interleaved donors diverged or did not respond independently")
    if checkpoint != {name: sha(origin / name) for name in checkpoint}:
        raise RuntimeError("The origin checkpoint changed")
    events = [json.loads(line) for line in (output / "interleaved.driver").read_text().splitlines()]
    if len(events) != 8 or len({event["pid"] for event in events}) != 1:
        raise RuntimeError("Donors did not alternate in one process")
    def residuals(directory):
        lines = (directory / "stdout").read_text().splitlines()
        stocks = [[float(v) for v in line.split()[1:]] for line in lines if line.startswith("HYBRID_STOCK_FLUX ")][-2:]
        fluxes = [[float(v) for v in line.split()[1:]] for line in lines if line.startswith("HYBRID_EXTERNAL_FLUX ")][-2:]
        if len(stocks) != 2 or len(fluxes) != 2:
            raise RuntimeError(f"Missing daily water ledger for {directory}")
        values = [math.fsum([*flow[:7], *(-v for v in flow[7:]),
                            *stock[6:], *(-v for v in stock[:6])])
                  for stock, flow in zip(stocks, fluxes)]
        if not all(math.isfinite(v) and abs(v) <= 1e-6 for v in values):
            raise RuntimeError(f"Unclosed resident donor water ledger: {values}")
        return values

    if single_a[1] != {name: sha(case / name) for name in checkpoint}:
        raise RuntimeError("Resident A endpoint does not reproduce the existing standalone donor")
    result = {
        "scope": "TWO_SERIAL_GNU_NAMESPACED_DONORS_ONE_PROCESS",
        "library_sha256": sha(library),
        "source_checkpoint": checkpoint,
        "a_head_cm": -50,
        "b_head_cm": -90,
        "a_audited_steps": sum(row.startswith("HYBRID_ACCEPTED_TRAJECTORY ") for row in single_a[0]),
        "b_audited_steps": sum(row.startswith("HYBRID_ACCEPTED_TRAJECTORY ") for row in single_b[0]),
        "a_daily_water_residual_cm": residuals(ab),
        "b_daily_water_residual_cm": residuals(ba),
        "a_standalone_endpoint_exact": True,
        "a_endpoint": single_a[1],
        "b_endpoint": single_b[1],
        "independent_controls_exact": True,
        "interleaved_calls": [{**event, "column": Path(event["column"]).parent.name} for event in events],
    }
    (output / "RESULT.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    if sys.argv[1:2] == ["--drive"]:
        drive(sys.argv[2], sys.argv[3:])
    else:
        main()

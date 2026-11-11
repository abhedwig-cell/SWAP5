"""Build and drive original project donors under SWAP5 day transactions."""

import contextlib
import ctypes
from dataclasses import dataclass
from datetime import date, timedelta
from hashlib import sha256
import json
import math
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
from donor_sources import records, render_checkpoint, render_day_return, replace, sha

APP = Path(__file__).resolve().parent

@dataclass(frozen=True)
class HybridProject:
    case: str
    model: str
    start_date: str
    nodes: int
    water_tolerance: float

    @property
    def start_clock(self):
        return (date.fromisoformat(self.start_date)-date(1900,1,1)).days+1

ANDELST = HybridProject('3.macroporeflow','HYBRID_ANDELST_WATER','1998-01-01',112,1e-6)
GRASSGROWTH = HybridProject('2.grassgrowth','HYBRID_GRASSGROWTH_WATER','1980-01-01',113,1e-10)
HUPSEL = HybridProject('1.hupselbrook','HYBRID_HUPSEL_WATER','2002-01-01',34,1e-10)
CASE = ANDELST.case
APPLICATION_MODEL = "HYBRID_ANDELST_WATER"
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


def build(reference, output, trace_richards=False, checkpoint_day=None, budget_retry=False, trace_day=15, shared_pond_transfer=False, refresh_macro_final=False, *, runtime_checkpoint=False, kernel_opt="O2", project=ANDELST):
    if project not in (ANDELST,GRASSGROWTH,HUPSEL):
        raise ValueError("Unregistered original hybrid project")
    if ((project!=ANDELST and any((trace_richards,shared_pond_transfer,refresh_macro_final)))
            or (project==GRASSGROWTH and budget_retry)):
        raise ValueError("Macro/Cauchy corrections require the Andelst project")
    distribution = reference / "distribution/SWAP_4.3.1"
    verify_source(distribution)
    case = distribution / "cases" / project.case
    pinned = ROOT / "reference/swap-4.3.1/projects" / project.case
    inputs = {p.relative_to(case).as_posix(): sha(p) for p in sorted(case.rglob("*")) if p.is_file()}
    expected = {p.relative_to(pinned).as_posix() for p in pinned.rglob("*") if p.is_file()}
    if set(inputs) != expected:
        raise ValueError("Original project file sets differ")
    for name in inputs:
        if (case / name).read_bytes().replace(b"\r\n", b"\n") != (pinned / name).read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError(f"Original project input differs: {name}")
    donor_build = reference / "build"
    objects = donor_build / "swap-obj"
    ttutil = donor_build / "ttutil-obj"
    render_day_return(donor_build / "swap-selected", output, nonmacro=project!=ANDELST, solute_ledger=project==HUPSEL)
    main = output / "swap_main.f90"
    source = main.read_text(encoding="cp1252")
    source = replace(source, "use Variables, only: t1900, flrunend",
                     "use iso_fortran_env, only: output_unit\n"
                     "use MOD_grid, only: numnod\n"
                     "use Variables, only: t1900, flrunend, h, gwl, qbot")
    if project==HUPSEL:
        source = replace(source, "use MOD_grid, only: numnod", "use MOD_solute, only: sampro\nuse MOD_grid, only: numnod")
    source = replace(source, "   do window = 1, 4", """   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)
   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900
   flush(output_unit)
   do
      read(*,*) window
      if (window == 0) exit""")
    source = replace(source, "      if (flrunend) error stop 'Donor ended before requested day'",
                     f"      if (flrunend .or. window_start /= {project.start_clock-1}d0+window) error stop 'Invalid requested day'")
    source = replace(source, "      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900",
                     """      write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)
      write(*,'(a,i0,1x,f18.8)') 'HYBRID_DAY_RETURN ', window, t1900
      flush(output_unit)""")
    if project==HUPSEL:
        source=replace(source, "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900",
                       "   write(*,'(a,1x,es25.17e3)') 'HYBRID_SOLUTE_READY', sampro\n"
                       "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900")
    main.write_text(source, encoding="cp1252")
    donor_flags = ["-O2", "-cpp", "-Dlinux", "-finit-local-zero",
                   "-ffree-line-length-none", "-fallow-argument-mismatch"]
    common = ["gfortran", *donor_flags, "-I", str(objects), "-I", str(ttutil)]
    patched = ["swap", "swap_main", "swap_csv_output"]
    if checkpoint_day is not None or runtime_checkpoint:
        swap = output / "swap.f90"
        day_source = swap.read_text(encoding="cp1252")
        module = day_source[:day_source.index("end module hybrid_day_window") + len("end module hybrid_day_window")]
        render_checkpoint(donor_build, output, checkpoint_day, RESTART_WINDOWS.get(checkpoint_day, 2),
                          runtime=runtime_checkpoint, nonmacro=project!=ANDELST)
        imports = "return_at_day_end"
        if runtime_checkpoint:
            imports += ", checkpoint_clock"
            module = replace(module, "end module hybrid_day_window",
                             "  real(8) :: checkpoint_clock = -1d0\nend module hybrid_day_window")
            source = replace(main.read_text(encoding="cp1252"), "only: return_at_day_end",
                             "only: return_at_day_end, checkpoint_clock")
            source = replace(source, "      read(*,*) window", "      read(*,*) window, checkpoint_clock")
            main.write_text(source, encoding="cp1252")
        source = module + "\n\n" + swap.read_text(encoding="cp1252")
        source = replace(source, "use MOD_swap_base,       only: pathwork,",
                         f"use hybrid_day_window, only: {imports}\nuse MOD_swap_base,       only: pathwork,")
        anchor = "   end do\n\n!  Specific for exchange when called as DLL"
        source = replace(source, anchor, "      if (return_at_day_end .and. flDayEnd) return\n\n" + anchor)
        swap.write_text(source, encoding="cp1252")
        patched.insert(0, "macropore")
        if runtime_checkpoint or checkpoint_day >= 365:
            patched.append("swapoutput")

    if project==HUPSEL and not budget_retry:raise ValueError("Hupsel requires its unchanged strict mass guard")
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
        if project==HUPSEL:source=replace(source,"budget_enabled = window >= 15","budget_enabled = .true.")
        main.write_text(source, encoding="cp1252")
    if trace_richards:
        clock = project.start_clock + trace_day - 1
        swap = output / "swap.f90"
        source = swap.read_text(encoding="cp1252")
        source = replace(source, "only: integral\n",
                         "only: integral, igrai,isnrai,igsnow,igird,irunon,iqssdi,iqbup, &\n"
                         "    iintc,iruno,iqrot,iepd,ievap,isubl,iqdra,iqbdo\n")
        source = replace(source, "only: fldecmprat\n", "only: fldecmprat, wasrdm1, wasrdm2, iQMpOutDrRap\n")
        source = replace(source, "only: snow\n", "only: snow, ssnow\n")
        if checkpoint_day is None and not runtime_checkpoint:
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
        if project==HUPSEL:
            source=replace(source,"1d-6 * (t1900-budget_start+dt)","1d-10 * (t1900-budget_start+dt)")
            # First finish the original Newton iteration at the required mass
            # boundary. Halving a converged-but-inaccurate step alone repeated
            # at dtmin without curing the observed day-one residual.
            source=replace(source,anchor,"""      if (budget_enabled .and. .not.flnonconv) then
         budget_step=projected_water_residual()
         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.
      end if
"""+anchor)
        if shared_pond_transfer:
            source = replace(source, "only: projected_water_residual",
                             "only: projected_water_residual, apply_surface_lateral_limit")
            source = replace(source, "   real(8)                          :: QMpLatSsSav",
                             "   real(8)                          :: QMpLatSsSav, lateral_before_pond")
            source = replace(source, "   if (FlRunoff .OR. ArMpSs > 0.0d0) call pondrunoff ()", """   lateral_before_pond = QMpLatSs
   if (FlRunoff .OR. ArMpSs > 0.0d0) call pondrunoff ()
   if (budget_enabled .and. budget_start >= 36051d0 .and. swmacro == 1 .and. QMpLatSs < lateral_before_pond) &
     call apply_surface_lateral_limit(QMpLatSs)""")
        if refresh_macro_final:
            # Exact scope of the paired day-458 replay. Keep the native
            # acceptance tests and retry policy for every residual evaluation.
            source = replace(source, "      if (iTask == 1 .OR. .NOT. flunsatok(3)) then",
                             "      if (iTask == 1 .OR. .NOT. flunsatok(3) .OR. &\n"
                             "          (t1900 >= 36252.9989d0 .AND. t1900 < 36253d0)) then")
        (output / "headcalc.f90").write_text(source, encoding="cp1252")
        patched.append("headcalc")

    if budget_retry:
        budget_source = APP / "hybrid_step_budget.f90"
        subprocess.run([*common, "-c", str(budget_source)], cwd=output, check=True)
    for name in patched:
        subprocess.run([*common, "-c", name + ".f90"], cwd=output, check=True)
    donor = executable(output, "day_donor")
    replacements = {name + ".o": output / (name + ".o") for name in patched}
    donor_objects = sorted(objects.glob("*.o"))
    ttutil_library = ttutil / "libttutil.a"
    subprocess.run(["gfortran", "-o", str(donor),
                    *(str(replacements.get(p.name, p)) for p in donor_objects),
                    *([str(output / "hybrid_step_budget.o")] if budget_retry else []),
                    str(ttutil_library)], cwd=output, check=True)
    adapter = APP / "donor_adapter.f90"
    sources = [
        "src/solver/mod_soil_water_accepted_step_direction_contract.f90",
        "src/transaction/mod_accepted_trajectory_directional_sensitivity.f90",
        "src/transaction/mod_accepted_trajectory_directional_publication.f90",
        "src/transaction/mod_transaction_reference.f90",
        "src/runtime/mod_canonical_contracts.f90",
        "src/runtime/mod_canonical_interval_runtime.f90",
        "src/kernel/mod_kernel_transactions.f90",
        "src/runtime/mod_groundwater_coupling_contract.f90",
        "src/runtime/mod_groundwater_swap_forcing_adapter.f90",
        "src/runtime/mod_groundwater_swap_transaction_participant.f90",
        "src/runtime/mod_groundwater_interface_mass_ledger.f90",
        "src/runtime/mod_fmr_soil_water_application_host.f90",
    ]
    kernel = executable(output, "day_kernel")
    kernel_flags = [f"-{kernel_opt}", "-ffree-line-length-none", "-fcheck=all"]
    driver = ROOT / "app/hybrid_water/main.f90"
    subprocess.run(["gfortran", *kernel_flags, *(str(ROOT / s) for s in sources),
                    str(adapter), str(driver), "-o", str(kernel)], cwd=output, check=True)

    # Use stable inputs because linking the same sources in another directory
    # need not reproduce executable bytes (for example PE timestamps).
    build_identity = {
        "compiler": subprocess.check_output(["gfortran", "--version"], text=True).splitlines()[0],
        "target": subprocess.check_output(["gfortran", "-dumpmachine"], text=True).strip(),
        "compiler_sha256": sha(Path(shutil.which("gfortran"))),
        "donor_flags": donor_flags,
        "kernel_flags": kernel_flags,
        "donor_generated": {name: sha(output / name) for name in (n + ".f90" for n in patched)},
        "donor_objects": {p.name: sha(p) for p in donor_objects if p.name not in replacements},
        "donor_modules": {p.name: sha(p) for p in sorted(objects.glob("*.mod"))},
        "ttutil_modules": {p.name: sha(p) for p in sorted(ttutil.glob("*.mod"))},
        "ttutil_library": sha(ttutil_library),
        "kernel_sources": [[name, sha(ROOT / name)] for name in sources],
        "adapter": sha(adapter),
        "driver": sha(driver),
        "host": sha(Path(__file__)),
    }
    if budget_retry:
        build_identity["budget_source"] = sha(budget_source)
    return donor, kernel, case, inputs, build_identity


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


CHECKPOINT_FILES = ("result.end", "macro.bin")


CHECKPOINT_SCHEMA = "swap5-hybrid-water-checkpoint-3"


def checkpoint_identity(inputs, build_identity, *, budget_retry, shared_pond_transfer, refresh_macro_final, project=ANDELST):
    return {
        "case": project.case, "inputs": inputs, "swap_source": DONOR_SOURCE_SHA, "ttutil_source": TTUTIL_SOURCE_SHA,
        "budget_retry": budget_retry, "shared_pond_transfer": shared_pond_transfer,
        "refresh_macro_final": refresh_macro_final, "build": build_identity,
    }


def restart_publisher(output):
    """Load the same durable file publisher used by native SWAP5 restarts."""
    source = ROOT / "app/support/restart_publish.c"
    library = output / ("restart_publish.dll" if os.name == "nt" else "restart_publish.so")
    flags = ["-shared", "-O2"]
    if os.name != "nt":
        flags.append("-fPIC")
    subprocess.run(["gcc", *flags, str(source), "-o", str(library)], check=True)
    publish = ctypes.CDLL(str(library)).swap5_restart_publish
    publish.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    publish.restype = ctypes.c_int
    return publish


def publish_checkpoint(output, donor_directory, receipt, binding, publish):
    """Publish both donor files only after the kernel accepts their day."""
    target = output / f"accepted-column-{receipt['column']}-day-{receipt['day']}.zip"
    if target.exists():
        raise FileExistsError(target)
    files = {name: (donor_directory / name).read_bytes() for name in CHECKPOINT_FILES}
    manifest = {
        "schema": CHECKPOINT_SCHEMA, "binding": binding, "receipt": receipt,
        "files": {name: sha256(payload).hexdigest() for name, payload in files.items()},
    }
    pending = target.with_suffix(".pending")
    try:
        with zipfile.ZipFile(pending, "x") as package:
            for name, payload in files.items():
                package.writestr(name, payload)
            package.writestr("checkpoint.json", json.dumps(manifest, indent=2) + "\n")
        encode = (lambda p: str(p).encode("utf-8")) if os.name == "nt" else os.fsencode
        stage = publish(encode(pending), encode(target))
        if stage:
            raise OSError(f"SWAP5 restart publication failed at stage {stage}: {target}")
    finally:
        pending.unlink(missing_ok=True)
    return target


def clear_checkpoint_stage(column, binding, number):
    """Recycle only this worker's already durably published auxiliary file."""
    stage = column.directory / "macro.bin"
    if not stage.exists():
        return
    if column.last_checkpoint is None:
        raise ValueError("Unowned checkpoint staging file")
    with zipfile.ZipFile(column.last_checkpoint) as package:
        if sorted(package.namelist()) != sorted((*CHECKPOINT_FILES, "checkpoint.json")):
            raise ValueError("Unexpected accepted checkpoint contents")
        manifest = json.loads(package.read("checkpoint.json"))
        files = {name: package.read(name) for name in CHECKPOINT_FILES}
    receipt = manifest["receipt"]
    if (manifest["schema"] != CHECKPOINT_SCHEMA or manifest["binding"] != binding
            or not receipt["committed"] or receipt["column"] != number
            or not 0 < receipt["day"] <= column.day
            or manifest["files"] != {name: sha256(data).hexdigest() for name, data in files.items()}
            or stage.read_bytes() != files["macro.bin"]):
        raise ValueError("Checkpoint staging is not backed by its accepted durable package")
    stage.unlink()


def verify_checkpoint(origin, cut, binding, unpacked):
    with zipfile.ZipFile(origin) as package:
        if sorted(package.namelist()) != sorted((*CHECKPOINT_FILES, "checkpoint.json")):
            raise ValueError("Unexpected accepted checkpoint contents")
        manifest = json.loads(package.read("checkpoint.json"))
        receipt = manifest["receipt"]
        files = {name: package.read(name) for name in CHECKPOINT_FILES}
    if (manifest["schema"] != CHECKPOINT_SCHEMA or manifest["binding"] != binding
            or not receipt["committed"] or receipt["day"] != cut
            or manifest["files"] != {name: sha256(data).hexdigest() for name, data in files.items()}):
        raise ValueError("Accepted checkpoint identity, day or content does not match")
    unpacked.mkdir()
    for name, data in files.items():
        (unpacked / name).write_bytes(data)
    return receipt


@dataclass(frozen=True)
class ColumnStart:
    variant: str = "original"
    day: int = 0
    origin: Path | None = None
    receipt: dict | None = None
    name: str | None = None


@dataclass
class DailyColumn:
    directory: Path
    variant: str
    worker: subprocess.Popen
    transcript: object
    day: int
    stocks: list
    pressure: list
    revision: int = 0
    refused: bool = False
    last_checkpoint: Path | None = None
    solute_stock: float | None = None


def prepare_column(case, directory, start, checkpoint_enabled, runtime, project=ANDELST):
    shutil.copytree(case, directory)
    if checkpoint_enabled or project==HUPSEL:
        control = directory / "swap.swp"
        source = control.read_text(encoding="cp1252")
        if project==HUPSEL:
            # Same output-only compatibility already owned by HIGH_PRECISION_REFERENCE.json.
            source=replace(source,"'WATBAL,ETTERMS,SOLBAL,GWL,S_CONC'",
                           "'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'")
            source,count=re.subn(r"(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1",r"\g<1>0",source)
            if count!=1:raise ValueError("Missing original monthly output setting")
            source += "\nNUM_DECIMALS = 12\n"
        source, count = re.subn(r"(?m)^([ \t]*SWENDTYPE[ \t]*=[ \t]*)[12]", r"\g<1>2", source)
        if count > 1:
            raise ValueError("Duplicate restart output setting")
        if count == 0:
            source += "\nSWENDTYPE = 2\n"
        if start.origin is not None:
            start_date = date.fromisoformat(project.start_date) + timedelta(days=start.day)
            source = replace(source, f"TSTART = {project.start_date}", f"TSTART = {start_date}")
            if project==ANDELST and start.day >= 365:
                bbc = directory / "swap.bbc"
                table = bbc.read_text(encoding="cp1252")
                terminal = re.search(r"(?m)^([ \t]*1998-12-31[ \t]+)(-?\d+(?:\.\d+)?)[ \t]*$", table)
                if terminal is None:
                    raise ValueError("Missing original terminal Cauchy head")
                table = replace(table, terminal[0], terminal[0] + f"\n {start_date}  {terminal[2]}")
                bbc.write_text(table, encoding="cp1252")
            source, count = re.subn(r"(?m)^([ \t]*SWINCO[ \t]*=[ \t]*)[12]", r"\g<1>3", source)
            if count != 1:
                raise ValueError("Missing restart setting")
            if runtime:
                shutil.copyfile(start.origin / "macro.bin", directory / "macro-origin.bin")
                shutil.copyfile(start.origin / "result.end", directory / "restart.end")
            source += "SWINITYPE = 2\n"
            inifil = "INIFIL = 'restart.end'" if runtime else "INIFIL = '../first/result.end'"
            source,count=re.subn(r"(?m)^[ \t]*INIFIL[ \t]*=.*$", inifil, source)
            if count>1:raise ValueError("Duplicate restart input setting")
            if count==0:source += inifil+"\n"
        control.write_text(source, encoding="cp1252")

    if start.variant == "shifted" and project==HUPSEL:
        drainage=directory/'swap.dra'
        source=drainage.read_text(encoding='cp1252')
        source,count=re.subn(r'(?m)^(  LM2 = )11[.]0( +!)',r'\g<1>11.001\2',source)
        if count!=1:raise ValueError('Missing original active drain spacing')
        drainage.write_text(source,encoding='cp1252')
        return
    if start.variant == "shifted":
        bbc = directory / "swap.bbc"
        source = bbc.read_text(encoding="cp1252")
        shifted_date = date(1998, 1, 1) + timedelta(days=start.day + (start.day < 365))
        if project==GRASSGROWTH:
            first_head=re.search(r"(?m)^[ \t]*(\d{4}-\d{2}-\d{2})[ \t]+-?\d",source)
            if first_head is None:raise ValueError("Missing original groundwater table")
            shifted_date=first_head[1]
        source, count = re.subn(
            rf"(?m)^([ \t]*{shifted_date}[ \t]+)(-?\d+(?:\.\d+)?)([ \t]*)$",
            lambda match: f"{match[1]}{float(match[2])+0.001:.6f}{match[3]}",
            source,
        )
        if count != 1:
            raise ValueError(f"Expected one Cauchy head at {shifted_date}")
        bbc.write_text(source, encoding="cp1252")


class DailyHost:
    """One kernel-owned transaction per requested day, with private legacy workers."""

    def __init__(self, stack, donor, kernel, case, output, starts, *, checkpoint_enabled=False,
                 runtime=False, binding=None, model=None, project=ANDELST):
        if project not in (ANDELST,GRASSGROWTH,HUPSEL):raise ValueError("Unregistered hybrid project")
        model=project.model if model is None else model
        if model!=project.model:raise ValueError("Model and project identity differ")
        self.project=project
        self.columns = []
        self.output = output
        self.binding = binding
        self.usable = False
        self.host, self.host_log = start_process(stack, [kernel, model]+(["explicit-project"] if project!=ANDELST else []), output, "kernel")
        _, selected = receive(self.host, self.host_log, {"DAILY_MODEL"})
        if selected["DAILY_MODEL"] != [model]:
            raise ValueError("Kernel selected a different soil water model")
        self.publish = restart_publisher(output) if binding is not None else None
        for start in starts:
            name = start.name or start.variant
            if Path(name).name != name or name in {".", ".."} or start.variant not in {"original", "shifted"}:
                raise ValueError("Invalid column directory or variant")
            if (start.origin is None) != (start.day == 0):
                raise ValueError("Column start day must match its origin")
            directory = output / name
            prepare_column(case, directory, start, checkpoint_enabled, runtime, project)
            worker, transcript = start_process(stack, [donor, "./swap.swp"], directory, "donor")
            _, initial = receive(worker, transcript, {"HYBRID_READY"})
            if list(map(float, initial["HYBRID_READY"])) != [project.start_clock + start.day]:
                raise ValueError("Incorrect donor initialization clock")
            stocks = list(map(float, initial["HYBRID_STOCK_FLUX"][:6]))
            pressure = list(map(float, initial["HYBRID_HYDRAULIC"][2:]))
            if len(stocks) != 6 or len(pressure) != project.nodes or not all(map(math.isfinite, stocks + pressure)):
                raise ValueError("Incomplete or nonfinite donor initial state")
            if start.receipt is not None and (
                    stocks != start.receipt["stock_end_cm"] or pressure != start.receipt["pressure_head_cm"]):
                raise ValueError("Restored donor state differs from the accepted checkpoint receipt")
            solute_stock=None
            if project==HUPSEL:
                solute_stock=float(initial['HYBRID_SOLUTE_READY'][0])
                if not math.isfinite(solute_stock):raise ValueError('Invalid initial solute stock')
                if start.receipt is not None and solute_stock!=start.receipt['solute_end_mg_cm2']:
                    raise ValueError('Restored solute stock differs from accepted receipt')
            self.columns.append(DailyColumn(directory, start.variant, worker, transcript, start.day, stocks, pressure,solute_stock=solute_stock))
        send(self.host, str(len(self.columns)))
        for column in self.columns:
            if project!=ANDELST:send(self.host,f"{project.nodes} {project.start_clock}")
            send(self.host, " ".join(map(str, [column.day, math.fsum(column.stocks), *column.stocks, *column.pressure])))
        self.usable = True

    def step(self, column, *, checkpoint=False):
        if not self.usable or not 1 <= column <= len(self.columns):
            raise ValueError("Host is closed or the requested column does not exist")
        current = self.columns[column-1]
        if current.refused or (checkpoint and (self.publish is None or current.variant != "original")):
            raise ValueError("Column was refused or checkpoint publication is unavailable")
        if checkpoint:
            target = self.output / f"accepted-column-{column}-day-{current.day+1}.zip"
            if target.exists():
                raise FileExistsError(target)
            clear_checkpoint_stage(current, self.binding, column)
        # A broken request/reply exchange cannot safely be retried on this host.
        self.usable = False
        day = current.day + 1
        send(self.host, f"{column} {day}")
        _, request = receive(self.host, self.host_log, {"DAILY_REQUEST"})
        if list(map(float, request["DAILY_REQUEST"])) != [column, day-1, self.project.start_clock+day-1, self.project.start_clock+day]:
            raise ValueError("Kernel request has incorrect ownership or clock")
        send(current.worker, f"{day} {self.project.start_clock+day if checkpoint else -1}")
        _, response = receive(current.worker, current.transcript, {"HYBRID_DAY_RETURN"})
        if list(map(float, response["HYBRID_DAY_RETURN"])) != [day, self.project.start_clock+day]:
            raise ValueError("Incorrect donor return clock")
        stocks = list(map(float, response["HYBRID_STOCK_FLUX"]))
        flow = list(map(float, response["HYBRID_EXTERNAL_FLUX"]))
        hydraulic = list(map(float, response["HYBRID_HYDRAULIC"]))
        if len(stocks) != 12 or len(flow) != 16 or len(hydraulic) != self.project.nodes+2:
            raise ValueError("Incomplete donor water budget")
        if not all(map(math.isfinite, stocks + flow + hydraulic)):
            raise ValueError("Nonfinite donor water budget")
        if stocks[6:] != current.stocks:
            raise ValueError(f"Day {day} donor origin differs from committed stocks")
        solute_budget={}
        if self.project==HUPSEL:
            ledger=list(map(float,response['HYBRID_SOLUTE_LEDGER']))
            uptake=list(map(float,response['HYBRID_UPTAKE']))
            if len(ledger)!=9 or len(uptake)!=6 or not all(map(math.isfinite,ledger+uptake)):
                raise ValueError('Missing or nonfinite solute/uptake accounting')
            end,delta,rain,irrig,bottom,drain,decay,root,reported=ledger
            residual=math.fsum([end,-current.solute_stock,-rain,-irrig,-bottom,drain,decay,root])
            if abs(residual)>1e-10 or abs(reported)>1e-10:
                raise ValueError('Original solute candidate exceeds unchanged1e-10 mass guard')
            solute_budget=dict(solute_end_mg_cm2=end,solute_start_mg_cm2=current.solute_stock,
                               solute_ledger_mg_cm2=ledger,solute_independent_residual_mg_cm2=residual,
                               uptake_terms_cm=uptake)
        bottom_out = flow[15] - flow[6]
        reply = [day, math.fsum(stocks[:6]), math.fsum(flow[:7]), math.fsum(flow[7:]),
                 bottom_out, -hydraulic[1], *hydraulic[2:], *stocks[:6]]
        send(self.host, " ".join(map(str, reply)))
        disposition, result = receive(self.host, self.host_log, {"DAILY_ACCEPTED", "DAILY_REFUSED"})
        reported_column, reported_day, revision = map(int, result[disposition][:3])
        committed = disposition == "DAILY_ACCEPTED"
        if (reported_column, reported_day, revision) != (column, day, current.revision + int(committed)):
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
        budget.update(solute_budget)
        if "HYBRID_BUDGET_RETRIES" in response:
            count, residual = response["HYBRID_BUDGET_RETRIES"]
            budget["budget_step_retries"] = int(count)
            budget["integrated_guard_residual_cm"] = float(residual)
        if committed:
            current.day = day
            current.revision = revision
            current.stocks = budget["stock_end_cm"].copy()
            current.pressure = budget["pressure_head_cm"].copy()
            if self.project==HUPSEL:current.solute_stock=budget["solute_end_mg_cm2"]
        else:
            current.refused = True
            stop_process(current.worker)
        self.usable = True
        if committed and checkpoint:
            current.last_checkpoint = publish_checkpoint(
                self.output, current.directory, budget, self.binding, self.publish)
        return budget

    def close(self):
        if not self.usable:
            raise ValueError("Cannot close a failed or already closed host")
        self.usable = False
        send(self.host, "0 0")
        for column in self.columns:
            if column.refused:
                continue
            send(column.worker, "0 -1")
            for line in column.worker.stdout:
                column.transcript.write(line)
            if column.worker.wait(timeout=10) != 100:
                raise RuntimeError("Donor did not close normally")
        if self.host.wait(timeout=10) != 0:
            raise RuntimeError("Kernel did not close normally")


def run(donor, kernel, case, output, days, variants=("original",), checkpoint_day=None, origin=None,
        checkpoint_binding=None, origin_receipt=None, *, runtime=False, publish_day=None,
        model=None, project=ANDELST):
    first = checkpoint_day if origin is not None else 0
    if origin is not None and not runtime:
        checkpoint_dir = output / "first"
        checkpoint_dir.mkdir()
        for name in CHECKPOINT_FILES:
            shutil.copyfile(origin / name, checkpoint_dir / name)
    starts = [ColumnStart(variant, first, origin, origin_receipt) for variant in variants]
    accepted = []
    refusal = None
    with contextlib.ExitStack() as stack:
        host = DailyHost(stack, donor, kernel, case, output, starts,
                         checkpoint_enabled=checkpoint_day is not None or runtime,
                         runtime=runtime, binding=checkpoint_binding, model=model, project=project)
        with (output / "daily.jsonl").open("w") as receipts:
            for day in range(first + 1, days + 1):
                for column in range(1, len(starts)+1):
                    budget = host.step(column, checkpoint=day == publish_day)
                    receipts.write(json.dumps(budget) + "\n")
                    receipts.flush()
                    if not budget["committed"]:
                        refusal = budget
                        break
                    accepted.append(budget)
                if refusal is not None:
                    break
        host.close()
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


def isolation(donor, kernel, case, output, days, cut=None, origin=None, *, runtime=False, origin_receipt=None):
    order = ("original", "shifted")
    datasets = {}
    for name, variants in [("alternating", order), ("control_a", order[:1]), ("control_b", order[1:])]:
        directory = output / name
        directory.mkdir()
        result = run(donor, kernel, case, directory, days, variants, checkpoint_day=cut, origin=origin,
                     runtime=runtime, origin_receipt=origin_receipt)
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
        "days_per_column": days - (cut or 0),
        "distinct_trajectories": True,
        "exact_against_each_separate_control": True,
        "shifted_cauchy_input_sha256": sha(output / "control_b/shifted/swap.bbc"),
    }

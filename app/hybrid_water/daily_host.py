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
from donor_sources import records, render_checkpoint, render_day_return, render_no_macro_timecontrol, render_physical_iteration_proposal, replace, sha
from solute_step_policy import LEGACY_SOLUTE_STEP_POLICY, TRANSACTIONAL_SOLUTE_STEP_POLICY, SOLUTE_STEP_POLICIES, render_transactional_cde

APP = Path(__file__).resolve().parent
ORIGINAL_TIME_POLICY = 'original-adaptive-day-seed-v1'
NO_MACRO_TIME_POLICY = 'configured-dtmax-daily-v1'
PHYSICAL_GROWTH_TIME_POLICY = 'configured-dtmax-physical-growth-v2'
from time_event_closure import POLICY as EVENT_CLOSURE_TIME_POLICY
from irrigation_pulse_time import POLICY as IRRIGATION_PULSE_TIME_POLICY
from local_wetting_time import POLICY as LOCAL_WETTING_TIME_POLICY
TIME_POLICIES = (ORIGINAL_TIME_POLICY,NO_MACRO_TIME_POLICY,PHYSICAL_GROWTH_TIME_POLICY,EVENT_CLOSURE_TIME_POLICY,IRRIGATION_PULSE_TIME_POLICY,LOCAL_WETTING_TIME_POLICY)
ORIGINAL_SOIL_TABLE_POLICY = 'original-tspack-v1'
PCHIP_SOIL_TABLE_POLICY = 'original-pchip-v1'
SOIL_TABLE_POLICIES = (ORIGINAL_SOIL_TABLE_POLICY,PCHIP_SOIL_TABLE_POLICY)
ALWAYS_WATER_POLISH = 'strict-water-always-polish-v1'
INTERIOR_WATER_POLISH = 'strict-water-half-interior-polish-v1'
from ria12_water_polish import POLICY as RIA12_WATER_POLISH
WATER_POLISH_POLICIES = (ALWAYS_WATER_POLISH, INTERIOR_WATER_POLISH, RIA12_WATER_POLISH)
NO_MACRO_FP_FLAGS = ('-ffp-contract=off', '-march=x86-64', '-mtune=generic')


def no_macro_fp_profile():
    """Explicit named x86-64 arithmetic policy, independent of compiler defaults."""
    return {'id': 'gnu-x86_64-separate-ops-v1', 'flags': list(NO_MACRO_FP_FLAGS)}

@dataclass(frozen=True)
class HybridProject:
    case: str
    model: str
    start_date: str
    nodes: int
    water_tolerance: float
    macro: bool = False
    solute: bool = False
    end_date: str = ''
    input_directory: str = ''
    input_inventory: tuple = ()
    time_step_policy: str = ORIGINAL_TIME_POLICY
    solute_step_policy: str = LEGACY_SOLUTE_STEP_POLICY
    soil_table_policy: str = ORIGINAL_SOIL_TABLE_POLICY
    age: bool = False
    original_output: bool = False
    age_irrigation_source: bool = False
    age_direct_soil_source: bool = False
    water_polish_policy: str = ALWAYS_WATER_POLISH

    @property
    def last_day(self):
        return (date.fromisoformat(self.end_date)-date.fromisoformat(self.start_date)).days+1

    @property
    def start_clock(self):
        return (date.fromisoformat(self.start_date)-date(1900,1,1)).days+1

ANDELST = HybridProject('3.macroporeflow','HYBRID_ANDELST_WATER','1998-01-01',112,1e-6,macro=True,end_date='1999-04-26')
GRASSGROWTH = HybridProject('2.grassgrowth','HYBRID_GRASSGROWTH_WATER','1980-01-01',113,1e-10,end_date='1984-12-31',time_step_policy=NO_MACRO_TIME_POLICY)
HUPSEL = HybridProject('1.hupselbrook','HYBRID_HUPSEL_WATER','2002-01-01',34,1e-10,solute=True,end_date='2004-12-31',time_step_policy=NO_MACRO_TIME_POLICY)
SALTFARM = HybridProject('4.salinitystress-04dS','HYBRID_SALTFARM_WATER','2012-01-01',195,1e-10,solute=True,end_date='2015-12-31',time_step_policy=PHYSICAL_GROWTH_TIME_POLICY,water_polish_policy=INTERIOR_WATER_POLISH)
PROJECTS = (ANDELST,GRASSGROWTH,HUPSEL,SALTFARM)


def project_case(reference, project):
    if project.input_directory:
        from experimental_project import validate
        return validate(project)
    if project not in PROJECTS:
        raise ValueError('Unregistered original hybrid project')
    return Path(reference)/'distribution/SWAP_4.3.1/cases'/project.case


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


def build(reference, output, trace_richards=False, checkpoint_day=None, budget_retry=False, trace_day=15, shared_pond_transfer=False, refresh_macro_final=False, *, runtime_checkpoint=False, kernel_opt="O2", project=ANDELST, donor_opt="O2"):
    if project.soil_table_policy not in SOIL_TABLE_POLICIES:
        raise ValueError('Unknown original soil-table interpolation policy')
    if project.soil_table_policy != ORIGINAL_SOIL_TABLE_POLICY and (not project.input_directory or project.macro):
        raise ValueError('Original PCHIP selection requires explicit experimental soil tables')
    if project.solute_step_policy not in SOLUTE_STEP_POLICIES:
        raise ValueError('Unknown chemical substep policy')
    if project.solute_step_policy != LEGACY_SOLUTE_STEP_POLICY and (not project.input_directory or project.macro or not project.solute):
        raise ValueError('Transactional chemical substeps require explicit experimental no-macro SWSOLU1')
    if not project.macro and project.time_step_policy not in TIME_POLICIES:
        raise ValueError('Unknown no-macro daily time-step policy')
    case = project_case(reference, project)
    strict_water = project.solute or bool(project.input_directory and budget_retry)
    if project.water_polish_policy not in WATER_POLISH_POLICIES:
        raise ValueError('Unknown strict-water polishing policy')
    if project.water_polish_policy == INTERIOR_WATER_POLISH and (project.macro or not strict_water or not budget_retry):
        raise ValueError('Interior polishing requires the strict no-macro water receipt')
    if project.water_polish_policy == RIA12_WATER_POLISH:
        if not strict_water or not budget_retry:
            raise ValueError('RIA water polishing requires the unchanged strict-water receipt')
        from ria12_water_polish import require_project
        require_project(project)
    management_state = project.solute or bool(project.input_directory)
    if donor_opt not in ('O0','O2') or (donor_opt!='O2' and project.macro):
        raise ValueError('Generated-donor optimization requires explicit no-macro qualification')
    if ((not project.macro and any((trace_richards,shared_pond_transfer,refresh_macro_final)))
            or (not project.macro and not project.solute and budget_retry and not project.input_directory)):
        raise ValueError("Macro/Cauchy corrections require the Andelst project")
    distribution = reference / "distribution/SWAP_4.3.1"
    verify_source(distribution)
    if not project.macro:
        provider = json.loads((reference/'PREPARED.json').read_text())
        if provider.get('floating_point_profile') != no_macro_fp_profile():
            raise ValueError('Prepared floating-point profile differs; prepare fresh no-macro sources')
    pinned = case if project.input_directory else ROOT / "reference/swap-4.3.1/projects" / project.case
    if not case.exists():shutil.copytree(pinned,case)
    inputs = {p.relative_to(case).as_posix(): sha(p) for p in sorted(case.rglob("*")) if p.is_file()}
    expected = {p.relative_to(pinned).as_posix() for p in pinned.rglob("*") if p.is_file()}
    if set(inputs) != expected:
        raise ValueError("Original project file sets differ")
    for name in inputs:
        if (case / name).read_bytes().replace(b"\r\n", b"\n") != (pinned / name).read_bytes().replace(b"\r\n", b"\n"):
            raise ValueError(f"Original project input differs: {name}")
    control=(case/'swap.swp').read_text(encoding='cp1252')
    def selector(name):
        values=re.findall(r'(?mi)^\s*'+name+r'\s*=\s*(\d+)\b',control)
        if len(values)!=1:raise ValueError('Missing/ambiguous physical selector: '+name)
        return int(values[0])
    from micro_lookup_state import enabled as micro_lookup_enabled
    micro_state=micro_lookup_enabled(project)
    from prescribed_head_flux_boundary import selected_boundary
    lower_boundary=selected_boundary(project)
    from prescribed_snow_boundary import enabled as paired_snow_enabled
    paired_snow=paired_snow_enabled(project)
    lower_receipt=lower_boundary is not None
    from fixed_irrigation_file import enabled as fixed_irrigation_file_enabled
    fixed_file=fixed_irrigation_file_enabled(project)
    from scheduled_subsurface_irrigation import enabled as scheduled_subsurface_enabled
    scheduled_subsurface=scheduled_subsurface_enabled(project)
    from conserved_subsurface_solute import enabled as chemical_source_enabled, correction as chemical_correction
    chemical_fixed=chemical_source_enabled(project)
    from conserved_scheduled_subsurface_solute import enabled as chemical_scheduled_enabled
    chemical_scheduled=chemical_scheduled_enabled(project)
    chemical_source=chemical_fixed or chemical_scheduled
    from conserved_aquifer_solute import enabled as aquifer_enabled, correction as aquifer_correction
    aquifer_source=aquifer_enabled(project)
    import groundwater_water_output as age_calendar_owner
    if age_calendar_owner.selection(project) is None:
        import original_output_aquifer as age_calendar_owner
    if age_calendar_owner.selection(project) is None:
        import original_output_hysteresis as age_calendar_owner
    if age_calendar_owner.selection(project) is None:
        import original_output as age_calendar_owner
        if age_calendar_owner.selection(project) is None:
            import age_output_clock as age_calendar_owner
            if age_calendar_owner.selection(project) is None:
                import age_output_schedule as age_calendar_owner
                if age_calendar_owner.selection(project) is None:
                    import age_output_calendar as age_calendar_owner
    age_calendar=age_calendar_owner.selection(project)
    import age_direct_soil_source as current_age_source
    age_source=current_age_source.selection(project)
    if lower_receipt and not budget_retry:raise ValueError('Implicit lower boundary requires independent strict trial receipt')
    if selector('SWMACRO')!=int(project.macro) or selector('SWSOLU')!=(2 if project.age else int(project.solute)):
        raise ValueError('Original physical options disagree with declared project; no implicit disabling')
    soil_tables = selector('SWSOPHY')==1
    if project.soil_table_policy != ORIGINAL_SOIL_TABLE_POLICY and not soil_tables:
        raise ValueError('Soil-table interpolation policy requires active SWSOPHY1')
    donor_build = reference / "build"
    objects = donor_build / "swap-obj"
    ttutil = donor_build / "ttutil-obj"
    render_day_return(donor_build / "swap-selected", output, nonmacro=not project.macro, solute_ledger=project.solute)
    main = output / "swap_main.f90"
    source = main.read_text(encoding="cp1252")
    source = replace(source, "use Variables, only: t1900, flrunend",
                     "use iso_fortran_env, only: output_unit\n"
                     "use MOD_grid, only: numnod\n"
                     "use Variables, only: t1900, flrunend, h, gwl, qbot")
    if project.solute:
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
    if project.solute:
        source=replace(source, "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900",
                       "   write(*,'(a,1x,es25.17e3)') 'HYBRID_SOLUTE_READY', sampro\n"
                       "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900")
    if aquifer_source:
        source=replace(source,'use MOD_solute, only: sampro','use MOD_solute, only: sampro, hybrid_aquifer_cumulative')
        source=replace(source,'real(8)              :: window_start','real(8)              :: window_start\nreal(8)::aq_initial(7)')
        source=replace(source,"   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900",
                       "   call hybrid_aquifer_cumulative(aq_initial)\n"
                       "   write(*,'(a,7(1x,es25.17e3))')'HYBRID_AQUIFER_CUMULATIVE',aq_initial\n"
                       "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900")
    if project.age:
        source=replace(source,'use MOD_grid, only: numnod','use MOD_solute,only:hybrid_age_observe,hybrid_age_effluent_observe\nuse MOD_grid, only: numnod')
        source=replace(source,'real(8)              :: window_start','real(8)              :: window_start\nreal(8)::age_initial(11),age_effluent_initial(24)')
        source=replace(source,"   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900",
                       "   call hybrid_age_observe(age_initial)\n"
                       "   write(*,'(a,11(1x,es25.17e3))')'HYBRID_AGE_CUMULATIVE',age_initial\n"
                       "   call hybrid_age_effluent_observe(age_effluent_initial)\n"
                       "   write(*,'(a,24(1x,es25.17e3))')'HYBRID_AGE_EFFLUENT',age_effluent_initial\n"
                       "   write(*,'(a,1x,f16.8)') 'HYBRID_READY', t1900")
    main.write_text(source, encoding="cp1252")
    if aquifer_source:
        csv=output/'swap_csv_output.f90'
        csv.write_bytes(aquifer_correction().reference_csv(csv.read_bytes(),prefix='HYBRID_AQUIFER_CUMULATIVE',include_soil=False))
    donor_flags = [f"-{donor_opt}", "-cpp", "-Dlinux", "-finit-local-zero",
                   "-ffree-line-length-none", "-fallow-argument-mismatch"]
    if not project.macro:donor_flags.extend(NO_MACRO_FP_FLAGS)
    common = ["gfortran", *donor_flags, "-I", str(objects), "-I", str(ttutil)]
    patched = ["swap", "swap_main", "swap_csv_output"]
    if project.time_step_policy == LOCAL_WETTING_TIME_POLICY:
        from local_wetting_time import source as wetting_source
        if project.macro or not project.input_directory:
            raise ValueError('Local wetting policy requires explicit experimental input')
        (output/'timecontrol.f90').write_bytes(wetting_source((donor_build/'swap-selected/timecontrol.f90').read_bytes()))
        patched.insert(0,'timecontrol')
    if project.time_step_policy == IRRIGATION_PULSE_TIME_POLICY:
        from irrigation_pulse_time import source as pulse_source
        if project.macro or not project.input_directory:
            raise ValueError('Irrigation pulse policy requires explicit experimental input')
        (output/'timecontrol.f90').write_bytes(pulse_source((donor_build/'swap-selected/timecontrol.f90').read_bytes()))
        patched.insert(0,'timecontrol')
    if project.time_step_policy == EVENT_CLOSURE_TIME_POLICY:
        from time_event_closure import source as event_source
        if project.macro or not project.input_directory:
            raise ValueError('Event closure requires explicit bounded experimental input')
        (output/'timecontrol.f90').write_bytes(event_source((donor_build/'swap-selected/timecontrol.f90').read_bytes()))
        patched.insert(0,'timecontrol')
    if project.soil_table_policy == PCHIP_SOIL_TABLE_POLICY:
        source=(donor_build/'swap-selected/sptabulated.f90').read_text(encoding='cp1252')
        source=replace(source,'logical, parameter :: use_TSPACK = .TRUE.',
                              'logical, parameter :: use_TSPACK = .FALSE.')
        (output/'sptabulated.f90').write_text(source,encoding='cp1252')
        patched.insert(0,'sptabulated')
    if not project.macro and project.time_step_policy in (NO_MACRO_TIME_POLICY,PHYSICAL_GROWTH_TIME_POLICY):
        render_no_macro_timecontrol(donor_build/'swap-selected',output)
        patched.insert(0,'timecontrol')
    if checkpoint_day is not None or runtime_checkpoint:
        swap = output / "swap.f90"
        day_source = swap.read_text(encoding="cp1252")
        module = day_source[:day_source.index("end module hybrid_day_window") + len("end module hybrid_day_window")]
        from hydraulic_vapor import describe as describe_vapor
        vapor_history = describe_vapor(project) is not None
        render_checkpoint(donor_build, output, checkpoint_day, RESTART_WINDOWS.get(checkpoint_day, 2),
                          runtime=runtime_checkpoint, nonmacro=not project.macro, solute_state=project.solute, age_state=project.age,
                          hydraulic_history=bool(project.input_directory and selector('SWHYST')>0) or vapor_history,
                          thermal_history=bool(project.input_directory and selector('SWSNOW')>0) or vapor_history,
                          management_state=management_state,
                          plant_et_state=bool(project.input_directory and selector('SWCFBS')==1),
                          micro_lookup_state=micro_state,
                          scheduled_pond_history=bool(micro_state and selector('SWPONDMX')==1))
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
        if not project.macro and re.search(r'(?mi)^\s*SWINCO\s*=\s*3\b',control):
            if re.search(r"(?mi)^\s*INIFIL\s*=\s*'restart.end'",control):
                raise ValueError('Original native input collides with reserved full-restart filename')
            source=replace(source,'use MOD_swap_base,       only: pathwork,',
                           'use MOD_swap_base, only: inifilnam\nuse MOD_swap_base,       only: pathwork,')
            source=replace(source,'swmacro == 0 .and. fl_initialize)',
                           "swmacro == 0 .and. fl_initialize .and. trim(inifilnam)=='restart.end')")
        swap.write_text(source, encoding="cp1252")
        patched.insert(0, "macropore")
        if runtime_checkpoint or checkpoint_day >= 365:
            patched.append("swapoutput")

    if project.solute and not budget_retry:raise ValueError("Hupsel requires its unchanged strict mass guard")
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
        if strict_water:source=replace(source,"budget_enabled = window >= 15","budget_enabled = .true.")
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
        if strict_water:
            source=replace(source,"1d-6 * (t1900-budget_start+dt)","1d-10 * (t1900-budget_start+dt)")
            source=replace(source,"   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror",
                           "   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at")
            source=replace(source,"   iBackTr        = 0","   mass_polish_at = 0\n   iBackTr        = 0")
            # First finish the original Newton iteration at the required mass
            # boundary. Halving a converged-but-inaccurate step alone repeated
            # at dtmin without curing the observed day-one residual.
            source=replace(source,anchor,"""      if (budget_enabled .and. .not.flnonconv) then
         budget_step=projected_water_residual()
         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.
         if (.not.flnonconv .and. mass_polish_at==0) then
            ! One more original Newton iteration avoids stopping directly on
            ! the day guard where independently summed receipts can round out.
            mass_polish_at=numbit
            flnonconv=.true.
         end if
      end if
"""+anchor)
            if project.water_polish_policy == INTERIOR_WATER_POLISH:
                # Keep the original and strict mass rejection unchanged. Only
                # omit padding inside a conservative half-guard interior;
                # near the boundary retain the original extra Newton solve.
                # This is a named stopping policy, not a relaxed day tolerance
                # or a retry/fallback after a refused day.
                source=replace(source,
                    'if (.not.flnonconv .and. mass_polish_at==0) then',
                    'if (.not.flnonconv .and. mass_polish_at==0 .and. &\n'
                    '             abs(budget_total+budget_step)>0.5d0*1d-10*(t1900-budget_start+dt)) then')
            if project.input_directory:
                from experimental_project import inspect
                configuration=inspect(project.input_directory)
                selected=configuration['selectors']
                # The same original linear pond relation applies to drain0/1.
                # The new original tabulated drain also holds its rates fixed
                # during HeadCalc. Resolve the actual original DRFIL owner.
                table_drainage=False
                if selected['SWDRA']==1 and selected['SWSNOW']==0:
                    from experimental_project import one
                    body=(case/'swap.swp').read_text(encoding='cp1252')
                    name=one(body,'DRFIL',r"'[^']+'").strip("'")
                    prefix=one(body,'PATHDRAIN',r"'[^']*'").strip("'").strip()
                    drain=(case/(prefix+name+'.dra')).read_text(encoding='cp1252')
                    table_drainage=one(drain,'DRAMET',r'[+-]?\d+')=='1'
                pond_tangent=(selected['SWDRA']==0 or
                              (selected['SWDRA']==1 and selected['SWRUNON']==1) or table_drainage)
                if pond_tangent and configuration['boundary']['SWBOTB']==6 and selected['SWSNOW']==0 and selected['SWKIMPL']==0:
                    source=replace(source,'   use hybrid_step_budget, only: projected_water_residual',
                                   '   use hybrid_step_budget, only: projected_water_residual, linear_pond_top_jacobian\n'
                                   '   use variables, only: rsro, rsroexp, pondmx')
                    source=replace(source,'   if (ftoph) dFdhM(1) = dFdhM(1) + kmean(1)/disnod(1)',
                                   '''   if (ftoph) then
      if (flrunoff .and. rsroexp==1d0 .and. rsro>=1d-3) then
         dFdhM(1)=dFdhM(1)+linear_pond_top_jacobian(kmean(1)/disnod(1),dt,pond,pondmx,rsro)
      else
         dFdhM(1)=dFdhM(1)+kmean(1)/disnod(1)
      end if
   end if''')
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
        if project.time_step_policy == LOCAL_WETTING_TIME_POLICY:
            from local_wetting_time import render_headcalc as render_wetting_headcalc
            source=render_wetting_headcalc(source)
        (output / "headcalc.f90").write_text(source, encoding="cp1252")
        patched.append("headcalc")

    if project.solute or project.input_directory:
        # Original linear pond/runoff relation remains exact even when the
        # lagged runoff estimate is below the legacy small-flux shortcut.
        # That shortcut booked runoff without subtracting it from new pond.
        source=(donor_build/'swap-selected/boundtop.f90').read_text(encoding='cp1252')
        from original_pond_budget import render as render_linear_pond_conservation
        source=render_linear_pond_conservation(source)
        (output/'boundtop.f90').write_text(source,encoding='cp1252')
        patched.append('boundtop')
    if project.solute:
        # The transport dtmin floor must not extend beyond the accepted water
        # interval. Its original order overshot short final fragments and
        # created solute during the day-five saline irrigation event.
        source=(donor_build/'swap-selected/solute.f90').read_text(encoding='cp1252')
        if aquifer_source:
            original=(donor_build/'swap-selected/solute.f90').read_bytes()
            if chemical_source:original=chemical_correction().source(original)
            source=aquifer_correction().source(original).decode('cp1252').replace('\r\n','\n')
        elif chemical_source:
            source=chemical_correction().source((donor_build/'swap-selected/solute.f90').read_bytes()).decode('cp1252').replace('\r\n','\n')
        end=source.index("      end subroutine solute_CDE",source.index("dtsolu  = min"))
        source=replace(source[:end],"            dtsolu  = min(dtsolu,(dt-tcumsol))\n            dtsolu  = max(dtsolu,dtmin)",
                       "            dtsolu  = max(dtsolu,dtmin)\n            dtsolu  = min(dtsolu,(dt-tcumsol))")+source[end:]
        source=replace(source,"      module subroutine calc_AgeTracer(task)\n         integer, intent(in) :: task\n      end subroutine calc_AgeTracer","""      module subroutine hybrid_solute_checkpoint(unit,restoring)
         integer,intent(in)::unit
         logical,intent(in)::restoring
      end subroutine hybrid_solute_checkpoint
      module subroutine calc_AgeTracer(task)
         integer, intent(in) :: task
      end subroutine calc_AgeTracer""")
        source=replace(source,"   public :: solute_CDE, calc_AgeTracer","   public :: solute_CDE, calc_AgeTracer, hybrid_solute_checkpoint")
        source=replace(source,"end submodule MOD_Solute_CDE","""module subroutine hybrid_solute_checkpoint(unit,restoring)
   use ieee_arithmetic,only:ieee_is_finite
   use MOD_grid,only:dz
   integer,intent(in)::unit
   logical,intent(in)::restoring
   integer::ios
   if(restoring)then
      read(unit,iostat=ios) cmsy(1:numnod),csurf,sampro
      if(ios/=0)error stop 'Incomplete Hupsel conserved solute state'
      if(.not.all(ieee_is_finite(cmsy(1:numnod))).or..not.all(ieee_is_finite([csurf,sampro]))) &
         error stop 'Nonfinite Hupsel conserved solute state'
      if(any(cmsy(1:numnod)<0d0).or.csurf<0d0.or.sampro<0d0)error stop 'Negative Hupsel solute state'
      if(abs(sum(cmsy(1:numnod)*dz(1:numnod))+csurf-sampro)>1d-10)error stop 'Unbalanced Hupsel solute state'
   else
      write(unit) cmsy(1:numnod),csurf,sampro
   end if
end subroutine hybrid_solute_checkpoint
end submodule MOD_Solute_CDE""")
        # Cumulative-output initialization must not erase restored physical
        # surface solute. Cold task1 already initializes csurf to zero.
        source=replace(source,"           csurf   = 0.0d0\n           samini  = sampro",
                       "           samini  = sampro")
        # Exact dry-surface limit of the original mixed-reservoir equation.
        # With no pond or macropore area, all surface mass enters the matrix.
        # Avoid division/multiplication cancellation leaving a signed roundoff
        # stock that the existing strict native restart correctly refuses.
        source=replace(source,"               csurf  = csurf + cfluxt                         ! mg cm-2\n               isqtop = qtop*(1.0d0-ArMpSs)*cpond              ! mg cm-2 d-1",
                       "               if (pond==0d0.and.ArMpSs==0d0) then\n"
                       "                  cfluxt = -csurf\n"
                       "                  csurf = 0d0\n"
                       "                  isqtop = cfluxt/dtsolu\n"
                       "               else\n"
                       "                  csurf = csurf + cfluxt\n"
                       "                  isqtop = qtop*(1.0d0-ArMpSs)*cpond\n"
                       "               end if")
        if project.solute_step_policy == TRANSACTIONAL_SOLUTE_STEP_POLICY:
            source=render_transactional_cde(source)
        if aquifer_source:
            begin=source.index('module subroutine hybrid_solute_checkpoint(unit,restoring)',source.index('submodule (MOD_Solute) MOD_Solute_CDE'))
            source=source[:begin]+replace(source[begin:],'end subroutine hybrid_solute_checkpoint',
                '   call hybrid_aquifer_checkpoint(unit,restoring)\nend subroutine hybrid_solute_checkpoint')
        (output/'solute.f90').write_text(source,encoding='cp1252')
        patched.insert(0,'solute')
        if chemical_source:
            (output/'mod_subsurface_solute_source.f90').write_bytes(chemical_correction().helper_source())
            patched.insert(0,'mod_subsurface_solute_source')
        if aquifer_source:
            (output/'mod_aquifer_solute_reservoir.f90').write_bytes(aquifer_correction().helper_source())
            patched.insert(0,'mod_aquifer_solute_reservoir')
    if project.age:
        from conserved_original_age import correction as age_correction
        age_patch=age_correction()
        (output/'solute.f90').write_bytes(age_patch.source((donor_build/'swap-selected/solute.f90').read_bytes(),native=True,effluent=True))
        age_csv=age_patch.csv_source((output/'swap_csv_output.f90').read_bytes())
        (output/'swap_csv_output.f90').write_bytes(age_csv.replace(b'AGE_CUMULATIVE',b'HYBRID_AGE_CUMULATIVE'))
        for name in (*age_patch.PROVIDERS,*age_patch.OUTPUT_PROVIDERS):
            (output/(name+'.f90')).write_bytes((ROOT/'src/process'/(name+'.f90')).read_bytes())
        patched[0:0]=[*age_patch.PROVIDERS,*age_patch.OUTPUT_PROVIDERS,'solute']
    if management_state:
        source=(donor_build/'swap-selected/MOD_cropdevelopment.f90').read_text(encoding='cp1252')
        source=replace(source,"            siccaploss = siccaploss + sicact",
                       "            siccaploss = siccaploss + sicact\n"
                       "            sicact = 0d0\n            siccap = 0d0")
        (output/'MOD_cropdevelopment.f90').write_text(source,encoding='cp1252')
        source=(donor_build/'swap-selected/wofost.f90').read_text(encoding='cp1252')
        source=replace(source,'   type (WOFOST_rates), save :: r_pot, r_act',
                       '   type (WOFOST_rates), save :: r_pot, r_act\n'
                       '   type (WOFOST_rates), save :: hybrid_r_pot,hybrid_r_act\n'
                       '   logical,save::hybrid_crop_pending=.false.,hybrid_crop_was_emerged=.false.')
        source=replace(source,'   public :: assimilation, wofost, reset_wofost_states_rates',
                       '   public :: assimilation, wofost, reset_wofost_states_rates\n'
                       '   public :: hybrid_wofost_checkpoint,hybrid_apply_wofost')
        rates=source.split('   type WOFOST_rates',1)[1].split('   end type WOFOST_rates',1)[0]
        names=re.findall(r'::\s*(\w+)',rates)
        if len(names)!=25:raise ValueError('Changed original WOFOST rate inventory')
        finite=', &\n         '.join('hybrid_r_'+mode+'%'+name for mode in ['pot','act'] for name in names)
        source=replace(source,'end module MOD_wofost',f"""
   subroutine hybrid_wofost_checkpoint(unit,restoring)
      use plant_interface,only:fl_cropemergence
      use ieee_arithmetic,only:ieee_is_finite
      integer,intent(in)::unit
      logical,intent(in)::restoring
      integer::flag,ios
      if(restoring)then
         read(unit,iostat=ios) flag,hybrid_r_pot,hybrid_r_act
         if(ios/=0.or.flag<0.or.flag>1)error stop 'Invalid Hupsel crop-rate context'
         if(.not.all(ieee_is_finite([{finite}])))error stop 'Nonfinite Hupsel crop-rate context'
         hybrid_crop_was_emerged=flag==1
         hybrid_crop_pending=.true.
      else
         flag=merge(1,0,fl_cropemergence)
         write(unit) flag,r_pot,r_act
      end if
   end subroutine
   subroutine hybrid_apply_wofost(emerged)
      logical,intent(in)::emerged
      if(.not.hybrid_crop_pending)return
      if(hybrid_crop_was_emerged.and.emerged)then
         r_pot=hybrid_r_pot
         r_act=hybrid_r_act
      end if
      hybrid_crop_pending=.false.
   end subroutine
end module MOD_wofost""")
        (output/'wofost.f90').write_text(source,encoding='cp1252')
        patched.insert(0,'wofost')
        patched.append('MOD_cropdevelopment')
        source=(donor_build/'swap-selected/irrigation.f90').read_text(encoding='cp1252')
        if chemical_source:
            source=chemical_correction().irrigation_source((donor_build/'swap-selected/irrigation.f90').read_bytes()).decode('cp1252').replace('\r\n','\n')
        if scheduled_subsurface:
            from scheduled_subsurface_irrigation import render_irrigation as render_scheduled_subsurface
            source=render_scheduled_subsurface(source)
        from age_fixed_irrigation import enabled as age_fixed_enabled
        age_fixed=age_fixed_enabled(project)
        if fixed_file or chemical_fixed or age_fixed:
            from fixed_irrigation_file import render_irrigation
            source=render_irrigation(source,allow_chemical_subsurface=chemical_fixed or age_fixed)
        if age_fixed:
            if age_source:
                source=current_age_source.render_irrigation(source,project)
            else:
                from age_fixed_irrigation import render_irrigation as render_age_fixed
                source=render_age_fixed(source)
        source=replace(source,"      subroutine read_irrigation_fixed()",
                       "      subroutine read_irrigation_fixed()\n         use MOD_swap_base,only:swinco")
        source=replace(source,"         call checkdate(ifnd,irdate,tend,tstart,'irdate', 'readswap/swirfix=1      ')",
                       "         if(swinco/=3 .or. .not.all(irdate(1:ifnd)<tstart)) &\n"
                       "            call checkdate(ifnd,irdate,tend,tstart,'irdate', 'readswap/swirfix=1      ')")
        # The original routine has SAVE locals as well as module variables.
        # Keep that complete original context owned by this private worker.
        start=source.index('      subroutine irrigation (task)')
        finish=source.index('      end subroutine irrigation',start)
        routine=source[start:finish]
        a=routine.index('! -- local variables');b=routine.index('      ! functions',a)
        local_region=routine[a:b];promoted=[];mapping={}
        for line in local_region.splitlines():
            if '::' not in line:continue
            left,right=line.split('::');right=right.split('!')[0].strip()
            values=[]
            for value in right.split(','):
                name=re.match(r'\w+',value.strip())[0]
                if name.lower()=='afgen':continue
                mapping[name.lower()]='hybrid_irrigation_local_'+name.lower()
                values.append(value.strip())
            if values:promoted.append(left+':: '+', '.join(values))
        routine=routine[:a]+'      real(8)::afgen\n'+routine[b:]
        routine=re.sub(r'(?m)^      save[ \t]*$', '',routine)
        token=re.compile(r"'([^']|'')*'|\"([^\"]|\"\")*\"|!.*|[A-Za-z_]\w*")
        def rename(match):
            value=match[0]
            return mapping.get(value.lower(),value) if value[0] not in "'\"!" else value
        routine=token.sub(rename,routine)
        promoted='\n'.join(token.sub(rename,line) for line in promoted)
        source=source[:start]+routine+source[finish:]
        source=replace(source,'use MOD_arrays, only: mairg, macp','use MOD_arrays, only: mairg, macp, maho')
        source=replace(source,'   contains',promoted+'\n   contains')
        source=replace(source,"         ! check if irdate is ascending, and determine initial entry point nirri",
                       "         ! check if irdate is ascending, and determine initial entry point nirri")
        source=replace(source,"         if (tstart >= irdate(ifnd)) nirri = ifnd",
                       "         if (tstart >= irdate(ifnd)) nirri = ifnd\n"
                       "         if(swinco==3.and.all(irdate(1:ifnd)<tstart))nirri=ifnd+1")
        header=source.split('   contains',1)[0]
        declarations=[];irrigation_fields=[]
        for line in header.splitlines():
            if not re.match(r'\s*(?:integer|real\([48]\)|logical|character\(len=200\))[ ,]',line) or '::' not in line:continue
            left,right=line.split('::');right=right.split('!')[0].split('=')[0].strip()
            declarations.append(re.sub(r',\s*save\b','',left,flags=re.I)+':: '+right)
            irrigation_fields.extend(re.match(r'\w+',name.strip())[0] for name in right.split(','))
        if len(irrigation_fields)!=50+len(mapping) or len(set(irrigation_fields))!=len(irrigation_fields):
            raise ValueError('Changed original irrigation state inventory')
        snapshot='\n'.join(declarations)
        source=replace(source,'   contains',f"""   type hybrid_irrigation_snapshot_t
{snapshot}
      real(8)::accepted_iptra_day,accepted_iqreddry_day,accepted_iqredsol_day
      logical::was_emerged
   end type
   type(hybrid_irrigation_snapshot_t),save::hybrid_irrigation_snapshot
   logical,save::hybrid_irrigation_pending=.false.
   contains""")
        wire=', &\n         '.join('hybrid_irrigation_snapshot%'+name for name in irrigation_fields+['accepted_iptra_day','accepted_iqreddry_day','accepted_iqredsol_day','was_emerged'])
        capture='\n'.join('         hybrid_irrigation_snapshot%'+name+'='+name for name in irrigation_fields)
        apply='\n'.join('         '+name+'=hybrid_irrigation_snapshot%'+name for name in irrigation_fields)
        procedures=f"""
   subroutine hybrid_irrigation_checkpoint(unit,restoring)
      use plant_interface,only:fl_cropemergence
      use MOD_integral_global,only:iptra_day,iqreddry_day,iqredsol_day
      use ieee_arithmetic,only:ieee_is_finite
      integer,intent(in)::unit
      logical,intent(in)::restoring
      integer::ios
      if(restoring)then
         read(unit,iostat=ios) {wire}
         if(ios/=0)error stop 'Incomplete Hupsel irrigation context'
         if(.not.all(ieee_is_finite([hybrid_irrigation_snapshot%accepted_iptra_day, &
            hybrid_irrigation_snapshot%accepted_iqreddry_day,hybrid_irrigation_snapshot%accepted_iqredsol_day]))) &
            error stop 'Nonfinite accepted irrigation feedback'
         if(hybrid_irrigation_snapshot%dayfix<0.or.hybrid_irrigation_snapshot%dayfix>366) &
            error stop 'Invalid Hupsel irrigation context'
         hybrid_irrigation_pending=.true.
      else
{capture}
         hybrid_irrigation_snapshot%accepted_iptra_day=iptra_day
         hybrid_irrigation_snapshot%accepted_iqreddry_day=iqreddry_day
         hybrid_irrigation_snapshot%accepted_iqredsol_day=iqredsol_day
         hybrid_irrigation_snapshot%was_emerged=fl_cropemergence
         write(unit) {wire}
      end if
   end subroutine
   subroutine hybrid_apply_irrigation(emerged)
      use MOD_integral_global,only:iptra_day,iqreddry_day,iqredsol_day
      logical,intent(in)::emerged
      if(.not.hybrid_irrigation_pending)return
      iptra_day=hybrid_irrigation_snapshot%accepted_iptra_day
      iqreddry_day=hybrid_irrigation_snapshot%accepted_iqreddry_day
      iqredsol_day=hybrid_irrigation_snapshot%accepted_iqredsol_day
      nirri=hybrid_irrigation_snapshot%nirri
      if(.not.hybrid_irrigation_snapshot%was_emerged.and.emerged)then
         if(schedule==1)then
            dayfix=366
            flirrigate=.true.
         else
{apply}
            schedule=0
         end if
      else
{apply}
      end if
      hybrid_irrigation_pending=.false.
   end subroutine
"""
        marker=re.search(r'(?im)^end module MOD_irrigation',source)
        if marker is None:raise ValueError('Missing original irrigation module end')
        source=source[:marker.start()]+procedures+source[marker.start():]
        (output/'irrigation.f90').write_text(source,encoding='cp1252')
        patched.insert(0,'irrigation')
    if micro_state:
        from micro_lookup_state import render as render_micro_lookup
        source=(donor_build/'swap-selected/RWU_micro.f90').read_text(encoding='cp1252')
        (output/'RWU_micro.f90').write_text(render_micro_lookup(source),encoding='cp1252')
        patched.insert(0,'RWU_micro')
        patched.remove('boundtop');patched.insert(0,'boundtop')
        from oxygen_lookup_state import render as render_oxygen_lookup
        source=(donor_build/'swap-selected/oxygenstress.f90').read_text(encoding='cp1252')
        (output/'oxygenstress.f90').write_text(render_oxygen_lookup(source),encoding='cp1252')
        patched.insert(0,'oxygenstress')
        from history_top_state import render as render_history_top
        from original_ria12_thermal import top_diagnostic as ria12_top_diagnostic
        (output/'boundtop.f90').write_text(ria12_top_diagnostic(render_history_top((output/'boundtop.f90').read_text(encoding='cp1252'),scheduled_pond=selector('SWPONDMX')==1),project),encoding='cp1252')
        if checkpoint_day is not None or runtime_checkpoint:
            path=output/'swap.f90';source=path.read_text(encoding='cp1252')
            source=replace(source,'use MOD_wofost,only:hybrid_apply_wofost',
                           'use O2_pars,only:hybrid_apply_oxygen\nuse MOD_top,only:hybrid_apply_top\nuse mod_RWU_micro,only:hybrid_apply_micro_lookup\nuse MOD_wofost,only:hybrid_apply_wofost')
            source=replace(source,'         call hybrid_apply_wofost(fl_cropemergence)',
                           '         call hybrid_apply_wofost(fl_cropemergence)\n         call hybrid_apply_top()\n         call hybrid_apply_oxygen()\n         call hybrid_apply_micro_lookup()')
            path.write_text(source,encoding='cp1252')
    if not project.macro and project.time_step_policy==PHYSICAL_GROWTH_TIME_POLICY:
        render_physical_iteration_proposal(output,strict_water=strict_water)
    if project.input_directory and selector('SWCFBS')==1:
        # Accepted original plant/ET interface can remain physically active
        # between crops. Native bare-soil initialization does not preserve it.
        source=(donor_build/'swap-selected/interface_plant.f90').read_text(encoding='cp1252')
        names=['cf','ch','albedo','rsc','rsw','kdif','kdir','vcover','co2','fco2amax','fco2eff','fco2tra']
        fields=','.join(names)
        assignments='\n'.join('         '+name+'=values('+str(i+1)+')' for i,name in enumerate(names))
        source=replace(source,'end module plant_interface',f"""contains
   subroutine hybrid_plant_et_checkpoint(unit,restoring)
      use ieee_arithmetic,only:ieee_is_finite
      integer,intent(in)::unit
      logical,intent(in)::restoring
      integer::flag,ios
      real(8)::values(12)
      if(restoring)then
         read(unit,iostat=ios)flag,values
         if(ios/=0)error stop 'Incomplete original plant ET history'
      else
         flag=swcf
         values=[{fields}]
      end if
      if(flag<0.or.flag>2)error stop 'Invalid original plant ET selector'
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original plant ET history'
      if(any(values<0d0).or.values(3)>1d0.or.values(8)>1d0) &
        error stop 'Invalid original plant ET history'
      if(restoring)then
         swcf=flag
{assignments}
      else
         write(unit)flag,values
      end if
   end subroutine
end module plant_interface""")
        (output/'interface_plant.f90').write_text(source,encoding='cp1252')
        patched.insert(0,'interface_plant')
    if budget_retry:
        budget_source = APP / "hybrid_step_budget.f90"
        if lower_receipt:
            from prescribed_head_flux_boundary import render_budget,render_headcalc
            if lower_boundary==1:
                reaction=output/'mod_prescribed_groundwater_reaction.f90'
                reaction.write_bytes((ROOT/'src/process/mod_prescribed_groundwater_reaction.f90').read_bytes())
                subprocess.run([*common,'-c',str(reaction)],cwd=output,check=True)
            budget_source=output/'hybrid_step_budget.f90'
            budget_source.write_text(render_budget((APP/'hybrid_step_budget.f90').read_text(encoding='cp1252'),lower_boundary),encoding='cp1252')
            path=output/'headcalc.f90'
            if not paired_snow:
                path.write_text(render_headcalc(path.read_text(encoding='cp1252'),lower_boundary),encoding='cp1252')
            if lower_boundary in (1,5,9):
                from prescribed_head_flux_boundary import render_readswap
                source=(donor_build/'swap-selected/readswap.f90').read_text(encoding='cp1252')
                (output/'readswap.f90').write_text(render_readswap(source,project.start_clock,lower_boundary),encoding='cp1252')
                if 'readswap' in patched:raise ValueError('Multiple original reader state owners')
                patched.append('readswap')
            if lower_boundary==9 and not paired_snow and not (age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt'])):
                from prescribed_head_flux_boundary import render_timecontrol
                path=output/'timecontrol.f90'
                source=(path if path.exists() else donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')
                path.write_text(render_timecontrol(source),encoding='cp1252')
                if 'timecontrol' not in patched:patched.append('timecontrol')
        subprocess.run([*common, "-c", str(budget_source)], cwd=output, check=True)
    from surface_schedule import enabled as surface_schedule_enabled
    scheduled_pond=surface_schedule_enabled(project)
    if scheduled_pond:
        from surface_schedule import render_readswap as render_surface_reader
        path=output/'readswap.f90'
        source=path.read_text(encoding='cp1252') if 'readswap' in patched else (donor_build/'swap-selected/readswap.f90').read_text(encoding='cp1252')
        path.write_text(render_surface_reader(source,project.start_clock),encoding='cp1252')
        if 'readswap' not in patched:patched.append('readswap')
    from frost_reference import enabled as frost_enabled
    frost=frost_enabled(project)
    if frost:
        from frost_reference import source as frost_source,render_witness
        (output/'frozencond.f90').write_bytes(frost_source((donor_build/'swap-selected/frozencond.f90').read_bytes()))
        patched.insert(0,'frozencond')
        path=output/'swap_csv_output.f90'
        path.write_text(render_witness(path.read_text(encoding='cp1252')),encoding='cp1252')
    if project.time_step_policy == EVENT_CLOSURE_TIME_POLICY:
        if not strict_water or not budget_retry:
            raise ValueError('Corrected event closure requires complete strict terminal water receipt')
        (output/'terminal_water_receipt.f90').write_bytes((APP/'terminal_water_receipt.f90').read_bytes())
        patched.insert(0,'terminal_water_receipt')
        path=output/'headcalc.f90';source=path.read_text(encoding='cp1252')
        source=replace(source,'   use hybrid_step_budget, only: projected_water_residual',
                       '   use hybrid_terminal_water_receipt, only: terminal_water_residual\n'
                       '   use variables, only: tcum\n'
                       '   use hybrid_step_budget, only: projected_water_residual')
        anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
        source=replace(source,anchor,anchor+'\n'
                       '         if(tcum+dt>=1d0-1d-8)then\n'
                       '            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.\n'
                       '         end if')
        path.write_text(source,encoding='cp1252')
    if age_calendar is not None:
        patched=age_calendar_owner.apply_build(output,donor_build,project,patched)
    from frost_drainage_composition import apply_build as frost_drainage_build
    patched=frost_drainage_build(output,donor_build,project,patched)
    if age_source:patched=current_age_source.apply_build(output,project,patched)
    from implicit_groundwater_trial import apply_build as implicit_groundwater_trial_build
    patched=implicit_groundwater_trial_build(output,donor_build,project,patched)
    if lower_boundary==9 and not paired_snow and age_calendar and (age_calendar['nprintday']>1 or age_calendar['flprintdt']):
        from prescribed_head_flux_boundary import render_timecontrol,render_output_trial
        if age_calendar.get('cde_clock_output'):
            from prescribed_head_flux_boundary import render_cde_clock_headcalc
            head=output/'headcalc.f90'
            head.write_text(render_cde_clock_headcalc(head.read_text(encoding='cp1252')),encoding='cp1252')
        integral=output/'integral.f90'
        integral.write_text(render_output_trial(integral.read_text(encoding='cp1252'),
            (donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252'),
            (donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')),encoding='cp1252')
        path=output/'timecontrol.f90'
        if 'timecontrol' not in patched or not path.is_file():raise ValueError('Missing actual original paired-boundary output clock owner')
        path.write_text(render_timecontrol(path.read_text(encoding='cp1252')),encoding='cp1252')
    from implicit_conductivity_retry import apply_build as implicit_retry_build
    patched=implicit_retry_build(output,donor_build,project,patched)
    from implicit_conductivity_jacobian import apply_build as implicit_jacobian_build
    patched=implicit_jacobian_build(output,project,patched)
    from implicit_groundwater_state import native_apply_build as groundwater_native_build
    patched=groundwater_native_build(output,project,patched)
    from implicit_pond_event import apply_build as implicit_pond_build
    patched=implicit_pond_build(output,project,patched)
    from implicit_root_finalization import apply_build as implicit_root_build
    patched=implicit_root_build(output,donor_build,project,patched)
    from implicit_pond_availability import apply_build as implicit_availability_build
    patched=implicit_availability_build(output,project,patched)
    from implicit_interception_partition import apply_build as implicit_interception_build
    patched=implicit_interception_build(output,donor_build,project,patched)
    from implicit_saturation_derivative import apply_build as implicit_saturation_build
    patched=implicit_saturation_build(output,donor_build,project,patched)
    from implicit_finite_newton import apply_build as implicit_finite_build
    patched=implicit_finite_build(output,project,patched)
    from weather_terminal_receipt import apply_build as weather_terminal_build
    patched=weather_terminal_build(output,donor_build,project,patched)
    from weather_root_state import apply_build as weather_root_build
    patched=weather_root_build(output,project,patched)
    from extended_drainage import apply_build as extended_drainage_build
    patched=extended_drainage_build(output,donor_build,project,patched)
    from ordinary_implicit_pond_switch import apply_build as ordinary_pond_build
    patched=ordinary_pond_build(output,project,patched)
    from implicit_frost_composition import apply_build as implicit_frost_build
    patched=implicit_frost_build(output,project,patched)
    from model7_capacity import apply_build as model7_capacity_build
    patched=model7_capacity_build(output,donor_build,project,patched)
    from hydraulic_vapor import apply_build as hydraulic_vapor_build
    patched=hydraulic_vapor_build(output,donor_build,project,patched)
    from model7_terminal_water import apply_build as model7_terminal_build
    patched=model7_terminal_build(output,project,patched)
    from original_ria12_thermal import apply_build as ria12_thermal_build
    patched=ria12_thermal_build(output,donor_build,project,patched)
    from original_ria12_corrected import apply_build as ria12_corrected_build
    patched=ria12_corrected_build(output,donor_build,project,patched)
    from ria12_water_polish import apply_build as ria12_water_polish_build
    patched=ria12_water_polish_build(output,donor_build,project,patched)
    for name in patched:
        subprocess.run([*common, "-c", name + ".f90"], cwd=output, check=True)
    donor = executable(output, "day_donor")
    replacements = {name + ".o": output / (name + ".o") for name in patched}
    donor_objects = sorted(objects.glob("*.o"))
    ttutil_library = ttutil / "libttutil.a"
    subprocess.run(["gfortran", "-o", str(donor),
                    *(str(replacements.get(p.name, p)) for p in donor_objects),
                    *([str(output/'mod_subsurface_solute_source.o')] if chemical_source else []),
                    *([str(output/'mod_aquifer_solute_reservoir.o')] if aquifer_source else []),
                    *([str(output/(name+'.o')) for name in (*age_patch.PROVIDERS,*age_patch.OUTPUT_PROVIDERS)] if project.age else []),
                    *([str(output/(name+'.o')) for name in ('mod_original_output_receipt','hybrid_age_output_state','age_output_calendar_probe')] if age_calendar is not None else []),
                    *([str(output/'original_cde_output_state.o')] if project.original_output and project.solute else []),
                    *([str(output/'cde_interval_receipt.o')] if age_calendar and age_calendar.get('cde_interval_output',False) else []),
                    *([str(output/'cde_clock_events.o')] if age_calendar and age_calendar.get('cde_clock_output',False) else []),
                    *([str(output/'original_output_hysteresis_domain.o')] if age_calendar and age_calendar.get('swhyst',0) in (1,2) and not age_calendar.get('aquifer_output',False) and not age_calendar.get('thermal_output',False) else []),
                    *([str(output/'original_output_aquifer_domain.o')] if age_calendar and age_calendar.get('aquifer_output',False) else []),
                    *([str(output/'original_output_thermal_domain.o')] if age_calendar and age_calendar.get('thermal_output',False) else []),
                    *([str(output/'thermal_output_snow_calendar_state.o')] if age_calendar and age_calendar.get('thermal_calendar',False) else []),
                    *([str(output/'age_irrigation_source_domain.o')] if age_source else []),
                    *([str(output/(name+'.o')) for name in ('mod_direct_soil_age_substep','direct_soil_age_state')] if project.age_direct_soil_source else []),
                    *([str(output / "hybrid_step_budget.o")] if budget_retry else []),
                    *([str(output/'mod_prescribed_groundwater_reaction.o')] if lower_boundary==1 else []),
                    *([str(output/(name+'.o')) for name in ('groundwater_native_state','groundwater_history_native_state','age_groundwater_native_state') if name in patched] if lower_boundary==1 else []),
                    *([str(output/'implicit_groundwater_native_state.o')] if 'implicit_groundwater_native_state' in patched else []),
                    *([str(output/'model7_terminal_water_receipt.o')] if 'model7_terminal_water_receipt' in patched else []),
                    *([str(output/'snow_vapor_terminal_water_receipt.o')] if 'snow_vapor_terminal_water_receipt' in patched else []),
                    *([str(output/'hydraulic_vapor_native.o')] if 'hydraulic_vapor_native' in patched else []),
                    *([str(output/'implicit_pond_event_state.o')] if 'implicit_pond_event_state' in patched else []),
                    *([str(output/'implicit_pond_availability.o')] if 'implicit_pond_availability' in patched else []),
                    *([str(output / "terminal_water_receipt.o")] if project.time_step_policy==EVENT_CLOSURE_TIME_POLICY else []),
                    *([str(output/'hybrid_weather_terminal_receipt.o')] if 'hybrid_weather_terminal_receipt' in patched else []),
                    *([str(output/'hybrid_weather_root_state.o')] if 'hybrid_weather_root_state' in patched else []),
                    *([str(output/'hybrid_extended_drainage_state.o')] if 'hybrid_extended_drainage_state' in patched else []),
                    *([str(output/'hybrid_extended_drain_terminal.o')] if 'hybrid_extended_drain_terminal' in patched else []),
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
    if not project.macro:kernel_flags.extend(NO_MACRO_FP_FLAGS)
    driver = ROOT / "app/hybrid_water/main.f90"
    subprocess.run(["gfortran", *kernel_flags, *(str(ROOT / s) for s in sources),
                    str(adapter), str(driver), "-o", str(kernel)], cwd=output, check=True)

    from direct_day_kernel import build as build_direct_kernel
    direct_kernel=build_direct_kernel(output,[ROOT/s for s in sources],adapter,kernel_flags,project)

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
    if direct_kernel is not None:build_identity['direct_day_kernel']=direct_kernel
    from model7_capacity import metadata as model7_capacity_metadata
    model7_policy=model7_capacity_metadata(project)
    if model7_policy is not None:build_identity['model7_capacity']=model7_policy
    from model7_terminal_water import metadata as model7_terminal_metadata
    model7_terminal=model7_terminal_metadata(project)
    if model7_terminal is not None:build_identity['model7_terminal_water']=model7_terminal
    from weather_terminal_receipt import metadata as weather_terminal_metadata
    weather_terminal=weather_terminal_metadata(project)
    if weather_terminal is not None:build_identity['weather_terminal_receipt']=weather_terminal
    from weather_root_state import metadata as weather_root_metadata
    weather_root=weather_root_metadata(project)
    if weather_root is not None:build_identity['weather_root_state']=weather_root
    from implicit_conductivity import metadata as implicit_metadata
    implicit_policy=implicit_metadata(project)
    if implicit_policy is not None:build_identity['implicit_conductivity']=implicit_policy
    from implicit_groundwater_trial import metadata as implicit_trial_metadata
    implicit_trial=implicit_trial_metadata(project)
    if implicit_trial is not None:build_identity['implicit_groundwater_trial']=implicit_trial
    from implicit_conductivity_retry import metadata as implicit_retry_metadata
    implicit_retry=implicit_retry_metadata(project)
    if implicit_retry is not None:build_identity['implicit_conductivity_retry']=implicit_retry
    from implicit_conductivity_jacobian import metadata as implicit_jacobian_metadata
    implicit_jacobian=implicit_jacobian_metadata(project)
    if implicit_jacobian is not None:build_identity['implicit_conductivity_jacobian']=implicit_jacobian
    from implicit_pond_event import metadata as implicit_pond_metadata
    implicit_pond=implicit_pond_metadata(project)
    if implicit_pond is not None:build_identity['implicit_pond_event']=implicit_pond
    from implicit_root_finalization import metadata as implicit_root_metadata
    implicit_root=implicit_root_metadata(project)
    if implicit_root is not None:build_identity['implicit_root_finalization']=implicit_root
    from implicit_pond_availability import metadata as implicit_availability_metadata
    implicit_availability=implicit_availability_metadata(project)
    if implicit_availability is not None:build_identity['implicit_pond_availability']=implicit_availability
    from implicit_interception_partition import metadata as implicit_interception_metadata
    implicit_interception=implicit_interception_metadata(project)
    if implicit_interception is not None:build_identity['implicit_interception_partition']=implicit_interception
    from implicit_saturation_derivative import metadata as implicit_saturation_metadata
    implicit_saturation=implicit_saturation_metadata(project)
    if implicit_saturation is not None:build_identity['implicit_saturation_derivative']=implicit_saturation
    from implicit_finite_newton import metadata as implicit_finite_metadata
    implicit_finite=implicit_finite_metadata(project)
    if implicit_finite is not None:build_identity['implicit_finite_newton']=implicit_finite
    from ordinary_implicit_pond_switch import metadata as ordinary_pond_metadata
    ordinary_pond=ordinary_pond_metadata(project)
    if ordinary_pond is not None:build_identity['ordinary_implicit_pond_switch']=ordinary_pond
    from extended_drainage import metadata as extended_drainage_metadata
    extended=extended_drainage_metadata(project)
    if extended is not None:build_identity['extended_drainage']=extended
    from cde_native_receipt import enabled as cde_receipt_enabled,metadata as cde_receipt_metadata
    if cde_receipt_enabled(project):build_identity['cde_native_receipt']=cde_receipt_metadata()
    from groundwater_water_output import metadata as original_output_metadata
    selected_output=original_output_metadata(project)
    if selected_output is not None:build_identity['original_output']=selected_output
    if project.input_directory:
        from hydraulic_vapor import metadata as hydraulic_vapor_metadata
        vapor_identity = hydraulic_vapor_metadata(project)
        if vapor_identity is not None:build_identity['hydraulic_vapor'] = vapor_identity
        build_identity['experimental_input_adapter'] = sha(APP/'experimental_project.py')
    if project.time_step_policy == LOCAL_WETTING_TIME_POLICY:
        from local_wetting_time import metadata as wetting_metadata
        build_identity['local_wetting_time'] = wetting_metadata((donor_build/'swap-selected/timecontrol.f90').read_bytes())
    if chemical_fixed:
        from conserved_subsurface_solute import metadata as chemical_metadata
        build_identity['conserved_subsurface_solute']=chemical_metadata()
    if chemical_scheduled:
        from conserved_scheduled_subsurface_solute import metadata as chemical_scheduled_metadata
        build_identity['conserved_scheduled_subsurface_solute']=chemical_scheduled_metadata()
    if aquifer_source:
        from conserved_aquifer_solute import metadata as aquifer_metadata
        build_identity['conserved_aquifer_solute']=aquifer_metadata()
        from aquifer_native_receipt import metadata as aquifer_receipt_metadata
        build_identity['aquifer_native_receipt']=aquifer_receipt_metadata()
    if project.age:
        from conserved_original_age import metadata as age_metadata
        build_identity['conserved_original_age']=age_metadata()
        from age_groundwater_output import source_age_identity as age_identity
        build_identity['conserved_original_age']=age_identity(build_identity['conserved_original_age'],project)
        from age_direct_soil_source import fixed_metadata
        fixed_age=fixed_metadata(project)
        if fixed_age is not None:build_identity['original_age_fixed_irrigation']=fixed_age
    if project.time_step_policy == IRRIGATION_PULSE_TIME_POLICY:
        from irrigation_pulse_time import metadata as pulse_metadata
        build_identity['irrigation_pulse_time'] = pulse_metadata((donor_build/'swap-selected/timecontrol.f90').read_bytes())
    if project.time_step_policy == EVENT_CLOSURE_TIME_POLICY:
        from time_event_closure import metadata as event_metadata
        build_identity['time_event_closure'] = event_metadata((donor_build/'swap-selected/timecontrol.f90').read_bytes())
    if micro_state:
        from micro_lookup_state import POLICY
        build_identity['micro_lookup_state_policy']=POLICY
        build_identity['micro_lookup_state_source']=sha(APP/'micro_lookup_state.py')
        build_identity['history_top_state_source']=sha(APP/'history_top_state.py')
        build_identity['oxygen_lookup_state_source']=sha(APP/'oxygen_lookup_state.py')
        if selector('SWPONDMX')==1:
            from scheduled_pond_state import POLICY as POND_HISTORY_POLICY
            build_identity['scheduled_pond_history']={'policy':POND_HISTORY_POLICY,'source_sha256':sha(APP/'scheduled_pond_state.py')}
    if budget_retry:
        build_identity["budget_source"] = sha(budget_source)
    if lower_receipt:
        from prescribed_head_flux_boundary import boundary_metadata as lower_metadata
        build_identity['lower_boundary_receipt']=lower_metadata(project,sha,APP,ROOT)
    from implicit_groundwater_state import native_metadata as groundwater_native_metadata
    groundwater_state=groundwater_native_metadata(project,sha,APP)
    if groundwater_state is not None:build_identity['groundwater_native_state']=groundwater_state
    if fixed_file:
        from fixed_irrigation_file import POLICY as FIXED_FILE_POLICY
        build_identity['fixed_irrigation_file']={'policy':FIXED_FILE_POLICY,'source_sha256':sha(APP/'fixed_irrigation_file.py')}
    if scheduled_subsurface:
        from scheduled_subsurface_irrigation import POLICY as SCHEDULED_SUBSURFACE_POLICY
        build_identity['scheduled_subsurface_irrigation']={'policy':SCHEDULED_SUBSURFACE_POLICY,'source_sha256':sha(APP/'scheduled_subsurface_irrigation.py')}
    if frost:
        from frost_reference import POLICY as FROST_POLICY
        build_identity['frost_reference']={'policy':FROST_POLICY,'source_sha256':sha(APP/'frost_reference.py'),
            'generated_source_sha256':sha(output/'frozencond.f90')}
    from frost_drainage_composition import metadata as frost_drainage_metadata
    if frost_drainage_metadata(project) is not None:
        build_identity['frost_drainage_composition']=frost_drainage_metadata(project)
    if scheduled_pond:
        from surface_schedule import POLICY as SURFACE_SCHEDULE_POLICY
        build_identity['surface_schedule']={'policy':SURFACE_SCHEDULE_POLICY,'source_sha256':sha(APP/'surface_schedule.py')}
    if not project.macro:
        build_identity['floating_point_profile'] = no_macro_fp_profile()
        build_identity['soil_table_policy'] = project.soil_table_policy if soil_tables else None
        if project.soil_table_policy == PCHIP_SOIL_TABLE_POLICY:
            build_identity['soil_table_policy_source'] = sha(Path(__file__))
        build_identity['solute_step_policy'] = project.solute_step_policy if project.solute else None
        if project.solute_step_policy == TRANSACTIONAL_SOLUTE_STEP_POLICY:
            build_identity['solute_step_policy_source'] = sha(APP/'solute_step_policy.py')
        build_identity['time_step_policy'] = project.time_step_policy
        build_identity['water_polish_policy'] = project.water_polish_policy
        build_identity['time_step_policy_source'] = sha(APP/'donor_sources.py')
        library = compile_restart_publisher(output)
        build_identity['restart_publisher'] = {
            'source_sha256': sha(ROOT/'app/support/restart_publish.c'),
            'library_sha256': sha(library),
            'gcc_sha256': sha(Path(shutil.which('gcc'))),
        }
    return donor, kernel, case, inputs, build_identity


def start_process(stack, command, directory, name, *, direct_identity=None):
    stderr = stack.enter_context((directory / (name + ".stderr")).open("w"))
    if direct_identity is not None:
        from direct_day_kernel import NativeDayKernel, library_path
        transcript=stack.enter_context((directory/(name+'.stdout')).open('w',encoding='utf8'))
        process=NativeDayKernel(library_path(Path(command[0]).parent),command[1],transcript)
        stack.callback(process.terminate)
        return process,transcript
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
    from direct_day_kernel import NativeDayKernel
    if isinstance(process,NativeDayKernel):return process.write(text)
    process.stdin.write(text + "\n")
    process.stdin.flush()


def send_reply(process, values):
    from direct_day_kernel import NativeDayKernel
    if isinstance(process, NativeDayKernel):
        return process.submit(values)
    return send(process, " ".join(map(str, values)))


def receive(process, transcript, prefixes):
    from direct_day_kernel import NativeDayKernel
    if isinstance(process,NativeDayKernel):return process.receive(prefixes)
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


def compile_restart_publisher(output):
    """Build the unchanged durable publisher once in an explicit build bundle."""
    source = ROOT / "app/support/restart_publish.c"
    library = output / ("restart_publish.dll" if os.name == "nt" else "restart_publish.so")
    flags = ["-shared", "-O2"]
    if os.name != "nt":
        flags.append("-fPIC")
    subprocess.run(["gcc", *flags, str(source), "-o", str(library)], check=True)
    return library


def validate_restart_publisher(bundle, identity):
    """Refuse changed publication code/binary before using a prepared library."""
    library = bundle/('restart_publish.dll' if os.name == 'nt' else 'restart_publish.so')
    if (identity['source_sha256'] != sha(ROOT/'app/support/restart_publish.c')
            or identity['library_sha256'] != sha(library)):
        raise ValueError('Build durable restart publisher differs')
    return library


def restart_publisher(output, *, bundle=None, identity=None):
    """Load the same durable publisher; prepared no-macro builds reuse its binary."""
    library = (validate_restart_publisher(bundle, identity) if identity is not None
               else compile_restart_publisher(output))
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
    aquifer_state: list | None = None
    age_state: list | None = None
    age_effluent: list | None = None


def prepare_column(case, directory, start, checkpoint_enabled, runtime, project=ANDELST):
    shutil.copytree(case, directory)
    if checkpoint_enabled or project.solute:
        control = directory / "swap.swp"
        source = control.read_text(encoding="cp1252")
        if (project.solute or project.input_directory) and not project.original_output:
            # Same output-only compatibility already owned by HIGH_PRECISION_REFERENCE.json.
            source,count=re.subn(r"(?mi)^(\s*INLIST_CSV\s*=\s*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",source)
            if count!=1:raise ValueError('Missing/ambiguous original CSV groups')
            from age_output_schedule import selection as age_schedule_selection
            if age_schedule_selection(project) is None:
                source,count=re.subn(r"(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1",r"\g<1>0",source)
                if count not in (0,1):raise ValueError("Ambiguous original monthly output setting")
            source,count=re.subn(r'(?m)^([ \t]*NUM_DECIMALS[ \t]*=[ \t]*)[^\s!]+',r'\g<1>12',source)
            if count>1:raise ValueError('Ambiguous original output precision')
            if count==0:source += "\nNUM_DECIMALS = 12\n"
        source, count = re.subn(r"(?m)^([ \t]*SWENDTYPE[ \t]*=[ \t]*)[12]", r"\g<1>2", source)
        if count > 1:
            raise ValueError("Duplicate restart output setting")
        if count == 0:
            source += "\nSWENDTYPE = 2\n"
        if start.origin is not None:
            start_date = date.fromisoformat(project.start_date) + timedelta(days=start.day)
            if project.input_directory:
                source,count=re.subn(r'(?m)^([ \t]*TSTART[ \t]*=[ \t]*)'+re.escape(project.start_date)+r'\b',
                                     lambda m:m[1]+str(start_date),source)
                if count!=1:raise ValueError('Missing/ambiguous experimental start date')
            else:
                source = replace(source, f"TSTART = {project.start_date}", f"TSTART = {start_date}")
            if project==ANDELST and start.day >= 365:
                bbc = directory / "swap.bbc"
                table = bbc.read_text(encoding="cp1252")
                terminal = re.search(r"(?m)^([ \t]*1998-12-31[ \t]+)(-?\d+(?:\.\d+)?)[ \t]*$", table)
                if terminal is None:
                    raise ValueError("Missing original terminal Cauchy head")
                table = replace(table, terminal[0], terminal[0] + f"\n {start_date}  {terminal[2]}")
                bbc.write_text(table, encoding="cp1252")
            source, count = re.subn(r"(?m)^([ \t]*SWINCO[ \t]*=[ \t]*)[123]\b", r"\g<1>3", source)
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
        project_case(case, project)
        model=project.model if model is None else model
        if model!=project.model:raise ValueError("Model and project identity differ")
        self.project=project
        self.columns = []
        self.output = output
        self.binding = binding
        self.usable = False
        direct_identity=binding['build'].get('direct_day_kernel') if binding is not None else None
        if direct_identity is not None:
            from direct_day_kernel import validate as validate_direct
            validate_direct(Path(kernel).parent,direct_identity,project)
        self.host, self.host_log = start_process(stack, [kernel, model]+(["explicit-project"] if not project.macro else []), output, "kernel", **({'direct_identity':direct_identity} if direct_identity is not None else {}))
        _, selected = receive(self.host, self.host_log, {"DAILY_MODEL"})
        if selected["DAILY_MODEL"] != [model]:
            raise ValueError("Kernel selected a different soil water model")
        publisher_identity = binding['build'].get('restart_publisher') if binding is not None else None
        self.publish = (restart_publisher(output, bundle=Path(donor).parent, identity=publisher_identity)
                        if binding is not None else None)
        for start in starts:
            name = start.name or start.variant
            if Path(name).name != name or name in {".", ".."} or start.variant not in {"original", "shifted"}:
                raise ValueError("Invalid column directory or variant")
            if (start.origin is None) != (start.day == 0):
                raise ValueError("Column start day must match its origin")
            directory = output / name
            prepare_column(case, directory, start, checkpoint_enabled, runtime, project)
            from weather_root_state import enabled as weather_root_enabled,validate_candidate as validate_weather_root
            if start.origin is not None and weather_root_enabled(project):
                if start.receipt is None:raise ValueError('Hourly root stress restore requires accepted receipt')
                validate_weather_root((directory/'macro-origin.bin').read_bytes(),start.receipt,project)
            from implicit_groundwater_state import enabled as implicit_groundwater,validate_candidate as validate_implicit_groundwater
            if start.origin is not None and implicit_groundwater(project):
                if start.receipt is None:raise ValueError('Implicit groundwater restore requires accepted receipt')
                validate_implicit_groundwater((directory/'macro-origin.bin').read_bytes(),start.receipt,project)
            if project.age and start.origin is not None:
                from age_groundwater_output import active_selection as age_groundwater,validate_candidate as validate_age_groundwater
                if age_groundwater(project) is not None:
                    if start.receipt is None:raise ValueError('Original AGE groundwater restore requires accepted receipt')
                    validate_age_groundwater((directory/'macro-origin.bin').read_bytes(),start.receipt,project)
            from extended_drainage import enabled as extended_enabled,validate_candidate as validate_extended
            if start.origin is not None and extended_enabled(project):
                if start.receipt is None:raise ValueError('Extended drain restore requires accepted receipt')
                validate_extended((directory/'macro-origin.bin').read_bytes(),start.receipt,project)
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
            aquifer_state=None
            if project.solute:
                solute_stock=float(initial['HYBRID_SOLUTE_READY'][0])
                if not math.isfinite(solute_stock):raise ValueError('Invalid initial solute stock')
                if start.receipt is not None and solute_stock!=start.receipt['solute_end_mg_cm2']:
                    raise ValueError('Restored solute stock differs from accepted receipt')
                from conserved_aquifer_solute import enabled as aquifer_enabled, validate_state as validate_aquifer
                if aquifer_enabled(project):
                    aquifer_state=validate_aquifer(list(map(float,initial['HYBRID_AQUIFER_CUMULATIVE'])))
                    if start.receipt is not None and aquifer_state!=start.receipt['aquifer_state']:
                        raise ValueError('Restored aquifer state differs from accepted receipt')
            age_state=None
            age_effluent=None
            if project.age:
                from conserved_original_age import validate_effluent
                from age_direct_soil_source import validate_age
                age_state=validate_age(list(map(float,initial['HYBRID_AGE_CUMULATIVE'])),project)
                age_effluent=validate_effluent(list(map(float,initial['HYBRID_AGE_EFFLUENT'])))
                if start.receipt is not None and age_state!=start.receipt['age_state_cm_day']:
                    raise ValueError('Restored original age state differs from accepted receipt')
                if start.receipt is not None and age_effluent!=start.receipt['age_effluent']:
                    raise ValueError('Restored original age effluent differs from accepted receipt')
            self.columns.append(DailyColumn(directory, start.variant, worker, transcript, start.day, stocks, pressure,solute_stock=solute_stock,aquifer_state=aquifer_state,age_state=age_state,age_effluent=age_effluent))
            if extended_enabled(project):
                from extended_drainage import state_witness as extended_witness
                state=extended_witness(initial.get('HYBRID_EXTENDED_DRAIN_STATE',[]),project,start.day)
                if start.receipt is not None and state!=start.receipt.get('extended_drainage_state'):
                    raise ValueError('Restored original surfacewater state differs from receipt')
                self.columns[-1].extended_drainage_state=state
        send(self.host, str(len(self.columns)))
        for column in self.columns:
            if not project.macro:send(self.host,f"{project.nodes} {project.start_clock}")
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
        if self.project.solute:
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
            if current.aquifer_state is not None:
                from conserved_aquifer_solute import ledger as aquifer_ledger
                solute_budget.update(aquifer_ledger(current.aquifer_state,list(map(float,response['HYBRID_AQUIFER_CUMULATIVE'])),current.solute_stock,ledger))
        bottom_out = flow[15] - flow[6]
        if self.project.age:
            from conserved_original_age import validate_effluent
            from age_direct_soil_source import age_ledger
            solute_budget.update(age_ledger(current.age_state,list(map(float,response['HYBRID_AGE_CUMULATIVE'])),self.project))
            solute_budget['age_effluent']=validate_effluent(list(map(float,response['HYBRID_AGE_EFFLUENT'])))
        reply = [day, math.fsum(stocks[:6]), math.fsum(flow[:7]), math.fsum(flow[7:]),
                 bottom_out, -hydraulic[1], *hydraulic[2:], *stocks[:6]]
        send_reply(self.host, reply)
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
        from weather_root_state import enabled as weather_root_enabled
        if weather_root_enabled(self.project):
            memory=list(map(float,response.get('HYBRID_WEATHER_ROOT_MEMORY',[])))
            if (len(memory)!=3 or not all(map(math.isfinite,memory))
                    or memory[0]!=self.project.start_clock+day or any(v<0 or v>1 for v in memory[1:])):
                raise ValueError('Invalid original hourly root stress witness')
            budget['weather_root_memory']=memory[1:]
            if committed and checkpoint:
                from weather_root_state import validate_candidate as validate_weather_root
                validate_weather_root((current.directory/'macro.bin').read_bytes(),budget,self.project)
        from extended_drainage import enabled as extended_enabled,state_witness as extended_witness,validate_candidate as validate_extended
        if extended_enabled(self.project):
            budget['extended_drainage_state']=extended_witness(response.get('HYBRID_EXTENDED_DRAIN_STATE',[]),self.project,day)
            from extended_drainage import flux_witness as extended_flux_witness
            budget['surfacewater']=extended_flux_witness(response.get('HYBRID_EXTENDED_DRAIN_FLUX',[]),self.project,budget,current.extended_drainage_state)
            if committed and checkpoint:validate_extended((current.directory/'macro.bin').read_bytes(),{**budget,**solute_budget},self.project)
        budget.update(solute_budget)
        if "HYBRID_BUDGET_RETRIES" in response:
            count, residual = response["HYBRID_BUDGET_RETRIES"]
            budget["budget_step_retries"] = int(count)
            budget["integrated_guard_residual_cm"] = float(residual)
        if committed:
            if extended_enabled(self.project):current.extended_drainage_state=budget['extended_drainage_state']
            current.day = day
            current.revision = revision
            current.stocks = budget["stock_end_cm"].copy()
            current.pressure = budget["pressure_head_cm"].copy()
            if self.project.solute:current.solute_stock=budget["solute_end_mg_cm2"]
            if current.aquifer_state is not None:current.aquifer_state=budget['aquifer_state'].copy()
            if current.age_state is not None:current.age_state=budget['age_state_cm_day'].copy()
            if current.age_effluent is not None:current.age_effluent=budget['age_effluent'].copy()
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

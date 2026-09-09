#!/usr/bin/env python3
from pathlib import Path
import subprocess

HEADCALC = Path('src/legacy/b1_10_port/headcalc.f90')
BACKEND = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
EXPECTED_BLOBS = {
    HEADCALC: 'e14733162da96399c8a247e5500b1d9e1ba95875',
    BACKEND: 'f5cf46b4eb40e68704bc0dfcdb18bf0746504889',
}


def git_blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FMR20_STAGE2_MATERIALIZE_FAIL {label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED_BLOBS.items():
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f'FMR20_STAGE2_MATERIALIZE_FAIL source drift {path}: {actual} != {expected}')
print('FMR20_STAGE2_G01_PREIMAGE_LOCK=PASS')

head = HEADCALC.read_text(encoding='utf-8')
old_init = """   swmacro = legacy_swmacro
   swbotb = legacy_swbotb
   dt = legacy_dt
   swkimpl = legacy_swkimpl
   swkmean = legacy_swkmean
   maxit = legacy_maxit
   maxbacktr = legacy_maxbacktr
   dtmin = legacy_dtmin
   critdevh2cp = legacy_critdevh2cp
   critdevh1cp = legacy_critdevh1cp
   critdevponddt = legacy_critdevponddt
   CritDevBalCp = legacy_CritDevBalCp
   CritDevBalTot = legacy_CritDevBalTot
   if (legacy_state_binding) then
      at_min_dt = legacy_fldtmin
      day_start_event = legacy_fldaystart
   else
      at_min_dt = ctx%control%at_min_dt
      day_start_event = ctx%time%day_start_event
   end if
   if (.not. legacy_state_binding) then
      if (.not. present(physical_config)) error stop 'HeadCalc: explicit physical config required'
      if (physical_config%macropore_active) error stop 'HeadCalc: active explicit macropore route not admitted'
      swmacro = 0
      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'
      swbotb = boundary_conditions%bottom_mode
      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'
      if (.not. present(explicit_step_duration)) error stop 'HeadCalc: explicit step duration required'
      if (explicit_step_duration <= 0.0d0) error stop 'HeadCalc: explicit step duration must be positive'
      dt = explicit_step_duration
      swkimpl = numerical_config%conductivity_implicit_mode
      swkmean = numerical_config%conductivity_mean_method
      maxit = numerical_config%max_iterations
      maxbacktr = numerical_config%max_backtracking
      dtmin = numerical_config%min_step_duration
      CritDevBalCp = numerical_config%compartment_balance_tolerance
      CritDevBalTot = numerical_config%total_balance_tolerance
      critdevh2cp = numerical_config%head_abs_tolerance
      critdevh1cp = numerical_config%head_rel_tolerance
      critdevponddt = numerical_config%ponding_tolerance
   end if
"""
new_init = """   if (legacy_state_binding) then
      swmacro = legacy_swmacro
      swbotb = legacy_swbotb
      dt = legacy_dt
      swkimpl = legacy_swkimpl
      swkmean = legacy_swkmean
      maxit = legacy_maxit
      maxbacktr = legacy_maxbacktr
      dtmin = legacy_dtmin
      critdevh2cp = legacy_critdevh2cp
      critdevh1cp = legacy_critdevh1cp
      critdevponddt = legacy_critdevponddt
      CritDevBalCp = legacy_CritDevBalCp
      CritDevBalTot = legacy_CritDevBalTot
      at_min_dt = legacy_fldtmin
      day_start_event = legacy_fldaystart
   else
      if (.not. present(physical_config)) error stop 'HeadCalc: explicit physical config required'
      if (physical_config%macropore_active) error stop 'HeadCalc: active explicit macropore route not admitted'
      swmacro = 0
      if (.not. present(boundary_conditions)) error stop 'HeadCalc: explicit boundary conditions required'
      swbotb = boundary_conditions%bottom_mode
      if (.not. present(numerical_config)) error stop 'HeadCalc: explicit numerical config required'
      if (.not. present(explicit_step_duration)) error stop 'HeadCalc: explicit step duration required'
      if (explicit_step_duration <= 0.0d0) error stop 'HeadCalc: explicit step duration must be positive'
      dt = explicit_step_duration
      swkimpl = numerical_config%conductivity_implicit_mode
      swkmean = numerical_config%conductivity_mean_method
      maxit = numerical_config%max_iterations
      maxbacktr = numerical_config%max_backtracking
      dtmin = numerical_config%min_step_duration
      CritDevBalCp = numerical_config%compartment_balance_tolerance
      CritDevBalTot = numerical_config%total_balance_tolerance
      critdevh2cp = numerical_config%head_abs_tolerance
      critdevh1cp = numerical_config%head_rel_tolerance
      critdevponddt = numerical_config%ponding_tolerance
      at_min_dt = ctx%control%at_min_dt
      day_start_event = ctx%time%day_start_event
   end if
"""
head = replace_once(head, old_init, new_init, 'split legacy/canonical startup config')

old_alt = """      if (ierror /= 0) then
         call dtdpst ('year-month-day', t1900+1.001d0, datetime)
         write(cval,'(I10)') i_instance
         message = cval//' Tri-band matrix in HeadCalc appeared to be singular at '//adjustl(trim(datetime))//' Alternative SOLVER chosen'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         ctx%diagnostics%alternative_solver_calls = ctx%diagnostics%alternative_solver_calls + 1
         call alternative_solver()
      end if
"""
new_alt = """      if (ierror /= 0) then
         if (.NOT.canonical_trial) then
            call dtdpst ('year-month-day', t1900+1.001d0, datetime)
            write(cval,'(I10)') i_instance
            message = cval//' Tri-band matrix in HeadCalc appeared to be singular at '//adjustl(trim(datetime))//' Alternative SOLVER chosen'
            call swap_warning ('headcalc', message)
         end if
         ctx%diagnostics%alternative_solver_calls = ctx%diagnostics%alternative_solver_calls + 1
         call alternative_solver()
      end if
"""
head = replace_once(head, old_alt, new_alt, 'canonical alternative-solver warning isolation')

old_warn = """      if (hist%flwarn) then
         hist%iwarn = hist%iwarn + 1
         call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
         write(cval,'(I10)') i_instance
         message = cval//' No convergence was reached of Richards equation at '//datetime//' no more than 4 warnings per date - SWAP did continue!'
         if (.NOT.canonical_trial) call swap_warning ('headcalc', message)
         if (hist%iwarn > 3) hist%flwarn = .FALSE.  
      end if
"""
new_warn = """      if (hist%flwarn) then
         hist%iwarn = hist%iwarn + 1
         if (.NOT.canonical_trial) then
            call dtdpst('year-month-day,hour:minute:seconds',t1900,datetime)
            write(cval,'(I10)') i_instance
            message = cval//' No convergence was reached of Richards equation at '//datetime//' no more than 4 warnings per date - SWAP did continue!'
            call swap_warning ('headcalc', message)
         end if
         if (hist%iwarn > 3) hist%flwarn = .FALSE.  
      end if
"""
head = replace_once(head, old_warn, new_warn, 'canonical no-convergence warning isolation')

# Structural fail-closed assertions: explicit config must be assigned only in
# the explicit branch and legacy configuration reads must sit in the legacy branch.
legacy_branch = head.split('   if (legacy_state_binding) then\n', 1)[1].split('   else\n', 1)[0]
for token in (
    'legacy_swmacro', 'legacy_swbotb', 'legacy_dt', 'legacy_swkimpl', 'legacy_swkmean',
    'legacy_maxit', 'legacy_maxbacktr', 'legacy_dtmin', 'legacy_critdevh2cp',
    'legacy_critdevh1cp', 'legacy_critdevponddt', 'legacy_CritDevBalCp',
    'legacy_CritDevBalTot', 'legacy_fldtmin', 'legacy_fldaystart'):
    if token not in legacy_branch:
        raise SystemExit(f'FMR20_STAGE2_MATERIALIZE_FAIL missing legacy-only startup token {token}')
if "if (.NOT.canonical_trial) call swap_warning" in head:
    raise SystemExit('FMR20_STAGE2_MATERIALIZE_FAIL canonical warning still constructs legacy message eagerly')
HEADCALC.write_text(head, encoding='utf-8')
print('FMR20_STAGE2_G02_HEADCALC_STARTUP_READ_ISOLATION=PASS')

backend = BACKEND.read_text(encoding='utf-8')
backend = replace_once(
    backend,
    '  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context\n',
    '',
    'remove legacy context mirror import')
backend = replace_once(
    backend,
    '    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok\n',
    '    logical :: snow_event_applied_this_call, temporal_history_ok\n',
    'remove context_ok local')
backend = replace_once(
    backend,
    '    call bind_b110_serialized_legacy_context(request, context_ok)\n    if (.not. context_ok) return\n',
    '',
    'remove legacy context mirror call')
if 'bind_b110_serialized_legacy_context' in backend or 'context_ok' in backend:
    raise SystemExit('FMR20_STAGE2_MATERIALIZE_FAIL legacy context mirror remains in canonical backend')
BACKEND.write_text(backend, encoding='utf-8')
print('FMR20_STAGE2_G03_CANONICAL_BACKEND_MIRROR_REMOVED=PASS')

changed = subprocess.check_output(['git', 'diff', '--name-only', '--', 'src'], text=True).splitlines()
expected = [
    'src/legacy/b1_10_port/headcalc.f90',
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
]
if changed != expected:
    raise SystemExit(f'FMR20_STAGE2_MATERIALIZE_FAIL unexpected source diff: {changed}')
print('FMR20_STAGE2_G04_EXACT_SOURCE_SCOPE=PASS')

for path in (HEADCALC, BACKEND):
    print(f'FMR20_STAGE2_POSTIMAGE {path} {git_blob(path)}')
print('FMR20_CONTEXT_MIRROR_REMOVAL_MATERIALIZE=PASS')

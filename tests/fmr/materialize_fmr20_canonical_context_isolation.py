#!/usr/bin/env python3
from pathlib import Path
import hashlib
import subprocess

HEADCALC = Path('src/legacy/b1_10_port/headcalc.f90')
BINDING = Path('src/adapter/mod_reference_richards_legacy_binding.f90')
EXPECTED_BLOBS = {
    HEADCALC: '55893f1f5ccba2052ad681743aa155b69f351246',
    BINDING: '6eda1fec1bd03c03a1c0a8f2df29a273f70d962f',
}


def git_blob(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'FMR20_MATERIALIZE_FAIL {label}: expected 1 occurrence, found {count}')
    return text.replace(old, new, 1)


for path, expected in EXPECTED_BLOBS.items():
    actual = git_blob(path)
    if actual != expected:
        raise SystemExit(f'FMR20_MATERIALIZE_FAIL source drift {path}: {actual} != {expected}')
print('FMR20_MATERIALIZE_G01_PREIMAGE_LOCK=PASS')

head = HEADCALC.read_text(encoding='utf-8')
head = replace_once(
    head,
    'use variables,          only: fldaystart, legacy_swbotb => swbotb,',
    'use variables,          only: legacy_fldaystart => fldaystart, legacy_swbotb => swbotb,',
    'alias fldaystart')
head = replace_once(
    head,
    'sw4, qbotab, fldtmin, legacy_maxit => maxit,',
    'sw4, qbotab, legacy_fldtmin => fldtmin, legacy_maxit => maxit,',
    'alias fldtmin')
head = replace_once(
    head,
    '   logical :: canonical_trial\n',
    '   logical :: canonical_trial\n   logical :: at_min_dt, day_start_event\n',
    'worker local logical declarations')
head = replace_once(
    head,
    '   CritDevBalTot = legacy_CritDevBalTot\n   if (.not. legacy_state_binding) then\n',
    '   CritDevBalTot = legacy_CritDevBalTot\n'
    '   if (legacy_state_binding) then\n'
    '      at_min_dt = legacy_fldtmin\n'
    '      day_start_event = legacy_fldaystart\n'
    '   else\n'
    '      at_min_dt = ctx%control%at_min_dt\n'
    '      day_start_event = ctx%time%day_start_event\n'
    '   end if\n'
    '   if (.not. legacy_state_binding) then\n',
    'derive worker-local min-dt/day-event')
head = replace_once(head, '   if (fldaystart) then\n', '   if (day_start_event) then\n', 'day-start read')
head = replace_once(head, '   if (fldtmin) MaxIt1 = 2*MaxIt\n', '   if (at_min_dt) MaxIt1 = 2*MaxIt\n', 'min-dt iteration ceiling')
head = replace_once(head, '         if (fldtmin .AND. state%numbit > MaxIt) then', '         if (at_min_dt .AND. state%numbit > MaxIt) then', 'min-dt backtracking limiter')
head = replace_once(head, '   if (.NOT.fldtmin) then\n', '   if (.NOT.at_min_dt) then\n', 'min-dt nonconvergence branch')
head = replace_once(
    head,
    '      fldtmin    = .FALSE.\n',
    '      at_min_dt = .FALSE.\n'
    '      if (legacy_state_binding) legacy_fldtmin = .FALSE.\n',
    'min-dt reset publication')

# The only remaining textual occurrences must be the two legacy aliases/usages
# in the explicit legacy branch; canonical algorithmic decisions use local state.
if head.count('legacy_fldtmin') != 3:
    raise SystemExit(f'FMR20_MATERIALIZE_FAIL unexpected legacy_fldtmin count {head.count("legacy_fldtmin")}')
if head.count('legacy_fldaystart') != 2:
    raise SystemExit(f'FMR20_MATERIALIZE_FAIL unexpected legacy_fldaystart count {head.count("legacy_fldaystart")}')
for forbidden in ('if (fldtmin)', 'if (.NOT.fldtmin)', 'if (fldaystart)'):
    if forbidden in head:
        raise SystemExit(f'FMR20_MATERIALIZE_FAIL canonical/shared token remains: {forbidden}')
HEADCALC.write_text(head, encoding='utf-8')
print('FMR20_MATERIALIZE_G02_HEADCALC_WORKER_LOCAL_CONTEXT=PASS')

binding = BINDING.read_text(encoding='utf-8')
binding = replace_once(
    binding,
    '       a23bu_initialize_worker, a23bu_reset_attempt_diagnostics, a23bu_reset_attempt_control\n',
    '       a23bu_initialize_worker, a23bu_reset_attempt_diagnostics, a23bu_seed_timestep_control\n',
    'worker min-dt seed import')
binding = replace_once(
    binding,
    '       dtmin, CritDevBalCp, CritDevBalTot, critdevh2cp, critdevh1cp, critdevponddt, fldtmin, &\n',
    '       dtmin, CritDevBalCp, CritDevBalTot, critdevh2cp, critdevh1cp, critdevponddt, &\n',
    'remove shared fldtmin import')
binding = replace_once(
    binding,
    '       call a23bu_reset_attempt_control(ws%legacy_worker)\n',
    '       call a23bu_seed_timestep_control(ws%legacy_worker, request%step_duration, &\n'
    '            request%numerical%min_step_duration)\n',
    'seed worker min-dt control')
binding = replace_once(
    binding,
    "    if (fldtmin) then\n       route = 'legacy-min-dt-deferred'\n       return\n    end if\n",
    '',
    'remove shared min-dt validation gate')
if 'fldtmin' in binding:
    raise SystemExit('FMR20_MATERIALIZE_FAIL fldtmin remains in canonical reference binding')
if 'a23bu_reset_attempt_control' in binding:
    raise SystemExit('FMR20_MATERIALIZE_FAIL reset-only min-dt control remains in reference binding')
BINDING.write_text(binding, encoding='utf-8')
print('FMR20_MATERIALIZE_G03_REFERENCE_BINDING_WORKER_SEED=PASS')

changed = subprocess.check_output(['git', 'diff', '--name-only', '--', 'src'], text=True).splitlines()
expected = [
    'src/adapter/mod_reference_richards_legacy_binding.f90',
    'src/legacy/b1_10_port/headcalc.f90',
]
if changed != expected:
    raise SystemExit(f'FMR20_MATERIALIZE_FAIL unexpected source diff: {changed}')
print('FMR20_MATERIALIZE_G04_EXACT_SOURCE_SCOPE=PASS')

for path in (HEADCALC, BINDING):
    print(f'FMR20_MATERIALIZE_POSTIMAGE {path} {git_blob(path)}')
print('FMR20_CANONICAL_CONTEXT_ISOLATION_MATERIALIZE=PASS')

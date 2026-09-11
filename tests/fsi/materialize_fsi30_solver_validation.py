#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path('src/adapter/mod_reference_richards_legacy_binding.f90')
EXPECTED_BLOB = 'f8acd89e54b410fe70792ddee29ddd47134a401d'
MARKER = "dynamic-top-provider-required"

text = PATH.read_text()
if MARKER in text:
    print('FSI30_SOLVER_VALIDATION_ALREADY_MATERIALIZED=YES')
    raise SystemExit(0)
actual = subprocess.check_output(['git','hash-object',str(PATH)], text=True).strip()
if actual != EXPECTED_BLOB:
    raise SystemExit(f'F-SI30 solver validation source lock failed: expected {EXPECTED_BLOB}, got {actual}')


def replace_once(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-SI30 {label}: expected one anchor, found {count}')
    text = text.replace(old, new, 1)

replace_once(
"""  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_LEGACY_CONTEXT, FSI_TOP_MODE_EXPLICIT_FLUX
""",
"""  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, &
       initialize_reference_state_binding, FSI_TOP_MODE_LEGACY_CONTEXT, FSI_TOP_MODE_EXPLICIT_FLUX, &
       FSI_TOP_MODE_DYNAMIC_PROVIDER
""",
'import-dynamic-mode')

replace_once(
"""    if (request%boundary%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) then
       route = 'explicit-top-mode-required'
       return
    end if
    if (.not. associated(request%evaluation%top_boundary)) then
       route = 'explicit-top-provider-required'
       return
    end if
""",
"""    select case (request%boundary%top_mode)
    case (FSI_TOP_MODE_EXPLICIT_FLUX)
       if (.not. associated(request%evaluation%top_boundary)) then
          route = 'explicit-top-provider-required'
          return
       end if
    case (FSI_TOP_MODE_DYNAMIC_PROVIDER)
       if (.not. associated(request%evaluation%dynamic_top_boundary)) then
          route = 'dynamic-top-provider-required'
          return
       end if
    case default
       route = 'explicit-top-mode-required'
       return
    end select
""",
'validate-dynamic-mode')

PATH.write_text(text)
new_blob = subprocess.check_output(['git','hash-object',str(PATH)], text=True).strip()
print('FSI30_SOLVER_VALIDATION_MATERIALIZED=YES')
print('FSI30_SOLVER_VALIDATION_INPUT_BLOB=' + EXPECTED_BLOB)
print('FSI30_SOLVER_VALIDATION_OUTPUT_BLOB=' + new_blob)

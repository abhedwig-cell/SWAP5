from pathlib import Path
import runpy

BACKEND = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')

runpy.run_path('tests/ross/_apply_ross12_serialized_production_wiring_patch.py', run_name='__main__')

text = BACKEND.read_text()
old = """    call bind_b110_serialized_legacy_context(request, context_ok)\n    if (.not. context_ok) return\n"""
new = """    if (self%soil_water_selection%uses_rossfast()) then\n      context_ok = .true.\n    else\n      call bind_b110_serialized_legacy_context(request, context_ok)\n    end if\n    if (.not. context_ok) return\n"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'ROSS12_LEGACY_CONTEXT_BYPASS_ANCHOR_COUNT={count}')
text = text.replace(old, new, 1)
BACKEND.write_text(text)
print('ROSS12_LEGACY_CONTEXT_BYPASS_PATCH_COUNT=1')
print('ROSS12_SERIALIZED_PRODUCTION_CANDIDATE_PATCH_COUNT=14')

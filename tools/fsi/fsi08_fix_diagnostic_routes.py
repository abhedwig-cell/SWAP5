#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
paths = [
    ROOT / 'src/adapter/mod_reference_richards_legacy_binding.f90',
    ROOT / 'tools/fsi/fsi08_materialize_provider_context.py',
    ROOT / 'tests/fsi/test_fsi08_provider_failclosed.f90',
    ROOT / 'tests/fsi/run_fsi08_provider_context_gate.sh',
]
replacements = {
    'explicit-constitutive-provider-required': 'constitutive-provider-required',
    'explicit-source-sink-provider-required': 'source-sink-provider-required',
}
for path in paths:
    text = path.read_text()
    before = text
    for old, new in replacements.items():
        if old not in text:
            raise SystemExit(f'F-SI08 route fix: missing {old} in {path.relative_to(ROOT)}')
        text = text.replace(old, new)
    if text == before:
        raise SystemExit(f'F-SI08 route fix: no change in {path.relative_to(ROOT)}')
    path.write_text(text)
print('F-SI08_DIAGNOSTIC_ROUTES_BOUNDED')

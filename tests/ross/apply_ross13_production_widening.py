#!/usr/bin/env python3
from __future__ import annotations

from decimal import Decimal
import json
from pathlib import Path
import re
import subprocess

MODEL = Path('src/runtime/mod_rossfast_d3r_model_binding.f90')
PROVIDER = Path('src/solver/mod_rossfast_d3r_table_provider.f90')
EXPECTED_MODEL_BLOB = '9f29ba7a08844692ba2628c7869d23713409f92b'
EXPECTED_PROVIDER_BLOB = 'afc05eb3001d91f66ca542978c3c6795283a7ac0'
CATALOG_HEAD = '04807fdcf45453a59b7f6c99fe97f1286c172833'
CATALOG_PATH = 'integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json'
EXPECTED_CATALOG_BLOB = '76596a00296318b871a9109ed6187bb86ccfae32'
IDS = [f'B{i:02d}' for i in range(1, 19)] + [f'O{i:02d}' for i in range(1, 19)]


def git(*args: str) -> str:
    return subprocess.check_output(['git', *args], text=True).strip()


def fail(message: str) -> None:
    raise SystemExit(f'F_ROSS13_APPLY_FAIL {message}')


def real64(value: Decimal) -> str:
    text = format(value, 'f')
    if '.' not in text:
        text += '.0'
    return text + '_real64'


if git('rev-parse', f'HEAD:{MODEL}') != EXPECTED_MODEL_BLOB:
    fail('model binding preimage drift')
if git('rev-parse', f'HEAD:{PROVIDER}') != EXPECTED_PROVIDER_BLOB:
    fail('table provider preimage drift')
if git('rev-parse', f'{CATALOG_HEAD}:{CATALOG_PATH}') != EXPECTED_CATALOG_BLOB:
    fail('historical material catalog authority drift')

raw = subprocess.check_output(['git', 'show', f'{CATALOG_HEAD}:{CATALOG_PATH}'], text=True)
data = json.loads(raw, parse_float=Decimal, parse_int=Decimal)
rows = data.get('rows', [])
if [row.get('sfu') for row in rows] != IDS:
    fail('historical material catalog IDs/order differ from exact B01-B18/O01-O18 authority')

fields = [
    'theta_r', 'theta_s', 'alpha_per_cm', 'n',
    'ksatfit_cm_per_day', 'ksatexm_cm_per_day', 'lambda', 'h_enpr_cm'
]
case_lines: list[str] = []
for row in rows:
    mid = row['sfu']
    vals = [real64(row[name]) for name in fields]
    case_lines.extend([
        f"    case('{mid}')",
        f"      material = rossfast_d3r_material_t('{mid}', {vals[0]}, {vals[1]}, &",
        f"           {vals[2]}, {vals[3]}, {vals[4]}, {vals[5]}, &",
        f"           {vals[6]}, {vals[7]})",
    ])

model_text = MODEL.read_text()
sub_start = model_text.index('  pure subroutine rossfast_d3r_material_from_id')
sub_end = model_text.index('  end subroutine rossfast_d3r_material_from_id', sub_start)
sub = model_text[sub_start:sub_end]
pattern = re.compile(
    r"    select case\(trim\(material_id\)\)\n.*?"
    r"    case default\n      found = \.false\.\n    end select",
    re.S,
)
if len(pattern.findall(sub)) != 1:
    fail('model material select-case target is not unique')
replacement = (
    '    select case(trim(material_id))\n'
    + '\n'.join(case_lines)
    + "\n    case default\n      found = .false.\n    end select"
)
new_sub = pattern.sub(replacement, sub, count=1)
new_model = model_text[:sub_start] + new_sub + model_text[sub_end:]
if new_model == model_text:
    fail('model binding did not change')
MODEL.write_text(new_model)

provider_text = PROVIDER.read_text()
old_provider_case = "    case('B01','B12','O01','O05','O14','O18')"
if provider_text.count(old_provider_case) != 1:
    fail('provider six-material select-case target is not unique')
provider_case = (
    "    case('B01','B02','B03','B04','B05','B06','B07','B08','B09', &\n"
    "         'B10','B11','B12','B13','B14','B15','B16','B17','B18', &\n"
    "         'O01','O02','O03','O04','O05','O06','O07','O08','O09', &\n"
    "         'O10','O11','O12','O13','O14','O15','O16','O17','O18')"
)
new_provider = provider_text.replace(old_provider_case, provider_case, 1)
PROVIDER.write_text(new_provider)

changed = git('diff', '--name-only', '--', 'src').splitlines()
expected = [str(MODEL), str(PROVIDER)]
if sorted(changed) != sorted(expected):
    fail(f'unexpected source mutation surface: {changed}')
subprocess.run(['git', 'diff', '--check', '--', *expected], check=True)

print('F_ROSS13_MODEL_PREIMAGE_LOCK=PASS')
print('F_ROSS13_PROVIDER_PREIMAGE_LOCK=PASS')
print('F_ROSS13_HISTORICAL_CATALOG_LOCK=PASS')
print('F_ROSS13_EXACT_TWO_FILE_MUTATION_SURFACE=PASS')

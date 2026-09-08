#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof14-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=03c8c2900c976dec955b2c34a5d903c68edd9547
FWO10=98a26f0294aafac6d1ed46ace2d6bcc05914d9f0

changed_src="$(git diff --name-only "$BASE" -- src)"
[[ -z "$changed_src" ]] || {
  echo 'FWOF14_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF14_ZERO_PRODUCTION_DELTA=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF14_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob src/crop/mod_crop_root_uptake_input_contract.f90 cc5594f6c7a91ac2ff37af611d40c740b7f25521
check_blob src/crop/mod_crop_root_uptake_input_assembly.f90 71f1e237c41af56ee85dcadfaae330f5d50ae0f7
check_blob src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90 9105126c219cbd06fadfa7757ba95d7b7bd0499b
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
echo 'FWOF14_FWO13_FMR12_FMR10_SOURCE_LOCKS=PASS'

git show "$FWO10:integration/f-wof/F-WOF10_STATUS.json" > "$BUILD/fwof10.json"

python3 - "$BUILD/fwof10.json" <<'PY'
from pathlib import Path
import json, sys

root = Path('.')
fwof10 = json.loads(Path(sys.argv[1]).read_text())
assert fwof10['scope']['full_crop_host_integration'] is False
assert any('crop-host' in item.lower() for item in fwof10['open'])
assert any('lifecycle' in item.lower() for item in fwof10['open'])

crop_files = sorted(p.name for p in (root / 'src/crop').glob('*') if p.is_file())
assert crop_files == [
    'mod_crop_root_uptake_input_assembly.f90',
    'mod_crop_root_uptake_input_contract.f90',
], crop_files

process_files = sorted(p.name for p in (root / 'src/process').glob('*') if p.is_file())
assert process_files == [
    'mod_irrigation_process.f90',
    'mod_root_water_uptake_process.f90',
    'mod_snow_process.f90',
], process_files

sources = sorted(list((root / 'src').rglob('*.f90')) + list((root / 'src').rglob('*.F90')))
for symbol in ['crop_root_state_view_t', 'root_uptake_et_result_t']:
    hits = [str(p) for p in sources if symbol in p.read_text(errors='ignore').lower()]
    assert hits == ['src/crop/mod_crop_root_uptake_input_assembly.f90'], (symbol, hits)

backend = (root / 'src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
for forbidden in ['potential_transpiration', 'crop_root_state_view_t', 'root_uptake_et_result_t']:
    assert forbidden not in backend, forbidden

status = json.loads((root / 'integration/f-wof/F-WOF13_STATUS.json').read_text())
assert status['status'] == 'QUALIFIED_EXPLICIT_CROP_ROOT_SNAPSHOT_AND_ET_ASSEMBLY_SEAM'
assert status['state']['qualified'] is True
print('FWOF14_CURRENT_OWNER_SOURCE_INVENTORY=PASS')
print('FWOF14_NO_CONCRETE_CROP_ROOT_VIEW_PRODUCER=PASS')
print('FWOF14_NO_CURRENT_ET_RESULT_PRODUCER=PASS')
print('FWOF14_FWO10_FULL_CROP_HOST_NOT_QUALIFIED=PASS')
PY

if git merge-base --is-ancestor "$FWO10" HEAD; then
  echo 'FWOF14_UNEXPECTED_FWO10_ANCESTOR_OF_CURRENT_LINEAGE' >&2
  exit 1
fi
if git merge-base --is-ancestor HEAD "$FWO10"; then
  echo 'FWOF14_UNEXPECTED_CURRENT_LINEAGE_ANCESTOR_OF_FWO10' >&2
  exit 1
fi
echo 'FWOF14_FWO10_CURRENT_LINEAGES_DIVERGED_NO_BLIND_MERGE=PASS'

echo 'FWOF14_DECISION=BLOCKED_BOTH_OWNER_INPUTS_NOT_YET_AVAILABLE'
echo 'FWOF14_ROOT_UPTAKE_PRODUCER_READINESS_GATE PASS'

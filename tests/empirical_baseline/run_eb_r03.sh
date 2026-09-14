#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

RUNTIME=src/runtime/mod_fmr_serialized_multiswap_runtime.f90
CURRENT_BLOB=1aa2454048d0e480becaee34f596f20f1a7bd66e
HISTORICAL_FMR38=b2e31bc8993075bc346f80ad7eb9dc4d92ff7ded
HISTORICAL_BLOB=f06a2eef7b47880e449cf9b201342d7bd1e197e1

git cat-file -e "$HISTORICAL_FMR38^{commit}"
test "$(git hash-object "$RUNTIME")" = "$CURRENT_BLOB"
test "$(git rev-parse "$HISTORICAL_FMR38:$RUNTIME")" = "$HISTORICAL_BLOB"
test "$CURRENT_BLOB" != "$HISTORICAL_BLOB"
grep -Fq 'forcing_index = int(column%forcing_handle)' "$RUNTIME"
grep -Fq 'forcing_registry(forcing_index)' "$RUNTIME"
grep -Fq 'type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing' "$RUNTIME"
echo 'EB_R03_CURRENT_RUNTIME_BLOB_PINNED=PASS'
echo 'EB_R03_HISTORICAL_FMR38_USED_AS_ORACLE_NOT_INHERITED=PASS'
echo 'EB_R03_CURRENT_REGISTRY_AND_RESOLVED_FORCING_SEAMS_PRESENT=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r03"
rm -rf "$BUILD"
mkdir -p "$BUILD"
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
BASE=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    if [[ "$src" == "src/solver/mod_soil_water_solver_contract.f90" ]]; then
      # The abstract/default unavailable temporal-indicator implementation has
      # intentionally unused interface arguments. They are unrelated to the
      # EB-R03 forcing-selection observation, so keep the warning visible but
      # do not promote this one warning class to an error for this support file.
      gfortran "${BASE[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    else
      gfortran "${BASE[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    fi
    objects+=("$obj")
  done

  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/empirical_baseline/mod_eb_r03_forcing_probe_backend.f90 -o "$OUT/mod_eb_r03_forcing_probe_backend.o"
  objects+=("$OUT/mod_eb_r03_forcing_probe_backend.o")
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_serialized_multiswap_runtime.f90 -o "$OUT/mod_fmr_serialized_multiswap_runtime.o"
  objects+=("$OUT/mod_fmr_serialized_multiswap_runtime.o")
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/empirical_baseline/observe_effective_forcing_selection.f90 -o "$OUT/observe_effective_forcing_selection.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/observe_effective_forcing_selection.o" \
    -o "$OUT/observe_effective_forcing_selection"
  "$OUT/observe_effective_forcing_selection" > "$OUT/observations.csv"
done

cmp "$BUILD/o0/observations.csv" "$BUILD/o2/observations.csv"
echo 'EB_R03_O0_O2_OBSERVATION_IDENTITY=PASS'
cat "$BUILD/o0/observations.csv"
echo "EB_R03_OBSERVATION_SHA256=$(sha256sum "$BUILD/o0/observations.csv" | cut -d' ' -f1)"

python3 - <<'PY'
import csv
import math
import os
from pathlib import Path

build = Path(os.environ.get('RUNNER_TEMP', os.environ.get('TMPDIR', '/tmp'))) / 'swap431-eb-r03'
path = build / 'o0' / 'observations.csv'
with path.open(newline='') as handle:
    rows = {row['case_id']: row for row in csv.DictReader(handle)}

expected = {
    'registry_a': ('registry', 1, 1.0, True, 'ADMITTED', 0.1, 0.1, 1, 0),
    'registry_b': ('registry', 2, 2.5, True, 'ADMITTED', 0.25, 0.25, 1, 0),
    'registry_a_replay': ('registry', 1, 1.0, True, 'ADMITTED', 0.1, 0.1, 1, 0),
    'resolved_b_with_handle_a': ('resolved', 1, 2.5, True, 'ADMITTED', 0.25, 0.25, 1, 0),
    'invalid_handle': ('registry', 3, -1.0, False, 'ROUTING_REJECTED', 0.0, 0.0, 0, 0),
}
if set(rows) != set(expected):
    raise SystemExit(f'case set mismatch: {sorted(rows)}')

for case_id, anchor in expected.items():
    row = rows[case_id]
    route, handle, scale, committed, admission, total_in, storage_change, revision, active = anchor
    if row['route'] != route or int(row['forcing_handle']) != handle:
        raise SystemExit(f'{case_id}: route/handle mismatch {row}')
    if not math.isclose(float(row['effective_scale']), scale, rel_tol=0.0, abs_tol=1e-15):
        raise SystemExit(f'{case_id}: effective scale mismatch {row}')
    if (row['committed'] == 'T') != committed or row['admission_status'].strip() != admission:
        raise SystemExit(f'{case_id}: commit/admission mismatch {row}')
    if not math.isclose(float(row['total_in']), total_in, rel_tol=0.0, abs_tol=2e-13):
        raise SystemExit(f'{case_id}: total_in mismatch {row}')
    if not math.isclose(float(row['storage_change']), storage_change, rel_tol=0.0, abs_tol=2e-13):
        raise SystemExit(f'{case_id}: storage_change mismatch {row}')
    if int(row['final_revision']) != revision or int(row['active_calls']) != active:
        raise SystemExit(f'{case_id}: revision/active mismatch {row}')

if rows['registry_a']['total_in'] != rows['registry_a_replay']['total_in']:
    raise SystemExit('A-B-A registry forcing replay is not textually identical')
if rows['registry_b']['total_in'] != rows['resolved_b_with_handle_a']['total_in']:
    raise SystemExit('resolved explicit forcing B does not reproduce registry forcing B')

print('EB_R03_HANDLE_SELECTS_EFFECTIVE_FORCING=PASS')
print('EB_R03_A_B_A_FORCING_STATELESS_REPLAY=PASS')
print('EB_R03_RESOLVED_FORCING_OVERRIDES_REGISTRY_HANDLE=PASS')
print('EB_R03_INVALID_HANDLE_FAILS_PRETRIAL=PASS')
print('EB_R03_CURRENT_CANONICAL_EFFECTIVE_FORCING_OBSERVATION PASS')
PY

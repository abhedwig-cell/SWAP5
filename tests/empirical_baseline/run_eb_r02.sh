#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FMR23_TESTED=3965b15ad0432b46134513eb13ec02a17f7d6b17
BINDING=src/runtime/mod_fmr_reference_et_demand_binding.f90
PROCESS=src/process/mod_reference_et_demand_process.f90
EXPECTED_BINDING_BLOB=8c679f911c9a82c498258224d83f5fce3cb09163
EXPECTED_PROCESS_BLOB=f5e88ec5089fd3b57ac111065fab2aa32dde0fae

git cat-file -e "$FMR23_TESTED^{commit}"
test "$(git hash-object "$BINDING")" = "$EXPECTED_BINDING_BLOB"
test "$(git rev-parse "$FMR23_TESTED:$BINDING")" = "$EXPECTED_BINDING_BLOB"
test "$(git hash-object "$PROCESS")" = "$EXPECTED_PROCESS_BLOB"
echo 'EB_R02_FMR23_BINDING_IDENTITY_INHERITED=PASS'
echo 'EB_R02_REFERENCE_ET_PROCESS_IDENTITY_INHERITED=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r02"
rm -rf "$BUILD"
mkdir -p "$BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/transaction/mod_transaction_reference.f90 -o "$OUT/mod_transaction_reference.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_canonical_contracts.f90 -o "$OUT/mod_canonical_contracts.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/runtime/mod_fmr_reference_et_demand_binding.f90 -o "$OUT/mod_fmr_reference_et_demand_binding.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/empirical_baseline/observe_reference_et_forcing_span.f90 -o "$OUT/observe_reference_et_forcing_span.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_reference_et_demand_process.o" "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/observe_reference_et_forcing_span.o" -o "$OUT/observe_reference_et_forcing_span"
  "$OUT/observe_reference_et_forcing_span" > "$OUT/observations.csv"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fmr/test_fmr23_reference_et_runtime_binding.f90 -o "$OUT/test_fmr23_reference_et_runtime_binding.o"
  gfortran -O"$opt" \
    "$OUT/mod_transaction_reference.o" "$OUT/mod_canonical_contracts.o" \
    "$OUT/mod_reference_et_demand_process.o" "$OUT/mod_fmr_reference_et_demand_binding.o" \
    "$OUT/test_fmr23_reference_et_runtime_binding.o" -o "$OUT/test_fmr23_reference_et_runtime_binding"
  "$OUT/test_fmr23_reference_et_runtime_binding" > "$OUT/fmr23-output.txt"
done

cmp "$BUILD/o0/observations.csv" "$BUILD/o2/observations.csv"
cmp "$BUILD/o0/fmr23-output.txt" "$BUILD/o2/fmr23-output.txt"
test "$(sha256sum "$BUILD/o0/fmr23-output.txt" | cut -d' ' -f1)" = 443f03b0fcc30a8e669c2db690eb94d2bd095606cbff11f75d82aa9cd88730d5
echo 'EB_R02_O0_O2_OBSERVATION_IDENTITY=PASS'
echo 'EB_R02_HISTORICAL_FMR23_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/observations.csv"
echo "EB_R02_OBSERVATION_SHA256=$(sha256sum "$BUILD/o0/observations.csv" | cut -d' ' -f1)"

python3 - <<'PY'
import csv
import math
import os
from pathlib import Path

build = Path(os.environ.get('RUNNER_TEMP', os.environ.get('TMPDIR', '/tmp'))) / 'swap431-eb-r02'
path = build / 'o0' / 'observations.csv'
with path.open(newline='') as handle:
    rows = {row['case_id']: row for row in csv.DictReader(handle)}

expected = {
    'contained_quarter': (0, 0, 0.25, True, True, 0.33462, 0.182, 0.2184),
    'contained_late': (0, 0, 0.35, True, True, 0.33462, 0.182, 0.2184),
    'left_not_covered': (3, 0, 0.20, False, False, 0.0, 0.0, 0.0),
    'invalid_zero_span': (2, 0, 0.10, False, False, 0.0, 0.0, 0.0),
    'negative_et': (4, 1, 0.10, True, False, 0.0, 0.0, 0.0),
    'nonemerged_cover': (0, 0, 0.20, True, True, 0.0, 0.364, 0.4368),
}
if set(rows) != set(expected):
    raise SystemExit(f'case set mismatch: {sorted(rows)}')

duration_tolerance = 2.0 * math.ulp(2701.0)
output_tolerance = 2.0e-13
for case_id, anchor in expected.items():
    row = rows[case_id]
    status, process_status, duration, called, produced, ptra, peva, epond = anchor
    if int(row['status']) != status or int(row['process_status']) != process_status:
        raise SystemExit(f'{case_id}: status mismatch {row}')
    if (row['process_called'] == 'T') != called or (row['result_produced'] == 'T') != produced:
        raise SystemExit(f'{case_id}: call/result flags mismatch {row}')
    observed_duration = float(row['duration'])
    if not math.isclose(observed_duration, duration, rel_tol=0.0, abs_tol=duration_tolerance):
        raise SystemExit(f'{case_id}: duration={observed_duration} target={duration} tol={duration_tolerance}')
    values = [float(row['ptra_cm_per_day']), float(row['peva_cm_per_day']), float(row['epond_cm_per_day'])]
    targets = [ptra, peva, epond]
    for value, target in zip(values, targets):
        if not math.isclose(value, target, rel_tol=0.0, abs_tol=output_tolerance):
            raise SystemExit(f'{case_id}: value={value} target={target}')

print('EB_R02_FORCING_SPAN_ANCHORS=PASS')
print('EB_R02_CURRENT_CANONICAL_FORCING_SPAN_OBSERVATION PASS')
PY

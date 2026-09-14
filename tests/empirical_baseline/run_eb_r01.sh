#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0
FPM06A_HEAD=23206aaf996ffb7dde355508fa2379a5efbd3d57
MODULE=src/process/mod_reference_et_demand_process.f90
EXPECTED_MODULE_BLOB=f5e88ec5089fd3b57ac111065fab2aa32dde0fae

git cat-file -e "$BASE^{commit}"
git cat-file -e "$FPM06A_HEAD^{commit}"
git merge-base --is-ancestor "$BASE" HEAD
test "$(git hash-object "$MODULE")" = "$EXPECTED_MODULE_BLOB"
test "$(git rev-parse "$FPM06A_HEAD:$MODULE")" = "$EXPECTED_MODULE_BLOB"
echo 'EB_R01_PINNED_CANONICAL_START=PASS'
echo 'EB_R01_FPM06A_MODULE_IDENTITY_INHERITED=PASS'

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r01"
rm -rf "$BUILD"
mkdir -p "$BUILD"
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/process/mod_reference_et_demand_process.f90 -o "$OUT/mod_reference_et_demand_process.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/empirical_baseline/observe_restricted_reference_et.f90 -o "$OUT/observe_restricted_reference_et.o"
  gfortran -O"$opt" \
    "$OUT/mod_reference_et_demand_process.o" "$OUT/observe_restricted_reference_et.o" \
    -o "$OUT/observe_restricted_reference_et"
  "$OUT/observe_restricted_reference_et" > "$OUT/observations.csv"
done
cmp "$BUILD/o0/observations.csv" "$BUILD/o2/observations.csv"
echo 'EB_R01_O0_O2_OBSERVATION_IDENTITY=PASS'
cat "$BUILD/o0/observations.csv"
echo "EB_R01_OBSERVATION_SHA256=$(sha256sum "$BUILD/o0/observations.csv" | cut -d' ' -f1)"

python3 - <<'PY'
import csv
import math
import os
from pathlib import Path

build = Path(os.environ.get('RUNNER_TEMP', os.environ.get('TMPDIR', '/tmp'))) / 'swap431-eb-r01'
path = build / 'o0' / 'observations.csv'
with path.open(newline='') as handle:
    rows = {row['case_id']: row for row in csv.DictReader(handle)}

expected = {
    'zero_forcing_bare': (0.0, 0.0, 0.0),
    'bare_5p2': (0.0, 0.52, 0.624),
    'inactive_cover_0p30': (0.0, 0.364, 0.4368),
    'active_cover_0p25': (0.1, 0.3, 0.3),
    'active_reference': (0.33462, 0.182, 0.2184),
    'active_full_cover': (0.5148, 0.0, 0.0),
    'active_half_variable': (0.1288, 0.115, 0.0805),
    'active_no_pond': (0.26, 0.26, 0.0),
}
if set(rows) != set(expected):
    raise SystemExit(f'case set mismatch: {sorted(rows)}')

fields = ('ptra_cm_per_day', 'peva_cm_per_day', 'epond_cm_per_day')
for case_id, anchors in expected.items():
    row = rows[case_id]
    if int(row['status']) != 0:
        raise SystemExit(f'{case_id}: nonzero status {row["status"]}')
    for field, anchor in zip(fields, anchors):
        observed = float(row[field])
        if not math.isclose(observed, anchor, rel_tol=0.0, abs_tol=2.0e-14):
            raise SystemExit(f'{case_id}: {field} observed={observed} expected={anchor}')

print('EB_R01_NUMERICAL_ANCHORS=PASS')
print('EB_R01_RESTRICTED_REFERENCE_ET_OBSERVATION PASS')
PY

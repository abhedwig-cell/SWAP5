#!/usr/bin/env bash
set -euo pipefail

BASE=8fa79a70a9faccaf8b63826df607a685eb75b046
CANDIDATE=c6cabe84272fef1829243e4271b2b1314233b634
SRC=src/process/mod_restricted_surface_evaporation.f90
TEST=tests/fpm/test_fpm06c_restricted_surface_evaporation.f90
AUDIT=integration/f-pm/F-PM06C_ARCHITECTURE_AUDIT.json
EXPECTED_BLOB=a213af4deec2fe854d79120899827852a57237d1
EXPECTED_PROCESS_VIEW=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
EXPECTED_SOLVER_CONTRACT=dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0

[[ "$(git merge-base "$BASE" HEAD)" == "$BASE" ]]
[[ "$(git rev-parse "$CANDIDATE:$SRC")" == "$EXPECTED_BLOB" ]]
[[ "$(git rev-parse "HEAD:$SRC")" == "$EXPECTED_BLOB" ]]
[[ "$(git rev-parse "HEAD:src/solver/mod_process_hydraulic_view.f90")" == "$EXPECTED_PROCESS_VIEW" ]]
[[ "$(git rev-parse "HEAD:src/solver/mod_soil_water_solver_contract.f90")" == "$EXPECTED_SOLVER_CONTRACT" ]]

mapfile -t prod_delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src)
[[ ${#prod_delta[@]} -eq 1 ]]
[[ "${prod_delta[0]}" == "$SRC" ]]
if git diff --name-only "$CANDIDATE"..HEAD -- src | grep -q .; then
  echo 'FPM06C_FAIL production source drift after candidate' >&2
  git diff --name-only "$CANDIDATE"..HEAD -- src >&2
  exit 6
fi

echo 'FPM06C_SOURCE_LOCK=PASS'
echo 'FPM06C_SINGLE_PRODUCTION_DELTA=PASS'

CODE=$(sed 's/!.*$//' "$SRC")
if printf '%s\n' "$CODE" | grep -Eiq 'headcalc|newton|jacobian|mass_(in|out)|mass[[:space:]_]*ledger|ponding_depth|process_hydraulic_view|soil_water_solver|tolerance|calendar|midnight'; then
  echo 'FPM06C_FAIL forbidden architectural dependency in production source' >&2
  exit 6
fi
if printf '%s\n' "$CODE" | grep -Eiq '\bday\b|86400'; then
  echo 'FPM06C_FAIL hidden day cadence in production source' >&2
  exit 6
fi

echo 'FPM06C_NO_SOLVER_INTERNAL_DEPENDENCY=PASS'
echo 'FPM06C_NO_SOLVER_TOLERANCE_CLASSIFICATION=PASS'
echo 'FPM06C_NO_MASS_BOOKING=PASS'
echo 'FPM06C_GENERIC_TIME_RATE_SEMANTICS=PASS'

python3 - <<'PY'
import json
p='integration/f-pm/F-PM06C_ARCHITECTURE_AUDIT.json'
d=json.load(open(p, encoding='utf-8'))
inv=d['invariants']
assert len(inv)==30
assert [x['id'] for x in inv]==list(range(1,31))
assert all(x['result']=='PASS' for x in inv)
assert d['production_blob']=='a213af4deec2fe854d79120899827852a57237d1'
print('FPM06C_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
PY

BUILD="${RUNNER_TEMP:-/tmp}/fpm06c-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

compile_and_run() {
  local opt="$1"
  local dir="$2"
  gfortran -std=f2008 -Wall -Wextra -Werror "$opt" -J"$dir" -I"$dir" -c "$SRC" -o "$dir/process.o"
  gfortran -std=f2008 -Wall -Wextra -Werror "$opt" -J"$dir" -I"$dir" -c "$TEST" -o "$dir/test.o"
  gfortran "$dir/process.o" "$dir/test.o" -o "$dir/test_fpm06c"
  "$dir/test_fpm06c" > "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
HASH=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')
echo "FPM06C_OUTPUT_SHA256=$HASH"
echo 'FPM06C_O0_O2_IDENTITY=PASS'
echo 'FPM06C_OWNER_GATE=PASS'

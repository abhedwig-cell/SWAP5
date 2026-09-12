#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$ROOT"
BASE=4023a16c32f4437f23fa1806a3ee0573f81fa1f3
ENERGY=src/process/mod_soil_thermal_energy_contract.f90
TEST=tests/eb/test_ebi02_soil_thermal_energy_contract.f90
TEMP_CONTRACT=src/process/mod_soil_temperature_contract.f90
TEMP_PROVIDER=src/process/mod_restricted_soil_temperature.f90
HYD=src/solver/mod_process_hydraulic_view.f90
LEGACY=tests/fci/test_fci43_restricted_soil_temperature_independent.f90
BUILD="${RUNNER_TEMP:-/tmp}/ebi02r1-${GITHUB_RUN_ID:-local}"; rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "EBI02R1_GATE_FAIL $*" >&2; exit 62; }

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
[[ "$(git rev-parse origin/integration/f-ci-canonical)" == "$BASE" ]] || fail "canonical race: expected $BASE got $(git rev-parse origin/integration/f-ci-canonical)"
echo 'EBI02R1_CURRENT_CANONICAL_RACE_GUARD=PASS'

test "$(git rev-parse HEAD:$TEMP_CONTRACT)" = baa13df3975de2c699b0ec910477bcfa9b47f15e || fail 'temperature contract drift'
test "$(git rev-parse HEAD:$TEMP_PROVIDER)" = fa4e1d7b48d3515e6569c9080d497178c25c4e85 || fail 'restricted provider drift'
test "$(git rev-parse HEAD:$HYD)" = d7d85fe71ced0d94b29c8d9395859ae1834f7dd6 || fail 'hydraulic view drift'
echo 'EBI02R1_FPM07B_FVQ58_THERMAL_SEAMS_PRESERVED=PASS'

mapfile -t delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
[[ "${#delta[@]}" -eq 1 && "${delta[0]}" == "$ENERGY" ]] || { printf '%s\n' "${delta[@]}" >&2; fail 'unexpected production delta'; }
echo 'EBI02R1_EXACT_ONE_FILE_PRODUCTION_DELTA=PASS'

python3 - "$ENERGY" "$HYD" <<'PY'
from pathlib import Path
import re,sys
e=Path(sys.argv[1]).read_text().lower(); h=Path(sys.argv[2]).read_text().lower()
for x in ['open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'pathwork', 'headcalc', 'jacobian', 'newton', 'mod_energy_conservation', 'mod_groundwater']:
    assert x not in e, x
for token in ['sensible_storage_accounted = .true.','top_conduction_accounted = .true.','bottom_conduction_accounted = .true.',
              'liquid_advection_accounted = .false.','vapor_transport_accounted = .false.','phase_change_accounted = .false.',
              'surface_energy_accounted = .false.','legacy_restricted_energy_accounting_complete','1.0e4_real64']:
    assert token in e, token
assert 'water_content(:)' in h
for token in ['q_liquid','q_vapour','q_vapor','water_flux','flux_liquid','flux_vapour']:
    assert token not in h, token
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', e)
print('EBI02R1_NO_IO_CALENDAR_HEADCALC_LEDGER_OR_GROUNDWATER_DEPENDENCY=PASS')
print('EBI02R1_PHASE_RESOLVED_HYDRAULIC_FLUX_NOT_AVAILABLE=PASS')
print('EBI02R1_FULL_PHYSICAL_ENERGY_CLOSURE_CLAIM=HELD_FALSE')
PY

git diff --check "$BASE" -- "$ENERGY" "$TEST" tests/eb .github/workflows || fail 'diff check'
echo 'EBI02R1_DIFF_CHECK=PASS'

DEP=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=unused-dummy-argument -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  D="$BUILD/o$opt"
  gfortran "${DEP[@]}" -O$opt -J "$D" -I "$D" -c src/transaction/mod_transaction_reference.f90 -o "$D/tx.o"
  gfortran "${DEP[@]}" -O$opt -J "$D" -I "$D" -c src/solver/mod_soil_water_solver_contract.f90 -o "$D/swc.o"
  gfortran "${DEP[@]}" -O$opt -J "$D" -I "$D" -c "$HYD" -o "$D/hyd.o"
  gfortran "${STRICT[@]}" -O$opt -J "$D" -I "$D" -c "$TEMP_CONTRACT" -o "$D/tc.o"
  gfortran "${STRICT[@]}" -O$opt -J "$D" -I "$D" -c "$TEMP_PROVIDER" -o "$D/tp.o"

  gfortran "${STRICT[@]}" -O$opt -J "$D" -I "$D" -c "$LEGACY" -o "$D/legacy.o"
  gfortran -O$opt "$D/tx.o" "$D/swc.o" "$D/hyd.o" "$D/tc.o" "$D/tp.o" "$D/legacy.o" -o "$D/legacy"
  "$D/legacy" > "$D/legacy.txt" 2>&1 || { cat "$D/legacy.txt" >&2; fail "legacy O$opt"; }
  grep -Fxq 'FVQ58_INDEPENDENT_ORACLE=PASS' "$D/legacy.txt" || fail "legacy marker O$opt"

  gfortran "${STRICT[@]}" -O$opt -J "$D" -I "$D" -c "$ENERGY" -o "$D/energy.o"
  gfortran "${STRICT[@]}" -O$opt -J "$D" -I "$D" -c "$TEST" -o "$D/test.o"
  gfortran -O$opt "$D/tx.o" "$D/swc.o" "$D/hyd.o" "$D/tc.o" "$D/tp.o" "$D/energy.o" "$D/test.o" -o "$D/test"
  "$D/test" > "$D/test.txt" 2>&1 || { cat "$D/test.txt" >&2; fail "EB-I02 O$opt"; }
  for m in EBI02_CHANGING_THETA_RESTRICTED_ONLY=PASS EBI02_J_CM2_TO_J_M2_CONVERSION=PASS EBI02_CONSTANT_THETA_DOES_NOT_IMPLY_ZERO_ADVECTIVE_ENERGY=PASS EBI02_FAIL_CLOSED_UNSUPPORTED_OR_INCONSISTENT_SCOPE=PASS 'EBI02_SOIL_THERMAL_ENERGY_CONTRACT_TEST PASS'; do grep -Fxq "$m" "$D/test.txt" || fail "missing $m"; done
done
cmp "$BUILD/o0/legacy.txt" "$BUILD/o2/legacy.txt" || fail 'legacy O0/O2 drift'
LEGACY_SHA=$(sha256sum "$BUILD/o0/legacy.txt" | awk '{print $1}')
[[ "$LEGACY_SHA" == e62c39e6fb3e71351fde4c949fb4c639d7fa16bb19fd593b55448432ae5ae583 ]] || fail "legacy hash drift $LEGACY_SHA"
cmp "$BUILD/o0/test.txt" "$BUILD/o2/test.txt" || fail 'EB-I02 O0/O2 drift'
echo "EBI02R1_FVQ58_ORACLE_OUTPUT_SHA256=$LEGACY_SHA"
echo 'EBI02R1_FVQ58_SCIENTIFIC_BEHAVIOR_PRESERVED=PASS'
echo 'EBI02R1_O0_O2_IDENTITY=PASS'
echo 'EBI02R1_SOIL_THERMAL_CONSERVATION_GATE PASS'

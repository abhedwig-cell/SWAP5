#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=c6494f913303b7aefc4f9c53c6c157082d54ea4b
TEMP_CONTRACT=src/process/mod_soil_temperature_contract.f90
TEMP_PROVIDER=src/process/mod_restricted_soil_temperature.f90
HYD_VIEW=src/solver/mod_process_hydraulic_view.f90
ENERGY_CONTRACT=src/process/mod_soil_thermal_energy_contract.f90
TEST=tests/eb/test_ebi02_soil_thermal_energy_contract.f90
LEGACY_ORACLE=tests/fci/test_fci43_restricted_soil_temperature_independent.f90
BLOB_TEMP_CONTRACT=baa13df3975de2c699b0ec910477bcfa9b47f15e
BLOB_TEMP_PROVIDER=fa4e1d7b48d3515e6569c9080d497178c25c4e85
BLOB_HYD_VIEW=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
EXPECTED_LEGACY_OUTPUT_SHA256=e62c39e6fb3e71351fde4c949fb4c639d7fa16bb19fd593b55448432ae5ae583
BUILD="${RUNNER_TEMP:-/tmp}/ebi02-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "EBI02_GATE_FAIL $*" >&2; exit 62; }

# This owner workunit starts from current canonical and must be recomposed rather
# than silently qualified if canonical moves underneath it.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$BASE" ]] || fail "canonical moved: expected $BASE got $CURRENT"
echo 'EBI02_CURRENT_CANONICAL_RACE_GUARD=PASS'

# Existing independently qualified soil-temperature science remains immutable.
test "$(git rev-parse HEAD:$TEMP_CONTRACT)" = "$BLOB_TEMP_CONTRACT" || fail 'soil temperature contract donor changed'
test "$(git rev-parse HEAD:$TEMP_PROVIDER)" = "$BLOB_TEMP_PROVIDER" || fail 'restricted soil temperature provider changed'
test "$(git rev-parse HEAD:$HYD_VIEW)" = "$BLOB_HYD_VIEW" || fail 'process hydraulic view changed'
echo 'EBI02_FPM07B_FVQ58_SCIENCE_BLOBS_IMMUTABLE=PASS'

mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${src_delta[@]}" > "$BUILD/src-delta"
printf '%s\n' "$ENERGY_CONTRACT" > "$BUILD/src-expected"
cmp -s "$BUILD/src-delta" "$BUILD/src-expected" || { cat "$BUILD/src-delta" >&2; fail 'unexpected production source delta'; }
echo 'EBI02_EXACT_ADDITIVE_PRODUCTION_SCOPE=PASS'

python3 - "$ENERGY_CONTRACT" "$HYD_VIEW" <<'PY'
from pathlib import Path
import re, sys
energy = Path(sys.argv[1]).read_text().lower()
hyd = Path(sys.argv[2]).read_text().lower()
for forbidden in ['open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'pathwork', 'headcalc', 'jacobian', 'newton']:
    assert forbidden not in energy, forbidden
assert 'mod_energy_conservation' not in energy
assert 'mod_groundwater' not in energy
assert '1.0e4_real64' in energy
assert 'liquid_advection_accounted = .false.' in energy
assert 'vapor_transport_accounted = .false.' in energy
assert 'phase_change_accounted = .false.' in energy
assert 'surface_energy_accounted = .false.' in energy
assert 'legacy_restricted_energy_accounting_complete' in energy
assert 'real(real64), allocatable :: water_content(:)' in hyd
for absent in ['q_liquid', 'q_vapour', 'q_vapor', 'water_flux', 'flux_liquid', 'flux_vapour']:
    assert absent not in hyd, absent
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', energy)
print('EBI02_NO_IO_CALENDAR_HEADCALC_OR_ENERGY_LEDGER_DEPENDENCY=PASS')
print('EBI02_PHASE_RESOLVED_HYDRAULIC_FLUX_DEPENDENCY_EXPLICITLY_UNAVAILABLE=PASS')
print('EBI02_FULL_PHYSICAL_ENERGY_CLOSURE_CLAIM=HELD_FALSE')
PY

git diff --check "$BASE" -- "$ENERGY_CONTRACT" "$TEST" tests/eb/run_ebi02_soil_thermal_conservation_gate.sh .github/workflows || fail 'diff check failed'
echo 'EBI02_DIFF_CHECK=PASS'

DEP_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=unused-dummy-argument -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_base() {
  local opt="$1" dir="$2"
  gfortran "${DEP_FLAGS[@]}" -O"$opt" -J "$dir" -I "$dir" -c src/transaction/mod_transaction_reference.f90 -o "$dir/tx.o"
  gfortran "${DEP_FLAGS[@]}" -O"$opt" -J "$dir" -I "$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/sw_contract.o"
  gfortran "${DEP_FLAGS[@]}" -O"$opt" -J "$dir" -I "$dir" -c "$HYD_VIEW" -o "$dir/hyd.o"
  gfortran "${STRICT_FLAGS[@]}" -O"$opt" -J "$dir" -I "$dir" -c "$TEMP_CONTRACT" -o "$dir/temp_contract.o"
  gfortran "${STRICT_FLAGS[@]}" -O"$opt" -J "$dir" -I "$dir" -c "$TEMP_PROVIDER" -o "$dir/temp_provider.o"
}

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  compile_base "$opt" "$OUT"

  # Replay the byte-identical independent F-VQ58/F-CI43 scientific oracle
  # against the unchanged provider and contract.
  gfortran "${STRICT_FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$LEGACY_ORACLE" -o "$OUT/legacy_test.o"
  gfortran -O"$opt" "$OUT/tx.o" "$OUT/sw_contract.o" "$OUT/hyd.o" "$OUT/temp_contract.o" "$OUT/temp_provider.o" \
    "$OUT/legacy_test.o" -o "$OUT/legacy_test"
  "$OUT/legacy_test" > "$OUT/legacy.txt" 2>&1 || { cat "$OUT/legacy.txt" >&2; fail "legacy oracle O$opt"; }
  grep -Fxq 'FVQ58_INDEPENDENT_ORACLE=PASS' "$OUT/legacy.txt" || fail "legacy oracle marker O$opt"

  gfortran "${STRICT_FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$ENERGY_CONTRACT" -o "$OUT/energy_contract.o"
  gfortran "${STRICT_FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/ebi02_test.o"
  gfortran -O"$opt" "$OUT/tx.o" "$OUT/sw_contract.o" "$OUT/hyd.o" "$OUT/temp_contract.o" "$OUT/temp_provider.o" \
    "$OUT/energy_contract.o" "$OUT/ebi02_test.o" -o "$OUT/ebi02_test"
  "$OUT/ebi02_test" > "$OUT/ebi02.txt" 2>&1 || { cat "$OUT/ebi02.txt" >&2; fail "EB-I02 test O$opt"; }
  for marker in \
    'EBI02_CHANGING_THETA_RESTRICTED_ONLY=PASS' \
    'EBI02_J_CM2_TO_J_M2_CONVERSION=PASS' \
    'EBI02_CONSTANT_THETA_DOES_NOT_IMPLY_ZERO_ADVECTIVE_ENERGY=PASS' \
    'EBI02_FAIL_CLOSED_UNSUPPORTED_OR_INCONSISTENT_SCOPE=PASS' \
    'EBI02_SOIL_THERMAL_ENERGY_CONTRACT_TEST PASS'; do
    grep -Fxq "$marker" "$OUT/ebi02.txt" || fail "missing marker O$opt: $marker"
  done
done

cmp "$BUILD/o0/legacy.txt" "$BUILD/o2/legacy.txt" || fail 'legacy O0/O2 output drift'
LEGACY_SHA="$(sha256sum "$BUILD/o0/legacy.txt" | awk '{print $1}')"
[[ "$LEGACY_SHA" == "$EXPECTED_LEGACY_OUTPUT_SHA256" ]] || fail "legacy independent oracle hash drift $LEGACY_SHA"
cmp "$BUILD/o0/ebi02.txt" "$BUILD/o2/ebi02.txt" || fail 'EB-I02 O0/O2 output drift'
echo "EBI02_FVQ58_ORACLE_OUTPUT_SHA256=$LEGACY_SHA"
echo 'EBI02_FVQ58_SCIENTIFIC_BEHAVIOR_PRESERVED=PASS'
echo 'EBI02_O0_O2_IDENTITY=PASS'
echo 'EBI02_SOIL_THERMAL_CONSERVATION_GATE PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=536042620038014057427a7915c212a3ac78f84d
FMR39=87b553094b66980006b69f5ba8b53d70ccd0a8e0
FMR39_BACKEND=07877429f94ccf07c353fa5f8ba969c341ad88dd
FMR39_RESTART=bb2c37efce37a73441181f14d15847c652ab45ea
FCI44_MODULE=src/runtime/mod_coupling_application_accuracy_contract.f90
FCI44_MODULE_BLOB=c07d573d21e7d013ab962c0a9d28102ab7b5cdfc
BUILD="${RUNNER_TEMP:-/tmp}/fmr40-${GITHUB_RUN_ID:-local}"
TEMP_TEST=tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90
TEMP_GATE=tests/fmr/run_fmr39_soil_temperature_runtime_gate.sh
rm -rf "$BUILD"
mkdir -p "$BUILD/fci44-o0" "$BUILD/fci44-o2"
cleanup(){ rm -f "$TEMP_TEST" "$TEMP_GATE"; rm -rf "$BUILD"; }
trap cleanup EXIT
fail(){ echo "FMR40_GATE_FAIL $*" >&2; exit 40; }

# Current-canonical race guard. A moving canonical invalidates this recomposition.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch current canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT"
echo "FMR40_CURRENT_CANONICAL_RACE_GUARD=PASS:$CURRENT"

# The recomposition must be exactly the two already-qualified F-MR39 runtime blobs.
mapfile -t delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
printf '%s\n' "${delta[@]}" > "$BUILD/delta.txt"
printf '%s\n' src/runtime/mod_fmr_restart_state_contract.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 | sort > "$BUILD/expected.txt"
cmp -s "$BUILD/delta.txt" "$BUILD/expected.txt" || { cat "$BUILD/delta.txt" >&2; fail 'unexpected production delta'; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$FMR39_BACKEND" ]] || fail 'F-MR39 backend blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_restart_state_contract.f90)" == "$FMR39_RESTART" ]] || fail 'F-MR39 restart-contract blob drift'
[[ "$(git rev-parse ${FMR39}:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$FMR39_BACKEND" ]] || fail 'F-MR39 source authority backend drift'
[[ "$(git rev-parse ${FMR39}:src/runtime/mod_fmr_restart_state_contract.f90)" == "$FMR39_RESTART" ]] || fail 'F-MR39 source authority restart drift'
echo 'FMR40_EXACT_FMR39_SOURCE_RECOMPOSITION=PASS'
echo 'FMR40_BOUNDED_PRODUCTION_DELTA=PASS'

# F-CI44 is orthogonal and must survive byte-identically.
[[ "$(git rev-parse ${BASE}:$FCI44_MODULE)" == "$FCI44_MODULE_BLOB" ]] || fail 'F-CI44 base module drift'
[[ "$(git rev-parse HEAD:$FCI44_MODULE)" == "$FCI44_MODULE_BLOB" ]] || fail 'F-CI44 module changed by recomposition'
echo 'FMR40_FCI44_MODULE_PRESERVED=PASS'

# Replay the exact F-MR39 test/gate authority. Only the old canonical-base pin is
# rebound to F-CI44; the test program and all F-MR39 acceptance markers remain exact.
git cat-file -e "${FMR39}^{commit}" || fail 'F-MR39 authority unavailable'
git show "${FMR39}:tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90" > "$TEMP_TEST"
git show "${FMR39}:tests/fmr/run_fmr39_soil_temperature_runtime_gate.sh" | \
  sed "s/^CANONICAL=.*/CANONICAL=$BASE/" > "$TEMP_GATE"
FMR39_TEST_BLOB="$(git rev-parse ${FMR39}:tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90)"
FMR39_GATE_BLOB="$(git rev-parse ${FMR39}:tests/fmr/run_fmr39_soil_temperature_runtime_gate.sh)"
echo "FMR40_FMR39_TEST_AUTHORITY=PASS:$FMR39_TEST_BLOB"
echo "FMR40_FMR39_GATE_AUTHORITY=PASS:$FMR39_GATE_BLOB"
bash "$TEMP_GATE" > "$BUILD/fmr39-rebound.txt" 2>&1 || { cat "$BUILD/fmr39-rebound.txt" >&2; fail 'F-MR39 rebound replay'; }
for marker in \
  FMR39_GATE=PASS \
  FMR39_RUNTIME_O0_O2_OUTPUT_IDENTITY=PASS \
  FMR39_DISABLED_PATH_O0_O2_OUTPUT_IDENTITY=PASS \
  FMR39_FVQ58_EXACT_SCIENTIFIC_AUTHORITY_REPLAY=PASS \
  FMR39_THERMAL_FAILURE_ROLLS_BACK_WATER_AND_TEMPERATURE=PASS \
  FMR39_SPLIT_RESTART_WATER_THERMAL_IDENTITY=PASS \
  FMR39_MIXED_ENABLED_DISABLED_MULTISWAP_ISOLATION=PASS; do
  grep -Fq "$marker" "$BUILD/fmr39-rebound.txt" || fail "missing rebound marker $marker"
done
grep -Fq 'FMR39_RUNTIME_OUTPUT_SHA256=cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942' "$BUILD/fmr39-rebound.txt" || fail 'F-MR39 runtime output fingerprint drift'
echo 'FMR40_FMR39_FULL_REBOUND_REPLAY=PASS'
echo 'FMR40_FMR39_RUNTIME_FINGERPRINT_IDENTITY=PASS'

# Focused F-CI44 contract oracle on the recomposed tree. The old admission gate
# cannot be replayed verbatim because it deliberately locks the pre-F-MR39 backend blob.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
compile_fci44(){
  local opt="$1" dir="$2"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c src/transaction/mod_transaction_reference.f90 -o "$dir/transaction.o"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c src/runtime/mod_canonical_contracts.f90 -o "$dir/contracts.o"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c "$FCI44_MODULE" -o "$dir/application_contract.o"
  gfortran "${COMMON[@]}" "$opt" -J "$dir" -I "$dir" -c tests/fci/test_fci44_application_accuracy_contract_admission.f90 -o "$dir/test.o"
  gfortran "$opt" "$dir/transaction.o" "$dir/contracts.o" "$dir/application_contract.o" "$dir/test.o" -o "$dir/test.exe"
  "$dir/test.exe" > "$dir/output.txt"
  "$dir/test.exe" > "$dir/output-repeat.txt"
  cmp "$dir/output.txt" "$dir/output-repeat.txt" || fail "F-CI44 repeat nondeterminism $opt"
}
compile_fci44 -O0 "$BUILD/fci44-o0"
compile_fci44 -O2 "$BUILD/fci44-o2"
cmp "$BUILD/fci44-o0/output.txt" "$BUILD/fci44-o2/output.txt" || fail 'F-CI44 focused O0/O2 drift'
grep -Fq 'FCI44_APPLICATION_ACCURACY_CONTRACT_TEST PASS' "$BUILD/fci44-o0/output.txt" || fail 'F-CI44 focused oracle missing close marker'
echo 'FMR40_FCI44_FOCUSED_CONTRACT_ORACLE_O0_O2=PASS'

git diff --check "$BASE" -- src integration/f-mr tests/fmr .github/workflows || fail 'diff check failed'
echo 'FMR40_REFERENCE_AND_SCIENCE_PRESERVATION=PASS'
echo 'FMR40_CURRENT_CANONICAL_RECOMPOSITION_GATE=PASS'

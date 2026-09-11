#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PROMOTED=13c16dc1c089e02c5f669f9596a13127bfbdb31f
OLD_CANONICAL=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
FCI43=a9f1123f2c6a5f08ffa51b491afda18fc4ab2060
FVQ58=5e81e14ad613cff7a72fc3f9cddcebc6696290d7
CONTRACT=src/process/mod_soil_temperature_contract.f90
PROVIDER=src/process/mod_restricted_soil_temperature.f90
BLOB_CONTRACT=baa13df3975de2c699b0ec910477bcfa9b47f15e
BLOB_PROVIDER=fa4e1d7b48d3515e6569c9080d497178c25c4e85
REFERENCE_TREE=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
ORACLE=tests/fci/test_fci43_restricted_soil_temperature_independent.f90
ORACLE_BLOB=51e76bbf839d86702a3d391585a6f0abc0e6bc38
EXPECTED_OUTPUT_SHA256=e62c39e6fb3e71351fde4c949fb4c639d7fa16bb19fd593b55448432ae5ae583
HISTORICAL=.github/workflows/fci42-surface-evaporation-allocation-performance-admission.yml
BUILD="${RUNNER_TEMP:-/tmp}/fci43p-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

fail() { echo "FCI43P_GATE_FAIL $*" >&2; exit 44; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$PROMOTED" "$OLD_CANONICAL" "$FCI43" "$FVQ58"; do need_commit "$sha"; done

# Reconciliation is against the exact promoted postimage and must abort on a moving canonical race.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CANONICAL_HEAD" == "$PROMOTED" ]] || fail "canonical moved during reconciliation: expected $PROMOTED got $CANONICAL_HEAD"
echo 'FCI43P_CURRENT_CANONICAL_PIN=PASS'

# Promotion must be a genuine two-parent merge with the declared old canonical and exact-qualified F-CI43 authority.
read -r merge p1 p2 extra <<<"$(git rev-list --parents -n1 "$PROMOTED")"
[[ "$merge" == "$PROMOTED" && "$p1" == "$OLD_CANONICAL" && "$p2" == "$FCI43" && -z "${extra:-}" ]] || fail "promotion parent set invalid: $merge $p1 $p2 ${extra:-}"
echo 'FCI43P_TRUE_TWO_PARENT_PROMOTION=PASS'

# Scientific and reference postimage must be byte-identical to the qualified authority.
test "$(git rev-parse ${PROMOTED}:$CONTRACT)" = "$BLOB_CONTRACT" || fail 'promoted contract blob drift'
test "$(git rev-parse ${PROMOTED}:$PROVIDER)" = "$BLOB_PROVIDER" || fail 'promoted provider blob drift'
test "$(git rev-parse HEAD:$CONTRACT)" = "$BLOB_CONTRACT" || fail 'reconciliation branch changed contract'
test "$(git rev-parse HEAD:$PROVIDER)" = "$BLOB_PROVIDER" || fail 'reconciliation branch changed provider'
test "$(git rev-parse ${PROMOTED}:reference)" = "$REFERENCE_TREE" || fail 'promoted reference tree drift'
test "$(git rev-parse HEAD:reference)" = "$REFERENCE_TREE" || fail 'reconciliation branch changed reference tree'
test "$(git rev-parse ${PROMOTED}:$ORACLE)" = "$ORACLE_BLOB" || fail 'promoted independent oracle blob drift'
test "$(git rev-parse HEAD:$ORACLE)" = "$ORACLE_BLOB" || fail 'reconciliation branch changed independent oracle'
git diff --quiet "$PROMOTED"..HEAD -- src reference "$ORACLE" || fail 'governance reconciliation changed scientific postimage'
echo 'FCI43P_SCIENTIFIC_POSTIMAGE_IMMUTABLE=PASS'
echo 'FCI43P_REFERENCE_IMMUTABLE=PASS'

# F-CI42 is a frozen historical exact-admission gate. It must not execute on future moving canonical heads.
grep -Fq 'qualification/f-ci42-fpe11-surface-evaporation-allocation-canonical-admission' "$HISTORICAL" || fail 'historical F-CI42 qualification trigger lost'
grep -Fq 'qualification/f-ci42p-current-canonical-postimage-governance-reconciliation' "$HISTORICAL" || fail 'historical F-CI42P reconciliation trigger lost'
if grep -Fq 'integration/f-ci-canonical' "$HISTORICAL"; then
  fail 'historical F-CI42 gate still triggers on moving canonical'
fi
echo 'FCI43P_STALE_FCI42_CANONICAL_TRIGGER_REMOVED=PASS'

# The moving canonical gate must remain active and must not be weakened by this workunit.
grep -Fq 'integration/f-ci-canonical' .github/workflows/fci-canonical.yml || fail 'moving canonical workflow trigger missing'
git diff --quiet "$PROMOTED"..HEAD -- .github/workflows/fci-canonical.yml || fail 'moving canonical workflow modified'
echo 'FCI43P_MOVING_CANONICAL_GATE_PRESERVED=PASS'

# Governance delta is bounded. No other pre-existing path may be modified.
while IFS= read -r path; do
  case "$path" in
    "$HISTORICAL"|tests/fci/run_fci43p_current_canonical_postimage_governance_reconciliation.sh|.github/workflows/fci43p-current-canonical-postimage-governance-reconciliation.yml|integration/f-ci/F-CI43P_EVIDENCE.json|integration/f-ci/F-CI43P_STATUS.json) ;;
    *) fail "unbounded F-CI43P delta: $path" ;;
  esac
done < <(git diff --name-only "$PROMOTED"..HEAD)
echo 'FCI43P_BOUNDED_GOVERNANCE_DELTA=PASS'

git diff --check "$PROMOTED" -- .github/workflows tests/fci integration/f-ci || fail 'diff check failed'

DEP_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=unused-dummy-argument -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
run_or_report() {
  local executable="$1" output="$2"
  if ! "$executable" > "$output" 2>&1; then
    cat "$output" >&2
    return 1
  fi
}
compile_and_run() {
  local opt="$1" dir="$2"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/transaction/mod_transaction_reference.f90 -o "$dir/tx.o"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/solver_contract.o"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/solver/mod_process_hydraulic_view.f90 -o "$dir/hydraulic_view.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$CONTRACT" -o "$dir/temp_contract.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$PROVIDER" -o "$dir/temp_provider.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$ORACLE" -o "$dir/test.o"
  gfortran "$opt" "$dir/tx.o" "$dir/solver_contract.o" "$dir/hydraulic_view.o" "$dir/temp_contract.o" "$dir/temp_provider.o" "$dir/test.o" -o "$dir/fci43p.exe"
  run_or_report "$dir/fci43p.exe" "$dir/output.txt"
  run_or_report "$dir/fci43p.exe" "$dir/output-repeat.txt"
  cmp "$dir/output.txt" "$dir/output-repeat.txt" || fail "repeated-run nondeterminism $opt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output drift'
ACTUAL_OUTPUT_SHA256="$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
[[ "$ACTUAL_OUTPUT_SHA256" == "$EXPECTED_OUTPUT_SHA256" ]] || fail "independent oracle output drift: $ACTUAL_OUTPUT_SHA256"
for marker in \
  'FVQ58_DENSE_ORACLE_CASES=6' \
  'FVQ58_LEGACY_DEVRIES_DENSE_ORACLE=PASS' \
  'FVQ58_SENSIBLE_ENERGY_CLOSURE=PASS' \
  'FVQ58_TEMPORAL_REFINEMENT=PASS' \
  'FVQ58_TRANSACTION_IMMUTABILITY=PASS' \
  'FVQ58_CONTINUOUS_SPLIT_RESTART_IDENTITY=PASS' \
  'FVQ58_MINIMAL_RESTART_AND_SEMANTIC_VIEW=PASS' \
  'FVQ58_FAIL_CLOSED_INVALID_INPUTS=PASS' \
  'FVQ58_MULTISWAP_COLUMN_ISOLATION=PASS' \
  'FVQ58_INDEPENDENT_ORACLE=PASS'; do
  grep -Fxq "$marker" "$BUILD/o0/output.txt" || fail "missing oracle marker $marker"
done
cat "$BUILD/o0/output.txt"
echo "FCI43P_FVQ58_OUTPUT_SHA256=$ACTUAL_OUTPUT_SHA256"
echo 'FCI43P_REPEATED_RUN_DETERMINISM_O0_O2=PASS'
echo 'FCI43P_PROMOTED_SCIENTIFIC_REPLAY=PASS'
echo 'FCI43P_RUNTIME_COMPOSITION_CLAIM=NOT_MADE'
echo 'FCI43P_RB1_REOPENED=NO'
echo 'FCI43P_POSTIMAGE_GOVERNANCE_RECONCILIATION=PASS'

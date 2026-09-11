#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
BASE_TREE=c77ac75aea522ac20a60da012595af9166efcff6
BASE_REF=9d08625217d7c0a7385df9da6a04183bcd9cb9e6
COMPOSITION=a8720c6c1981d763ed3397ebe93aa04c35779653
COMPOSITION_TREE=d06a64816a8f45200d1500ea7f345707e8ce01ce
FVQ58=5e81e14ad613cff7a72fc3f9cddcebc6696290d7
FVQ58_STATUS_BLOB=bb2dc0f8b9a297ebe899846a0a5f5c0fbc3af0b5
CANDIDATE=3f387d820adf46b1260c37d52019a2b83b2d8c74
CONTRACT=src/process/mod_soil_temperature_contract.f90
PROVIDER=src/process/mod_restricted_soil_temperature.f90
BLOB_CONTRACT=baa13df3975de2c699b0ec910477bcfa9b47f15e
BLOB_PROVIDER=fa4e1d7b48d3515e6569c9080d497178c25c4e85
FVQ58_TEST_BLOB=51e76bbf839d86702a3d391585a6f0abc0e6bc38
TEST=tests/fci/test_fci43_restricted_soil_temperature_independent.f90
EXPECTED_OUTPUT_SHA256=e62c39e6fb3e71351fde4c949fb4c639d7fa16bb19fd593b55448432ae5ae583
BUILD="${RUNNER_TEMP:-/tmp}/fci43-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/o0" "$BUILD/o2"

fail() { echo "FCI43_GATE_FAIL $*" >&2; exit 43; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
for sha in "$BASE" "$COMPOSITION" "$FVQ58" "$CANDIDATE"; do need_commit "$sha"; done

# Admission is valid only while the pinned canonical base has not moved.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CANONICAL_HEAD="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CANONICAL_HEAD" == "$BASE" ]] || fail "canonical race: expected $BASE got $CANONICAL_HEAD"
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'canonical base tree drift'
test "$(git rev-parse ${BASE}:reference)" = "$BASE_REF" || fail 'canonical reference tree drift'
echo 'FCI43_PREPROMOTION_CANONICAL_RACE_GUARD=PASS'

# The composition must be the direct, exact two-blob child of the pinned canonical base.
test "$(git rev-parse ${COMPOSITION}^)" = "$BASE" || fail 'composition is not direct child of canonical base'
test "$(git rev-parse ${COMPOSITION}^{tree})" = "$COMPOSITION_TREE" || fail 'composition tree drift'
test "$(git rev-parse ${COMPOSITION}:$CONTRACT)" = "$BLOB_CONTRACT" || fail 'composition contract blob drift'
test "$(git rev-parse ${COMPOSITION}:$PROVIDER)" = "$BLOB_PROVIDER" || fail 'composition provider blob drift'
test "$(git rev-parse HEAD:$CONTRACT)" = "$BLOB_CONTRACT" || fail 'qualification governance changed contract blob'
test "$(git rev-parse HEAD:$PROVIDER)" = "$BLOB_PROVIDER" || fail 'qualification governance changed provider blob'
git diff --quiet "$COMPOSITION"..HEAD -- src || fail 'post-composition qualification changed production source'
test "$(git rev-parse HEAD:reference)" = "$BASE_REF" || fail 'F-CI43 changed reference source'
mapfile -t delta < <(git diff --name-only "$BASE".."$COMPOSITION" -- src | sort)
expected=("$PROVIDER" "$CONTRACT")
IFS=$'\n' expected_sorted=($(printf '%s\n' "${expected[@]}" | sort)); unset IFS
[[ "${delta[*]}" == "${expected_sorted[*]}" ]] || fail "unexpected production delta: ${delta[*]:-none}"
echo 'FCI43_EXACT_TWO_BLOB_PRODUCTION_SCOPE=PASS'
echo 'FCI43_REFERENCE_IMMUTABLE=PASS'

# Donor and independent qualification authority are immutable prerequisites.
test "$(git rev-parse ${CANDIDATE}:$CONTRACT)" = "$BLOB_CONTRACT" || fail 'candidate contract donor drift'
test "$(git rev-parse ${CANDIDATE}:$PROVIDER)" = "$BLOB_PROVIDER" || fail 'candidate provider donor drift'
test "$(git rev-parse ${FVQ58}:integration/f-vq/F-VQ58_STATUS.json)" = "$FVQ58_STATUS_BLOB" || fail 'F-VQ58 status blob drift'
git show ${FVQ58}:integration/f-vq/F-VQ58_STATUS.json | grep -Fq 'QUALIFIED_RESTRICTED_SOIL_TEMPERATURE_PROCESS_WITHIN_FROZEN_SENSIBLE_HEAT_SCOPE' || fail 'F-VQ58 qualification decision missing'
git show ${FVQ58}:integration/f-vq/F-VQ58_STATUS.json | grep -Fq '"canonical_admitted": false' || fail 'F-VQ58 provenance unexpectedly rewrites admission state'
git show ${FVQ58}:integration/f-vq/F-VQ58_STATUS.json | grep -Fq '"runtime_composed": false' || fail 'F-VQ58 runtime hold missing'
test "$(git rev-parse ${FVQ58}:tests/fvq/test_fvq58_restricted_soil_temperature_independent.f90)" = "$FVQ58_TEST_BLOB" || fail 'F-VQ58 oracle blob drift'
test "$(git rev-parse HEAD:$TEST)" = "$FVQ58_TEST_BLOB" || fail 'F-CI43 oracle is not byte-identical to F-VQ58 oracle'
echo 'FCI43_FVQ58_INDEPENDENT_AUTHORITY_PINNED=PASS'
echo 'FCI43_FVQ58_ORACLE_BYTE_IDENTITY=PASS'

# Admission rechecks architecture boundaries on the branch-local production postimage.
python3 - "$CONTRACT" "$PROVIDER" <<'PY'
from pathlib import Path
import re, sys
contract = Path(sys.argv[1]).read_text()
process = Path(sys.argv[2]).read_text()
contract_code = '\n'.join(line.split('!')[0] for line in contract.splitlines()).lower()
process_code = '\n'.join(line.split('!')[0] for line in process.splitlines()).lower()
assert 'extends(transaction_state_t)' in contract_code
assert 'soil_temperature_restart_payload_t' in contract_code
assert 'soil_temperature_workspace_t' in contract_code
assert 'soil_temperature_field_view_t' in contract_code
assert 'if (abs(residual)>numerical%energy_abs_tolerance_j_cm2) then' in process_code
assert '0.5_real64*(hydraulic_start%water_content+hydraulic_end%water_content)' in process_code
assert 'use mod_process_hydraulic_view, only: process_hydraulic_view_t' in process_code
for forbidden in ['open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'pathwork', 'headcalc', 'jacobian', 'newton']:
    assert forbidden not in contract_code, forbidden
for forbidden in ['open(', 'read(', 'write(', 'daynr', 't1900', 'swpfilnam', 'pathwork', 'headcalc', 'jacobian', 'newton', 'latent', 'ice']:
    assert forbidden not in process_code, forbidden
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', contract_code)
assert not re.search(r'(^|[^a-z0-9_])save([^a-z0-9_]|$)', process_code)
m = re.search(r'type, public :: soil_temperature_restart_payload_t(.*?)end type soil_temperature_restart_payload_t', contract_code, re.S)
assert m, 'restart payload type missing'
restart_body = m.group(1)
assert 'schema_version' in restart_body and 'temperature_c(:)' in restart_body
for forbidden in ['workspace', 'conductivity', 'heat_capacity', 'rhs', 'solution', 'water_content', 'forcing']:
    assert forbidden not in restart_body, forbidden
assert 'logical :: frost_active = .false.' in contract_code
assert 'logical :: snow_active = .false.' in contract_code
assert 'frost_active' not in process_code
assert 'snow_active' not in process_code
print('FCI43_TRANSACTION_AND_STATE_BOUNDARIES=PASS')
print('FCI43_MANDATORY_ENERGY_ACCOUNTING=PASS')
print('FCI43_NO_IO_CALENDAR_OR_HEADCALC_INTERNALS=PASS')
print('FCI43_MINIMAL_RESTART_STATE=PASS')
print('FCI43_FROST_SNOW_LATENT_SCOPE_HELD=PASS')
PY

git diff --check "$BASE" -- src/process tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI43_DIFF_CHECK=PASS'

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
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/tx.o" "$dir/solver_contract.o" "$dir/hydraulic_view.o" "$dir/temp_contract.o" "$dir/temp_provider.o" "$dir/test.o" -o "$dir/fci43.exe"
  run_or_report "$dir/fci43.exe" "$dir/output.txt"
  run_or_report "$dir/fci43.exe" "$dir/output-repeat.txt"
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
echo "FCI43_FVQ58_OUTPUT_SHA256=$ACTUAL_OUTPUT_SHA256"
echo 'FCI43_REPEATED_RUN_DETERMINISM_O0_O2=PASS'
echo 'FCI43_BRANCH_LOCAL_INDEPENDENT_SCIENTIFIC_REPLAY=PASS'
echo 'FCI43_RUNTIME_COMPOSITION_CLAIM=NOT_MADE'
echo 'FCI43_LARGE_BATCH_THROUGHPUT_CLAIM=NOT_MADE'
echo 'FCI43_RB1_REOPENED=NO'
echo 'FCI43_CANONICAL_ADMISSION_GATE=PASS'

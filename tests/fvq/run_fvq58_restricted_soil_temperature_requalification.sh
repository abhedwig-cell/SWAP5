#!/usr/bin/env bash
set -euo pipefail

BASE=0aeb0a2ed4096e1f9493d3dabc70962ea5270182
RELEASE=b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0
OWNER_CLOSEOUT=1b541514405cf18450a4b2c73eb758270df527a7
CANDIDATE=3f387d820adf46b1260c37d52019a2b83b2d8c74
BLOB_CONTRACT=baa13df3975de2c699b0ec910477bcfa9b47f15e
BLOB_PROVIDER=fa4e1d7b48d3515e6569c9080d497178c25c4e85
OWNER_STATUS_BLOB=dcabd9c57f61050ad7cfb71d5593bcf0d97a9980
BLOB_TX=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
BLOB_SOLVER_CONTRACT=dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
BLOB_HYDRAULIC_VIEW=d7d85fe71ced0d94b29c8d9395859ae1834f7dd6
TEST=tests/fvq/test_fvq58_restricted_soil_temperature_independent.f90
BUILD="${RUNNER_TEMP:-/tmp}/fvq58-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD/candidate" "$BUILD/o0" "$BUILD/o2"

# Qualification branch must remain production/reference-clean.
test "$(git rev-parse ${BASE}:src)" = "$(git rev-parse HEAD:src)"
test "$(git rev-parse ${BASE}:reference)" = "$(git rev-parse HEAD:reference)"
echo 'FVQ58_QUALIFICATION_PRODUCTION_IMMUTABLE=PASS'

# Canonical seams used by the candidate are pinned independently.
test "$(git rev-parse ${BASE}:src/transaction/mod_transaction_reference.f90)" = "$BLOB_TX"
test "$(git rev-parse ${BASE}:src/solver/mod_soil_water_solver_contract.f90)" = "$BLOB_SOLVER_CONTRACT"
test "$(git rev-parse ${BASE}:src/solver/mod_process_hydraulic_view.f90)" = "$BLOB_HYDRAULIC_VIEW"
echo 'FVQ58_CANONICAL_SEAMS_PINNED=PASS'

# Load the exact owner-qualified production candidate only into temporary build space.
git cat-file -e "${CANDIDATE}^{commit}" 2>/dev/null || git fetch --no-tags origin "$CANDIDATE" >/dev/null 2>&1
git cat-file -e "${RELEASE}^{commit}" 2>/dev/null || git fetch --no-tags origin "$RELEASE" >/dev/null 2>&1
test "$(git rev-parse ${CANDIDATE}:src/process/mod_soil_temperature_contract.f90)" = "$BLOB_CONTRACT"
test "$(git rev-parse ${CANDIDATE}:src/process/mod_restricted_soil_temperature.f90)" = "$BLOB_PROVIDER"
mapfile -t candidate_delta < <(git diff --name-only "$RELEASE".."$CANDIDATE" -- src | sort)
expected_delta=(
  src/process/mod_restricted_soil_temperature.f90
  src/process/mod_soil_temperature_contract.f90
)
[[ "${candidate_delta[*]}" == "${expected_delta[*]}" ]]
echo 'FVQ58_EXACT_CANDIDATE_SCOPE=PASS'

# Owner closeout is provenance only, never the scientific oracle.
git cat-file -e "${OWNER_CLOSEOUT}^{commit}" 2>/dev/null || git fetch --no-tags origin "$OWNER_CLOSEOUT" >/dev/null 2>&1
test "$(git rev-parse ${OWNER_CLOSEOUT}:integration/f-pm/F-PM07B_CANDIDATE_STATUS.json)" = "$OWNER_STATUS_BLOB"
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM07B_CANDIDATE_STATUS.json | \
  grep -Fq 'QUALIFIED_RESTRICTED_SOIL_TEMPERATURE_PROCESS_CANDIDATE_READY_FOR_INDEPENDENT_FVQ'
git show ${OWNER_CLOSEOUT}:integration/f-pm/F-PM07B_CANDIDATE_STATUS.json | \
  grep -Fq '"qualified_candidate_source_head": "3f387d820adf46b1260c37d52019a2b83b2d8c74"'
echo 'FVQ58_OWNER_HANDOFF_EXACT=PASS'

git show ${CANDIDATE}:src/process/mod_soil_temperature_contract.f90 > "$BUILD/candidate/mod_soil_temperature_contract.f90"
git show ${CANDIDATE}:src/process/mod_restricted_soil_temperature.f90 > "$BUILD/candidate/mod_restricted_soil_temperature.f90"
test "$(git hash-object "$BUILD/candidate/mod_soil_temperature_contract.f90")" = "$BLOB_CONTRACT"
test "$(git hash-object "$BUILD/candidate/mod_restricted_soil_temperature.f90")" = "$BLOB_PROVIDER"

# Static architecture and held-scope guards, evaluated independently from owner tests.
python3 - "$BUILD/candidate/mod_soil_temperature_contract.f90" "$BUILD/candidate/mod_restricted_soil_temperature.f90" <<'PY'
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
assert 'require_energy_closure' not in contract_code
assert 'require_energy_closure' not in process_code
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
print('FVQ58_EXPLICIT_DATA_AND_STATE_SEPARATION=PASS')
print('FVQ58_MANDATORY_ENERGY_CLOSURE_GUARD=PASS')
print('FVQ58_NO_IO_CALENDAR_OR_SOLVER_INTERNALS=PASS')
print('FVQ58_MINIMAL_RESTART_SCHEMA_GUARD=PASS')
print('FVQ58_HELD_FROST_SNOW_SCOPE_GUARD=PASS')
PY

git diff --check "$BASE" -- tests/fvq integration/f-vq .github/workflows

echo 'FVQ58_DIFF_CHECK=PASS'

DEP_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Wno-error=unused-dummy-argument -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT_FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

compile_and_run() {
  local opt="$1" dir="$2"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/transaction/mod_transaction_reference.f90 -o "$dir/tx.o"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/solver_contract.o"
  gfortran "${DEP_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c src/solver/mod_process_hydraulic_view.f90 -o "$dir/hydraulic_view.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$BUILD/candidate/mod_soil_temperature_contract.f90" -o "$dir/temp_contract.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$BUILD/candidate/mod_restricted_soil_temperature.f90" -o "$dir/temp_provider.o"
  gfortran "${STRICT_FLAGS[@]}" "$opt" -J "$dir" -I "$dir" -c "$TEST" -o "$dir/test.o"
  gfortran "$opt" "$dir/tx.o" "$dir/solver_contract.o" "$dir/hydraulic_view.o" "$dir/temp_contract.o" "$dir/temp_provider.o" "$dir/test.o" -o "$dir/fvq58.exe"
  "$dir/fvq58.exe" > "$dir/output.txt" 2>&1
  "$dir/fvq58.exe" > "$dir/output-repeat.txt" 2>&1
  cmp "$dir/output.txt" "$dir/output-repeat.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"

for marker in \
  'FVQ58_DENSE_ORACLE_CASES=6' \
  'FVQ58_LEGACY_DEVRIES_DENSE_ORACLE=PASS' \
  'FVQ58_ZERO_GRADIENT_IDENTITY=PASS' \
  'FVQ58_BOUNDARY_SIGN_AND_ZERO_BOTTOM=PASS' \
  'FVQ58_SENSIBLE_ENERGY_CLOSURE=PASS' \
  'FVQ58_TEMPORAL_REFINEMENT=PASS' \
  'FVQ58_TRANSACTION_IMMUTABILITY=PASS' \
  'FVQ58_CONTINUOUS_SPLIT_RESTART_IDENTITY=PASS' \
  'FVQ58_MINIMAL_RESTART_AND_SEMANTIC_VIEW=PASS' \
  'FVQ58_FAIL_CLOSED_INVALID_INPUTS=PASS' \
  'FVQ58_MULTISWAP_COLUMN_ISOLATION=PASS' \
  'FVQ58_INDEPENDENT_ORACLE=PASS'; do
  grep -Fxq "$marker" "$BUILD/o0/output.txt"
done

cat "$BUILD/o0/output.txt"
echo "FVQ58_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
echo 'FVQ58_REPEATED_RUN_DETERMINISM_O0=PASS'
echo 'FVQ58_REPEATED_RUN_DETERMINISM_O2=PASS'
echo 'FVQ58_O0_O2_IDENTITY=PASS'
echo 'FVQ58_ARCHITECTURE_INVARIANTS_RECHECK=PASS'
echo 'FVQ58_GATE=PASS'

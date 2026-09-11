#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=82280e350ea7514cc9f394db882d5cb3ef25b18c
FMR41_SOURCE=50b8bd32b03946d947b9c8b87a17192684843b6e
FMR41_CLOSEOUT=e7165e598b035282a2cb7527b2fb2f466f1dbbff
FMR39=87b553094b66980006b69f5ba8b53d70ccd0a8e0
FMR39_TEST=tests/fmr/test_fmr39_soil_temperature_runtime_composition.f90
FMR39_TEST_BLOB=00a0d30fd4f1f3ef3888dbc03cf71d41770c4fab
FMR39_EXPECTED_SHA=cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942
FMR06=99d96d8a0b4d2752d254fd0f4f3fc1a0f4181dc3
FMR06_TEST=tests/fmr/test_fmr06_snow_multiswap.f90
FMR06_TEST_BLOB=ed4b742b76e97ff0ad27b386850c1d093e4f03d1
BUILD="${RUNNER_TEMP:-/tmp}/fci48-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "FCI48_GATE_FAIL $*" >&2; exit 48; }
need_commit(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for c in "$BASE" "$FMR41_SOURCE" "$FMR41_CLOSEOUT" "$FMR39" "$FMR06"; do need_commit "$c"; done

# Fail closed on canonical movement.
git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT"
echo 'FCI48_CANONICAL_RACE_GUARD=PASS'

# Production composition is exactly the three already-qualified F-MR41 blobs.
mapfile -t changed_src < <(git diff --name-only "$BASE" -- src | sort)
printf '%s\n' "${changed_src[@]}" > "$BUILD/changed-src.txt"
printf '%s\n' \
  src/runtime/mod_fmr_restart_state_contract.f90 \
  src/runtime/mod_fmr_runtime_core.f90 \
  src/runtime/mod_fmr_serialized_reference_backend.f90 | sort > "$BUILD/expected-src.txt"
cmp -s "$BUILD/changed-src.txt" "$BUILD/expected-src.txt" || { cat "$BUILD/changed-src.txt" >&2; fail 'unexpected production source delta'; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_runtime_core.f90)" == 88adf19e274956ab0f97fe6b4f6307fbfb453790 ]] || fail 'runtime core blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 2364c765935813675dee0d2838a7ce183d81f560 ]] || fail 'serialized backend blob drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_restart_state_contract.f90)" == 4a9c1644665c02de77c82e4b5fa2baaaf0a1fb6d ]] || fail 'restart contract blob drift'
[[ "$(git rev-parse ${FMR41_SOURCE}:src/runtime/mod_fmr_runtime_core.f90)" == 88adf19e274956ab0f97fe6b4f6307fbfb453790 ]] || fail 'donor runtime core authority drift'
[[ "$(git rev-parse ${FMR41_SOURCE}:src/runtime/mod_fmr_serialized_reference_backend.f90)" == 2364c765935813675dee0d2838a7ce183d81f560 ]] || fail 'donor backend authority drift'
[[ "$(git rev-parse ${FMR41_SOURCE}:src/runtime/mod_fmr_restart_state_contract.f90)" == 4a9c1644665c02de77c82e4b5fa2baaaf0a1fb6d ]] || fail 'donor restart authority drift'
git diff --quiet "$BASE" -- reference || fail 'reference tree changed'
echo 'FCI48_EXACT_THREE_BLOB_COMPOSITION=PASS'
echo 'FCI48_REFERENCE_IMMUTABLE=PASS'

# Pin the closed donor decision and its exact source authority.
git show ${FMR41_CLOSEOUT}:integration/f-mr/F-MR41_QUALIFICATION_STATUS.json > "$BUILD/fmr41-status.json"
python3 - "$BUILD/fmr41-status.json" <<'PY'
import json, sys
s=json.load(open(sys.argv[1]))
assert s['status']=='CLOSED_QUALIFIED'
assert s['decision']=='QUALIFIED_TYPED_OPTIONAL_STATE_LAYOUT_IDENTITY_AND_FAIL_CLOSED_RUNTIME_CONTRACT'
assert s['candidate_source_authority']=='50b8bd32b03946d947b9c8b87a17192684843b6e'
assert s['candidate_source_blobs']=={
 'src/runtime/mod_fmr_runtime_core.f90':'88adf19e274956ab0f97fe6b4f6307fbfb453790',
 'src/runtime/mod_fmr_serialized_reference_backend.f90':'2364c765935813675dee0d2838a7ce183d81f560',
 'src/runtime/mod_fmr_restart_state_contract.f90':'4a9c1644665c02de77c82e4b5fa2baaaf0a1fb6d'}
assert s['scientific_and_architecture_scope']['new_physics'] is False
assert s['scientific_and_architecture_scope']['new_solver'] is False
assert s['scientific_and_architecture_scope']['scientific_tolerance_relaxation'] is False
assert s['scientific_and_architecture_scope']['mass_accounting_change'] is False
print('FCI48_FMR41_CLOSED_AUTHORITY_PINNED=PASS')
PY

# Audit all 30 architecture invariants on this admission image.
python3 - <<'PY'
import json
p='integration/f-ci/F-CI48_ARCHITECTURE_AUDIT.json'
a=json.load(open(p))
assert a['canonical_base']=='82280e350ea7514cc9f394db882d5cb3ef25b18c'
assert a['donor_source_authority']=='50b8bd32b03946d947b9c8b87a17192684843b6e'
assert a['mass_conservation']=='HARD_UNCHANGED'
assert a['new_physics'] is False and a['new_solver'] is False
assert a['scientific_tolerance_relaxation'] is False
ids=[x['id'] for x in a['invariants']]
assert ids==list(range(1,31)), ids
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in a['invariants'])
print('FCI48_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
PY

git diff --check "$BASE" -- src tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
echo 'FCI48_DIFF_CHECK=PASS'

# Historical layout identity provenance remains immutable.
test "$(git rev-parse ${FMR39}:$FMR39_TEST)" = "$FMR39_TEST_BLOB" || fail 'F-MR39 oracle drift'
test "$(git rev-parse ${FMR06}:$FMR06_TEST)" = "$FMR06_TEST_BLOB" || fail 'F-MR06 snow oracle drift'
git show ${FMR39}:$FMR39_TEST | grep -Fq '390501_int64' || fail 'F-MR39 thermal layout identity missing'
git show ${FMR06}:$FMR06_TEST | grep -Fq 'optional_state_layout_id = 60605_int64' || fail 'F-MR06 snow layout identity missing'
echo 'FCI48_HISTORICAL_LAYOUT_IDENTITIES_PINNED=PASS'

python3 - <<'PY'
from pathlib import Path
c=Path('src/runtime/mod_fmr_runtime_core.f90').read_text().lower()
b=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
r=Path('src/runtime/mod_fmr_restart_state_contract.f90').read_text().lower()
assert 'fmr_optional_state_layout_base = 0_int64' in c
assert 'fmr_optional_state_layout_snow = 60605_int64' in c
assert 'fmr_optional_state_layout_restricted_soil_temperature = 390501_int64' in c
assert 'pure logical function fmr_optional_state_layout_known' in c
assert 'fmr_optional_state_layout_known(template%optional_state_layout_id)' in b
assert 'template%optional_state_layout_id /= fmr_optional_state_layout_restricted_soil_temperature' in b
assert 'template%optional_state_layout_id /= fmr_optional_state_layout_snow' in b
assert 'optional_state_layout_id <= 0_int64' not in b
assert 'fmr_optional_state_layout_known(template%optional_state_layout_id)' in r
assert 'case (fmr_optional_state_layout_snow)' in r
assert 'case (fmr_optional_state_layout_restricted_soil_temperature)' in r
assert 'optional_state_layout_id > 0' not in r
print('FCI48_STATIC_TYPED_LAYOUT_CONTRACT=PASS')
PY

RFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/transaction/mod_transaction_reference.f90
 src/transaction/mod_fkt_temporal_indicator_history.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_fmr_runtime_core.f90
 src/runtime/mod_fmr_checkpoint_orchestrator.f90
 src/runtime/mod_fmr_accepted_commit_receipt.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_process_hydraulic_view.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_serialized_context_binding.f90
 src/process/mod_snow_process.f90
 src/process/mod_soil_temperature_contract.f90
 src/process/mod_restricted_soil_temperature.f90
 src/runtime/mod_fmr_serialized_reference_backend.f90
 src/runtime/mod_fmr_serialized_multiswap_runtime.f90
 src/runtime/mod_fmr_restart_state_contract.f90
 src/runtime/mod_fmr_committed_restart.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
)

git show ${FMR39}:$FMR39_TEST > "$BUILD/fmr39-valid.f90"
python3 - "$BUILD/fmr39-valid.f90" "$BUILD/fmr39-unknown.f90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
anchor='templates(1)%optional_state_layout_id = 390501_int64'
replacement='templates(1)%optional_state_layout_id = 390502_int64'
count=src.count(anchor)
if count != 1:
    raise SystemExit(f'FCI48 mutation anchor count={count}')
Path(sys.argv[2]).write_text(src.replace(anchor,replacement,1))
print('FCI48_UNKNOWN_THERMAL_LAYOUT_ORACLE_MATERIALIZED=PASS')
PY

for opt in 0 2; do
  OUT="$BUILD/o$opt"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; flags=("${RFLAGS[@]}")
    case "$src" in src/process/mod_soil_temperature_contract.f90|src/process/mod_restricted_soil_temperature.f90) flags=("${STRICT[@]}");; esac
    gfortran "${flags[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fci/test_fci48_fmr41_optional_state_layout_contract.f90 -o "$OUT/fci48.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fci48.o" -o "$OUT/fci48"
  "$OUT/fci48" > "$OUT/fci48.txt" 2>&1 || { cat "$OUT/fci48.txt" >&2; fail "contract matrix O$opt"; }
  grep -Fq 'FCI48_OPTIONAL_STATE_LAYOUT_CONTRACT_TEST PASS' "$OUT/fci48.txt" || fail "contract marker O$opt"
  grep -Fq 'FCI48_UNKNOWN_POSITIVE_LAYOUT_FAIL_CLOSED=PASS' "$OUT/fci48.txt" || fail "unknown restart marker O$opt"

  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmr39-valid.f90" -o "$OUT/fmr39-valid.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr39-valid.o" -o "$OUT/fmr39-valid"
  "$OUT/fmr39-valid" > "$OUT/fmr39-valid.txt" 2>&1 || { cat "$OUT/fmr39-valid.txt" >&2; fail "F-MR39 valid authority O$opt"; }
  grep -Fq 'FMR39_RESTRICTED_SOIL_TEMPERATURE_RUNTIME_TEST PASS' "$OUT/fmr39-valid.txt" || fail "F-MR39 close marker O$opt"

  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmr39-unknown.f90" -o "$OUT/fmr39-unknown.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr39-unknown.o" -o "$OUT/fmr39-unknown"
  set +e
  "$OUT/fmr39-unknown" > "$OUT/fmr39-unknown.txt" 2>&1
  rc=$?
  set -e
  [[ $rc -ne 0 ]] || fail "unknown positive thermal layout unexpectedly admitted O$opt"
  echo "FCI48_UNKNOWN_POSITIVE_THERMAL_LAYOUT_REJECTED_O${opt}=PASS"

  gfortran "${RFLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fmr/test_fmr19_process_restart.f90 -o "$OUT/fmr19.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/fmr19.o" -o "$OUT/fmr19"
  "$OUT/fmr19" > "$OUT/fmr19.txt" 2>&1 || { cat "$OUT/fmr19.txt" >&2; fail "F-MR19 preservation O$opt"; }
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$OUT/fmr19.txt" || fail "F-MR19 marker O$opt"
  echo "FCI48_BASE_LAYOUT_FMR19_PRESERVATION_O${opt}=PASS"
done

cmp "$BUILD/o0/fci48.txt" "$BUILD/o2/fci48.txt" || fail 'F-CI48 contract O0/O2 drift'
cmp "$BUILD/o0/fmr39-valid.txt" "$BUILD/o2/fmr39-valid.txt" || fail 'F-MR39 valid O0/O2 drift'
cmp "$BUILD/o0/fmr19.txt" "$BUILD/o2/fmr19.txt" || fail 'F-MR19 O0/O2 drift'
ACTUAL_SHA="$(sha256sum "$BUILD/o0/fmr39-valid.txt" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$FMR39_EXPECTED_SHA" ]] || fail "F-MR39 valid output drift $ACTUAL_SHA"
echo "FCI48_FMR39_VALID_RUNTIME_OUTPUT_SHA256=$ACTUAL_SHA"
echo 'FCI48_VALID_THERMAL_AUTHORITY_PRESERVED=PASS'
echo 'FCI48_FMR19_RESTART_PRESERVED=PASS'
echo 'FCI48_O0_O2_DETERMINISM=PASS'
echo 'FCI48_WATER_MASS_POLICY_HARD_UNCHANGED=PASS'
echo 'FCI48_GATE=PASS'

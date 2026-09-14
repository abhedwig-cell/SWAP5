#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq76-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f "$ROOT/tests/fpm/.fvq76_pm14_preservation.sh"' EXIT
cd "$ROOT"

fail(){ echo "FVQ76_DRAINAGE_POST_FCI62_REQUALIFICATION_FAIL $*" >&2; exit 76; }

CANONICAL='46ed64aba280bf721bce6f99446d0dd4ed00e38f'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM14='52c1a9aebddc435ef3792378f958305a96308ed0'
PM17='45455f54c0c3554150e273aff07bfccd06d69c14'
VQ73='ea40e2d850aa9b4b23b25ba6b4a63ffd39811001'
VQ74='60c121a0993993bd79fb30ddfd54e2a9d14f042e'
TEST73_BLOB='e7008eda5f29ee2e401cb3eb8a1b1523da3bc25a'
TEST74_BLOB='dabe53d0714abee8e87b2e90f89c2eed169506e0'
OLD_BACKEND='0f09c0df1559ece894356b146b64d872470c0a32'
NEW_BACKEND='21e0e4229f202f1a3a74c4da004aa32a2c855f03'

# ---------------------------------------------------------------------------
# A. Pin exact current canonical and immutable frozen-scope authorities.
# ---------------------------------------------------------------------------
LIVE="$(git ls-remote origin refs/heads/integration/f-ci-canonical | awk '{print $1}')"
[[ "$LIVE" == "$CANONICAL" ]] || fail "live canonical drift expected=$CANONICAL actual=$LIVE"
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'qualification branch is not descended from exact F-CI62 canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'F-VQ76 changes production/reference source'
[[ "$(git rev-parse "$PM13:integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'F-PM13 denominator authority drift'
[[ "$(git rev-parse "$PM17:integration/f-pm/F-PM17_STATUS.json")" == 'ff7e444ad99271ea6daf7bde5be6c84896d1aeab' ]] || fail 'F-PM17 scope correction drift'
python3 - "$PM13" "$PM17" <<'PY'
import json,subprocess,sys
pm13,pm17=sys.argv[1:]
def load(c,p): return json.loads(subprocess.check_output(['git','show',f'{c}:{p}'],text=True))
a=load(pm13,'integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json')
s=load(pm17,'integration/f-pm/F-PM17_STATUS.json')
assert len(a['denominator']['frozen_variants']) == 8
assert [x['id'] for x in a['hard_blockers']] == [
  'G1_RUNTIME_COMPOSITION','G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS','G3_CANONICAL_ADMISSION_PRESERVATION']
assert a['denominator']['changed'] is False and a['denominator']['scope_reduced'] is False
assert s['decision']=='F_PM15_G1R_NOT_A_FROZEN_DRAINAGE_V1_EXIT_REQUIREMENT'
assert s['fully_implicit_implementation_authorized'] is False
print('FVQ76_FROZEN_DRAINAGE_V1_DENOMINATOR_EXACT=PASS')
print('FVQ76_NO_FULLY_IMPLICIT_SCOPE_EXPANSION=PASS')
PY
echo 'FVQ76_NO_PRODUCTION_OR_REFERENCE_CHANGE=PASS'

# ---------------------------------------------------------------------------
# B. Lock immutable independent executable oracles, then materialize only the
#    test programs. Current production sources are deliberately used at link.
# ---------------------------------------------------------------------------
[[ "$(git rev-parse "$VQ73:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90")" == "$TEST73_BLOB" ]] || fail 'F-VQ73 immutable test-program drift'
[[ "$(git rev-parse "$VQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90")" == "$TEST74_BLOB" ]] || fail 'F-VQ74 immutable test-program drift'
git show "$VQ73:tests/fvq/test_fvq73_fpm14_drainage_response_independent.f90" > "$BUILD/test73.f90"
git show "$VQ74:tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90" > "$BUILD/test74.f90"
[[ "$(git hash-object "$BUILD/test73.f90")" == "$TEST73_BLOB" ]] || fail 'materialized VQ73 test differs from immutable blob'
[[ "$(git hash-object "$BUILD/test74.f90")" == "$TEST74_BLOB" ]] || fail 'materialized VQ74 test differs from immutable blob'
echo 'FVQ76_IMMUTABLE_VQ73_VQ74_EXECUTABLE_ORACLES=PASS'

# ---------------------------------------------------------------------------
# C. Current production postimage: ten PM14 response/binding files are exact;
#    shared backend is intentionally the new F-CI62 blob and must be re-tested.
# ---------------------------------------------------------------------------
declare -A STABLE_BLOBS=(
  [src/process/mod_drainage_empirical_interflow_response.f90]=eb53096b678d08b76d3fb1adb2247bc2a58ee748
  [src/process/mod_drainage_ernst_ipos45_preparation.f90]=fa1d5d400bb32be42e78889c0ff2a3bcab335142
  [src/process/mod_drainage_ernst_ipos45_response.f90]=b00ef0ae1f10182af2d0a8ea636d10b196e93379
  [src/process/mod_drainage_hooghoudt_equivalent_depth.f90]=6b7b2bb1fd259879d3f26c46abfc071ea2b2f108
  [src/process/mod_drainage_hooghoudt_ipos1_response.f90]=89f26e2d2b77bef5bdd0c5fdb2ce9ca1f03206fa
  [src/process/mod_drainage_hooghoudt_ipos23_response.f90]=5637ddb4d33141f00b4ebf737d1c7f7fe1824164
  [src/process/mod_drainage_multilevel_aggregation.f90]=70d35512ef7c5958f7e4bf284cba104a7b641fdb
  [src/process/mod_drainage_process.f90]=dbacd49da3bb0b94f822f9ee0478d15183e9c0fa
  [src/process/mod_drainage_tabulated_response.f90]=738f57c334910ab73bc8870e3aa8dda1c1a48c7a
  [src/runtime/mod_fmr_drainage_response_binding.f90]=76c2a2ea569a4e85e490ebd2e7fb89c28d8b3fb5
)
for p in "${!STABLE_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${STABLE_BLOBS[$p]}" ]] || fail "stable drainage production blob drift: $p"
done
[[ "$(git rev-parse "$VQ73:src/runtime/mod_fmr_serialized_reference_backend.f90")" == "$OLD_BACKEND" ]] || fail 'historical F-VQ73 backend authority drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$NEW_BACKEND" ]] || fail 'unexpected F-CI62 backend blob'
[[ "$OLD_BACKEND" != "$NEW_BACKEND" ]] || fail 'expected shared-backend drift absent'
[[ "$(git rev-parse HEAD:src/process/mod_drainage_spatial_distribution.f90)" == '1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a' ]] || fail 'DIVDRA process drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_divdra_serialized_runtime.f90)" == '9a384658ec37b68d2ef911e741aa89707dcb3e77' ]] || fail 'DIVDRA runtime drift'
[[ "$(git rev-parse HEAD:src/process/mod_restricted_fixed_weir_surface_water.f90)" == '16da4f6ec3d120b5a40f17ef04fb8faa457f4eaa' ]] || fail 'fixed-weir process drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_fixed_weir_serialized_runtime.f90)" == 'f81229c2f4ad766fb8606111ca965963ebba46fe' ]] || fail 'fixed-weir runtime drift'
echo 'FVQ76_CURRENT_POSTIMAGE_BLOBS_LOCKED_BACKEND_DRIFT_EXPLICIT=PASS'

# ---------------------------------------------------------------------------
# D. Compile the exact current F-CI62 production postimage once per optimizer,
#    then link and execute the immutable VQ73 and VQ74 test programs unchanged.
# ---------------------------------------------------------------------------
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done

  for testno in 73 74; do
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/test${testno}.f90" -o "$OUT/test${testno}.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/test${testno}.o" -o "$OUT/test${testno}"
    "$OUT/test${testno}" > "$OUT/output${testno}.txt" 2>&1 || {
      cat "$OUT/output${testno}.txt" >&2
      fail "immutable VQ${testno} executable oracle failed on current postimage O$opt"
    }
  done

  for marker in \
    'FVQ73_TWO_LEVEL_BINDING_SEPARATION_AND_TANGENT=PASS' \
    'FVQ73_AGGREGATE_DERIVED_VIEW_NOT_TRANSFER=PASS' \
    'FVQ73_TWO_LEVEL_RUNTIME_HARD_MASS_AND_SINGLE_BOOKING=PASS' \
    'FVQ73_GENERIC_NONCALENDAR_INTERVAL=PASS' \
    'FVQ73_INVALID_SECOND_LEVEL_FAIL_CLOSED_ATOMIC=PASS' \
    'FVQ73_FPM14_DRAINAGE_RESPONSE_INDEPENDENT_RUNTIME=PASS'; do
    grep -Fxq "$marker" "$OUT/output73.txt" || { cat "$OUT/output73.txt" >&2; fail "missing VQ73 marker on O$opt: $marker"; }
  done

  for marker in \
    'FVQ74_MULTISWAP_ACTIVE_PRECOMPUTED_ISOLATION=PASS' \
    'FVQ74_MULTISWAP_ORDER_INDEPENDENCE=PASS' \
    'FVQ74_ACCEPTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS' \
    'FVQ74_RESTART_CONTINUATION_EQUIVALENCE=PASS' \
    'FVQ74_REJECTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_REJECTED_RUNTIME_ATOMICITY=PASS' \
    'FVQ74_DRAINAGE_CROSS_CUTTING_INDEPENDENT=PASS'; do
    grep -Fxq "$marker" "$OUT/output74.txt" || { cat "$OUT/output74.txt" >&2; fail "missing VQ74 marker on O$opt: $marker"; }
  done
  echo "FVQ76_IMMUTABLE_VQ73_REPLAY_O${opt}=PASS"
  echo "FVQ76_IMMUTABLE_VQ74_REPLAY_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output73.txt" "$BUILD/o2/output73.txt" || { diff -u "$BUILD/o0/output73.txt" "$BUILD/o2/output73.txt" >&2 || true; fail 'VQ73 O0/O2 output drift on F-CI62 postimage'; }
cmp -s "$BUILD/o0/output74.txt" "$BUILD/o2/output74.txt" || { diff -u "$BUILD/o0/output74.txt" "$BUILD/o2/output74.txt" >&2 || true; fail 'VQ74 O0/O2 output drift on F-CI62 postimage'; }
echo 'FVQ76_VQ73_O0_O2_EXACT_IDENTITY=PASS'
echo 'FVQ76_VQ74_O0_O2_EXACT_IDENTITY=PASS'
echo "FVQ76_VQ73_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output73.txt" | awk '{print $1}')"
echo "FVQ76_VQ74_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output74.txt" | awk '{print $1}')"

# ---------------------------------------------------------------------------
# E. Replay the already-admitted DIVDRA and fixed-weir preservation suite on
#    the same current postimage. The PM14 runner locks its historical test
#    support and executes the fixed-weir route rather than blob-locking backend.
# ---------------------------------------------------------------------------
[[ "$(git rev-parse "$PM14:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh")" == '0045e64f5174180e1e00265b775add3be1bf949f' ]] || fail 'PM14 preservation oracle drift'
git show "$PM14:tests/fpm/run_fpm14_precomputed_divdra_fixed_weir_preservation.sh" > tests/fpm/.fvq76_pm14_preservation.sh
chmod +x tests/fpm/.fvq76_pm14_preservation.sh
bash tests/fpm/.fvq76_pm14_preservation.sh > "$BUILD/preservation.txt" 2>&1 || {
  cat "$BUILD/preservation.txt" >&2
  fail 'DIVDRA/fixed-weir current-postimage preservation replay'
}
for marker in \
  'FPM14_PRECOMPUTED_DIVDRA_CURRENT_POSTIMAGE_PRESERVED=PASS' \
  'FPM14_FIXED_WEIR_PROCESS_CURRENT_POSTIMAGE_REPLAY=PASS' \
  'FPM14_FIXED_WEIR_RUNTIME_COMPILE_CURRENT_POSTIMAGE_REPLAY=PASS' \
  'FPM14_FIXED_WEIR_TRANSACTIONAL_CURRENT_POSTIMAGE_REPLAY=PASS' \
  'FPM14_FIXED_WEIR_RESTART_CURRENT_POSTIMAGE_REPLAY=PASS' \
  'FPM14_PRECOMPUTED_DIVDRA_FIXED_WEIR_PRESERVATION_GATE=PASS'; do
  grep -Fq "$marker" "$BUILD/preservation.txt" || { cat "$BUILD/preservation.txt" >&2; fail "missing preservation marker: $marker"; }
done
echo 'FVQ76_DIVDRA_FIXED_WEIR_BEHAVIORAL_PRESERVATION=PASS'
echo "FVQ76_PRESERVATION_OUTPUT_SHA256=$(sha256sum "$BUILD/preservation.txt" | awk '{print $1}')"

# ---------------------------------------------------------------------------
# F. Static no-state/HeadCalc/I-O/calendar checks and machine-readable audit.
# ---------------------------------------------------------------------------
python3 - <<'PY'
import json
from pathlib import Path
backend=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
binding=Path('src/runtime/mod_fmr_drainage_response_binding.f90').read_text().lower()
start=backend.index('type, extends(canonical_state_t), public :: fmr_b110_physical_state_t')
end=backend.index('end type fmr_b110_physical_state_t',start)
assert 'drainage' not in backend[start:end]
for token in ('headcalc','open(','read(','write(','.swp','midnight','calendar'):
    assert token not in binding
p=json.loads(Path('integration/f-vq/F-VQ76_PRE_REGISTRATION.json').read_text())
a=json.loads(Path('integration/f-vq/F-VQ76_ARCHITECTURE_AUDIT.json').read_text())
assert p['scope_guards']['production_change'] is False
assert p['scope_guards']['reference_change'] is False
assert p['scope_guards']['new_drainage_physics'] is False
assert p['scope_guards']['scope_reduction'] is False
assert p['scope_guards']['scope_expansion'] is False
assert a['invariant_count']==30 and len(a['invariants'])==30
assert [x['id'] for x in a['invariants']]==list(range(1,31))
assert a['mass_conservation_concession'] is False
print('FVQ76_NO_PERSISTENT_DRAINAGE_RESPONSE_STATE=PASS')
print('FVQ76_HEADCALC_IO_CALENDAR_ISOLATION=PASS')
print('FVQ76_ARCHITECTURE_SCOPE_GUARDS=PASS')
PY

git diff --check "$CANONICAL"..HEAD
echo "FVQ76_EXACT_HEAD=$(git rev-parse HEAD)"
echo 'F-VQ76 DRAINAGE POST-FCI62 PRESERVATION REQUALIFICATION=PASS'

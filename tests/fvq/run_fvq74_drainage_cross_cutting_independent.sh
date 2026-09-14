#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fvq74-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "FVQ74_GATE_FAIL $*" >&2; exit 74; }
CANONICAL='e79b0272edb544ec4c8000a4d6869274f1ab3ae5'
PM13='e5cd87eafb95356ca0d5ef8399fcb64feae78fd2'
PM13_FILE='integration/f-pm/F-PM13_DRAINAGE_V1_FINAL_COMPLETION.json'

# F-VQ74 is qualification/evidence only. It may not mutate production or reference authority.
git merge-base --is-ancestor "$CANONICAL" HEAD || fail 'branch not descended from frozen current canonical'
git diff --quiet "$CANONICAL"..HEAD -- src reference || fail 'qualification branch changes src/reference authority'
echo 'FVQ74_NO_PRODUCTION_OR_REFERENCE_CHANGE=PASS'

# Freeze the exact PM13 denominator and its three original closure blockers.
[[ "$(git rev-parse "$PM13:$PM13_FILE")" == 'ce4dc39da4a97f070539896e9929f00c475d7ffa' ]] || fail 'PM13 completion denominator drift'
python3 - "$PM13" "$PM13_FILE" <<'PY'
import json,subprocess,sys
sha,path=sys.argv[1:]
d=json.loads(subprocess.check_output(['git','show',f'{sha}:{path}'],text=True))
assert d['denominator']['changed'] is False
assert d['denominator']['scope_reduced'] is False
assert d['cross_cutting_exit_audit']['hundred_percent_complete'] is False
assert [x['id'] for x in d['hard_blockers']] == [
    'G1_RUNTIME_COMPOSITION',
    'G2_TRANSACTION_MASS_RESTART_MULTISWAP_DIAGNOSTICS',
    'G3_CANONICAL_ADMISSION_PRESERVATION']
assert len(d['denominator']['frozen_variants']) == 8
print('FVQ74_PM13_FROZEN_DENOMINATOR_EXACT=PASS')
print('FVQ74_PM13_G2_EXIT_REQUIREMENT_EXACT=PASS')
PY

# Exact current-canonical PM14 response production postimage admitted by F-CI61/F-CI61P.
declare -A PROD_BLOBS=(
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
  [src/runtime/mod_fmr_serialized_reference_backend.f90]=0f09c0df1559ece894356b146b64d872470c0a32
)
for p in "${!PROD_BLOBS[@]}"; do
  [[ "$(git rev-parse "HEAD:$p")" == "${PROD_BLOBS[$p]}" ]] || fail "current-canonical production blob drift: $p"
done
echo 'FVQ74_CURRENT_CANONICAL_PM14_BLOBS_EXACT=PASS'

# State ownership and architecture guards relevant to PM13 G2.
python3 - <<'PY'
from pathlib import Path
s=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
start=s.index('type, extends(canonical_state_t), public :: fmr_b110_physical_state_t')
end=s.index('end type fmr_b110_physical_state_t',start)
state=s[start:end].lower()
assert 'drainage' not in state
binding=Path('src/runtime/mod_fmr_drainage_response_binding.f90').read_text().lower()
for token in ('headcalc','open(','read(','write(','.swp','midnight','calendar'):
    assert token not in binding
print('FVQ74_NO_PERSISTENT_DRAINAGE_PROCESS_STATE_STATIC=PASS')
print('FVQ74_HEADCalc_IO_CALENDAR_ISOLATION_STATIC=PASS')
PY

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fvq/test_fvq74_drainage_cross_cutting_independent.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "independent cross-cutting execution O$opt"
  }
  for marker in \
    'FVQ74_MULTISWAP_ACTIVE_PRECOMPUTED_ISOLATION=PASS' \
    'FVQ74_MULTISWAP_ORDER_INDEPENDENCE=PASS' \
    'FVQ74_ACCEPTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_RESTART_NO_ADDITIONAL_DRAINAGE_STATE=PASS' \
    'FVQ74_RESTART_CONTINUATION_EQUIVALENCE=PASS' \
    'FVQ74_REJECTED_RUNTIME_DIAGNOSTICS=PASS' \
    'FVQ74_REJECTED_RUNTIME_ATOMICITY=PASS' \
    'FVQ74_DRAINAGE_CROSS_CUTTING_INDEPENDENT=PASS'; do
    grep -Fxq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker: $marker"
    }
  done
  echo "FVQ74_CROSS_CUTTING_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'O0/O2 output identity'
}
echo 'FVQ74_CROSS_CUTTING_O0_O2_EXACT_IDENTITY=PASS'
echo "FVQ74_CROSS_CUTTING_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | awk '{print $1}')"
cat "$BUILD/o0/output.txt"
git diff --check "$CANONICAL"..HEAD
echo 'FVQ74_DRAINAGE_CROSS_CUTTING_GATE=PASS'

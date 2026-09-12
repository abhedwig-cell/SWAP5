#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE="eba90d79010b095b6556e93bd8b77a8c28d25560"
FTB09="fe3545c4537b11cefd0186aa401048d4f4b10eb9"
FCI36_FROZEN="8fa79a70a9faccaf8b63826df607a685eb75b046"
FVQ51="716d0952c2a9580b213cd22d8c3c1dc824f53dff"
FTB09_MANIFEST="testbank/manifests/F-TB09_INTEGRATED_COLUMN_PHYSICS_CASES.json"
FCI36_STATUS="integration/f-ci/F-CI36_STATUS.json"
TEST="tests/ftb/test_ftb10_drain_bottom_interaction.f90"
BUILD="${RUNNER_TEMP:-/tmp}/ftb10-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "FTB10_GATE_FAIL $*" >&2; exit 10; }
need_commit(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
for sha in "$BASE" "$FTB09" "$FCI36_FROZEN" "$FVQ51"; do need_commit "$sha"; done

git merge-base --is-ancestor "$BASE" HEAD || fail 'HEAD is not descended from frozen current-canonical base'
[[ -z "$(git diff --name-only "$BASE"..HEAD -- src)" ]] || fail 'production src delta is forbidden'
[[ -z "$(git diff --name-only "$BASE"..HEAD -- reference)" ]] || fail 'reference delta is forbidden'
git diff --check "$BASE"..HEAD || fail 'diff check failed'
echo 'FTB10_PRODUCTION_SOURCE_UNCHANGED=PASS'
echo 'FTB10_REFERENCE_TREE_UNCHANGED=PASS'

python3 - "$FTB09" "$FTB09_MANIFEST" <<'PY'
import json, subprocess, sys
sha,path=sys.argv[1:]
p=json.loads(subprocess.check_output(['git','show',f'{sha}:{path}'],text=True))
case=next(x for x in p['cases'] if x['stable_id']=='SWAP5-TB09-DRAIN-BOTTOM-003-v1')
assert case['qualification_state']=='CATALOGED_NOT_PHYSICS_QUALIFIED'
assert case['execution_state']=='CATALOG_SPEC_OWNER_EXECUTOR_REQUIRED'
assert case['water_balance']['required'] is True
assert case['water_balance']['soft_tolerance_tradeoff_allowed'] is False
assert case['water_balance']['equation_id']=='TB09-MASS-003'
assert 'F-MR36' in case['owner_evidence_reused'] and 'F-CI36' in case['owner_evidence_reused']
assert any('Does not qualify the direct SWAP-MODFLOW' in x for x in case['nonclaims'])
print('FTB10_FTB09_CASE003_AUTHORITY_PINNED=PASS')
PY

python3 - "$BASE" "$FCI36_STATUS" "$FCI36_FROZEN" "$FVQ51" <<'PY'
import json, subprocess, sys
base,path,frozen,fvq=sys.argv[1:]
s=json.loads(subprocess.check_output(['git','show',f'{base}:{path}'],text=True))
assert s['decision']=='QUALIFIED_CLOSED_CANONICAL_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_ADMISSION'
assert s['candidate']['composition_blob']=='5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5'
assert s['candidate']['runtime_blob']=='9a384658ec37b68d2ef911e741aa89707dcb3e77'
assert s['independent_closeout']==fvq
assert 'fully implicit or trial-state drainage response' in s['nonclaims']
workflow=subprocess.check_output(['git','show',f'{base}:.github/workflows/fci-canonical.yml'],text=True)
assert 'frozen-fci36-divdra-active-runtime-authority:' in workflow
assert f'ref: {frozen}' in workflow
assert 'run_fci36_fmr36_divdra_active_runtime_canonical_admission.sh' in workflow
print('FTB10_FCI36_FROZEN_AUTHORITY_CHAIN_PINNED=PASS')
PY

test "$(git rev-parse ${FCI36_FROZEN}:src)" = "91afa55dfcfdeedd2dd166f804a2dc91c5ee3e30" || fail 'frozen F-CI36 src tree drift'
test "$(git rev-parse ${FCI36_FROZEN}:reference)" = "9d08625217d7c0a7385df9da6a04183bcd9cb9e6" || fail 'frozen F-CI36 reference tree drift'
test "$(git rev-parse ${FVQ51}:tests/fvq/test_fvq51_divdra_active_runtime_callsite.f90)" = "b8206e0388568f5e792304af9bf9bd889212a10c" || fail 'F-VQ51 verifier source drift'
echo 'FTB10_FCI36_FROZEN_POSTIMAGE_PINNED=PASS'

test "$(git rev-parse HEAD:src/runtime/mod_fmr_divdra_serialized_composition.f90)" = "5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5" || fail 'DIVDRA composition blob drift'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_divdra_serialized_runtime.f90)" = "9a384658ec37b68d2ef911e741aa89707dcb3e77" || fail 'DIVDRA runtime blob drift'
test "$(git rev-parse HEAD:src/process/mod_drainage_spatial_distribution.f90)" = "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a" || fail 'DIVDRA process blob drift'
test "$(git rev-parse HEAD:src/runtime/mod_fmr_divdra_runtime_binding.f90)" = "e4737fb6f00a11ed16e34bee44b3442ac84b31aa" || fail 'DIVDRA binding blob drift'
echo 'FTB10_CURRENT_CANONICAL_DIVDRA_BLOBS_MATCH_ADMITTED_AUTHORITY=PASS'

# Verify that prescribed-head SWBOTB=5 is an active current-canonical solver route,
# not an ignored metadata field. The materializer publishes qbot as an output.
grep -Fq 'request%boundary%bottom_mode == 5' src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'prescribed-head bottom route missing'
grep -Fq 'call materialize_prescribed_head_bottom_flux' src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'prescribed-head qbot materialization missing'
echo 'FTB10_PRESCRIBED_HEAD_BOTTOM_ROUTE_ACTIVE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
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
  src/process/mod_drainage_spatial_distribution.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_divdra_runtime_binding.f90
  src/runtime/mod_fmr_divdra_serialized_composition.f90
  src/runtime/mod_fmr_divdra_serialized_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$TEST" -o "$OUT/ftb10.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/ftb10.o" -o "$OUT/ftb10"
  "$OUT/ftb10" > "$OUT/ftb10.txt" 2>&1 || { cat "$OUT/ftb10.txt" >&2; fail "F-TB10 execution O$opt"; }
  for marker in \
    FTB10_TB09_003_ACTIVE_DIVDRA=PASS \
    FTB10_TB09_003_BOTTOM_HEAD_CHANGE=PASS \
    FTB10_TB09_003_BOTTOM_FLUX_RESPONSE=PASS \
    FTB10_TB09_003_GROUNDWATER_VIEW_CHANGE=PASS \
    FTB10_TB09_003_INTERVAL1_HARD_MASS=PASS \
    FTB10_TB09_003_INTERVAL2_HARD_MASS=PASS \
    FTB10_TB09_003_FULL_WINDOW_HARD_MASS=PASS \
    'FTB10_TB09_DRAIN_BOTTOM_INTERACTION PASS'; do
      grep -Fq "$marker" "$OUT/ftb10.txt" || { cat "$OUT/ftb10.txt" >&2; fail "missing marker $marker O$opt"; }
  done
  echo "FTB10_EXECUTION_O${opt}=PASS"
done

cmp -s "$BUILD/o0/ftb10.txt" "$BUILD/o2/ftb10.txt" || { diff -u "$BUILD/o0/ftb10.txt" "$BUILD/o2/ftb10.txt" >&2 || true; fail 'F-TB10 O0/O2 drift'; }
HASH="$(sha256sum "$BUILD/o0/ftb10.txt" | awk '{print $1}')"
echo "FTB10_OUTPUT_SHA256=$HASH"
echo 'FTB10_FROZEN_OWNER_AUTHORITY_PRESERVED=PASS'
echo 'FTB10_O0_O2_EXACT_IDENTITY=PASS'
cat "$BUILD/o0/ftb10.txt"
echo 'FTB10_DRAIN_BOTTOM_INTEGRATED_QUALIFICATION_GATE=PASS'

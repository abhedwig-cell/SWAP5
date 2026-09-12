#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fci49-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "FCI49_GATE_FAIL $*" >&2; exit 49; }
need_commit(){ git cat-file -e "$1^{commit}" 2>/dev/null || git fetch --no-tags origin "$1" >/dev/null 2>&1 || fail "cannot fetch $1"; }
BASE=e537baf521e633c432a9f33de495fab9f18e918d
PREREG=9e896c8a3aab287177af8968cc4fb6ae6dfb1858
COMPOSE=dce3ac71ce7844c03fb23f2fdb0940e9a9216f7b
RECON=a67897f18636ba9b8edcd87bcba82cd546e322a5
DONOR=48336cb7f14e9246b03c23e549fe7354a93f9e6b
DONOR_CANDIDATE=8ca0b0fb587cdb4dfb7cc5037f571406778f38c8
FKT15R=1b3d8ba6cc70d74a124f20f01f0c47a102763ae0
FKT14=9796f1d32d73018ed5266af80524677abc5ec906
for c in "$BASE" "$PREREG" "$COMPOSE" "$RECON" "$DONOR" "$DONOR_CANDIDATE" "$FKT15R" "$FKT14"; do need_commit "$c"; done

git fetch --no-tags origin integration/f-ci-canonical >/dev/null 2>&1 || fail 'cannot fetch canonical'
CURRENT="$(git rev-parse origin/integration/f-ci-canonical)"
[[ "$CURRENT" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT"
[[ "$(git rev-parse ${PREREG}^)" == "$BASE" ]] || fail 'preregistration is not direct child of canonical base'
[[ "$(git rev-parse ${COMPOSE}^)" == "$PREREG" ]] || fail 'source composition is not direct child of preregistration'
git merge-base --is-ancestor "$RECON" HEAD || fail 'qualification head lost reconciliation authority'
git merge-base --is-ancestor "$DONOR_CANDIDATE" "$DONOR" || fail 'qualified donor candidate not ancestor of definitive donor closeout'
git merge-base --is-ancestor "$FKT15R" "$DONOR" || fail 'qualified recomposition not ancestor of definitive donor'
echo 'FCI49_CANONICAL_AND_LINEAGE_GUARDS=PASS'

ALLOW=(
 src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
 src/adapter/mod_b110_production_soil_water_task2.f90
 src/adapter/mod_b1_10_reference_model.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_soil_water_transaction_result_bridge.f90
 src/kernel/mod_kernel_transactions.f90
 src/legacy/b1_10_port/headcalc.f90
 src/legacy/b1_10_port/soilwater.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/solver/mod_b110_dynamic_top_boundary_provider.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/transaction/mod_transaction_reference.f90
)
printf '%s\n' "${ALLOW[@]}" | sort > "$BUILD/expected-src.txt"
git diff --name-only "$BASE"..HEAD -- src | sort > "$BUILD/actual-src.txt"
cmp "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" || { diff -u "$BUILD/expected-src.txt" "$BUILD/actual-src.txt" >&2 || true; fail 'source delta is not exact 17-path allowlist'; }
for p in "${ALLOW[@]}"; do
  a="$(git rev-parse "HEAD:$p")"; d="$(git rev-parse "$DONOR:$p")"
  [[ "$a" == "$d" ]] || fail "definitive donor blob mismatch $p head=$a donor=$d"
done
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference tree changed'
echo 'FCI49_EXACT_DEFINITIVE_DONOR_SOURCE_IDENTITY=PASS'
echo 'FCI49_REFERENCE_IMMUTABLE=PASS'

# Pin the definitive closeout and single-owner reconciliation. No superseded KT15 branch is a source authority here.
git show "$DONOR:integration/f-kt/F-KT15_CLOSEOUT.json" > "$BUILD/fkt15-closeout.json"
python3 - "$BUILD/fkt15-closeout.json" integration/f-kt/F-KT15_LINEAGE_RECONCILIATION.json <<'PY'
import json,sys
c=json.load(open(sys.argv[1])); r=json.load(open(sys.argv[2]))
assert c['status']=='CLOSED_QUALIFIED'
assert c['decision']=='QUALIFIED_RESTRICTED_PRODUCTION_SOIL_WATER_TASK2_SOLVER_SERVICE_TRANSACTION_COMPOSITION_READY_FOR_SEPARATE_CANONICAL_ADMISSION'
assert c['authorities']['qualified_production_candidate']=='8ca0b0fb587cdb4dfb7cc5037f571406778f38c8'
assert c['authorities']['true_canonical_ancestry_merge']=='9465be74c01fe6455466e5ba7f62a761986ad450'
assert c['canonical_race_reconciliation']['new_canonical']=='e537baf521e633c432a9f33de495fab9f18e918d'
assert c['qualified_capability']['O0_O2_identity'] is True
assert c['qualified_capability']['hard_mass_gate_preserved'] is True
assert r['decision']=='SINGLE_KT15_PRODUCTION_LINEAGE_RESTORED'
owners=[x for x in r['branches'] if x['classification']=='DEFINITIVE_ACTIVE_OWNER']
assert len(owners)==1 and owners[0]['branch']=='work/f-kt15-task2-solver-service-production-composition'
assert owners[0]['head']=='48336cb7f14e9246b03c23e549fe7354a93f9e6b'
assert all(x['classification'] in {'DEFINITIVE_ACTIVE_OWNER','HISTORICAL_SUPERSEDED','ABANDONED_DUPLICATE','REMEDIATION_ANCESTOR'} for x in r['branches'])
print('FCI49_DEFINITIVE_SINGLE_OWNER_AUTHORITY_PINNED=PASS')
PY

python3 - <<'PY'
import json
p='integration/f-ci/F-CI49_ARCHITECTURE_AUDIT.json'; a=json.load(open(p))
assert a['canonical_base']=='e537baf521e633c432a9f33de495fab9f18e918d'
assert a['definitive_donor']=='48336cb7f14e9246b03c23e549fe7354a93f9e6b'
assert a['mass_conservation']=='HARD_UNCHANGED'
assert a['new_physics'] is False and a['new_solver_functionality'] is False
assert a['scientific_tolerance_relaxation'] is False
assert a['superseded_KT15_source_consumed'] is False
ids=[x['id'] for x in a['invariants']]
assert ids==list(range(1,31)), ids
assert all(x['status'] in {'PRESERVED','QUALIFIED'} for x in a['invariants'])
print('FCI49_ARCHITECTURE_INVARIANTS_30_OF_30=PASS')
PY

# Persistent restart/state ownership is unchanged. Trial capsule/workspace remains worker-local and must not enter committed restart records.
git diff --quiet "$BASE"..HEAD -- \
  src/runtime/mod_fmr_committed_restart.f90 \
  src/runtime/mod_fmr_restart_state_contract.f90 \
  src/kernel/mod_kernel_committed_persistence.f90 || fail 'persistent restart ownership changed'
python3 - <<'PY'
from pathlib import Path
r=Path('src/runtime/mod_fmr_committed_restart.f90').read_text().lower()
record=r.split('type, public :: fmr_committed_restart_record_t',1)[1].split('end type fmr_committed_restart_record_t',1)[0]
for forbidden in ('newton','jacobian','workspace','scratch','soil_water_trial','warm_start'):
    assert forbidden not in record, forbidden
w=Path('src/runtime/mod_a23bu_worker_execution_context.f90').read_text().lower()
assert 'soil_water_trial' in w
print('FCI49_NO_SOLVER_SCRATCH_PERSISTENCE=PASS')
print('FCI49_COMPACT_COMMITTED_RESTART_STATE_PRESERVED=PASS')
PY

# Materialize only immutable tests from the definitive donor for replay. They are not production source and are not persisted in this branch.
mkdir -p tests/fkt
DONOR_TESTS=(
 tests/fkt/fkt15_production_task2_stubs.f90
 tests/fkt/test_fkt15_production_task2.f90
 tests/fkt/test_fkt15_production_surface_regimes.f90
 tests/fkt/fkt15_reference_model_stubs.f90
 tests/fkt/test_fkt15_reference_model_transport.f90
)
for p in "${DONOR_TESTS[@]}"; do git show "$DONOR:$p" > "$p" || fail "cannot materialize definitive donor test $p"; done

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
TASK2_MODULES=(
 tests/fkt/fkt15_production_task2_stubs.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 src/solver/mod_surface_evaporation_capacity_contract.f90
 src/solver/mod_b110_surface_evaporation_capacity_provider.f90
 src/process/mod_restricted_surface_evaporation.f90
 src/solver/mod_b110_dynamic_top_boundary_provider.f90
 src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 src/adapter/mod_b110_production_soil_water_task2.f90
)
for opt in 0 2; do
  OUT="$BUILD/task2-o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${TASK2_MODULES[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"; objs+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/legacy/b1_10_port/soilwater.f90 -o "$OUT/soilwater.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fkt/test_fkt15_production_task2.f90 -o "$OUT/test.o"
  gfortran "${FLAGS[@]}" -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$OUT/test" > "$OUT/task2.txt" || { cat "$OUT/task2.txt" >&2 || true; fail "task2 O$opt"; }
  for m in FKT15_ACCEPTED_TYPED_ROUTE=PASS FKT15_ACCEPTED_SENSITIVITY=PASS FKT15_SINGLE_HYDRAULIC_AUTHORITY=PASS FKT15_UNSUPPORTED_DIRECT_FALLBACK_SEAM=PASS FKT15_STALE_SENSITIVITY_CLEAR=PASS FKT15_WORKER_ISOLATION_1=PASS FKT15_WORKER_ISOLATION_2=PASS FKT15_WORKER_ISOLATION_4=PASS FKT15_WORKER_ISOLATION_8=PASS FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS FKT15_RETRY_FAIL_CLOSED=PASS FKT15_PRODUCTION_TASK2_GATE=PASS; do grep -Fq "$m" "$OUT/task2.txt" || fail "task2 O$opt missing $m"; done
  gfortran "${FLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fkt/test_fkt15_production_surface_regimes.f90 -o "$OUT/surface.o"
  gfortran "${FLAGS[@]}" -O"$opt" "${objs[@]}" "$OUT/surface.o" -o "$OUT/surface"
  timeout 90s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$OUT/surface" > "$OUT/surface.txt" || { cat "$OUT/surface.txt" >&2 || true; fail "surface O$opt"; }
  for m in FKT15_PRODUCTION_SURFACE_FLUX=PASS FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS FKT15_PRODUCTION_PONDED_HEAD=PASS FKT15_PRODUCTION_LINEAR_RUNOFF=PASS FKT15_PRODUCTION_SURFACE_METADATA_IDENTITY=PASS FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS FKT15_PRODUCTION_FLUX_ONLY_TANGENT_SCOPE=PASS FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS; do grep -Fq "$m" "$OUT/surface.txt" || fail "surface O$opt missing $m"; done
  echo "FCI49_FKT15_TASK2_AND_SURFACE_O${opt}=PASS"
done
cmp "$BUILD/task2-o0/task2.txt" "$BUILD/task2-o2/task2.txt" || fail 'task2 O0/O2 deterministic replay differs'
cmp "$BUILD/task2-o0/surface.txt" "$BUILD/task2-o2/surface.txt" || fail 'surface O0/O2 deterministic replay differs'
echo 'FCI49_FKT15_O0_O2_DETERMINISTIC_REPLAY=PASS'

# Accepted-only F-KT14 transport replay at O0/O2 on the composed current-canonical image.
TFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TRANSPORT=(
 src/transaction/mod_transaction_reference.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 tests/fkt/fkt15_reference_model_stubs.f90
 src/adapter/mod_soil_water_transaction_result_bridge.f90
 src/adapter/mod_b1_10_reference_model.f90
 tests/fkt/test_fkt15_reference_model_transport.f90
)
for opt in 0 2; do
  OUT="$BUILD/transport-o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${TRANSPORT[@]}"; do obj="$OUT/$(basename "${src%.*}").o"; gfortran "${TFLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"; objs+=("$obj"); done
  gfortran "${TFLAGS[@]}" -O"$opt" "${objs[@]}" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" || fail "transport O$opt"
  for m in FKT15_REFERENCE_ACCEPTED_FKT14_TRANSPORT=PASS FKT15_REFERENCE_REJECTED_STALE_EXCLUSION=PASS FKT15_REFERENCE_DIRECT_FALLBACK_NO_SENSITIVITY=PASS FKT15_REFERENCE_MODEL_TRANSPORT_GATE=PASS; do grep -Fq "$m" "$OUT/out.txt" || fail "transport O$opt missing $m"; done
  echo "FCI49_FKT14_ACCEPTED_ONLY_TRANSPORT_O${opt}=PASS"
done
cmp "$BUILD/transport-o0/out.txt" "$BUILD/transport-o2/out.txt" || fail 'transport O0/O2 differs'
echo 'FCI49_FKT14_TRANSPORT_O0_O2_IDENTITY=PASS'

# Generic transaction commit/rejection semantics on current source, without historical single-delta assumptions.
CFLAGS=(-std=f2008 -Wall -Wextra -Werror -ffree-line-length-none -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
COMMIT_MODULES=(src/transaction/mod_transaction_reference.f90 src/runtime/mod_canonical_contracts.f90 src/runtime/mod_canonical_interval_runtime.f90 src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_accepted_commit_receipt.f90)
for opt in 0 2; do
  OUT="$BUILD/commit-o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${COMMIT_MODULES[@]}"; do obj="$OUT/$(basename "${src%.*}").o"; gfortran "${CFLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"; objs+=("$obj"); done
  gfortran "${CFLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fmr/test_fmr18_accepted_commit_receipt.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" || { cat "$OUT/out.txt" >&2 || true; fail "commit semantics O$opt"; }
  for m in FMR18_REAL_FKT_COMMIT_CREATES_EXACT_RECEIPT=PASS FMR18_COMMIT_REJECTION_EMITS_NO_RECEIPT=PASS FMR18_EXPECTED_RECEIPT_FAILURES_PRECEDE_PHYSICAL_COMMIT=PASS FMR18_PREVALIDATION_REJECTION_IS_NONMUTATING_AND_REPLAYABLE=PASS; do grep -Fq "$m" "$OUT/out.txt" || fail "commit O$opt missing $m"; done
  echo "FCI49_TRANSACTION_COMMIT_REJECTION_O${opt}=PASS"
done
cmp "$BUILD/commit-o0/out.txt" "$BUILD/commit-o2/out.txt" || fail 'commit semantics O0/O2 differs'
echo 'FCI49_TRANSACTION_COMMIT_ROLLBACK_DETERMINISTIC=PASS'

# Current-canonical split-run/restart replay with an irregular non-calendar t0/tm/t1 window.
cp tests/fmr/test_fmr19_process_restart.f90 "$BUILD/restart.f90"
python3 - "$BUILD/restart.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
for old,new in {
'real(real64), parameter :: t0 = 1000.125_real64':'real(real64), parameter :: t0 = 7311.0625_real64',
'real(real64), parameter :: tm = 1000.375_real64':'real(real64), parameter :: tm = 7311.3125_real64',
'real(real64), parameter :: t1 = 1000.625_real64':'real(real64), parameter :: t1 = 7311.6875_real64'}.items():
    assert old in s, old
    s=s.replace(old,new,1)
p.write_text(s)
print('FCI49_GENERIC_T0_T1_RESTART_ORACLE_MATERIALIZED=PASS')
PY
RFLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
RESTART_MODULES=(
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
for opt in 0 2; do
  OUT="$BUILD/restart-o$opt"; mkdir -p "$OUT"; objs=()
  for src in "${RESTART_MODULES[@]}"; do obj="$OUT/$(basename "${src%.*}").o"; gfortran "${RFLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$src" -o "$obj"; objs+=("$obj"); done
  gfortran "${RFLAGS[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c "$BUILD/restart.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objs[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt" || { cat "$OUT/out.txt" >&2 || true; fail "restart O$opt"; }
  for m in FMR19_EXACT_LINEAGE_REVISION_TIME_CONTINUATION=PASS FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS FMR19_DETERMINISTIC_REPLAY=PASS; do grep -Fq "$m" "$OUT/out.txt" || fail "restart O$opt missing $m"; done
  echo "FCI49_RESTART_GENERIC_T0_T1_O${opt}=PASS"
done
cmp "$BUILD/restart-o0/out.txt" "$BUILD/restart-o2/out.txt" || fail 'restart O0/O2 differs'
echo 'FCI49_RESTART_AND_DETERMINISTIC_REPLAY=PASS'

git diff --check "$BASE" -- src tests/fci integration/f-ci .github/workflows || fail 'diff check failed'
# Remove runtime-materialized donor tests before exact cleanliness check.
rm -rf tests/fkt
git status --porcelain | grep -q . && fail 'gate left working tree dirty'
echo 'FCI49_CURRENT_CANONICAL_COMPATIBILITY_PREPROMOTION=PASS'
echo 'FCI49_DEFINITIVE_ADMISSION_GATE=PASS'

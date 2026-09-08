#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-fvq26-$$"
WT="$BUILD/fvq26"
FVQ26_CLOSEOUT=a1d5ad9147e18301f68183822577b1ba8fca3de2
FMR13_CLOSEOUT=985058c0261d284424432a65bded16b7fc9107cb
FMR14_CLOSEOUT=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
KERNEL_PRE=9f7c16e71cfb93b57f796ba759bae73824318a2f
KERNEL_POST=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_PRE=1bb0c6d4683db2729d48de31babcea72bc1a6caf
RUNTIME_POST=7a60f8b8d18672098fed1c6890a95aac738ed21d
FVQ26_TEST_BLOB=05002e0e084c21f90e7a97351df3ff8143666948
mkdir -p "$BUILD"
cleanup() {
  git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true
  rm -rf "$BUILD"
}
trap cleanup EXIT
cd "$ROOT"

# Owner qualification must be final and explicitly released to F-PE.
python3 - <<'PY'
import json, subprocess
raw=subprocess.check_output(['git','show','origin/qualification/f-vq26-fmr11-prescribed-bottom-head-runtime:integration/f-vq/F-VQ26_STATUS.json'],text=True)
s=json.loads(raw)
assert s['status']=='QUALIFIED_RESTRICTED_SERIALIZED_PRESCRIBED_BOTTOM_HEAD_RUNTIME_SCIENTIFIC_ADMISSION'
assert s['state']['qualified'] is True
assert s['production_source_modified'] is False
assert s['physics_changed'] is False
assert s['numerical_controls_changed'] is False
assert s['acceptance_changed'] is False
assert s['mass_requirement_relaxed'] is False
assert s['transaction_semantics_changed'] is False
assert 'F-PE may use this exact admitted stationary workload' in s['next_action']
print('FPE03_FVQ26_OWNER_RELEASE_LOCK=PASS')
PY

# Create an immutable F-VQ26 worktree and prove the F-MR14 observer delta has
# exact preimages on this side lineage before applying it. This is test-only;
# no repository production source is changed.
git worktree add --detach "$WT" "$FVQ26_CLOSEOUT" >/dev/null
[[ "$(git -C "$WT" rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_PRE" ]]
[[ "$(git -C "$WT" rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_PRE" ]]
[[ "$(git rev-parse "$FMR13_CLOSEOUT:src/kernel/mod_kernel_transactions.f90")" == "$KERNEL_PRE" ]]
[[ "$(git rev-parse "$FMR13_CLOSEOUT:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")" == "$RUNTIME_PRE" ]]
[[ "$(git -C "$WT" rev-parse HEAD:tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90)" == "$FVQ26_TEST_BLOB" ]]
echo 'FPE03_FVQ26_EXACT_OBSERVER_PREIMAGES=PASS'

git diff "$FMR13_CLOSEOUT" "$FMR14_CLOSEOUT" -- \
  src/kernel/mod_kernel_transactions.f90 \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90 > "$BUILD/fmr14-observer.patch"
[[ -s "$BUILD/fmr14-observer.patch" ]]
git -C "$WT" apply "$BUILD/fmr14-observer.patch"
[[ "$(git -C "$WT" hash-object src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_POST" ]]
[[ "$(git -C "$WT" hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_POST" ]]
changed="$(git -C "$WT" diff --name-only)"
expected=$'src/kernel/mod_kernel_transactions.f90\nsrc/runtime/mod_fmr_serialized_multiswap_runtime.f90'
[[ "$changed" == "$expected" ]] || { printf 'FPE03_FVQ26_OVERLAY_DELTA_FAIL\n%s\n' "$changed" >&2; exit 1; }
echo 'FPE03_FVQ26_EXACT_FMR14_OBSERVER_POSTIMAGES=PASS'
echo 'FPE03_FVQ26_OBSERVER_OVERLAY_PHYSICS_CHANGE=NO'

# Add only print statements to a temporary copy of the exact admitted F-VQ26
# oracle. Workload, forcing, mode-5 boundary, tolerances and acceptance remain unchanged.
python3 - "$WT/tests/fvq/test_fvq26_prescribed_bottom_head_runtime_v2.f90" "$BUILD/fvq26_screen.f90" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
anchor="""  write(*,'(A,Z16.16)') 'FVQ26V2_NEGATIVE_QBOT_BITS=', transfer(obs_down%bottom_flux, 0_int64)\n"""
insert="""  write(*,'(A,I0)') 'FPE03_FVQ26_DOWN_ACCEPTED_SUBSTEPS=', result_down(1)%accepted_substeps\n  write(*,'(A,7(1X,I0))') 'FPE03_FVQ26_DOWN_COST=', result_down(1)%solver_nonlinear_iterations, &\n       result_down(1)%solver_internal_retries, result_down(1)%solver_headcalc_calls, &\n       result_down(1)%solver_jacobian_builds, result_down(1)%solver_linear_solves, &\n       result_down(1)%solver_backtracking_attempts, result_down(1)%solver_alternative_solver_calls\n  write(*,'(A,3(1X,L1),1X,ES24.16)') 'FPE03_FVQ26_DOWN_ACCEPTANCE=', result_down(1)%completed, &\n       result_down(1)%committed, result_down(1)%mass%complete, result_down(1)%mass%residual\n  write(*,'(A,I0)') 'FPE03_FVQ26_UP_ACCEPTED_SUBSTEPS=', result_up(1)%accepted_substeps\n  write(*,'(A,7(1X,I0))') 'FPE03_FVQ26_UP_COST=', result_up(1)%solver_nonlinear_iterations, &\n       result_up(1)%solver_internal_retries, result_up(1)%solver_headcalc_calls, &\n       result_up(1)%solver_jacobian_builds, result_up(1)%solver_linear_solves, &\n       result_up(1)%solver_backtracking_attempts, result_up(1)%solver_alternative_solver_calls\n  write(*,'(A,3(1X,L1),1X,ES24.16)') 'FPE03_FVQ26_UP_ACCEPTANCE=', result_up(1)%completed, &\n       result_up(1)%committed, result_up(1)%mass%complete, result_up(1)%mass%residual\n\n"""+anchor
if src.count(anchor)!=1:
    raise SystemExit(f'exact output anchor drift: {src.count(anchor)}')
Path(sys.argv[2]).write_text(src.replace(anchor,insert,1))
print('FPE03_FVQ26_TEMPORARY_OBSERVER_TEST_TRANSFORM=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_root_water_uptake_process.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

cd "$WT"
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq26_screen.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 60s "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  for marker in \
    'FVQ26V2_ACCEPTED_NEGATIVE_QBOT=PASS' \
    'FVQ26V2_ACCEPTED_POSITIVE_QBOT=PASS' \
    'FVQ26V2_BOTTOM_HEAD_AUTHORITY=PASS' \
    'FVQ26V2_BOTTOM_FLUX_SEED_IRRELEVANCE=PASS' \
    'FVQ26V2_QBOT_MASS_EXACTLY_ONCE=PASS' \
    'FVQ26V2_ZERO_TOLERANCE_TEMPORAL_ACCEPTANCE=PASS' \
    'FVQ26V2_PRESCRIBED_BOTTOM_HEAD_RUNTIME_ORACLE PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  grep -Fq 'FPE03_FVQ26_DOWN_COST=' "$OUT/output.txt"
  grep -Fq 'FPE03_FVQ26_UP_COST=' "$OUT/output.txt"
  echo "FPE03_FVQ26_MODE5_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPE03_FVQ26_MODE5_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/output.txt" <<'PY'
from pathlib import Path
import sys
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()
baseline=(3,0,3,3,3,3,0)
def cost(k): return tuple(int(x) for x in vals[k].split())
def accepted(prefix):
    p=vals[prefix+'_ACCEPTANCE'].split()
    return p[:3]==['T','T','T'] and abs(float(p[3].replace('D','E'))) <= 1.0e-12 and int(vals[prefix+'_ACCEPTED_SUBSTEPS'])>0
rows=[]
for name,prefix in [('fvq26_mode5_down','FPE03_FVQ26_DOWN'),('fvq26_mode5_up','FPE03_FVQ26_UP')]:
    c=cost(prefix+'_COST'); a=accepted(prefix); h=any(x>b for x,b in zip(c,baseline))
    rows.append((name,a,int(vals[prefix+'_ACCEPTED_SUBSTEPS']),c,h))
print('FPE03_FVQ26_BASELINE_VECTOR='+','.join(map(str,baseline)))
for name,a,sub,c,h in rows:
    print(f'FPE03_FVQ26_CASE={name}:accepted={str(a).upper()}:substeps={sub}:cost='+','.join(map(str,c))+f':higher={str(h).upper()}')
if not all(r[1] for r in rows): raise SystemExit('admitted F-VQ26 runtime case lost acceptance under observer-only overlay')
h=[r for r in rows if r[4]]
print(f'FPE03_FVQ26_ACCEPTED_HIGHER_COST_COUNT={len(h)}')
if h:
    print('FPE03_B04_FVQ26_CANDIDATE=POSITIVE_ACCEPTED_HIGHER_COST_MODE5_CASE_FOUND')
    print('FPE03_B04_FVQ26_HIGHER_CASES='+';'.join(r[0]+':'+','.join(map(str,r[3])) for r in h))
else:
    print('FPE03_B04_FVQ26_CANDIDATE=NEGATIVE_NO_ACCEPTED_HIGHER_COST_MODE5_CASE')
print('FPE03_FVQ26_MODE5_COST_SCREEN PASS')
PY

echo 'FPE03_FVQ26_WORKLOAD_CHANGED=NO'
echo 'FPE03_FVQ26_ACCEPTANCE_CHANGED=NO'
echo 'FPE03_FVQ26_MASS_REQUIREMENT_RELAXED=NO'

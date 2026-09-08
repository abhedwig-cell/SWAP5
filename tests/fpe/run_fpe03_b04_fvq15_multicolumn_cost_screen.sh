#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-fvq15-screen-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
FVQ15_BRANCH=qualification/f-vq15-fmr05-serialized-multiswap
FVQ19_BRANCH=qualification/f-vq19-fmr08-nonstationary-temporal
FVQ15_TEST_BLOB=00652f1dc23c05f465ed0f2f044e423baccadd47
SNOW_TEST_BLOB=4f45bb0623fef3fb6d091579e8f435563c858a69
BASELINE='3 0 3 3 3 3 0'

fail() { echo "FPE03_FVQ15_SCREEN_FAIL $*" >&2; exit 1; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob mismatch $path expected=$expected actual=$actual"
  echo "FPE03_FVQ15_SOURCE_LOCK=PASS path=$path blob=$actual"
}

# Screening is observer/test-only on the exact independently admitted F-VQ27 source postimage.
git diff --quiet "$FVQ27" -- src || {
  echo 'FPE03_FVQ15_PRODUCTION_IMMUTABILITY_TO_FVQ27=FAIL' >&2
  git diff --name-only "$FVQ27" -- src >&2
  exit 1
}
echo 'FPE03_FVQ15_PRODUCTION_IMMUTABILITY_TO_FVQ27=PASS'

check_blob src/adapter/mod_b110_serialized_context_binding.f90 e21c964eac48d5feb91388cfd06a646c4002a497
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 db432cac3f1156a179c636435a25f52cdececffc
check_blob src/legacy/b1_10_port/headcalc.f90 55893f1f5ccba2052ad681743aa155b69f351246
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 6f39d60a87c1987ae95d7faec2f55f865af90a08
check_blob src/solver/mod_reference_richards_workspace.f90 59ef9d037c1875610d45ac83387ebab9e917e0fe
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/kernel/mod_kernel_transactions.f90 af42c7d51ef545e20c76d3000f1ed1493690d68e
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 7a60f8b8d18672098fed1c6890a95aac738ed21d
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/runtime/mod_fmr_checkpoint_orchestrator.f90 232875e7192f995930c102609cee08dc8938c86a
check_blob src/runtime/mod_fmr_root_uptake_process_binding.f90 2fc348f18e8561096fa34dd3c11c64b359583f11
echo 'FPE03_FVQ15_EXACT_FVQ27_SOURCE_LOCKS=PASS'

# F-VQ19 released exactly the already-screened F-MR06 snow fixture. Prove this
# source identity rather than re-running the same workload as a supposedly new tranche.
current_snow="$(git rev-parse HEAD:tests/fmr/test_fmr06_snow_smoke.f90)"
fvq19_snow="$(git rev-parse "origin/$FVQ19_BRANCH:tests/fmr/test_fmr06_snow_smoke.f90")"
[[ "$current_snow" == "$SNOW_TEST_BLOB" && "$fvq19_snow" == "$SNOW_TEST_BLOB" ]] || fail 'F-VQ19 snow fixture identity drift'
python3 - <<'PY'
import json, subprocess
branch='qualification/f-vq19-fmr08-nonstationary-temporal'
handoff=json.loads(subprocess.check_output(['git','show',f'origin/{branch}:integration/f-vq/F-VQ19_FPE_HANDOFF.json'],text=True))
status=json.loads(subprocess.check_output(['git','show',f'origin/{branch}:integration/f-vq/F-VQ19_STATUS.json'],text=True))
assert handoff['released_evidence']['fixture']=='tests/fmr/test_fmr06_snow_smoke.f90'
assert handoff['released_evidence']['fixture_blob']=='4f45bb0623fef3fb6d091579e8f435563c858a69'
assert handoff['released_evidence']['nonstationary_state_change']=='snow_water_storage 0.10 -> 0.12'
assert handoff['released_evidence']['interval']=='1400.25 -> 1401.25'
assert handoff['released_evidence']['temporal_tolerance']=='0.0'
assert status['fpe_release'] is True
assert status['decision']=='QUALIFIED_INDEPENDENT_NONSTATIONARY_EXACT_TEMPORAL_ACCEPTANCE_READY_FOR_FPE'
print('FPE03_FVQ19_EXACT_ALREADY_SCREENED_SNOW_FIXTURE=PASS')
print('FPE03_FVQ19_TRANCHE2_REDUNDANT_WITH_TRANCHE1=PASS')
PY

# Materialize the exact independently qualified F-VQ15 workload only in scratch.
git show "origin/$FVQ15_BRANCH:tests/fvq/test_fvq15_multicolumn_reference.f90" > "$BUILD/fvq15_screen.f90"
[[ "$(git hash-object "$BUILD/fvq15_screen.f90")" == "$FVQ15_TEST_BLOB" ]] || fail 'F-VQ15 workload blob drift'
python3 - <<'PY'
import json, subprocess
branch='qualification/f-vq15-fmr05-serialized-multiswap'
s=json.loads(subprocess.check_output(['git','show',f'origin/{branch}:integration/f-vq/F-VQ15_STATUS.json'],text=True))
assert s['status']=='QUALIFIED_FMR05_RESTRICTED_SERIALIZED_MULTICOLUMN_PHYSICAL_ADMISSION'
assert s['QUALIFIED'] is True and s['scientific_admission'] is True
assert s['verified_matrix']['columns']==[1,2,17,31]
assert s['verified_matrix']['input_orders']==['canonical','reversed']
assert s['verified_matrix']['o0_o2_output_identity'] is True
assert s['verified_matrix']['max_simultaneous_real_physical_solves']==1
assert s['production_physics_qualified_scope']=='EXACT_FVQ14_RESTRICTED_PROFILE_ONLY'
print('FPE03_FVQ15_INDEPENDENT_SCIENTIFIC_ADMISSION_LOCK=PASS')
PY

# Observer-only transform. Workload inputs, physical configuration, acceptance,
# transaction and mass gates remain unchanged. The historical F-VQ15 aggregate
# oracle is adapted only to the later qualified deterministic execution-order
# aggregation: expected mass terms are summed by dispatch_ordinal, exactly as the
# current runtime does. This preserves bitwise authoritative-mass checking while
# avoiding an obsolete input-order summation expectation.
python3 - "$BUILD/fvq15_screen.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
old1="""    call validate_runtime_batch(canonical_results, runtime_diag, n)\n    call verify_all_against_direct(canonical_results, states, n)\n\n    call run_multi_case(n, .true., 1, reverse_results, diagnostics, aggregate, runtime_diag, states, status)\n"""
new1="""    call validate_runtime_batch(canonical_results, runtime_diag, n)\n    call verify_all_against_direct(canonical_results, states, n)\n    call print_screen_costs('canonical', n, canonical_results)\n\n    call run_multi_case(n, .true., 1, reverse_results, diagnostics, aggregate, runtime_diag, states, status)\n"""
old2="""    call validate_runtime_batch(reverse_results, runtime_diag, n)\n    call verify_all_against_direct(reverse_results, states, n)\n    call require(result_sets_identical(canonical_results, reverse_results), 'canonical/reverse result identity')\n"""
new2="""    call validate_runtime_batch(reverse_results, runtime_diag, n)\n    call verify_all_against_direct(reverse_results, states, n)\n    call print_screen_costs('reversed', n, reverse_results)\n    call require(result_sets_identical(canonical_results, reverse_results), 'canonical/reverse result identity')\n"""
anchor="""contains\n\n  subroutine run_multi_case(n, reverse_order, batch_size, results, diag, agg, rdiag, states_out, dispatch_status)\n"""
insert="""contains\n\n  subroutine print_screen_costs(order, n, results)\n    character(len=*), intent(in) :: order\n    integer, intent(in) :: n\n    type(fmr_serialized_column_result_t), intent(in) :: results(:)\n    integer :: i\n    do i = 1, size(results)\n      write(*,'(A,1X,A,1X,I0,1X,I0,8(1X,I0))') 'FPE03_FVQ15_COST', trim(order), n, i, &\n           results(i)%accepted_substeps, results(i)%solver_nonlinear_iterations, &\n           results(i)%solver_internal_retries, results(i)%solver_headcalc_calls, &\n           results(i)%solver_jacobian_builds, results(i)%solver_linear_solves, &\n           results(i)%solver_backtracking_attempts, results(i)%solver_alternative_solver_calls\n    end do\n  end subroutine print_screen_costs\n\n  subroutine run_multi_case(n, reverse_order, batch_size, results, diag, agg, rdiag, states_out, dispatch_status)\n"""
oldagg="""    integer :: i\n\n    mass = canonical_mass_accounting_t()\n    mass%complete = .true.\n    mass%interval_t0 = t0\n    mass%interval_t1 = t1\n    mass%missing_contribution_mask = TX_MASS_MISSING_NONE\n    do i = 1, size(results)\n      if (.not. results(i)%committed) cycle\n      mass%accepted_transaction_count = mass%accepted_transaction_count + results(i)%mass%accepted_transaction_count\n      mass%storage_start = mass%storage_start + results(i)%mass%storage_start\n      mass%storage_end = mass%storage_end + results(i)%mass%storage_end\n      mass%storage_change = mass%storage_change + results(i)%mass%storage_change\n      mass%total_in = mass%total_in + results(i)%mass%total_in\n      mass%total_out = mass%total_out + results(i)%mass%total_out\n      mass%residual = mass%residual + results(i)%mass%residual\n    end do\n"""
newagg="""    integer :: i, pos, idx\n\n    mass = canonical_mass_accounting_t()\n    mass%complete = .true.\n    mass%interval_t0 = t0\n    mass%interval_t1 = t1\n    mass%missing_contribution_mask = TX_MASS_MISSING_NONE\n    do pos = 1, size(results)\n      idx = 0\n      do i = 1, size(results)\n        if (results(i)%dispatch_ordinal == pos) then\n          idx = i\n          exit\n        end if\n      end do\n      call require(idx > 0, 'expected aggregate dispatch ordinal')\n      if (.not. results(idx)%committed) cycle\n      mass%accepted_transaction_count = mass%accepted_transaction_count + results(idx)%mass%accepted_transaction_count\n      mass%storage_start = mass%storage_start + results(idx)%mass%storage_start\n      mass%storage_end = mass%storage_end + results(idx)%mass%storage_end\n      mass%storage_change = mass%storage_change + results(idx)%mass%storage_change\n      mass%total_in = mass%total_in + results(idx)%mass%total_in\n      mass%total_out = mass%total_out + results(idx)%mass%total_out\n      mass%residual = mass%residual + results(idx)%mass%residual\n    end do\n"""
assert src.count(old1)==1, 'canonical transform anchor drift'
assert src.count(old2)==1, 'reverse transform anchor drift'
assert src.count(anchor)==1, 'contains transform anchor drift'
assert src.count(oldagg)==1, 'aggregate oracle anchor drift'
src=src.replace(old1,new1,1).replace(old2,new2,1).replace(anchor,insert,1).replace(oldagg,newagg,1)
p.write_text(src)
print('FPE03_FVQ15_OBSERVER_ONLY_TRANSFORM=PASS')
print('FPE03_FVQ15_AGGREGATE_ORACLE_REBOUND_TO_DISPATCH_ORDER=PASS')
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
  src/solver/mod_reference_linear_solver.f90
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

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq15_screen.f90" -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 120s "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FVQ15_MULTICOLUMN_DIRECT_REFERENCE_TEST PASS' "$OUT/output.txt"
  for n in 1 2 17 31; do
    grep -Fq "FVQ15_DIRECT_REFERENCE_COLUMNS_${n}=PASS" "$OUT/output.txt"
    grep -Fq "FVQ15_REVERSE_ORDER_COLUMNS_${n}=PASS" "$OUT/output.txt"
  done
  grep -Fq 'FVQ15_A_B_A_EXACT=PASS' "$OUT/output.txt"
  grep -Fq 'FVQ15_GENERIC_TIME_1000_125_TO_1000_625=PASS' "$OUT/output.txt"
  grep -Fq 'FPE03_FVQ15_COST ' "$OUT/output.txt"
  echo "FPE03_FVQ15_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FPE03_FVQ15_O0_O2_FULL_OUTPUT_IDENTITY=PASS'

python3 - "$BUILD/o0/output.txt" <<'PY'
from pathlib import Path
import sys
baseline=(3,0,3,3,3,3,0)
rows=[]
for line in Path(sys.argv[1]).read_text().splitlines():
    if not line.startswith('FPE03_FVQ15_COST '): continue
    p=line.split()
    order=p[1]; n=int(p[2]); idx=int(p[3]); accepted_substeps=int(p[4]); c=tuple(map(int,p[5:12]))
    if len(c)!=7: raise SystemExit(f'bad cost row: {line}')
    higher=any(x>b for x,b in zip(c,baseline))
    rows.append((order,n,idx,accepted_substeps,c,higher))

expected=sum(2*n for n in (1,2,17,31))
if len(rows)!=expected:
    raise SystemExit(f'expected {expected} cost rows, got {len(rows)}')
if any(r[3] <= 0 for r in rows):
    raise SystemExit('accepted F-VQ15 column reports no accepted substeps')

print('FPE03_FVQ15_BASELINE_VECTOR='+','.join(map(str,baseline)))
for order,n,idx,sub,c,higher in rows:
    print(f'FPE03_FVQ15_CASE={order}:n={n}:index={idx}:substeps={sub}:cost='+','.join(map(str,c))+f':higher={str(higher).upper()}')
higher=[r for r in rows if r[5]]
print(f'FPE03_FVQ15_ACCEPTED_COLUMN_OBSERVATIONS={len(rows)}')
print(f'FPE03_FVQ15_HIGHER_COST_COLUMN_OBSERVATIONS={len(higher)}')
if higher:
    unique=[]
    for r in higher:
      if r[4] not in unique: unique.append(r[4])
    print('FPE03_B04_FVQ15_SCREEN=POSITIVE_ACCEPTED_HIGHER_COST_CANDIDATE')
    print('FPE03_B04_FVQ15_HIGHER_VECTORS='+';'.join(','.join(map(str,c)) for c in unique))
else:
    print('FPE03_B04_FVQ15_SCREEN=NEGATIVE_ALL_ADMITTED_COLUMNS_AT_OR_BELOW_BASELINE')
PY

echo 'FPE03_FVQ15_PHYSICS_CHANGED=NO'
echo 'FPE03_FVQ15_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FPE03_FVQ15_ACCEPTANCE_CHANGED=NO'
echo 'FPE03_FVQ15_RETRY_POLICY_CHANGED=NO'
echo 'FPE03_FVQ15_MASS_REQUIREMENT_RELAXED=NO'
echo 'FPE03_FVQ15_TRANSACTION_SEMANTICS_CHANGED=NO'
echo 'FPE03_FVQ15_MULTICOLUMN_COST_SCREEN PASS'

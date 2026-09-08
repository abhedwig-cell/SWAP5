#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-admitted-screen-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ25=652783f7cb87ed876a17452e7a6d98b54b4b50c8
KERNEL_BLOB=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_BLOB=7a60f8b8d18672098fed1c6890a95aac738ed21d
HEADCALC_BLOB=1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
LINEAR_SOLVER_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
SNOW_TEST_BLOB=4f45bb0623fef3fb6d091579e8f435563c858a69
ROOT_TEST_BLOB=38251f62c3a9617230171b69d29a233ce8165ce1

# F-PE screening must be observer/test-only on the exact F-VQ25 production postimage.
git diff --quiet "$FVQ25" -- src || {
  echo 'FPE03_ADMITTED_SCREEN_PRODUCTION_SOURCE_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FVQ25" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_BLOB" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_BLOB" ]]
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$HEADCALC_BLOB" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == "$LINEAR_SOLVER_BLOB" ]]
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr06_snow_smoke.f90)" == "$SNOW_TEST_BLOB" ]]
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr09_root_sink_runtime.f90)" == "$ROOT_TEST_BLOB" ]]
python3 - <<'PY'
import json
from pathlib import Path
v25=json.loads(Path('integration/f-vq/F-VQ25_STATUS.json').read_text())
v17=json.loads(Path('integration/f-vq/F-VQ17_STATUS.json').read_text())
v21=json.loads(Path('integration/f-vq/F-VQ21_STATUS.json').read_text())
assert v25['status']=='QUALIFIED_INDEPENDENT_FMR14_INTERVAL_DIAGNOSTICS_SCIENTIFIC_NO_CHANGE_ADMISSION'
assert v25['state']['qualified'] is True
assert v25['physics_changed'] is False and v25['acceptance_changed'] is False and v25['mass_requirement_relaxed'] is False
assert v17['decision']=='QUALIFIED_FMR06_SERIALIZED_ONE_CALL_DAILY_SNOW_MULTISWAP_SCIENTIFIC_ADMISSION'
assert v17['QUALIFIED'] is True and v17['scientific_admission'] is True
assert v21['status']=='QUALIFIED_INDEPENDENT_FMR09_PRECOMPUTED_ROOT_SINK_RUNTIME_SCIENTIFIC_ADMISSION'
assert v21['state']['qualified'] is True
print('FPE03_ADMITTED_SCREEN_OWNER_LOCKS=PASS')
PY
echo 'FPE03_ADMITTED_SCREEN_PRODUCTION_SOURCE_IMMUTABILITY=PASS'
echo 'FPE03_ADMITTED_SCREEN_FIXTURE_BLOBS=PASS'

# Generate observer-only temporary copies. No workload values, policies or physics are changed.
python3 - "$BUILD" <<'PY'
from pathlib import Path
import sys
b=Path(sys.argv[1])

snow=Path('tests/fmr/test_fmr06_snow_smoke.f90').read_text()
anchor="""  call require(committed_fingerprint(committed) == committed_before, 'trial did not mutate committed state')\n\n  observation = backend%observation()\n"""
insert="""  call require(committed_fingerprint(committed) == committed_before, 'trial did not mutate committed state')\n  write(*,'(A,1X,I0)') 'FPE03_SCREEN_SNOW_ACCEPTED_SUBSTEPS=', diagnostics%accepted_substeps\n  write(*,'(A,7(1X,I0))') 'FPE03_SCREEN_SNOW_COST=', diagnostics%nonlinear_iterations, &\n       diagnostics%internal_retries, diagnostics%headcalc_calls, diagnostics%jacobian_builds, &\n       diagnostics%linear_solves, diagnostics%backtracking_attempts, diagnostics%alternative_solver_calls\n  write(*,'(A,1X,L1,1X,L1,1X,L1,1X,ES24.16)') 'FPE03_SCREEN_SNOW_ACCEPTANCE=', result%completed, candidate%ready(), &\n       result%mass%complete, result%mass%residual\n\n  observation = backend%observation()\n"""
assert snow.count(anchor)==1, 'snow observer anchor drift'
(b/'snow_screen.f90').write_text(snow.replace(anchor,insert,1))

root=Path('tests/fmr/test_fmr09_root_sink_runtime.f90').read_text()
anchor="""  write(*,'(A,1X,ES24.16,1X,ES24.16)') 'FMR09_BALANCED_MASS=', result_balanced(1)%mass%residual, &\n       result_balanced(1)%mass%total_out\n\n"""
insert=anchor+"""  write(*,'(A,1X,I0)') 'FPE03_SCREEN_ROOT_CONTROL_ACCEPTED_SUBSTEPS=', result_control(1)%accepted_substeps\n  write(*,'(A,7(1X,I0))') 'FPE03_SCREEN_ROOT_CONTROL_COST=', result_control(1)%solver_nonlinear_iterations, &\n       result_control(1)%solver_internal_retries, result_control(1)%solver_headcalc_calls, &\n       result_control(1)%solver_jacobian_builds, result_control(1)%solver_linear_solves, &\n       result_control(1)%solver_backtracking_attempts, result_control(1)%solver_alternative_solver_calls\n  write(*,'(A,1X,L1,1X,L1,1X,L1,1X,ES24.16)') 'FPE03_SCREEN_ROOT_CONTROL_ACCEPTANCE=', &\n       result_control(1)%completed, result_control(1)%committed, result_control(1)%mass%complete, result_control(1)%mass%residual\n  write(*,'(A,1X,I0)') 'FPE03_SCREEN_ROOT_BALANCED_ACCEPTED_SUBSTEPS=', result_balanced(1)%accepted_substeps\n  write(*,'(A,7(1X,I0))') 'FPE03_SCREEN_ROOT_BALANCED_COST=', result_balanced(1)%solver_nonlinear_iterations, &\n       result_balanced(1)%solver_internal_retries, result_balanced(1)%solver_headcalc_calls, &\n       result_balanced(1)%solver_jacobian_builds, result_balanced(1)%solver_linear_solves, &\n       result_balanced(1)%solver_backtracking_attempts, result_balanced(1)%solver_alternative_solver_calls\n  write(*,'(A,1X,L1,1X,L1,1X,L1,1X,ES24.16)') 'FPE03_SCREEN_ROOT_BALANCED_ACCEPTANCE=', &\n       result_balanced(1)%completed, result_balanced(1)%committed, result_balanced(1)%mass%complete, result_balanced(1)%mass%residual\n\n"""
assert root.count(anchor)==1, 'root observer anchor drift'
(b/'root_screen.f90').write_text(root.replace(anchor,insert,1))
print('FPE03_ADMITTED_SCREEN_OBSERVER_TRANSFORM=PASS')
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
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/snow_screen.f90" -o "$OUT/snow.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/snow.o" -o "$OUT/snow"
  "$OUT/snow" > "$OUT/snow.txt" 2>&1 || { cat "$OUT/snow.txt" >&2; exit 1; }
  grep -Fq 'FMR06_SNOW_SMOKE_TEST PASS' "$OUT/snow.txt"
  grep -Fq 'FPE03_SCREEN_SNOW_COST=' "$OUT/snow.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/root_screen.f90" -o "$OUT/root.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/root.o" -o "$OUT/root"
  "$OUT/root" > "$OUT/root.txt" 2>&1 || { cat "$OUT/root.txt" >&2; exit 1; }
  grep -Fq 'FMR09_ROOT_SINK_RUNTIME_TEST PASS' "$OUT/root.txt"
  grep -Fq 'FPE03_SCREEN_ROOT_CONTROL_COST=' "$OUT/root.txt"
  grep -Fq 'FPE03_SCREEN_ROOT_BALANCED_COST=' "$OUT/root.txt"
  echo "FPE03_ADMITTED_SCREEN_O${opt}=PASS"
done

cmp "$BUILD/o0/snow.txt" "$BUILD/o2/snow.txt"
cmp "$BUILD/o0/root.txt" "$BUILD/o2/root.txt"
echo 'FPE03_ADMITTED_SCREEN_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/snow.txt" "$BUILD/o0/root.txt" <<'PY'
from pathlib import Path
import sys
baseline=(3,0,3,3,3,3,0)
records=[]

def kv(path):
    out={}
    for line in Path(path).read_text().splitlines():
        if '=' in line:
            k,v=line.split('=',1); out[k.strip()]=v.strip()
    return out
s=kv(sys.argv[1]); r=kv(sys.argv[2])

def cost(d,key): return tuple(int(x) for x in d[key].split())
def accept(d,key):
    parts=d[key].split(); return parts[0]=='T' and parts[1]=='T' and parts[2]=='T' and abs(float(parts[3].replace('D','E'))) <= 1.0e-12

def add(name,d,costkey,acceptkey,subkey):
    c=cost(d,costkey); sub=int(d[subkey]); a=accept(d,acceptkey) and sub>0
    records.append((name,a,sub,c,any(x>b for x,b in zip(c,baseline))))

add('fvq17_snow',s,'FPE03_SCREEN_SNOW_COST','FPE03_SCREEN_SNOW_ACCEPTANCE','FPE03_SCREEN_SNOW_ACCEPTED_SUBSTEPS')
add('fvq21_root_control',r,'FPE03_SCREEN_ROOT_CONTROL_COST','FPE03_SCREEN_ROOT_CONTROL_ACCEPTANCE','FPE03_SCREEN_ROOT_CONTROL_ACCEPTED_SUBSTEPS')
add('fvq21_root_balanced',r,'FPE03_SCREEN_ROOT_BALANCED_COST','FPE03_SCREEN_ROOT_BALANCED_ACCEPTANCE','FPE03_SCREEN_ROOT_BALANCED_ACCEPTED_SUBSTEPS')

print('FPE03_ADMITTED_SCREEN_BASELINE_VECTOR='+','.join(map(str,baseline)))
for name,a,sub,c,h in records:
    print(f'FPE03_ADMITTED_SCREEN_CASE={name}:accepted={str(a).upper()}:substeps={sub}:cost='+','.join(map(str,c))+f':higher={str(h).upper()}')
accepted=[x for x in records if x[1]]
higher=[x for x in accepted if x[4]]
if len(accepted)!=3:
    raise SystemExit('one or more scientifically admitted screening cases was not accepted')
print(f'FPE03_ADMITTED_SCREEN_ACCEPTED_COUNT={len(accepted)}')
print(f'FPE03_ADMITTED_SCREEN_ACCEPTED_HIGHER_COST_COUNT={len(higher)}')
if higher:
    print('FPE03_B04_RUNTIME_SCREEN_CANDIDATE=POSITIVE_ACCEPTED_HIGHER_COST_CASE_FOUND')
    print('FPE03_B04_RUNTIME_SCREEN_HIGHER_CASES='+';'.join(x[0]+':'+','.join(map(str,x[3])) for x in higher))
else:
    print('FPE03_B04_RUNTIME_SCREEN_CANDIDATE=NEGATIVE_NO_HIGHER_COST_CASE_IN_TRANCHE_1')
print('FPE03_ADMITTED_RUNTIME_SCREEN PASS')
PY

# Original scientific tests are immutable.
git diff --exit-code -- tests/fmr/test_fmr06_snow_smoke.f90 tests/fmr/test_fmr09_root_sink_runtime.f90
echo 'FPE03_ADMITTED_SCREEN_PHYSICS_CHANGED=NO'
echo 'FPE03_ADMITTED_SCREEN_NUMERICAL_CONTROLS_CHANGED=NO'
echo 'FPE03_ADMITTED_SCREEN_ACCEPTANCE_CHANGED=NO'
echo 'FPE03_ADMITTED_SCREEN_MASS_REQUIREMENT_RELAXED=NO'

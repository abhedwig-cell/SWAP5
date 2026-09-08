#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-fvq24-admitted-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ25=652783f7cb87ed876a17452e7a6d98b54b4b50c8
FMR14=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
FMR13=985058c0261d284424432a65bded16b7fc9107cb
FVQ24_CLOSEOUT=4a8c0740222da5934e1fae53000c1c19db733e27
FVQ24_STATUS_BLOB=15047078258dc038e542096c8f95630edc9bab78
FSI18_CLOSEOUT=8c5438a73e8ae4c9fcbd9de9fdd82d9a600626b2
FSI18_PROBE_BLOB=1a0898cfd927455d9219db0f59ac238943cd1435
OLD_FPE03=e67d624967f53184904e689333594015e9658683
OLD_FPE03_BLOB=6623613a3526c119bf1fada5540eed93346592e1
GENERATOR_BLOB=424f531a9efa318d6a68d82f2fdb5e5724b4f724
KERNEL_BLOB=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_BLOB=7a60f8b8d18672098fed1c6890a95aac738ed21d
LINEAR_SOLVER_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
HEADCALC_BLOB=1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
WORKSPACE_BLOB=178d3289e09583c256b1aa400407d468d9c18e68
SOLVER_CONTRACT_BLOB=0a57b07712f93538cbfaf9130838682307cede09

# The characterization branch may add tests/governance only. Production must
# remain the exact F-VQ25/F-MR14 observer-only postimage.
git diff --quiet "$FVQ25" -- src || {
  echo 'FPE03_FVQ24_PRODUCTION_SOURCE_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FVQ25" -- src >&2
  exit 1
}
for spec in \
  "src/kernel/mod_kernel_transactions.f90:$KERNEL_BLOB" \
  "src/runtime/mod_fmr_serialized_multiswap_runtime.f90:$RUNTIME_BLOB" \
  "src/solver/mod_reference_linear_solver.f90:$LINEAR_SOLVER_BLOB" \
  "src/legacy/b1_10_port/headcalc.f90:$HEADCALC_BLOB" \
  "src/solver/mod_reference_richards_workspace.f90:$WORKSPACE_BLOB" \
  "src/solver/mod_soil_water_solver_contract.f90:$SOLVER_CONTRACT_BLOB"; do
  path=${spec%%:*}; expected=${spec##*:}
  [[ "$(git rev-parse "HEAD:$path")" == "$expected" ]] || {
    echo "FPE03_FVQ24_SOURCE_BLOB_MISMATCH=$path" >&2; exit 1;
  }
done
echo 'FPE03_FVQ24_PRODUCTION_SOURCE_IMMUTABILITY=PASS'
echo 'FPE03_FVQ24_FVQ25_SOURCE_LOCKS=PASS'

# Independently pin the scientific owner record and its immutable originating probe.
[[ "$(git rev-parse "$FVQ24_CLOSEOUT:integration/f-vq/F-VQ24_STATUS.json")" == "$FVQ24_STATUS_BLOB" ]]
[[ "$(git rev-parse "$FSI18_CLOSEOUT:tests/fsi/test_fsi18_reference_convergence_cliff.F90")" == "$FSI18_PROBE_BLOB" ]]
git show "$FVQ24_CLOSEOUT:integration/f-vq/F-VQ24_STATUS.json" > "$BUILD/fvq24-status.json"
python3 - "$BUILD/fvq24-status.json" <<'PY'
import json, sys
s=json.load(open(sys.argv[1]))
assert s['status']=='QUALIFIED_INDEPENDENT_FMR12_FMR13_NONZERO_HEADCALC_SOLVER_SEAM_EQUIVALENCE'
assert s['scientific_admission'] is True
assert s['qualification']['nonzero_cases_2_to_5_converged_both_sides']=='PASS'
assert s['probe_stimulus']['head0']==-75.0
assert s['probe_stimulus']['step_duration']==1.0
assert s['probe_stimulus']['top_flux_relative_perturbations']==[0.0,3.0e-12,-3.0e-12,1.0e-11,-1.0e-11]
assert s['probe_stimulus']['bottom_mode']==7
assert s['probe_stimulus']['root_sink']=='ZERO'
assert s['probe_stimulus']['source_sink']=='NONZERO_NODEWISE_QDRA_WITH_MATCHING_QSSDI'
assert s['probe_stimulus']['macropore']=='INACTIVE'
assert s['release']['fmr13_nonzero_reference_workload_scientifically_admitted'] is True
assert s['release']['fpe_may_use_this_exact_nonzero_workload_for_reference_characterization'] is True
print('FPE03_FVQ24_SCIENTIFIC_OWNER_LOCK=PASS')
PY

# F-VQ25 independently admitted the observer-only F-MR14 postimage with no
# scientific change in the existing real-physics scope.
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-vq/F-VQ25_STATUS.json').read_text())
assert s['status']=='QUALIFIED_INDEPENDENT_FMR14_INTERVAL_DIAGNOSTICS_SCIENTIFIC_NO_CHANGE_ADMISSION'
assert s['state']['qualified'] is True
assert s['physics_changed'] is False
assert s['numerical_controls_changed'] is False
assert s['acceptance_changed'] is False
assert s['mass_requirement_relaxed'] is False
print('FPE03_FVQ24_FVQ25_OBSERVER_ONLY_LINEAGE_LOCK=PASS')
PY

# Pin the runtime harness base and the local mechanical transformer.
[[ "$(git rev-parse "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90")" == "$OLD_FPE03_BLOB" ]]
[[ "$(git rev-parse HEAD:tests/fpe/fpe03_make_fvq24_runtime_probe.py)" == "$GENERATOR_BLOB" ]]
git show "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90" > "$BUILD/base.f90"
python3 tests/fpe/fpe03_make_fvq24_runtime_probe.py "$BUILD/base.f90" "$BUILD/probe.f90" > "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_CASES=5' "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_SCIENTIFIC_STIMULUS_CHANGED=NO' "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_TRANSACTION_POLICY_CHANGED=NO' "$BUILD/generator.log"
echo 'FPE03_FVQ24_EXACT_ADMITTED_STIMULUS_MAPPED_TO_RUNTIME=PASS'

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
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/probe.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  "$OUT/probe" > "$OUT/run-a.txt" 2>&1 || { cat "$OUT/run-a.txt" >&2; exit 1; }
  "$OUT/probe" > "$OUT/run-b.txt" 2>&1 || { cat "$OUT/run-b.txt" >&2; exit 1; }
  cmp "$OUT/run-a.txt" "$OUT/run-b.txt"
  grep -Fq 'FPE03_FVQ24_STIMULUS_SOURCE=SCIENTIFICALLY_ADMITTED_FVQ24' "$OUT/run-a.txt"
  grep -Fq 'FPE03_FVQ24_RUNTIME_PROBE PASS' "$OUT/run-a.txt"
  echo "FPE03_FVQ24_RUNTIME_REPLAY_O${opt}=PASS"
done
cmp "$BUILD/o0/run-a.txt" "$BUILD/o2/run-a.txt"
echo 'FPE03_FVQ24_RUNTIME_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/run-a.txt" <<'PY'
import sys
from pathlib import Path
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()

def iv(p,n): return int(vals[p+n])
def bv(p,n): return vals[p+n]=='T'
def fv(p,n): return float(vals[p+n].replace('D','E'))
def vector(p):
    return (iv(p,'NONLINEAR_ITERATIONS'),iv(p,'INTERNAL_RETRIES'),iv(p,'HEADCALC_CALLS'),
            iv(p,'JACOBIAN_BUILDS'),iv(p,'LINEAR_SOLVES'),iv(p,'BACKTRACKING_ATTEMPTS'),
            iv(p,'ALTERNATIVE_SOLVER_CALLS'))

names=['baseline','plus_3e-12','minus_3e-12','plus_1e-11','minus_1e-11']
rows=[]
for i,name in enumerate(names,1):
    p=f'FPE03_CASE_{i:02d}_'
    row={
      'case':i,'name':name,'accepted':bv(p,'ACCEPTED'),'status':iv(p,'KERNEL_STATUS'),
      'substeps':iv(p,'ACCEPTED_SUBSTEPS'),'mass':abs(fv(p,'MASS_RESIDUAL')),'cost':vector(p)
    }
    if row['accepted']:
        assert row['status']==0, row
        assert row['substeps']>=1, row
        assert row['mass']<=1e-12, row
    else:
        assert row['substeps']==0, row
    rows.append(row)

base=rows[0]
assert base['accepted'], base
higher=[r for r in rows[1:] if r['accepted'] and r['cost']!=base['cost'] and any(a>b for a,b in zip(r['cost'],base['cost']))]
accepted_nonzero=[r for r in rows[1:] if r['accepted']]
rejected_nonzero=[r for r in rows[1:] if not r['accepted']]

def fmt(r):
    return f"case={r['case']}:{r['name']}:accepted={str(r['accepted']).upper()}:status={r['status']}:substeps={r['substeps']}:cost="+','.join(map(str,r['cost']))

print('FPE03_FVQ24_BASELINE_AGGREGATE_COST_VECTOR='+','.join(map(str,base['cost'])))
print('FPE03_FVQ24_ACCEPTED_NONZERO_COUNT='+str(len(accepted_nonzero)))
print('FPE03_FVQ24_REJECTED_NONZERO_COUNT='+str(len(rejected_nonzero)))
print('FPE03_FVQ24_ACCEPTED_HIGHER_COST_COUNT='+str(len(higher)))
print('FPE03_FVQ24_CASES='+';'.join(fmt(r) for r in rows))
print('FPE03_FVQ24_ACCEPTED_HIGHER_COST_CASES='+';'.join(fmt(r) for r in higher))
if higher:
    print('FPE03_FVQ24_B04=RESOLVED_EXACT_SCIENTIFICALLY_ADMITTED_ACCEPTED_HIGHER_COST_REFERENCE_WORKLOAD_OBSERVED')
elif accepted_nonzero:
    print('FPE03_FVQ24_B04=OPEN_ADMITTED_NONZERO_ACCEPTED_BUT_NO_HIGHER_AGGREGATE_COST_OBSERVED')
else:
    print('FPE03_FVQ24_B04=OPEN_FVQ24_SOLVER_ADMITTED_NONZERO_WORKLOAD_REJECTED_BY_PRODUCTION_TRANSACTION_PATH')
print('FPE03_FVQ24_REPRESENTATIVE_TAIL_DISTRIBUTION=NOT_ESTABLISHED')
print('FPE03_FVQ24_BOUNDED_COST_THRESHOLD=NOT_ESTABLISHED')
print('FPE03_FVQ24_FPE02_B01=OPEN')
print('FPE03_FVQ24_EXECUTION_CLASS_ADMISSION=REFERENCE_ONLY')
PY

echo 'FPE03_FVQ24_HARD_MASS_GATE_FOR_ACCEPTED_CASES=PASS'
echo 'FPE03_FVQ24_REJECTED_CASES_NO_COMMIT_ASSERTED_BY_BASE_HARNESS=PASS'
echo 'FPE03_FVQ24_ADMITTED_TAIL_CHARACTERIZATION_GATE PASS'

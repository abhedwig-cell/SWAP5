#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr16-temporal-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
FVQ24=4a8c0740222da5934e1fae53000c1c19db733e27
OLD_FPE03=e67d624967f53184904e689333594015e9658683
OLD_FPE03_BLOB=6623613a3526c119bf1fada5540eed93346592e1
FVQ24_GENERATOR_BRANCH=work/f-pe03-fvq24-admitted-tail-characterization
FVQ24_GENERATOR_BLOB=e08f3224afef41b16b52fd966b0f72544f266e26
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08

fail() { echo "FMR16_TEMPORAL_CHARACTERIZATION_FAIL $*" >&2; exit 1; }

# Readiness characterization must not modify production source.
git diff --quiet "$FVQ27" -- src || {
  echo 'FMR16_PRODUCTION_IMMUTABILITY_TO_FVQ27=FAIL' >&2
  git diff --name-only "$FVQ27" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'backend blob drift'
echo 'FMR16_PRODUCTION_IMMUTABILITY_TO_FVQ27=PASS'
echo 'FMR16_BINARY_TEMPORAL_BACKEND_SOURCE_LOCK=PASS'

# Lock the scientific owner and exact F-VQ24 stimulus release.
git show "$FVQ24:integration/f-vq/F-VQ24_STATUS.json" > "$BUILD/fvq24-status.json"
python3 - "$BUILD/fvq24-status.json" <<'PY'
import json,sys
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
assert s['release']['fpe_may_use_this_exact_nonzero_workload_for_reference_characterization'] is True
print('FMR16_FVQ24_SCIENTIFIC_STIMULUS_LOCK=PASS')
PY

# Recreate the exact existing F-VQ24 runtime probe from its locked historical source.
[[ "$(git rev-parse "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90")" == "$OLD_FPE03_BLOB" ]]
[[ "$(git rev-parse "$FVQ24_GENERATOR_BRANCH:tests/fpe/fpe03_make_fvq24_runtime_probe.py")" == "$FVQ24_GENERATOR_BLOB" ]]
git show "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90" > "$BUILD/base.f90"
git show "$FVQ24_GENERATOR_BRANCH:tests/fpe/fpe03_make_fvq24_runtime_probe.py" > "$BUILD/make_probe.py"
python3 "$BUILD/make_probe.py" "$BUILD/base.f90" "$BUILD/probe.f90" > "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_CASES=5' "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_SCIENTIFIC_STIMULUS_CHANGED=NO' "$BUILD/generator.log"
grep -Fq 'FPE03_FVQ24_TRANSACTION_POLICY_CHANGED=NO' "$BUILD/generator.log"
echo 'FMR16_FVQ24_EXACT_RUNTIME_PROBE_RECREATED=PASS'

# Build-only observer copy of the exact production backend. The function keeps
# the current binary 0/huge return behavior; it only emits componentwise deltas.
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='''  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)\n    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n'''
new='''  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)\n    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: same\n    real(real64) :: dhead, dtheta, dpond, dgwl, rhead, rtheta, hscale, tscale\n'''
assert s.count(old)==1
s=s.replace(old,new,1)
old2='''          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)\n'''
new2='''          if (same) then\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            dtheta = maxval(abs(full%water_content-half%water_content))\n            dpond = abs(full%ponding_depth-half%ponding_depth)\n            dgwl = abs(full%groundwater_level-half%groundwater_level)\n            hscale = max(tiny(1.0_real64), maxval(abs(full%pressure_head)), maxval(abs(half%pressure_head)))\n            tscale = max(tiny(1.0_real64), maxval(abs(full%water_content)), maxval(abs(half%water_content)))\n            rhead = dhead/hscale\n            rtheta = dtheta/tscale\n            write(*,'(A,6(1X,ES26.17E3))') 'FMR16_TEMPORAL_COMPONENT_DELTA', dhead, dtheta, dpond, dgwl, rhead, rtheta\n          end if\n          if (same) same = all(full%pressure_head == half%pressure_head) .and. &\n                           all(full%water_content == half%water_content) .and. &\n                           full%ponding_depth == half%ponding_depth .and. &\n                           full%groundwater_level == half%groundwater_level\n          if (same) same = allocated(full%snow) .eqv. allocated(half%snow)\n'''
assert s.count(old2)==1
s=s.replace(old2,new2,1)
p.write_text(s)
print('FMR16_TEMPORAL_OBSERVER_COPY_GENERATED=PASS')
PY

# Prove the observer copy normalizes exactly to the production backend when the
# declarations and write-only block are removed.
python3 - "$BUILD/mod_fmr_serialized_reference_backend_probe.f90" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text()
prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
probe=probe.replace('    real(real64) :: dhead, dtheta, dpond, dgwl, rhead, rtheta, hscale, tscale\n','',1)
block='''          if (same) then\n            dhead = maxval(abs(full%pressure_head-half%pressure_head))\n            dtheta = maxval(abs(full%water_content-half%water_content))\n            dpond = abs(full%ponding_depth-half%ponding_depth)\n            dgwl = abs(full%groundwater_level-half%groundwater_level)\n            hscale = max(tiny(1.0_real64), maxval(abs(full%pressure_head)), maxval(abs(half%pressure_head)))\n            tscale = max(tiny(1.0_real64), maxval(abs(full%water_content)), maxval(abs(half%water_content)))\n            rhead = dhead/hscale\n            rtheta = dtheta/tscale\n            write(*,'(A,6(1X,ES26.17E3))') 'FMR16_TEMPORAL_COMPONENT_DELTA', dhead, dtheta, dpond, dgwl, rhead, rtheta\n          end if\n'''
assert probe.count(block)==1
probe=probe.replace(block,'',1)
assert probe==prod
print('FMR16_OBSERVER_COPY_NORMALIZES_BITWISE_TO_PRODUCTION=PASS')
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
  "$BUILD/mod_fmr_serialized_reference_backend_probe.f90"
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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/probe.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  timeout 120s "$OUT/probe" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FPE03_FVQ24_RUNTIME_PROBE PASS' "$OUT/output.txt"
  grep -Fq 'FMR16_TEMPORAL_COMPONENT_DELTA' "$OUT/output.txt"
  echo "FMR16_TEMPORAL_CHARACTERIZATION_O${opt}=PASS"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FMR16_TEMPORAL_CHARACTERIZATION_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/output.txt" <<'PY'
from pathlib import Path
import sys, math
lines=Path(sys.argv[1]).read_text().splitlines()
pending=[]; cases=[]
for line in lines:
    if line.startswith('FMR16_TEMPORAL_COMPONENT_DELTA'):
        v=tuple(float(x.replace('D','E')) for x in line.split()[1:])
        if len(v)!=6: raise SystemExit('bad delta row')
        pending.append(v)
    elif line.startswith('FPE03_CASE_') and '_NAME=' in line:
        case=int(line[len('FPE03_CASE_'):len('FPE03_CASE_')+2])
        name=line.split('=',1)[1].strip()
        cases.append({'case':case,'name':name,'deltas':pending}); pending=[]
if pending: raise SystemExit('unassigned temporal rows')
if len(cases)!=5: raise SystemExit(f'expected 5 cases, got {len(cases)}')
expected_attempts={1:1,2:3,3:3,4:3,5:3}
print('FMR16_TEMPORAL_DELTA_FIELD_ORDER=max_abs_head,max_abs_theta,abs_ponding,abs_groundwater,relative_head,relative_theta')
for c in cases:
    if len(c['deltas'])!=expected_attempts[c['case']]:
        raise SystemExit(f"case {c['case']} expected {expected_attempts[c['case']]} temporal rows got {len(c['deltas'])}")
    for j,v in enumerate(c['deltas']):
        dt=1.0*(0.5**j)
        print(f"FMR16_CASE={c['case']}:{c['name']}:attempt={j+1}:dt={dt:.17g}:delta="+','.join(f'{x:.17e}' for x in v))
    if c['case']>1:
        for k,label in [(0,'head'),(1,'theta')]:
            vals=[r[k] for r in c['deltas']]
            ratios=[vals[i+1]/vals[i] if vals[i] else 0.0 for i in range(len(vals)-1)]
            monotone=all(vals[i+1] < vals[i] for i in range(len(vals)-1))
            print(f"FMR16_CASE={c['case']}:{label}:STRICTLY_DECREASES_WITH_DT_HALVING={str(monotone).upper()}:ratios="+','.join(f'{r:.9e}' for r in ratios))
            if not monotone: raise SystemExit(f"case {c['case']} {label} delta not monotone")
# Baseline should retain exact identity and all observed nonzero cases must expose finite graded deltas.
if any(x!=0.0 for x in cases[0]['deltas'][0]): raise SystemExit('baseline not exact zero')
for c in cases[1:]:
    if not all(all(math.isfinite(x) for x in row) for row in c['deltas']): raise SystemExit('nonfinite delta')
    if not any(row[0]>0.0 or row[1]>0.0 for row in c['deltas']): raise SystemExit('nonzero case has no state delta')
print('FMR16_BASELINE_EXACT_TEMPORAL_IDENTITY=PASS')
print('FMR16_NONZERO_RICHARDS_FINITE_GRADED_STATE_DELTAS=PASS')
print('FMR16_DT_HALVING_CONVERGENCE_SIGNAL=PASS')
PY

echo 'FMR16_PRODUCTION_ACCEPTANCE_CHANGED=NO'
echo 'FMR16_MASS_REQUIREMENT_CHANGED=NO'
echo 'FMR16_RETRY_POLICY_CHANGED=NO'
echo 'FMR16_TEMPORAL_METRIC_NOT_YET_SELECTED=PASS'
echo 'FMR16_FVQ24_TEMPORAL_DELTA_CHARACTERIZATION PASS'

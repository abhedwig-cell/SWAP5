#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-fvq25-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR14=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
FVQ25=652783f7cb87ed876a17452e7a6d98b54b4b50c8
OLD_FPE03=e67d624967f53184904e689333594015e9658683
OLD_TEST_BLOB=6623613a3526c119bf1fada5540eed93346592e1
HISTORICAL_FPE03=c9aa2219ddf69555b0cae77c89628fe355d0a4eb
NONSTATIONARY_GENERATOR_BLOB=e514ed55cb3228129a0b9d20b5eb8af2b5627359
REFINEMENT_GENERATOR_BLOB=c34afff46c3774f2eb872f57f784d834d231bb14
FMR06_BLOB=ed4b742b76e97ff0ad27b386850c1d093e4f03d1
KERNEL_BLOB=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_BLOB=7a60f8b8d18672098fed1c6890a95aac738ed21d
LINEAR_SOLVER_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
HEADCALC_BLOB=1ab0a7dec7a1ca785c01540ebe1c6f3342a1773b
WORKSPACE_BLOB=178d3289e09583c256b1aa400407d468d9c18e68

# Characterization must not modify the independently admitted F-MR14 source.
git diff --quiet "$FMR14" -- src || {
  echo 'FPE03_FVQ25_PRODUCTION_SOURCE_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FMR14" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_BLOB" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_BLOB" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_reference_linear_solver.f90)" == "$LINEAR_SOLVER_BLOB" ]]
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == "$HEADCALC_BLOB" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_reference_richards_workspace.f90)" == "$WORKSPACE_BLOB" ]]
[[ "$(git rev-parse HEAD:tests/fmr/test_fmr06_snow_multiswap.f90)" == "$FMR06_BLOB" ]]
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-vq/F-VQ25_STATUS.json').read_text())
assert s['status']=='QUALIFIED_INDEPENDENT_FMR14_INTERVAL_DIAGNOSTICS_SCIENTIFIC_NO_CHANGE_ADMISSION'
assert s['state']['qualified'] is True
assert s['fpe03_b03']=='CLEARED_FOR_RECHARACTERIZATION_RESUME'
assert s['fpe02_b01']=='BLOCKED_SHARED_SEMANTICS_REQUIRES_FMR_FVQ_REQUALIFICATION'
assert s['perturbed_workload_scientifically_admitted'] is False
print('FPE03_FVQ25_ADMITTED_DIAGNOSTICS_LINEAGE_LOCK=PASS')
PY
echo 'FPE03_FVQ25_PRODUCTION_SOURCE_IMMUTABILITY=PASS'
echo 'FPE03_FVQ25_SOURCE_LOCKS=PASS'

# Reproduce the exact historical diagnostic workload and generators.
[[ "$(git rev-parse "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90")" == "$OLD_TEST_BLOB" ]]
[[ "$(git rev-parse "$HISTORICAL_FPE03:tests/fpe/fpe03_make_nonstationary_snow_overlay.py")" == "$NONSTATIONARY_GENERATOR_BLOB" ]]
[[ "$(git rev-parse "$HISTORICAL_FPE03:tests/fpe/fpe03_make_flux_refinement_probe.py")" == "$REFINEMENT_GENERATOR_BLOB" ]]
git show "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90" > "$BUILD/old-fpe03.f90"
git show "$HISTORICAL_FPE03:tests/fpe/fpe03_make_nonstationary_snow_overlay.py" > "$BUILD/make-nonstationary.py"
git show "$HISTORICAL_FPE03:tests/fpe/fpe03_make_flux_refinement_probe.py" > "$BUILD/make-refinement.py"
python3 "$BUILD/make-nonstationary.py" "$BUILD/old-fpe03.f90" tests/fmr/test_fmr06_snow_multiswap.f90 "$BUILD/base-overlay.f90" > "$BUILD/base-generation.txt"
python3 "$BUILD/make-refinement.py" "$BUILD/base-overlay.f90" "$BUILD/refinement.f90" > "$BUILD/refinement-generation.txt"
grep -Fq 'FPE03_FMR06_ACTIVE_SNOW_SOURCE_ANCHORS=PASS' "$BUILD/base-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_CASES=11' "$BUILD/refinement-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_NONZERO_PERTURBATIONS=10' "$BUILD/refinement-generation.txt"
grep -Fq 'FPE03_FLUX_REFINEMENT_SCIENTIFIC_ADMISSION_EXPANDED=NO' "$BUILD/refinement-generation.txt"
echo 'FPE03_FVQ25_HISTORICAL_WORKLOAD_REPRODUCED_EXACTLY=PASS'

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/refinement.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  "$OUT/probe" > "$OUT/probe-a.txt" 2>&1 || { cat "$OUT/probe-a.txt" >&2; exit 1; }
  "$OUT/probe" > "$OUT/probe-b.txt" 2>&1 || { cat "$OUT/probe-b.txt" >&2; exit 1; }
  cmp "$OUT/probe-a.txt" "$OUT/probe-b.txt"
  grep -Fq 'FPE03_NONSTATIONARY_BASELINE_FPE05_COST_IDENTITY=PASS' "$OUT/probe-a.txt"
  grep -Fq 'FPE03_FLUX_REFINEMENT_PERTURBATIONS=DIAGNOSTIC_NOT_SCIENTIFIC_ADMISSION' "$OUT/probe-a.txt"
  grep -Fq 'FPE03_FLUX_REFINEMENT_PROBE PASS' "$OUT/probe-a.txt"
  echo "FPE03_FVQ25_REPLAY_O${opt}=PASS"
done
cmp "$BUILD/o0/probe-a.txt" "$BUILD/o2/probe-a.txt"
echo 'FPE03_FVQ25_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/probe-a.txt" <<'PY'
import math, sys
from pathlib import Path
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()

def iv(p,name): return int(vals[p+name])
def bv(p,name): return vals[p+name]=='T'
def fv(p,name): return float(vals[p+name].replace('D','E'))
def vector(p):
    return (
        iv(p,'NONLINEAR_ITERATIONS'), iv(p,'INTERNAL_RETRIES'), iv(p,'HEADCALC_CALLS'),
        iv(p,'JACOBIAN_BUILDS'), iv(p,'LINEAR_SOLVES'), iv(p,'BACKTRACKING_ATTEMPTS'),
        iv(p,'ALTERNATIVE_SOLVER_CALLS'))

basep='FPE03_CASE_01_'
assert bv(basep,'ACCEPTED') and bv(basep,'COMMITTED')
assert iv(basep,'KERNEL_STATUS')==0
assert iv(basep,'ACCEPTED_SUBSTEPS')==1
assert abs(fv(basep,'MASS_RESIDUAL')) <= 1e-12
baseline=vector(basep)
assert baseline==(3,0,3,3,3,3,0), baseline

levels=[1e-10,3e-11,1e-11,3e-12,1e-12]
accepted=[]; rejected=[]; higher=[]
for j,level in enumerate(levels):
    for offset,sign in ((0,'plus'),(1,'minus')):
        i=2+2*j+offset; p=f'FPE03_CASE_{i:02d}_'
        acc=bv(p,'ACCEPTED'); committed=bv(p,'COMMITTED'); vec=vector(p)
        residual=abs(fv(p,'MASS_RESIDUAL'))
        row={'case':i,'sign':sign,'level':level,'vector':vec,'kernel_status':iv(p,'KERNEL_STATUS'),
             'accepted_substeps':iv(p,'ACCEPTED_SUBSTEPS'),'mass_residual':residual}
        if acc:
            assert committed, row
            assert row['kernel_status']==0, row
            assert residual <= 1e-12, row
            assert row['accepted_substeps'] >= 1, row
            accepted.append(row)
            if vec != baseline: higher.append(row)
        else:
            assert not committed, row
            assert row['accepted_substeps']==0, row
            rejected.append(row)

def fmt(r):
    return (f"case={r['case']}:{r['sign']}:{r['level']:.0e}:status={r['kernel_status']}:"
            f"substeps={r['accepted_substeps']}:cost="+','.join(map(str,r['vector'])))
print('FPE03_FVQ25_BASELINE_AGGREGATE_COST_VECTOR='+','.join(map(str,baseline)))
print(f'FPE03_FVQ25_ACCEPTED_NONZERO_COUNT={len(accepted)}')
print(f'FPE03_FVQ25_REJECTED_NONZERO_COUNT={len(rejected)}')
print(f'FPE03_FVQ25_ACCEPTED_HIGHER_COST_COUNT={len(higher)}')
print('FPE03_FVQ25_ACCEPTED_CASES='+';'.join(fmt(r) for r in accepted))
print('FPE03_FVQ25_REJECTED_CASES='+';'.join(fmt(r) for r in rejected))
print('FPE03_FVQ25_ACCEPTED_HIGHER_COST_CASES='+';'.join(fmt(r) for r in higher))
if higher:
    print('FPE03_FVQ25_CLASSIFICATION=ACCEPTED_HIGHER_COST_REFERENCE_ROUTE_OBSERVED_DIAGNOSTIC_ONLY')
else:
    print('FPE03_FVQ25_CLASSIFICATION=NO_ACCEPTED_HIGHER_COST_REFERENCE_ROUTE_OBSERVED')
print('FPE03_FVQ25_PERTURBED_WORKLOAD_SCIENTIFIC_ADMISSION=NOT_GRANTED')
print('FPE03_FVQ25_REPRESENTATIVE_TAIL_DISTRIBUTION=NOT_ESTABLISHED')
print('FPE03_FVQ25_BOUNDED_COST_THRESHOLD=NOT_ESTABLISHED')
print('FPE03_FVQ25_FPE02_B01=OPEN')
print('FPE03_FVQ25_EXECUTION_CLASS_ADMISSION=REFERENCE_ONLY')
PY

echo 'FPE03_FVQ25_HARD_MASS_GATE_FOR_ACCEPTED_CASES=PASS'
echo 'FPE03_FVQ25_REJECTED_CASES_NO_COMMIT=PASS'
echo 'FPE03_FVQ25_REFERENCE_TAIL_RECHARACTERIZATION_GATE PASS'

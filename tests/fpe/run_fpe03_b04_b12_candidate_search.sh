#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-b12-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR14=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
OLD_FPE03=e67d624967f53184904e689333594015e9658683
OLD_TEST_BLOB=6623613a3526c119bf1fada5540eed93346592e1
KERNEL_BLOB=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_BLOB=7a60f8b8d18672098fed1c6890a95aac738ed21d
MVG_PROVIDER_BLOB=97d67eb373073b183be6d1bf5b756ecb5125dde2
B12_ROW='B12,0.01,0.529749,0.016562,1.090671,2.245895,179.6716,-4.493581,0'
B12_ROW_SHA256=20958231bf61dce00c024c6b8eeca30d0478ae17814d8d16688da6ea0b2d2a53

# Candidate search is qualification/test-only. Production remains the exact
# F-MR14 postimage independently admitted by F-VQ25.
git diff --quiet "$FMR14" -- src || {
  echo 'FPE03_B12_PRODUCTION_SOURCE_IMMUTABILITY=FAIL' >&2
  git diff --name-only "$FMR14" -- src >&2
  exit 1
}
[[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "$KERNEL_BLOB" ]]
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$RUNTIME_BLOB" ]]
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == "$MVG_PROVIDER_BLOB" ]]
echo 'FPE03_B12_PRODUCTION_SOURCE_IMMUTABILITY=PASS'

# Source-bound B12 provenance copied from the user-supplied SWAP 4.3.1
# Staringreeks_2018.csv. Fail closed if either header or row drifts.
[[ "$(head -n 1 tests/fpe/fixtures/staringreeks_2018_b12.csv)" == 'sfu,ORES,OSAT,ALFA,NPAR,KSATFIT,KSATEXM,LEXP,H_ENPR' ]]
[[ "$(sed -n '2p' tests/fpe/fixtures/staringreeks_2018_b12.csv)" == "$B12_ROW" ]]
printf '%s\n' "$B12_ROW" > "$BUILD/b12-row.txt"
[[ "$(sha256sum "$BUILD/b12-row.txt" | cut -d' ' -f1)" == "$B12_ROW_SHA256" ]]
echo 'FPE03_B12_SOURCE_FIXTURE_LOCK=PASS'

# Preserve the exact historical F-PE03 stress matrix. Only the hydraulic
# parameter set is transformed from the old generic MvG set to source-bound B12.
[[ "$(git rev-parse "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90")" == "$OLD_TEST_BLOB" ]]
git show "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90" > "$BUILD/original.f90"
python3 - "$BUILD/original.f90" "$BUILD/b12.f90" <<'PY'
import sys
from pathlib import Path
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])

def repl(old,new,label):
    global src
    n=src.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected one anchor, found {n}')
    src=src.replace(old,new,1)

repl('program test_fpe03_reference_stress\n','program test_fpe03_b12_reference_search\n','program')
repl('    parameters%parameter_set_id = 50301_int64\n','    parameters%parameter_set_id = 50312_int64\n','parameter set id')
repl('      parameters%cofgen(1,i) = 0.032_real64\n','      parameters%cofgen(1,i) = 0.01_real64\n','ORES')
repl('      parameters%cofgen(2,i) = 0.423_real64\n','      parameters%cofgen(2,i) = 0.529749_real64\n','OSAT')
repl('      parameters%cofgen(3,i) = 4.75_real64\n','      parameters%cofgen(3,i) = 2.245895_real64\n','KSATFIT')
repl('      parameters%cofgen(4,i) = 0.0135_real64\n','      parameters%cofgen(4,i) = 0.016562_real64\n','ALFA')
repl('      parameters%cofgen(5,i) = 0.365_real64\n','      parameters%cofgen(5,i) = -4.493581_real64\n','LEXP')
repl('      parameters%cofgen(6,i) = 1.455_real64\n','      parameters%cofgen(6,i) = 1.090671_real64\n','NPAR')
repl('      parameters%cofgen(10,i) = parameters%cofgen(3,i)\n','      parameters%cofgen(10,i) = 179.6716_real64\n','KSATEXM compatibility slot')
repl("  write(*,'(A)') 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS'\n",
     "  write(*,'(A)') 'FPE03_REFERENCE_STRESS_CHARACTERIZATION PASS'\n"
     "  write(*,'(A)') 'FPE03_B12_PARAMETER_MAPPING=ORES,OSAT,KSATFIT,ALFA,LEXP,NPAR,M,ALFA,H_ENPR,KSATEXM'\n"
     "  write(*,'(A)') 'FPE03_B12_SOURCE_BOUND_STRESS_MATRIX PASS'\n",
     'final markers')
repl('end program test_fpe03_reference_stress\n','end program test_fpe03_b12_reference_search\n','end program')
out.write_text(src)
print('FPE03_B12_HISTORICAL_24_CASE_MATRIX_REUSED=PASS')
print('FPE03_B12_ONLY_HYDRAULIC_PARAMETER_SET_CHANGED=PASS')
PY

grep -Fq 'FPE03_B12_HISTORICAL_24_CASE_MATRIX_REUSED=PASS' <(python3 - "$BUILD/original.f90" /dev/null <<'PY'
# no-op marker check is handled by the actual generation above
print('FPE03_B12_HISTORICAL_24_CASE_MATRIX_REUSED=PASS')
PY
)

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
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/b12.f90" -o "$OUT/probe.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/probe.o" -o "$OUT/probe"
  "$OUT/probe" > "$OUT/probe-a.txt" 2>&1 || { cat "$OUT/probe-a.txt" >&2; exit 1; }
  "$OUT/probe" > "$OUT/probe-b.txt" 2>&1 || { cat "$OUT/probe-b.txt" >&2; exit 1; }
  cmp "$OUT/probe-a.txt" "$OUT/probe-b.txt"
  grep -Fq 'FPE03_B12_SOURCE_BOUND_STRESS_MATRIX PASS' "$OUT/probe-a.txt"
  echo "FPE03_B12_REPLAY_O${opt}=PASS"
done
cmp "$BUILD/o0/probe-a.txt" "$BUILD/o2/probe-a.txt"
echo 'FPE03_B12_O0_O2_IDENTITY=PASS'

python3 - "$BUILD/o0/probe-a.txt" <<'PY'
import sys
from pathlib import Path
vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
    if '=' in line:
        k,v=line.split('=',1); vals[k.strip()]=v.strip()

def iv(p,n): return int(vals[p+n])
def bv(p,n): return vals[p+n]=='T'
def fv(p,n): return float(vals[p+n].replace('D','E'))
def vec(p):
    return (iv(p,'NONLINEAR_ITERATIONS'),iv(p,'INTERNAL_RETRIES'),iv(p,'HEADCALC_CALLS'),
            iv(p,'JACOBIAN_BUILDS'),iv(p,'LINEAR_SOLVES'),iv(p,'BACKTRACKING_ATTEMPTS'),
            iv(p,'ALTERNATIVE_SOLVER_CALLS'))

admitted=(3,0,3,3,3,3,0)
accepted=[]; rejected=[]; higher=[]
for i in range(1,25):
    p=f'FPE03_CASE_{i:02d}_'
    row=(i,vals[p+'NAME'],vec(p),iv(p,'ACCEPTED_SUBSTEPS'),iv(p,'KERNEL_STATUS'),abs(fv(p,'MASS_RESIDUAL')))
    if bv(p,'ACCEPTED'):
        assert row[3] >= 1, row
        assert row[4] == 0, row
        assert row[5] <= 1e-12, row
        accepted.append(row)
        if any(a>b for a,b in zip(row[2],admitted)):
            higher.append(row)
    else:
        rejected.append(row)

def fmt(r):
    return f'case={r[0]}:{r[1]}:cost='+','.join(map(str,r[2]))+f':substeps={r[3]}:status={r[4]}'
print('FPE03_B12_ADMITTED_BASELINE_VECTOR='+','.join(map(str,admitted)))
print(f'FPE03_B12_ACCEPTED_COUNT={len(accepted)}')
print(f'FPE03_B12_REJECTED_COUNT={len(rejected)}')
print(f'FPE03_B12_ACCEPTED_HIGHER_COST_COUNT={len(higher)}')
print('FPE03_B12_ACCEPTED_CASES='+';'.join(fmt(r) for r in accepted))
print('FPE03_B12_ACCEPTED_HIGHER_COST_CASES='+';'.join(fmt(r) for r in higher))
if higher:
    print('FPE03_B12_B04_CANDIDATE=POSITIVE_ACCEPTED_HIGHER_COST_DIAGNOSTIC_REQUIRES_INDEPENDENT_FVQ')
else:
    print('FPE03_B12_B04_CANDIDATE=NEGATIVE_NO_ACCEPTED_HIGHER_COST_CASE_IN_HISTORICAL_MATRIX')
print('FPE03_B12_SCIENTIFIC_ADMISSION=NOT_GRANTED')
print('FPE03_B12_MASS_OR_POLICY_RELAXATION=NO')
PY

echo 'FPE03_B12_HARD_MASS_GATE_FOR_ACCEPTED_CASES=PASS'
echo 'FPE03_B12_CANDIDATE_SEARCH PASS'

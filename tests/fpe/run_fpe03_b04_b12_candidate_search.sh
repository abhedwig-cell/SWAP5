#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe03-b12-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FMR14=3a531e2c7da54ba0d98b87d3b4d660fd9772b398
FVQ25=652783f7cb87ed876a17452e7a6d98b54b4b50c8
OLD_FPE03=e67d624967f53184904e689333594015e9658683
OLD_TEST_BLOB=6623613a3526c119bf1fada5540eed93346592e1
KERNEL_BLOB=af42c7d51ef545e20c76d3000f1ed1493690d68e
RUNTIME_BLOB=7a60f8b8d18672098fed1c6890a95aac738ed21d
MVG_PROVIDER_BLOB=97d67eb373073b183be6d1bf5b756ecb5125dde2
B12_STATUS_BLOB=db51ec7f247837b224698506c66088be7e53ab1a
B12_ROW='B12,0.01,0.529749,0.016562,1.090671,2.245895,179.6716,-4.493581,0'
B12_ROW_SHA256_NO_EOL=8f6b214ba7894dd49be927c9384a80168f0ad05fabeb48b2f8d1330ef916e59e
B12_ROW_SHA256_LF=ffe20ab48aa426fe20e57dd1ef9ef1a90efa3cf99fa9da24eb09d1c2eb148dfb
B12_ORIGINAL_ROW_SHA256_CRLF=20958231bf61dce00c024c6b8eeca30d0478ae17814d8d16688da6ea0b2d2a53

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
print('FPE03_B12_FVQ25_LINEAGE_LOCK=PASS')
PY
echo 'FPE03_B12_PRODUCTION_SOURCE_IMMUTABILITY=PASS'

# Source-bound B12 provenance copied from the exact user-supplied SWAP 4.3.1
# Staringreeks_2018.csv. The original CSV uses CRLF; Git normalizes the small
# repository fixture to LF. Record and check these as distinct representations.
[[ "$(git rev-parse HEAD:integration/f-pe/F-PE03_B04_B12_STATUS.json)" == "$B12_STATUS_BLOB" ]]
[[ "$(head -n 1 tests/fpe/fixtures/staringreeks_2018_b12.csv)" == 'sfu,ORES,OSAT,ALFA,NPAR,KSATFIT,KSATEXM,LEXP,H_ENPR' ]]
[[ "$(sed -n '2p' tests/fpe/fixtures/staringreeks_2018_b12.csv)" == "$B12_ROW" ]]
printf '%s' "$B12_ROW" > "$BUILD/b12-row-no-eol.txt"
printf '%s\n' "$B12_ROW" > "$BUILD/b12-row-lf.txt"
[[ "$(sha256sum "$BUILD/b12-row-no-eol.txt" | cut -d' ' -f1)" == "$B12_ROW_SHA256_NO_EOL" ]]
[[ "$(sha256sum "$BUILD/b12-row-lf.txt" | cut -d' ' -f1)" == "$B12_ROW_SHA256_LF" ]]
python3 - <<'PY'
import json
from pathlib import Path
s=json.loads(Path('integration/f-pe/F-PE03_B04_B12_STATUS.json').read_text())
f=s['source_fixture']
assert f['archive_sha256']=='2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360'
assert f['source_file_sha256']=='12234a25374b0a47a20e5fcee0577132895f263a77e0f60f5eb4f2fcb5f9ecae'
assert f['original_b12_row_sha256_with_crlf']=='20958231bf61dce00c024c6b8eeca30d0478ae17814d8d16688da6ea0b2d2a53'
assert f['repository_fixture_b12_row_sha256_with_lf']=='ffe20ab48aa426fe20e57dd1ef9ef1a90efa3cf99fa9da24eb09d1c2eb148dfb'
m=s['source_mapping_resolution']['cofgen_mapping']
assert [m[str(i)] for i in range(1,11)] == [
  'ORES','OSAT','KSATFIT','ALFA','LEXP','NPAR','1 - 1/NPAR',
  'ALFA when hysteresis is disabled','H_ENPR','KSATEXM when supplied and greater than KSATFIT']
print('FPE03_B12_SOURCE_MAPPING_RECORD=PASS')
PY
echo "FPE03_B12_ORIGINAL_CRLF_ROW_SHA256=$B12_ORIGINAL_ROW_SHA256_CRLF"
echo 'FPE03_B12_SOURCE_FIXTURE_LOCK=PASS'

# Preserve the exact historical F-PE03 stress matrix. Only the hydraulic
# parameter set is transformed from the old generic MvG set to source-bound B12.
[[ "$(git rev-parse "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90")" == "$OLD_TEST_BLOB" ]]
git show "$OLD_FPE03:tests/fpe/test_fpe03_reference_stress.f90" > "$BUILD/original.f90"
python3 - "$BUILD/original.f90" "$BUILD/b12.f90" <<'PY' > "$BUILD/generation.log"
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

old_header='program test_fpe03_reference_stress\n'
if not src.startswith(old_header):
    raise SystemExit('program header: exact first-line anchor missing')
src='program test_fpe03_b12_reference_search\n'+src[len(old_header):]
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

required = [
  'parameters%cofgen(1,i) = 0.01_real64',
  'parameters%cofgen(2,i) = 0.529749_real64',
  'parameters%cofgen(3,i) = 2.245895_real64',
  'parameters%cofgen(4,i) = 0.016562_real64',
  'parameters%cofgen(5,i) = -4.493581_real64',
  'parameters%cofgen(6,i) = 1.090671_real64',
  'parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)',
  'parameters%cofgen(8,i) = parameters%cofgen(4,i)',
  'parameters%cofgen(9,i) = 0.0_real64',
  'parameters%cofgen(10,i) = 179.6716_real64',
  'parameters%bottom_mode = 7',
  'parameters%swkimpl = 0',
  'parameters%swsophy = 0',
  'parameters%max_iterations = 8',
  'parameters%max_backtracking = 4',
  'parameters%compartment_balance_tolerance = 1.0e-12_real64',
  'parameters%total_balance_tolerance = 1.0e-12_real64',
  'parameters%root_extraction_active = .false.',
  'parameters%macropore_active = .false.',
  'parameters%hysteresis_active = .false.',
  'config%transaction%temporal_tolerance = 0.0_real64',
  'config%transaction%mass_tolerance = hard_mass_gate',
  'config%transaction%retry_scale = 0.5_real64',
  'config%transaction%max_retries = 2'
]
for token in required:
    if token not in src:
        raise SystemExit(f'B12 transformed harness missing source/policy lock: {token}')
out.write_text(src)
print('FPE03_B12_HISTORICAL_24_CASE_MATRIX_REUSED=PASS')
print('FPE03_B12_ONLY_HYDRAULIC_PARAMETER_SET_CHANGED=PASS')
print('FPE03_B12_NUMERICAL_AND_TRANSACTION_POLICY_CHANGED=NO')
PY
grep -Fq 'FPE03_B12_HISTORICAL_24_CASE_MATRIX_REUSED=PASS' "$BUILD/generation.log"
grep -Fq 'FPE03_B12_ONLY_HYDRAULIC_PARAMETER_SET_CHANGED=PASS' "$BUILD/generation.log"
grep -Fq 'FPE03_B12_NUMERICAL_AND_TRANSACTION_POLICY_CHANGED=NO' "$BUILD/generation.log"
echo 'FPE03_B12_TRANSFORM_LOCK=PASS'

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
        assert row[3] == 0, row
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
echo 'FPE03_B12_REJECTED_CASES_ZERO_ACCEPTED_SUBSTEPS=PASS'
echo 'FPE03_B12_CANDIDATE_SEARCH PASS'

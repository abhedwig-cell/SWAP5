#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe06-timing-$$"
ARTIFACT="$ROOT/fpe06_timing_artifact"
mkdir -p "$BUILD" "$ARTIFACT"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PRE_RESULTS=integration/f-pe/F-PE06_PRETIMING_RESULTS.json
PRE_RESULTS_BLOB=a444ce2068e220af1d6046a644fe376b4e73e854
CORRECTION=integration/f-pe/F-PE06_MEASUREMENT_PROTOCOL_CORRECTION_01.json
CORRECTION_BLOB=9419441824831b9129cafed1b45be198b3c102b4
PLAN=integration/f-vq/F-VQ34_QUALIFICATION_PLAN.json
PLAN_BLOB=4f3f7c8883397ed96d3af2f6585f25698c58e7b4
PREDRIVER=tests/fpe/test_fpe06_temporal_certificate_cost.f90
PREDRIVER_BLOB=fda2917afb9cd68ee0c1abf6de1a89352a6cee67
TIMING_DRIVER=tests/fpe/test_fpe06_temporal_certificate_timing.f90
TIMING_DRIVER_BLOB=38029349ac1ce89ee6e1f74481fd9ad1e5b058cf
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
BACKEND_BLOB=9af5a494526810324dc00706b444e448e770cba9
HISTORY=src/transaction/mod_fkt_temporal_indicator_history.f90
HISTORY_BLOB=78884becbfa2fdaba74726608f9e37a303ae4c58
TRANSACTION=src/transaction/mod_transaction_reference.f90
TRANSACTION_BLOB=2fd932b74dbd0ffc0ec089f49e632b7ac8852df4
INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
INDICATOR_BLOB=fe8f87d11257d4c6bc019f1d628ac41ba3106d4e
LINEAR=src/solver/mod_reference_linear_solver.f90
LINEAR_BLOB=b292d284e5549049eac1c80df4cc30008154eb96
SOLVER_CONTRACT=src/solver/mod_soil_water_solver_contract.f90
SOLVER_CONTRACT_BLOB=dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
CANONICAL=src/runtime/mod_canonical_contracts.f90
CANONICAL_BLOB=c06aa869a0bd479df4c7d6e1d0b4f5c07a207144
KERNEL=src/kernel/mod_kernel_transactions.f90
KERNEL_BLOB=63994d8ea6d0a40611574484ececf99e86379783
CHECKPOINT=src/runtime/mod_fmr_checkpoint_orchestrator.f90
CHECKPOINT_BLOB=232875e7192f995930c102609cee08dc8938c86a
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

BLOCKS=9
REPETITIONS=30
WARMUP=3

fail() { echo "FPE06_TIMING_RUNNER_FAIL $*" >&2; exit 1; }

for spec in \
  "$PRE_RESULTS:$PRE_RESULTS_BLOB" \
  "$CORRECTION:$CORRECTION_BLOB" \
  "$PLAN:$PLAN_BLOB" \
  "$PREDRIVER:$PREDRIVER_BLOB" \
  "$TIMING_DRIVER:$TIMING_DRIVER_BLOB" \
  "$BACKEND:$BACKEND_BLOB" \
  "$HISTORY:$HISTORY_BLOB" \
  "$TRANSACTION:$TRANSACTION_BLOB" \
  "$INDICATOR:$INDICATOR_BLOB" \
  "$LINEAR:$LINEAR_BLOB" \
  "$SOLVER_CONTRACT:$SOLVER_CONTRACT_BLOB" \
  "$CANONICAL:$CANONICAL_BLOB" \
  "$KERNEL:$KERNEL_BLOB" \
  "$CHECKPOINT:$CHECKPOINT_BLOB"; do
  path="${spec%%:*}"; blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:$path)" == "$blob" ]] || fail "source lock drift $path"
done

echo 'FPE06_TIMING_G01_SOURCE_LOCK=PASS'

python3 - "$PRE_RESULTS" "$PLAN" "$BUILD/cases.tsv" <<'PY'
import json,sys
pre=json.load(open(sys.argv[1])); plan=json.load(open(sys.argv[2]))
assert pre['workflow_conclusion']=='success'
assert pre['matrix']['O0_cases_passed']==12 and pre['matrix']['O2_cases_passed']==12
assert pre['hard_equivalence_gates']['candidate_physical_state_bitwise_equal'] is True
assert pre['hard_equivalence_gates']['strict_mass_result_bitwise_equal'] is True
m=plan['independent_matrix']; assert m['case_count']==12 and len(m['cases'])==12
with open(sys.argv[3],'w') as f:
    for c in m['cases']:
        f.write(f"{c['case']}\t{float(c['h0_cm']):.17e}\t{float(c['jump_cm']):.17e}\t{float(c['horizon_day']):.17e}\n")
print('FPE06_TIMING_G02_GREEN_PRETIMING_PREREQUISITE=PASS')
print('FPE06_TIMING_G02_FROZEN_CASES=12')
PY

git fetch --quiet --no-tags origin \
  work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then fail 'zero-correction TRIDAG survived'; fi
echo 'FPE06_TIMING_G03_REFERENCE_TRIDAG_SOURCE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -fbacktrace)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

RAW="$ARTIFACT/F-PE06_TIMING_RAW.tsv"
printf 'optimization\tcase\tblock\torder\tarm\tper_trial_seconds\trepetitions\twarmup\n' > "$RAW"

run_arm() {
  local exe="$1" arm="$2" h0="$3" jump="$4" dt="$5" budget="$6" output="$7"
  "$exe" "$arm" "$h0" "$jump" "$dt" "$budget" "$REPETITIONS" "$WARMUP" > "$output" 2>&1 || {
    cat "$output" >&2
    fail "timing execution arm=$arm"
  }
  grep -Fq 'FPE06_TIMING_CASE=PASS' "$output" || { cat "$output" >&2; fail "timing PASS arm=$arm"; }
  grep -Fq 'FPE06_TIMING_HEADCALC=3' "$output" || fail "headcalc topology arm=$arm"
  awk -F= '/FPE06_TIMING_PER_TRIAL_SECONDS=/{gsub(/ /,"",$2); print $2; exit}' "$output"
}

build_and_measure() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj cid h0 jump dt budget preout block order arm tout seconds
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$PREDRIVER" -o "$out/predriver.o"
  gfortran "$opt" "${objects[@]}" "$out/predriver.o" -o "$out/predriver"
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$TIMING_DRIVER" -o "$out/timing.o"
  gfortran "$opt" "${objects[@]}" "$out/timing.o" -o "$out/timing"

  while IFS=$'\t' read -r cid h0 jump dt; do
    preout="$out/pre_${cid}.txt"
    "$out/predriver" "$h0" "$jump" "$dt" > "$preout" 2>&1 || { cat "$preout" >&2; fail "budget preflight opt=$tag case=$cid"; }
    grep -Fq 'FPE06_PRETIMING_EQUIVALENCE=PASS' "$preout" || fail "budget preflight marker opt=$tag case=$cid"
    budget="$(awk -F= '/FPE06_TEST_ORACLE_BUDGET=/{gsub(/ /,"",$2); print $2; exit}' "$preout")"
    [[ -n "$budget" ]] || fail "budget parse opt=$tag case=$cid"
    for block in $(seq 1 "$BLOCKS"); do
      order=0
      for arm in A B B A; do
        order=$((order+1))
        tout="$out/${cid}_b${block}_o${order}_${arm}.txt"
        seconds="$(run_arm "$out/timing" "$arm" "$h0" "$jump" "$dt" "$budget" "$tout")"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$tag" "$cid" "$block" "$order" "$arm" "$seconds" "$REPETITIONS" "$WARMUP" >> "$RAW"
      done
    done
    echo "FPE06_TIMING_${tag}_${cid}=PASS"
  done < "$BUILD/cases.tsv"
  echo "FPE06_TIMING_${tag}_CASES=12"
}

build_and_measure -O0 O0
build_and_measure -O2 O2

python3 - "$RAW" "$ARTIFACT/F-PE06_TIMING_SUMMARY.json" "$BLOCKS" "$REPETITIONS" "$WARMUP" <<'PY'
import csv,json,math,statistics,sys
raw_path,out_path=sys.argv[1],sys.argv[2]
blocks=int(sys.argv[3]); reps=int(sys.argv[4]); warmup=int(sys.argv[5])
rows=[]
with open(raw_path,newline='') as f:
    for r in csv.DictReader(f,delimiter='\t'):
        r['block']=int(r['block']); r['order']=int(r['order']); r['per_trial_seconds']=float(r['per_trial_seconds'])
        rows.append(r)
assert len(rows)==2*12*blocks*4

def p95(values):
    s=sorted(values); return s[max(0,math.ceil(0.95*len(s))-1)]

def metrics(values):
    return {'median':statistics.median(values),'p95':p95(values),'max':max(values),'min':min(values)}

summary={
  'schema_version':1,
  'work_unit':'F-PE06',
  'evidence_stage':'PAIRED_WALL_CLOCK_CHARACTERIZATION',
  'harness':{
    'ordering':'ABBA', 'blocks_per_case':blocks, 'repetitions_per_process':reps, 'warmup_per_process':warmup,
    'principal_advances_per_trial':3, 'temporal_service_invocations_per_B_trial':3,
    'timed_region':'fmr_serialized_reference_backend%run_trial loop only; process setup, fixture construction and budget preflight excluded',
    'benchmark_temporal_route':'TX_TEMPORAL_EXTERNAL_FULL_HALF with finite huge(real64) tolerance in both arms',
    'interpretation':'characterization only; not a universal hardware-independent bound or production policy'
  },
  'optimization':{}
}
for opt in ('O0','O2'):
    opt_rows=[r for r in rows if r['optimization']==opt]
    assert len(opt_rows)==12*blocks*4
    paired=[]; per_case={}
    cases=sorted({r['case'] for r in opt_rows})
    for case in cases:
        crows=[r for r in opt_rows if r['case']==case]
        cpaired=[]
        for block in range(1,blocks+1):
            brows=[r for r in crows if r['block']==block]
            assert [r['arm'] for r in sorted(brows,key=lambda x:x['order'])]==['A','B','B','A']
            av=[r['per_trial_seconds'] for r in brows if r['arm']=='A']
            bv=[r['per_trial_seconds'] for r in brows if r['arm']=='B']
            assert len(av)==2 and len(bv)==2 and min(av+bv)>0.0
            a=sum(av)/2.0; b=sum(bv)/2.0; delta=b-a; ratio=b/a
            rec={'case':case,'block':block,'A_seconds':a,'B_seconds':b,'delta_seconds':delta,
                 'ratio_B_over_A':ratio,'delta_per_temporal_service_seconds':delta/3.0}
            paired.append(rec); cpaired.append(rec)
        per_case[case]={
          'A_seconds':metrics([x['A_seconds'] for x in cpaired]),
          'B_seconds':metrics([x['B_seconds'] for x in cpaired]),
          'delta_seconds':metrics([x['delta_seconds'] for x in cpaired]),
          'ratio_B_over_A':metrics([x['ratio_B_over_A'] for x in cpaired]),
          'delta_per_temporal_service_seconds':metrics([x['delta_per_temporal_service_seconds'] for x in cpaired])
        }
    summary['optimization'][opt]={
      'raw_process_observations':len(opt_rows),
      'paired_blocks':len(paired),
      'aggregate':{
        'A_seconds':metrics([x['A_seconds'] for x in paired]),
        'B_seconds':metrics([x['B_seconds'] for x in paired]),
        'delta_seconds':metrics([x['delta_seconds'] for x in paired]),
        'ratio_B_over_A':metrics([x['ratio_B_over_A'] for x in paired]),
        'delta_per_temporal_service_seconds':metrics([x['delta_per_temporal_service_seconds'] for x in paired])
      },
      'per_case':per_case
    }
with open(out_path,'w') as f: json.dump(summary,f,indent=2,sort_keys=True)
print('FPE06_TIMING_G04_SUMMARY_GENERATED=PASS')
for opt in ('O0','O2'):
    a=summary['optimization'][opt]['aggregate']
    print(f"FPE06_TIMING_{opt}_PAIRED_BLOCKS={summary['optimization'][opt]['paired_blocks']}")
    print(f"FPE06_TIMING_{opt}_MEDIAN_A={a['A_seconds']['median']:.17e}")
    print(f"FPE06_TIMING_{opt}_MEDIAN_B={a['B_seconds']['median']:.17e}")
    print(f"FPE06_TIMING_{opt}_MEDIAN_DELTA={a['delta_seconds']['median']:.17e}")
    print(f"FPE06_TIMING_{opt}_P95_DELTA={a['delta_seconds']['p95']:.17e}")
    print(f"FPE06_TIMING_{opt}_MAX_DELTA={a['delta_seconds']['max']:.17e}")
    print(f"FPE06_TIMING_{opt}_MEDIAN_RATIO={a['ratio_B_over_A']['median']:.17e}")
PY

gfortran --version | head -n1 > "$ARTIFACT/compiler.txt"
printf 'COMMON=%s\nO0=-O0\nO2=-O2\n' "${COMMON[*]}" > "$ARTIFACT/build_flags.txt"
printf 'HEAD=%s\nBLOCKS=%s\nREPETITIONS=%s\nWARMUP=%s\nORDER=ABBA\n' "$(git rev-parse HEAD)" "$BLOCKS" "$REPETITIONS" "$WARMUP" > "$ARTIFACT/provenance.txt"

echo 'FPE06_TIMING_RUNNER=PASS'

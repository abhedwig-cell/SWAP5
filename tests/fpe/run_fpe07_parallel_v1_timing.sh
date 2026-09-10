#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe07-$$"
OUTDIR="${FPE07_OUTDIR:-$ROOT/fpe07-evidence}"
mkdir -p "$BUILD" "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=1a249cde0c088e8023cd603d30239ce0d30bf4d7
fail() { echo "FPE07_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35 \
  tests/fmr/test_fmr20_parallel_v1_qualification.f90:bfebfde94b3931367d69d502a6fc7b1deb8f2ad6 \
  tests/fmr/run_fmr20_parallel_v1_qualification.sh:3fd1da2c10923adc1f5acf0d4e044e5e8c7236e3 \
  tests/fpe/test_fpe07_parallel_v1_timing.f90:fe9b7b79477b9164609c3da9fc30f3d816a8e055; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FPE07_G01_SOURCE_LOCK=PASS'

if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  git fetch --quiet --no-tags --depth=1 origin "$BASE"
fi
[[ -z "$(git diff --name-only "$BASE" HEAD -- src)" ]] || {
  git diff --name-only "$BASE" HEAD -- src >&2
  fail 'F-PE07 must not modify production source'
}
echo 'FPE07_G02_NO_PRODUCTION_SOURCE_CHANGE=PASS'

# Re-run the complete F-MR20 scientific qualification on the exact frozen
# production postimage before collecting performance observations.
bash tests/fmr/run_fmr20_parallel_v1_qualification.sh > "$OUTDIR/F-PE07_SCIENTIFIC_PRECONDITION.log" 2>&1 || {
  cat "$OUTDIR/F-PE07_SCIENTIFIC_PRECONDITION.log" >&2
  fail 'F-MR20 scientific precondition'
}
grep -Fq 'FMR20_PARALLEL_V1_QUALIFICATION_GATE=PASS' "$OUTDIR/F-PE07_SCIENTIFIC_PRECONDITION.log" || \
  fail 'missing F-MR20 qualification marker'
echo 'FPE07_G03_SCIENTIFIC_PRECONDITION=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -fbacktrace -fopenmp -O2)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
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
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
)

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c tests/fpe/test_fpe07_parallel_v1_timing.f90 -o "$BUILD/test.o"
gfortran -fopenmp -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

"$BUILD/test" > "$OUTDIR/F-PE07_TIMING_DRIVER.log" 2>&1 || {
  cat "$OUTDIR/F-PE07_TIMING_DRIVER.log" >&2
  fail 'timing driver'
}
grep -Fq 'FPE07_TIMING_DRIVER PASS' "$OUTDIR/F-PE07_TIMING_DRIVER.log" || fail 'missing timing driver PASS'
grep '^FPE07_RAW,' "$OUTDIR/F-PE07_TIMING_DRIVER.log" > "$OUTDIR/F-PE07_TIMING_RAW.csv"

python3 - "$OUTDIR/F-PE07_TIMING_RAW.csv" "$OUTDIR/F-PE07_TIMING_SUMMARY.json" <<'PY'
import csv, json, math, statistics, sys
from collections import defaultdict
raw_path, summary_path = sys.argv[1:]
rows=[]
with open(raw_path, newline='') as f:
    for row in csv.reader(f):
        if len(row) != 7 or row[0] != 'FPE07_RAW':
            raise SystemExit(f'bad raw row: {row}')
        rows.append({
            'block': int(row[1]), 'workers': int(row[2]), 'rep': int(row[3]),
            'ticks': int(row[4]), 'elapsed_us': float(row[5]), 'overlap': int(row[6])
        })
if len(rows) != 12*3*8:
    raise SystemExit(f'expected 288 raw rows, got {len(rows)}')
for w in (1,2,4):
    wr=[r for r in rows if r['workers']==w]
    if len(wr) != 96: raise SystemExit(f'worker {w}: expected 96 rows, got {len(wr)}')
    if any(r['elapsed_us'] <= 0 or not math.isfinite(r['elapsed_us']) for r in wr):
        raise SystemExit(f'worker {w}: invalid timing')
    if w == 1 and any(r['overlap'] != 1 for r in wr): raise SystemExit('worker1 overlap drift')
    if w == 2 and any(r['overlap'] != 2 for r in wr): raise SystemExit('worker2 overlap drift')
    if w == 4 and any(not (2 <= r['overlap'] <= 4) for r in wr): raise SystemExit('worker4 overlap drift')

def percentile(xs,p):
    xs=sorted(xs)
    if not xs: raise ValueError
    k=(len(xs)-1)*p
    lo=math.floor(k); hi=math.ceil(k)
    if lo==hi: return xs[lo]
    return xs[lo]*(hi-k)+xs[hi]*(k-lo)

by_worker=defaultdict(list)
by_block_worker=defaultdict(list)
for r in rows:
    by_worker[r['workers']].append(r['elapsed_us'])
    by_block_worker[(r['block'],r['workers'])].append(r['elapsed_us'])
block_medians={}
for b in range(1,13):
    for w in (1,2,4):
        vals=by_block_worker[(b,w)]
        if len(vals)!=8: raise SystemExit(f'block {b} worker {w} cardinality')
        block_medians[(b,w)]=statistics.median(vals)
ratios={w:[block_medians[(b,1)]/block_medians[(b,w)] for b in range(1,13)] for w in (2,4)}
summary={
  'schema_version':1,
  'work_unit':'F-PE07',
  'scope':{'logical_columns':32,'batch_size':9,'workers':[1,2,4],'optimization':'O2'},
  'raw_observations':len(rows),
  'paired_blocks':12,
  'repetitions_per_arm_per_block':8,
  'workers':{},
  'observed_runtime_ratio_T1_over_Tw':{},
  'interpretation':{
    'ratio_above_one':'observed faster than worker-1 arm on this runner/fixture',
    'ratio_below_one':'observed slower than worker-1 arm on this runner/fixture',
    'not_a_claim':'no universal speedup, efficiency or production throughput guarantee'
  }
}
for w in (1,2,4):
    vals=by_worker[w]
    summary['workers'][str(w)]={
      'observations':len(vals),
      'median_us_per_32_column_call':statistics.median(vals),
      'p95_us_per_32_column_call':percentile(vals,0.95),
      'min_us_per_32_column_call':min(vals),
      'max_us_per_32_column_call':max(vals),
      'median_us_per_column':statistics.median(vals)/32.0,
      'min_observed_overlap':min(r['overlap'] for r in rows if r['workers']==w),
      'max_observed_overlap':max(r['overlap'] for r in rows if r['workers']==w)
    }
for w in (2,4):
    vals=ratios[w]
    summary['observed_runtime_ratio_T1_over_Tw'][str(w)]={
      'paired_block_ratios':vals,
      'median':statistics.median(vals),
      'p05':percentile(vals,0.05),
      'p95':percentile(vals,0.95),
      'min':min(vals),'max':max(vals),
      'blocks_ratio_gt_1':sum(v>1 for v in vals),
      'blocks_ratio_lt_1':sum(v<1 for v in vals)
    }
with open(summary_path,'w') as f: json.dump(summary,f,indent=2,sort_keys=True)
print(json.dumps(summary,indent=2,sort_keys=True))
PY

cat > "$OUTDIR/provenance.txt" <<EOF
work_unit=F-PE07
head=$(git rev-parse HEAD)
base_fmr20=$BASE
runner=$(uname -a)
EOF
gfortran --version > "$OUTDIR/compiler.txt"
printf '%s\n' '-std=f2008 -ffree-line-length-none -fbacktrace -fopenmp -O2' > "$OUTDIR/build_flags.txt"

cat "$OUTDIR/F-PE07_TIMING_SUMMARY.json"
echo 'FPE07_G04_TIMING_CHARACTERIZATION=PASS'
echo 'FPE07_TIMING_GATE=PASS'

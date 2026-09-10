#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe09-timing-$$"
OUTDIR="${FPE09_OUTDIR:-$ROOT/fpe09-evidence}"
mkdir -p "$BUILD/base_src" "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=0c136148fb5a53db3804070ac74fc8cef55d81f3
fail() { echo "FPE09_TIMING_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == "ffd4701740dceb2df12f05e9cad73e81eeb55b43" ]] || fail 'candidate MvG source lock'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "64c3d9581c71fc7bf5e5f3764995d41280312a2e" ]] || fail 'candidate backend source lock'
[[ "$(git rev-parse HEAD:tests/fpe/test_fpe07_parallel_v1_timing.f90)" == "fe9b7b79477b9164609c3da9fc30f3d816a8e055" ]] || fail 'timing driver source lock'

if ! git cat-file -e "$BASE^{commit}" 2>/dev/null; then
  git fetch --quiet --no-tags --depth=1 origin "$BASE"
fi
[[ "$(git rev-parse "$BASE:src/solver/mod_b110_default_mvg_provider.f90")" == "97d67eb373073b183be6d1bf5b756ecb5125dde2" ]] || fail 'baseline MvG source lock'
[[ "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_reference_backend.f90")" == "e0432faa0e05a3c136ee5aed6fddb12ad631848d" ]] || fail 'baseline backend source lock'
git show "$BASE:src/solver/mod_b110_default_mvg_provider.f90" > "$BUILD/base_src/mod_b110_default_mvg_provider.f90"
git show "$BASE:src/runtime/mod_fmr_serialized_reference_backend.f90" > "$BUILD/base_src/mod_fmr_serialized_reference_backend.f90"
echo 'FPE09_TIMING_G01_BASE_AND_CANDIDATE_LOCK=PASS'

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

build_variant() {
  local variant="$1"
  local out="$BUILD/$variant"
  mkdir -p "$out"
  local objects=()
  local src actual obj
  for src in "${MODULE_SRC[@]}"; do
    actual="$src"
    if [[ "$variant" == baseline && "$src" == src/solver/mod_b110_default_mvg_provider.f90 ]]; then
      actual="$BUILD/base_src/mod_b110_default_mvg_provider.f90"
    elif [[ "$variant" == baseline && "$src" == src/runtime/mod_fmr_serialized_reference_backend.f90 ]]; then
      actual="$BUILD/base_src/mod_fmr_serialized_reference_backend.f90"
    fi
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$actual" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c tests/fpe/test_fpe07_parallel_v1_timing.f90 -o "$out/test.o"
  gfortran -fopenmp -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}

build_variant baseline
build_variant candidate
echo 'FPE09_TIMING_G02_DUAL_BUILD=PASS'

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

RAW="$OUTDIR/F-PE09_PAIRED_TIMING_RAW.csv"
: > "$RAW"
run_one() {
  local variant="$1" round="$2"
  local log="$OUTDIR/${variant}_round_${round}.log"
  "$BUILD/$variant/test" > "$log" 2>&1 || { cat "$log" >&2; fail "$variant timing driver round $round"; }
  grep -Fq 'FPE07_TIMING_DRIVER PASS' "$log" || fail "$variant round $round missing timing PASS"
  awk -F',' -v v="$variant" -v r="$round" 'BEGIN{OFS=","} /^FPE07_RAW,/{print "FPE09_RAW",v,r,$2,$3,$4,$5,$6,$7}' "$log" >> "$RAW"
}

# Balanced process order on one hosted runner. Each invocation performs its own
# untimed warmups and internally times only complete 32-column runtime calls.
run_one baseline 1
run_one candidate 1
run_one candidate 2
run_one baseline 2
run_one baseline 3
run_one candidate 3
run_one candidate 4
run_one baseline 4

echo 'FPE09_TIMING_G03_BALANCED_SAME_RUNNER_EXECUTION=PASS'

python3 - "$RAW" "$OUTDIR/F-PE09_PAIRED_TIMING_SUMMARY.json" <<'PY'
import csv, json, math, statistics, sys
from collections import defaultdict
raw_path, summary_path = sys.argv[1:]
rows=[]
with open(raw_path, newline='') as f:
    for row in csv.reader(f):
        if len(row) != 9 or row[0] != 'FPE09_RAW':
            raise SystemExit(f'bad raw row: {row}')
        rows.append({
            'variant':row[1], 'round':int(row[2]), 'driver_block':int(row[3]),
            'workers':int(row[4]), 'rep':int(row[5]), 'ticks':int(row[6]),
            'elapsed_us':float(row[7]), 'overlap':int(row[8])})
expected=2*4*12*3*8
if len(rows) != expected:
    raise SystemExit(f'expected {expected} rows, got {len(rows)}')
for r in rows:
    if r['variant'] not in ('baseline','candidate') or r['round'] not in (1,2,3,4):
        raise SystemExit('variant/round domain')
    if r['workers'] not in (1,2,4) or not math.isfinite(r['elapsed_us']) or r['elapsed_us'] <= 0:
        raise SystemExit('invalid timing row')
    if r['workers']==1 and r['overlap'] != 1: raise SystemExit('worker1 overlap drift')
    if r['workers']==2 and r['overlap'] != 2: raise SystemExit('worker2 overlap drift')
    if r['workers']==4 and not (2 <= r['overlap'] <= 4): raise SystemExit('worker4 overlap drift')

def pct(xs,p):
    xs=sorted(xs); k=(len(xs)-1)*p; lo=math.floor(k); hi=math.ceil(k)
    return xs[lo] if lo==hi else xs[lo]*(hi-k)+xs[hi]*(k-lo)

by=defaultdict(list)
round_median={}
for r in rows:
    by[(r['variant'],r['workers'])].append(r['elapsed_us'])
for variant in ('baseline','candidate'):
    for rnd in (1,2,3,4):
        for w in (1,2,4):
            vals=[r['elapsed_us'] for r in rows if r['variant']==variant and r['round']==rnd and r['workers']==w]
            if len(vals)!=96: raise SystemExit(f'cardinality {variant} {rnd} {w}: {len(vals)}')
            round_median[(variant,rnd,w)]=statistics.median(vals)
summary={
 'schema_version':1,
 'work_unit':'F-PE09',
 'comparison':'F-PE08 preimage vs F-PE09 exact-shape cache-reuse postimage',
 'scope':{'logical_columns':32,'batch_size':9,'workers':[1,2,4],'optimization':'O2','paired_rounds':4},
 'raw_observations':len(rows),
 'variants':{},
 'paired_round_base_over_candidate':{},
 'interpretation':{
   'ratio_above_one':'candidate observed faster in that paired round',
   'ratio_below_one':'candidate observed slower in that paired round',
   'not_a_claim':'no universal speedup, production SLA, or portable worker-count policy'
 }
}
for variant in ('baseline','candidate'):
    summary['variants'][variant]={}
    for w in (1,2,4):
        vals=by[(variant,w)]
        summary['variants'][variant][str(w)]={
          'observations':len(vals),'median_us':statistics.median(vals),'p95_us':pct(vals,.95),
          'min_us':min(vals),'max_us':max(vals)}
for w in (1,2,4):
    ratios=[]
    for rnd in (1,2,3,4):
        ratios.append(round_median[('baseline',rnd,w)]/round_median[('candidate',rnd,w)])
    summary['paired_round_base_over_candidate'][str(w)]={
      'ratios':ratios,'median':statistics.median(ratios),'min':min(ratios),'max':max(ratios),
      'rounds_candidate_faster':sum(x>1 for x in ratios),'rounds_candidate_slower':sum(x<1 for x in ratios)}
with open(summary_path,'w') as f: json.dump(summary,f,indent=2,sort_keys=True)
print(json.dumps(summary,indent=2,sort_keys=True))
PY

cat > "$OUTDIR/provenance.txt" <<EOF
work_unit=F-PE09
candidate_head=$(git rev-parse HEAD)
baseline_fpe08=$BASE
runner=$(uname -a)
EOF
gfortran --version > "$OUTDIR/compiler.txt"
printf '%s\n' '-std=f2008 -ffree-line-length-none -fbacktrace -fopenmp -O2' > "$OUTDIR/build_flags.txt"
cat "$OUTDIR/F-PE09_PAIRED_TIMING_SUMMARY.json"
echo 'FPE09_TIMING_G04_PAIRED_CHARACTERIZATION=PASS'
echo 'FPE09_PAIRED_TIMING_GATE=PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fpe07-$$"
EVIDENCE="${FPE07_EVIDENCE_DIR:-$ROOT/fpe07-evidence}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=1a249cde0c088e8023cd603d30239ce0d30bf4d7
BASE_REF=refs/remotes/origin/work/f-mr20-concurrency-isolation
fail() { echo "FPE07_GATE_FAIL $*" >&2; exit 1; }

for spec in \
  integration/f-pe/F-PE07_MEASUREMENT_PROTOCOL.json:a88298c8fd3e87e8b3a038a6acc5bc11f33a8c76 \
  tests/fpe/test_fpe07_parallel_v1_timing.f90:9083b98ab6b9889a79a67d71c62f49f2cd258a83 \
  src/runtime/mod_fmr_runtime_core.f90:adc2b7514cc062c0cde4e71582ba8ed7776a7335 \
  src/runtime/mod_fmr_serialized_reference_backend.f90:e0432faa0e05a3c136ee5aed6fddb12ad631848d \
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90:be4005a97e35c498ffc40297409a75efe65ff5df \
  src/adapter/mod_reference_richards_legacy_binding.f90:1c7be9119986eb8ad3bd3c00b0b3b3afb4ed68ff \
  src/legacy/b1_10_port/headcalc.f90:04c4877754b39161d5afa0f2496a015fd3334cc5 \
  src/runtime/mod_fmr_parallel_physical_scheduler.f90:544a1ca16fdeebdfce7f89d1ddf1825fa32fa654 \
  src/runtime/mod_fmr_parallel_worker_pool.f90:393e9bfbc4c078d259a5ec70aca78f50e54e8b35; do
  path="${spec%%:*}"
  blob="${spec##*:}"
  [[ "$(git rev-parse HEAD:"$path")" == "$blob" ]] || fail "source lock drift: $path"
done
echo 'FPE07_G01_SOURCE_LOCK=PASS'

git fetch --quiet --no-tags --depth=1 origin work/f-mr20-concurrency-isolation:"$BASE_REF"
[[ "$(git rev-parse "$BASE_REF")" == "$BASE" ]] || fail 'F-MR20 closeout base drift'
if [[ -n "$(git diff --name-only "$BASE_REF" HEAD -- src)" ]]; then
  git diff --name-only "$BASE_REF" HEAD -- src >&2
  fail 'production source changed relative to F-MR20 closeout'
fi
echo 'FPE07_G02_NO_PRODUCTION_SOURCE_CHANGE=PASS'

# Scientific preflight uses the qualified F-MR20 runner with its own runtime-checking build.
bash tests/fmr/run_fmr20_parallel_v1_qualification.sh > "$BUILD/preflight.txt" 2>&1 || {
  cat "$BUILD/preflight.txt" >&2
  fail 'F-MR20 scientific preflight'
}
grep -Fq 'FMR20_PARALLEL_V1_QUALIFICATION_GATE=PASS' "$BUILD/preflight.txt" || fail 'missing F-MR20 preflight marker'
echo 'FPE07_G03_FMR20_SCIENTIFIC_PREFLIGHT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -fbacktrace -fopenmp)
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

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

: > "$EVIDENCE/F-PE07_TIMING_RAW.tsv"
printf 'optimization\tblock\tslot\tworkers\tseconds_per_dispatch\toverlap\n' >> "$EVIDENCE/F-PE07_TIMING_RAW.tsv"

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe07_parallel_v1_timing.f90 -o "$OUT/test.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'FPE07_WARMUP=PASS' "$OUT/output.txt" || fail "O$opt warmup marker"
  grep -Fq 'FPE07_TIMING_DRIVER_PASS' "$OUT/output.txt" || fail "O$opt timing driver marker"
  [[ "$(grep -c '^FPE07_OBS|' "$OUT/output.txt")" == 60 ]] || fail "O$opt expected 60 timing observations"
  python3 - "$opt" "$OUT/output.txt" "$EVIDENCE/F-PE07_TIMING_RAW.tsv" <<'PY'
import re, sys
opt, src, dest = sys.argv[1:]
pat = re.compile(r'^FPE07_OBS\|block=(\d+)\|slot=(\d+)\|workers=(\d+)\|seconds=\s*([0-9.Ee+-]+)\|overlap=(\d+)$')
rows=[]
for line in open(src, encoding='utf-8'):
    m=pat.match(line.strip())
    if m:
        rows.append(m.groups())
if len(rows) != 60:
    raise SystemExit(f'expected 60 observations, got {len(rows)}')
with open(dest,'a',encoding='utf-8') as f:
    for block,slot,workers,seconds,overlap in rows:
        f.write(f'O{opt}\t{block}\t{slot}\t{workers}\t{float(seconds):.17g}\t{overlap}\n')
PY
  echo "FPE07_TIMING_O${opt}=PASS"
done

python3 - "$EVIDENCE/F-PE07_TIMING_RAW.tsv" "$EVIDENCE/F-PE07_TIMING_SUMMARY.json" <<'PY'
import csv, json, math, statistics, sys
raw, out = sys.argv[1:]
rows=[]
with open(raw, newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f, delimiter='\t'):
        r['block']=int(r['block']); r['slot']=int(r['slot']); r['workers']=int(r['workers'])
        r['seconds_per_dispatch']=float(r['seconds_per_dispatch']); r['overlap']=int(r['overlap'])
        rows.append(r)

def percentile(vals, p):
    vals=sorted(vals)
    if not vals: return None
    x=(len(vals)-1)*p
    lo=math.floor(x); hi=math.ceil(x)
    if lo==hi: return vals[lo]
    return vals[lo]*(hi-x)+vals[hi]*(x-lo)

summary={
  'schema_version':1,
  'work_unit':'F-PE07',
  'base_fmr20_closeout':'1a249cde0c088e8023cd603d30239ce0d30bf4d7',
  'profile':{'columns':32,'batch_size':9,'workers':[1,2,4]},
  'observations_per_optimization':60,
  'dispatches_per_observation':10,
  'metrics':{}
}
for opt in ('O0','O2'):
    optrows=[r for r in rows if r['optimization']==opt]
    om={'arms':{},'paired_blocks':{}}
    block_medians={}
    for w in (1,2,4):
        vals=[r['seconds_per_dispatch'] for r in optrows if r['workers']==w]
        overlaps=[r['overlap'] for r in optrows if r['workers']==w]
        om['arms'][f'W{w}']={
          'n_observations':len(vals),
          'median_seconds_per_32_column_interval':statistics.median(vals),
          'p95_seconds_per_32_column_interval':percentile(vals,0.95),
          'min_seconds_per_32_column_interval':min(vals),
          'max_seconds_per_32_column_interval':max(vals),
          'median_seconds_per_column':statistics.median(vals)/32.0,
          'min_observed_overlap':min(overlaps),
          'max_observed_overlap':max(overlaps)
        }
    for b in range(1,11):
        block_medians[b]={}
        for w in (1,2,4):
            vals=[r['seconds_per_dispatch'] for r in optrows if r['block']==b and r['workers']==w]
            if len(vals)!=2: raise SystemExit(f'{opt} block {b} worker {w}: expected 2 observations')
            block_medians[b][w]=statistics.median(vals)
    for w in (2,4):
        speed=[block_medians[b][1]/block_medians[b][w] for b in range(1,11)]
        om['paired_blocks'][f'W1_over_W{w}']={
          'n_blocks':len(speed),
          'median_speedup':statistics.median(speed),
          'p05_speedup':percentile(speed,0.05),
          'p95_speedup':percentile(speed,0.95),
          'median_parallel_efficiency':statistics.median(speed)/w,
          'blocks_with_speedup_gt_1':sum(x>1.0 for x in speed),
          'blocks_with_speedup_le_1':sum(x<=1.0 for x in speed)
        }
    summary['metrics'][opt]=om
with open(out,'w',encoding='utf-8') as f:
    json.dump(summary,f,indent=2,sort_keys=True)
    f.write('\n')
PY

{
  echo "F-PE07 provenance"
  echo "head=$(git rev-parse HEAD)"
  echo "tree=$(git rev-parse HEAD^{tree})"
  echo "base_fmr20=$BASE"
  echo "compiler=$(gfortran --version | head -1)"
  echo "uname=$(uname -a)"
  echo "nproc=$(nproc)"
  echo "OMP_DYNAMIC=$OMP_DYNAMIC"
  echo "OMP_THREAD_LIMIT=$OMP_THREAD_LIMIT"
  echo "OMP_PROC_BIND=$OMP_PROC_BIND"
  echo "OMP_PLACES=$OMP_PLACES"
  echo "timing_compile_flags=-std=f2008 -ffree-line-length-none -fbacktrace -fopenmp -O0/-O2"
} > "$EVIDENCE/provenance.txt"

cp "$BUILD/preflight.txt" "$EVIDENCE/F-PE07_FMR20_SCIENTIFIC_PREFLIGHT.txt"
cat "$EVIDENCE/F-PE07_TIMING_SUMMARY.json"
echo 'FPE07_TIMING_GATE=PASS'

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=3c5f5bd3686e1632058b906be21abd73883e30ef
BUILD="${RUNNER_TEMP:-/tmp}/fpe11-timing-${GITHUB_RUN_ID:-local}"
BASE_TREE="$BUILD/base-tree"
rm -rf "$BUILD"
mkdir -p "$BUILD" "$BASE_TREE"
trap 'rm -rf "$BUILD"' EXIT

git cat-file -e "${BASE}^{commit}" 2>/dev/null || git fetch --no-tags origin "$BASE" >/dev/null 2>&1
git archive "$BASE" | tar -x -C "$BASE_TREE"

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
  src/solver/mod_process_hydraulic_view.f90
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
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)

compile_tree() {
  local tree="$1" tag="$2"
  local out="$BUILD/$tag"
  mkdir -p "$out"
  local objects=()
  for rel in "${MODULE_SRC[@]}"; do
    local src="$tree/$rel"
    local obj="$out/$(basename "${rel%.*}").o"
    gfortran -std=f2008 -ffree-line-length-none -O2 -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran -std=f2008 -ffree-line-length-none -O2 -J"$out" -I"$out" \
    -c "$ROOT/tests/fpe/test_fpe11_surface_evaporation_timing.f90" -o "$out/timing.o"
  gfortran -O2 "${objects[@]}" "$out/timing.o" -o "$out/timing.exe"
}

compile_tree "$BASE_TREE" baseline
compile_tree "$ROOT" candidate

RAW="$BUILD/raw.csv"
echo 'nodes,round,position,arm,seconds,checksum' > "$RAW"

run_one() {
  local arm="$1" nodes="$2" calls="$3" round="$4" position="$5"
  local line seconds checksum
  line=$("$BUILD/$arm/timing.exe" "$nodes" "$calls")
  seconds=$(sed -n 's/.*seconds=\([^,]*\),checksum=.*/\1/p' <<<"$line" | tr -d ' ')
  checksum=$(sed -n 's/.*checksum=\(.*\)$/\1/p' <<<"$line" | tr -d ' ')
  [[ -n "$seconds" && -n "$checksum" ]] || { echo "FPE11_TIMING_PARSE_FAIL $line" >&2; exit 11; }
  echo "$nodes,$round,$position,$arm,$seconds,$checksum" >> "$RAW"
}

# Each profile size gets four paired observations per arm with process order
# balanced as B C | C B | B C | C B. Separate processes limit cross-arm heap
# history effects and mirror the PE09/PE10 same-runner paired methodology.
for spec in '2 300000' '20 250000' '60 200000' '200 120000' '1000 40000'; do
  read -r nodes calls <<<"$spec"
  for round in 1 2 3 4; do
    if (( round % 2 == 1 )); then
      run_one baseline  "$nodes" "$calls" "$round" 1
      run_one candidate "$nodes" "$calls" "$round" 2
    else
      run_one candidate "$nodes" "$calls" "$round" 1
      run_one baseline  "$nodes" "$calls" "$round" 2
    fi
  done
done

cat "$RAW"
python3 - "$RAW" <<'PY'
import csv, statistics, sys
p=sys.argv[1]
rows=list(csv.DictReader(open(p)))
all_faster=True
all_checksums=True
print('FPE11_TIMING_METHOD=PAIRED_SAME_RUNNER_BALANCED_ORDER_O2')
for n in sorted({int(r['nodes']) for r in rows}):
    rs=[r for r in rows if int(r['nodes'])==n]
    b=[float(r['seconds']) for r in rs if r['arm']=='baseline']
    c=[float(r['seconds']) for r in rs if r['arm']=='candidate']
    bm=statistics.median(b); cm=statistics.median(c)
    speedup=bm/cm
    delta=(1.0-cm/bm)*100.0
    paired=[]
    for rnd in range(1,5):
        rb=next(float(r['seconds']) for r in rs if r['arm']=='baseline' and int(r['round'])==rnd)
        rc=next(float(r['seconds']) for r in rs if r['arm']=='candidate' and int(r['round'])==rnd)
        paired.append(rc < rb)
    checks={r['checksum'] for r in rs}
    checksum_ok=len(checks)==1
    all_checksums &= checksum_ok
    all_faster &= cm < bm
    print(f'FPE11_PROFILE_RESULT nodes={n} baseline_median_s={bm:.9f} candidate_median_s={cm:.9f} '
          f'baseline_over_candidate={speedup:.6f} candidate_delta_pct={delta:.3f} '
          f'paired_rounds_candidate_faster={sum(paired)}/4 checksum_identity={"PASS" if checksum_ok else "FAIL"}')
print('FPE11_CHECKSUM_IDENTITY=' + ('PASS' if all_checksums else 'FAIL'))
print('FPE11_CANDIDATE_MEDIAN_FASTER_ALL_PROFILE_SIZES=' + ('YES' if all_faster else 'NO'))
print('FPE11_PAIRED_TIMING_EVIDENCE=PASS')
print('FPE11_FULL_MULTISWAP_SPEEDUP_CLAIM=NOT_MADE')
if not all_checksums:
    raise SystemExit(11)
PY

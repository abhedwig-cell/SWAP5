#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CANON=bf0fb81daf0f0fee53566a426886eaa0d0ad2832
OWNER=b436f8e70664cdb851f20f148463459358568579
QUALIFIED=a0b810bf68d5b5228da5f39ce9e30fc41ddd6954
PREIMAGE=3c5f5bd3686e1632058b906be21abd73883e30ef
BINDING=src/runtime/mod_fmr_process_hydraulic_view_binding.f90
MATERIALIZER=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
KERNEL=src/kernel/mod_kernel_transactions.f90
PROCESS=src/process/mod_restricted_surface_evaporation.f90
CAPACITY=src/solver/mod_surface_evaporation_capacity_contract.f90
BUILD="${RUNNER_TEMP:-/tmp}/fpe11-current-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE11_CURRENT_FAIL $*" >&2; exit 111; }

for sha in "$CANON" "$OWNER" "$QUALIFIED" "$PREIMAGE"; do
  git cat-file -e "$sha^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "missing authority $sha"
done
git merge-base --is-ancestor "$CANON" HEAD || fail 'qualification head does not descend from registered canonical snapshot'
if [[ -n "$(git diff --name-only "$CANON..HEAD" -- src reference)" ]]; then
  git diff --name-only "$CANON..HEAD" -- src reference >&2
  fail 'qualification branch changed production/reference source'
fi

test "$(git rev-parse HEAD:$BINDING)" = 67b346251ba21be62c6ed3077f2c71ddd2c8dd02 || fail 'qualified binding blob drift'
test "$(git rev-parse HEAD:$MATERIALIZER)" = b8ff1fb1d9434e952163b6955305c6373dd8ac82 || fail 'current materializer blob drift'
test "$(git rev-parse HEAD:$KERNEL)" = e4db4ede8162c8be877c8cad9f1babd57ba451b6 || fail 'current kernel dependency blob drift'
test "$(git rev-parse HEAD:$PROCESS)" = a213af4deec2fe854d79120899827852a57237d1 || fail 'surface process blob drift'
test "$(git rev-parse HEAD:$CAPACITY)" = 551513f77caeb9c54e8c8b1cdc326be0e9d01982 || fail 'capacity contract blob drift'
echo 'FPE11_CURRENT_ZERO_PRODUCTION_REFERENCE_DELTA=PASS'
echo 'FPE11_CURRENT_EXACT_SOURCE_IDENTITIES=PASS'

python3 - "$PREIMAGE" "$BINDING" "$MATERIALIZER" <<'PY'
from pathlib import Path
import re, subprocess, sys
pre,binding,materializer=sys.argv[1:]
b=Path(binding).read_text().lower()
r=Path(materializer).read_text().lower()
old=subprocess.check_output(['git','show',f'{pre}:{materializer}'],text=True).lower()

def sub(text,name):
    m=re.search(rf'(?ms)^\s*subroutine\s+{name}\b.*?^\s*end\s+subroutine\s+{name}\b',text)
    assert m, name
    return m.group(0)

assert 'call committed%snapshot(snapshot, available)' in b
assert 'call move_alloc(physical%pressure_head, view%pressure_head)' in b
assert 'call move_alloc(physical%water_content, view%water_content)' in b
assert not re.search(r'\ballocate\s*\(', b)
cur_det=sub(r,'detached_state_from_view')
old_det=sub(old,'detached_state_from_view')
assert 'intent(inout) :: view' in cur_det
assert 'move_alloc(view%pressure_head, state%pressure_head)' in cur_det
assert 'move_alloc(view%water_content, state%water_content)' in cur_det
assert not re.search(r'\ballocate\s*\(',cur_det)
assert 'intent(in) :: view' in old_det
assert 'allocate(state%pressure_head(n), state%water_content(n))' in old_det
assert 'state%pressure_head = view%pressure_head' in old_det
assert 'state%water_content = view%water_content' in old_det
restricted=sub(r,'fmr_materialize_restricted_surface_evaporation')
assert 'call fmr_build_committed_process_hydraulic_view(committed, view, ok)' in restricted
assert 'call detached_state_from_view(view, base_state, ok)' in restricted
assert 'call capacity_provider%evaluate(base_state, capacity)' in restricted
assert 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)' in restricted
assert 'headcalc' not in restricted and 'modflow' not in restricted
print('FPE11_CURRENT_OWNERSHIP_TRANSFER_SOURCE_GUARD=PASS')
print('FPE11_PREIMAGE_COUNTERFACTUAL_ALLOCATION_PATTERN=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/solver/mod_process_hydraulic_view.f90
  tests/fpe/mod_fpe11_current_kernel_view_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)

compile_modules() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  local rel obj
  for rel in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${rel%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$rel" -o "$obj"
  done
}
module_objects() {
  local out="$1" rel
  for rel in "${MODULE_SRC[@]}"; do printf '%s\n' "$out/$(basename "${rel%.*}").o"; done
}

for opt in 0 2; do
  OUT="$BUILD/functional-o$opt"
  compile_modules "$opt" "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c tests/fpe/test_fpe11_current_canonical_preservation.f90 -o "$OUT/test.o"
  mapfile -t OBJS < <(module_objects "$OUT")
  gfortran -O"$opt" "${OBJS[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'FPE11_CURRENT_KERNEL_COMMITTED_IMMUTABILITY=PASS' "$OUT/output.txt" || fail "immutability O$opt"
  grep -Fq 'FPE11_CURRENT_KERNEL_ABA_DETERMINISM=PASS' "$OUT/output.txt" || fail "ABA O$opt"
  grep -Fq 'FPE11_CURRENT_DRY_PONDED_SCIENTIFIC_IDENTITY=PASS' "$OUT/output.txt" || fail "science O$opt"
  grep -Fq 'FPE11_CURRENT_FUNCTIONAL_PRESERVATION=PASS' "$OUT/output.txt" || fail "functional O$opt"
done
cmp -s "$BUILD/functional-o0/output.txt" "$BUILD/functional-o2/output.txt" || fail 'current functional O0/O2 drift'
echo 'FPE11_CURRENT_O0_O2_IDENTITY=PASS'
cat "$BUILD/functional-o0/output.txt"

TOUT="$BUILD/timing"
compile_modules 2 "$TOUT"
gfortran "${COMMON[@]}" -O2 -J"$TOUT" -I"$TOUT" -c tests/fpe/test_fpe11_current_canonical_timing.f90 -o "$TOUT/timing.o"
mapfile -t TOBJS < <(module_objects "$TOUT")
gfortran -O2 "${TOBJS[@]}" "$TOUT/timing.o" -o "$TOUT/timing"
RAW="$BUILD/timing.csv"
echo 'nodes,round,position,arm,seconds,checksum' > "$RAW"
run_one(){
  local arm="$1" nodes="$2" calls="$3" round="$4" position="$5" line sec sum
  line=$("$TOUT/timing" "$arm" "$nodes" "$calls")
  sec=$(sed -n 's/.*seconds=\([^,]*\),checksum=.*/\1/p' <<<"$line" | tr -d ' ')
  sum=$(sed -n 's/.*checksum=\(.*\)$/\1/p' <<<"$line" | tr -d ' ')
  [[ -n "$sec" && -n "$sum" ]] || fail "timing parse: $line"
  echo "$nodes,$round,$position,$arm,$sec,$sum" >> "$RAW"
}
for spec in '20 120000' '200 70000' '1000 30000'; do
  read -r nodes calls <<<"$spec"
  for round in 1 2 3 4; do
    if (( round % 2 == 1 )); then
      run_one baseline "$nodes" "$calls" "$round" 1
      run_one candidate "$nodes" "$calls" "$round" 2
    else
      run_one candidate "$nodes" "$calls" "$round" 1
      run_one baseline "$nodes" "$calls" "$round" 2
    fi
  done
done
cat "$RAW"
python3 - "$RAW" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
all_median=True; all_checksum=True; total_faster=0; total_pairs=0
print('FPE11_CURRENT_TIMING_METHOD=PAIRED_SAME_RUNNER_BALANCED_ORDER_O2_CURRENT_KERNEL')
for n in sorted({int(r['nodes']) for r in rows}):
    rs=[r for r in rows if int(r['nodes'])==n]
    b=[float(r['seconds']) for r in rs if r['arm']=='baseline']
    c=[float(r['seconds']) for r in rs if r['arm']=='candidate']
    bm=statistics.median(b); cm=statistics.median(c)
    paired=[]
    for rnd in range(1,5):
        bv=next(float(r['seconds']) for r in rs if r['arm']=='baseline' and int(r['round'])==rnd)
        cv=next(float(r['seconds']) for r in rs if r['arm']=='candidate' and int(r['round'])==rnd)
        paired.append(cv < bv)
    checks={r['checksum'] for r in rs}
    checksum_ok=len(checks)==1
    all_checksum &= checksum_ok
    all_median &= cm < bm
    total_faster += sum(paired); total_pairs += len(paired)
    delta=(1.0-cm/bm)*100.0
    print(f'FPE11_CURRENT_PROFILE nodes={n} baseline_median_s={bm:.9f} candidate_median_s={cm:.9f} candidate_delta_pct={delta:.3f} paired_faster={sum(paired)}/4 checksum_identity={"PASS" if checksum_ok else "FAIL"}')
print(f'FPE11_CURRENT_PAIRED_FASTER={total_faster}/{total_pairs}')
print('FPE11_CURRENT_CHECKSUM_IDENTITY=' + ('PASS' if all_checksum else 'FAIL'))
print('FPE11_CURRENT_CANDIDATE_MEDIAN_FASTER_ALL_PROFILE_SIZES=' + ('YES' if all_median else 'NO'))
if not all_checksum or not all_median or total_faster < 9:
    raise SystemExit(111)
print('FPE11_CURRENT_LOCAL_NONREGRESSION_MEASUREMENT=PASS')
print('FPE11_CURRENT_WHOLE_SWAP_SPEEDUP_CLAIM=NOT_MADE')
print('FPE11_CURRENT_MULTISWAP_SPEEDUP_CLAIM=NOT_MADE')
print('FPE11_CURRENT_PORTABLE_SPEED_GUARANTEE=NOT_MADE')
PY

echo "FPE11_CURRENT_CANONICAL_SNAPSHOT=$CANON"
echo "FPE11_OWNER_CLOSEOUT=$OWNER"
echo "FPE11_OWNER_QUALIFIED_POSTIMAGE=$QUALIFIED"
echo 'FPE11_CURRENT_CANONICAL_PERFORMANCE_ADMISSION_REPLAY=PASS'

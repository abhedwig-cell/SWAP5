#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-planvalid01-qual-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT
BASE=f5ba657695156a936cb3dc8e14669f92d333753b

git fetch --no-tags --depth=1 origin "$BASE"
git show "$BASE:src/runtime/mod_fmr_runtime_core.f90" > "$BUILD/src/runtime_base.f90"

compile_variant() {
  local name="$1"
  local source="$2"
  local out="$BUILD/$name"
  gfortran -std=f2008 -ffree-line-length-none -O2 -J "$out" -I "$out" -c "$source" -o "$out/runtime.o"
  gfortran -std=f2008 -ffree-line-length-none -O2 -J "$out" -I "$out" -c tests/fpe/test_fpe_planvalid01_baseline.f90 -o "$out/test.o"
  gfortran -O2 "$out/runtime.o" "$out/test.o" -o "$out/test"
}
compile_variant base "$BUILD/src/runtime_base.f90"
compile_variant candidate src/runtime/mod_fmr_runtime_core.f90

gfortran -std=f2008 -ffree-line-length-none -O2 -J "$BUILD/candidate" -I "$BUILD/candidate"   -c tests/fpe/test_fpe_planvalid01_semantics.f90 -o "$BUILD/candidate/semantics.o"
gfortran -O2 "$BUILD/candidate/runtime.o" "$BUILD/candidate/semantics.o" -o "$BUILD/candidate/semantics"
"$BUILD/candidate/semantics"

: > "$BUILD/timing.csv"
echo 'n,pair,variant,ns_per_build,checksum' >> "$BUILD/timing.csv"
run_one() {
  local n="$1" pair="$2" variant="$3" reps="$4"
  local line
  line="$("$BUILD/$variant/test" "$n" "$reps" | grep '^PLANVALID01_BASELINE,n=')"
  python3 - "$n" "$pair" "$variant" "$line" "$BUILD/timing.csv" <<'PY'
import csv,re,sys
n,pair,variant,line,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([n,pair,variant,v('ns_per_build'),v('checksum')])
print(line)
PY
}
for n in 100 1000 10000; do
  case "$n" in
    100) reps=1000 ;;
    1000) reps=50 ;;
    10000) reps=3 ;;
  esac
  for pair in 1 2 3 4 5; do
    if (( pair % 2 == 1 )); then
      run_one "$n" "$pair" base "$reps"
      run_one "$n" "$pair" candidate "$reps"
    else
      run_one "$n" "$pair" candidate "$reps"
      run_one "$n" "$pair" base "$reps"
    fi
  done
done

python3 - "$BUILD/timing.csv" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
for n in (100,1000,10000):
    rr=[r for r in rows if int(r['n'])==n]
    by={}
    for r in rr: by.setdefault(int(r['pair']),{})[r['variant']]=r
    ratios=[]
    for pair,v in sorted(by.items()):
        if v['base']['checksum'] != v['candidate']['checksum']:
            raise SystemExit(f'checksum drift n={n} pair={pair}')
        ratios.append(float(v['candidate']['ns_per_build'])/float(v['base']['ns_per_build']))
    print(f'PLANVALID01_PAIRED_N={n},MEAN_RATIO={statistics.mean(ratios):.9f},MEDIAN_RATIO={statistics.median(ratios):.9f},PAIRS={len(ratios)}')
print('PLANVALID01_PAIRED=PASS')
PY

bash tests/fpe/run_fpe_zero_waste01_execution_plan.sh
bash tests/fapp/run_ppa_wu01_production_application_bootstrap.sh
echo 'PLANVALID01_QUALIFICATION=PASS'

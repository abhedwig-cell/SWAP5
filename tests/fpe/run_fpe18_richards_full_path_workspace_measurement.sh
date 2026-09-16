#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fpe18-full-${GITHUB_RUN_ID:-local}"
OUT="${FPE18_FULL_OUTDIR:-$ROOT/artifacts/fpe18-richards-full-path}"
rm -rf "$BUILD" "$OUT"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

C2_EVIDENCE=integration/f-si/F-SI23_GATE_C2_PHYSICAL_TRANSFER_EVIDENCE.json
DRIVER=tests/fpe/test_fpe18_richards_full_path_workspace_timing.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py

fail() { echo "FPE18_FULL_RUNNER_FAIL $*" >&2; exit 18; }

{
  echo "git_head=$(git rev-parse HEAD)"
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "uname=$(uname -a)"
  gfortran --version | head -n 1 | sed 's/^/gfortran=/'
  python3 --version | sed 's/^/python=/'
  if command -v lscpu >/dev/null 2>&1; then lscpu; fi
} > "$OUT/metadata.txt"

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
GENERATOR_BLOB=$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")
echo "fsi18_generator_blob=$GENERATOR_BLOB" >> "$OUT/metadata.txt"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi

test -f "$C2_EVIDENCE" || fail 'F-SI23 C2 evidence missing'
python3 - "$C2_EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
src,out=sys.argv[1:]
d=json.load(open(src))
rows=d['rows']
if len(rows)!=15:
    raise SystemExit('expected 15 F-SI23 C2 rows')
with open(out,'w') as f:
    for r in rows:
        f.write(f"{r['case']}\t{r['h0_cm']:.17e}\t{r['jump_cm']:.17e}\n")
PY

COMMON=(-std=f2008 -ffree-line-length-none)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

build_bench() {
  local tag="$1"; shift
  local flags=("$@")
  local b="$BUILD/$tag"
  mkdir -p "$b"
  local objects=()
  local idx=0
  for src in "${MODULE_SRC[@]}"; do
    idx=$((idx+1))
    local obj="$b/mod_${idx}.o"
    gfortran "${COMMON[@]}" "${flags[@]}" -J"$b" -I"$b" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "${flags[@]}" -J"$b" -I"$b" -c "$DRIVER" -o "$b/driver.o"
  gfortran "${flags[@]}" "${objects[@]}" "$b/driver.o" -o "$b/bench.exe"
}

# Strict source-bound equivalence pass.
build_bench strict -O0 -g -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow
while IFS=$'\t' read -r cid h0 jump; do
  timeout 120s "$BUILD/strict/bench.exe" verify "$h0" "$jump" 1 1 > "$OUT/strict_case_${cid}.txt" 2>&1 || {
    cat "$OUT/strict_case_${cid}.txt" >&2
    fail "strict equivalence case=$cid"
  }
  grep -Fq 'FPE18_FULL_EQUIVALENCE=PASS' "$OUT/strict_case_${cid}.txt" || fail "strict PASS marker case=$cid"
done < "$BUILD/cases.tsv"
echo 'FPE18_FULL_STRICT_15_CASE_EQUIVALENCE=PASS'

build_bench O0 -O0
build_bench O2 -O2

for opt in O0 O2; do
  while IFS=$'\t' read -r cid h0 jump; do
    timeout 120s "$BUILD/$opt/bench.exe" verify "$h0" "$jump" 1 1 > "$OUT/${opt}_verify_case_${cid}.txt" 2>&1 || {
      cat "$OUT/${opt}_verify_case_${cid}.txt" >&2
      fail "$opt equivalence case=$cid"
    }
    grep -Fq 'FPE18_FULL_EQUIVALENCE=PASS' "$OUT/${opt}_verify_case_${cid}.txt" || fail "$opt PASS marker case=$cid"
  done < "$BUILD/cases.tsv"
done
for cid in $(seq 1 15); do
  cmp "$OUT/O0_verify_case_${cid}.txt" "$OUT/O2_verify_case_${cid}.txt" || {
    diff -u "$OUT/O0_verify_case_${cid}.txt" "$OUT/O2_verify_case_${cid}.txt" >&2 || true
    fail "O0/O2 verify drift case=$cid"
  }
done
echo 'FPE18_FULL_O0_O2_15_CASE_IDENTITY=PASS'

RAW="$OUT/raw_timing.csv"
echo 'optimization,case,h0,jump,calls,warmup,round,position,arm,wall_s,cpu_s,checksum,mass' > "$RAW"

run_one() {
  local opt="$1" cid="$2" h0="$3" jump="$4" arm="$5" calls="$6" warmup="$7" round="$8" position="$9"
  local line wall cpu checksum mass
  line=$(timeout 120s "$BUILD/$opt/bench.exe" "$arm" "$h0" "$jump" "$calls" "$warmup") || fail "timing execution opt=$opt case=$cid arm=$arm"
  wall=$(sed -n 's/.*wall_s=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  cpu=$(sed -n 's/.*cpu_s=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  checksum=$(sed -n 's/.*checksum=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  mass=$(sed -n 's/.*mass=\(.*\)$/\1/p' <<<"$line" | tr -d ' ')
  [[ -n "$wall" && -n "$cpu" && -n "$checksum" && -n "$mass" ]] || fail "timing parse opt=$opt case=$cid arm=$arm line=$line"
  echo "$opt,$cid,$h0,$jump,$calls,$warmup,$round,$position,$arm,$wall,$cpu,$checksum,$mass" >> "$RAW"
}

# Cases 5, 10 and 15 are the +0.1 cm endpoint of each of the three frozen
# hydraulic-state groups. They are existing F-SI24 cases, not new benchmark physics.
CALLS=2500
WARMUP=20
for opt in O0 O2; do
  for cid in 5 10 15; do
    row=$(awk -F '\t' -v id="$cid" '$1==id {print $0}' "$BUILD/cases.tsv")
    [[ -n "$row" ]] || fail "timing case $cid missing"
    IFS=$'\t' read -r _ h0 jump <<<"$row"
    for round in 1 2 3 4 5 6; do
      if (( round % 2 == 1 )); then
        run_one "$opt" "$cid" "$h0" "$jump" fresh "$CALLS" "$WARMUP" "$round" 1
        run_one "$opt" "$cid" "$h0" "$jump" reuse "$CALLS" "$WARMUP" "$round" 2
      else
        run_one "$opt" "$cid" "$h0" "$jump" reuse "$CALLS" "$WARMUP" "$round" 1
        run_one "$opt" "$cid" "$h0" "$jump" fresh "$CALLS" "$WARMUP" "$round" 2
      fi
    done
  done
done

cat "$RAW"
python3 - "$RAW" "$OUT/summary.json" <<'PY'
import csv,json,statistics,sys
raw,summary_path=sys.argv[1:]
rows=list(csv.DictReader(open(raw,newline='')))
if len(rows)!=72:
    raise SystemExit(f'expected 72 timing rows, got {len(rows)}')
summary={'method':'fsi24_frozen_cases_paired_fresh_vs_reused_reference_richards_legacy_workspace','profiles':[]}
all_exact=True
for opt in ('O0','O2'):
    for cid in (5,10,15):
        rs=[r for r in rows if r['optimization']==opt and int(r['case'])==cid]
        fresh=[r for r in rs if r['arm']=='fresh']
        reuse=[r for r in rs if r['arm']=='reuse']
        if len(fresh)!=6 or len(reuse)!=6:
            raise SystemExit(f'incomplete profile {opt} case {cid}')
        exact=True
        paired_faster=[]
        paired_cpu_faster=[]
        for rnd in range(1,7):
            f=next(r for r in fresh if int(r['round'])==rnd)
            u=next(r for r in reuse if int(r['round'])==rnd)
            if float(f['checksum']) != float(u['checksum']) or float(f['mass']) != float(u['mass']):
                exact=False
            paired_faster.append(float(u['wall_s']) < float(f['wall_s']))
            paired_cpu_faster.append(float(u['cpu_s']) < float(f['cpu_s']))
        all_exact &= exact
        fw=[float(r['wall_s']) for r in fresh]; rw=[float(r['wall_s']) for r in reuse]
        fc=[float(r['cpu_s']) for r in fresh]; rc=[float(r['cpu_s']) for r in reuse]
        fwm,rwm=statistics.median(fw),statistics.median(rw)
        fcm,rcm=statistics.median(fc),statistics.median(rc)
        item={
          'optimization':opt,'case':cid,'h0':float(rs[0]['h0']),'jump':float(rs[0]['jump']),
          'calls':int(rs[0]['calls']),'warmup':int(rs[0]['warmup']),
          'scientific_checksum_and_mass_identity':exact,
          'fresh_wall_median_s':fwm,'reuse_wall_median_s':rwm,
          'fresh_over_reuse_wall':fwm/rwm,
          'reuse_wall_delta_percent':(1.0-rwm/fwm)*100.0,
          'reuse_faster_wall_rounds':sum(paired_faster),
          'fresh_cpu_median_s':fcm,'reuse_cpu_median_s':rcm,
          'fresh_over_reuse_cpu':fcm/rcm if rcm>0 else None,
          'reuse_cpu_delta_percent':(1.0-rcm/fcm)*100.0 if fcm>0 else None,
          'reuse_faster_cpu_rounds':sum(paired_cpu_faster),
          'fresh_wall_samples_s':fw,'reuse_wall_samples_s':rw,
        }
        summary['profiles'].append(item)
        print('FPE18_FULL_PROFILE '
              f'opt={opt} case={cid} h0={item["h0"]:.6g} jump={item["jump"]:.6g} '
              f'fresh_wall_median_s={fwm:.9f} reuse_wall_median_s={rwm:.9f} '
              f'fresh_over_reuse_wall={item["fresh_over_reuse_wall"]:.6f} '
              f'reuse_wall_delta_pct={item["reuse_wall_delta_percent"]:.3f} '
              f'reuse_faster_wall_rounds={sum(paired_faster)}/6 '
              f'fresh_cpu_median_s={fcm:.9f} reuse_cpu_median_s={rcm:.9f} '
              f'exact={"PASS" if exact else "FAIL"}')
summary['all_timed_checksum_and_mass_identity']=all_exact
with open(summary_path,'w') as f: json.dump(summary,f,indent=2,sort_keys=True)
print('FPE18_FULL_TIMED_SCIENTIFIC_IDENTITY=' + ('PASS' if all_exact else 'FAIL'))
print('FPE18_FULL_MEASUREMENT_COMPLETE=PASS')
print('FPE18_WHOLE_MODEL_SPEEDUP_CLAIM=NOT_MADE')
if not all_exact:
    raise SystemExit(18)
PY

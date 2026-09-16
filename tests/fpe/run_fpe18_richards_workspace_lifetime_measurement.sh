#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-/tmp}/fpe18-workspace-${GITHUB_RUN_ID:-local}"
OUT="${FPE18_OUTDIR:-$ROOT/artifacts/fpe18-workspace-lifetime}"
rm -rf "$BUILD" "$OUT"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

{
  echo "git_head=$(git rev-parse HEAD)"
  echo "utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "uname=$(uname -a)"
  gfortran --version | head -n 1 | sed 's/^/gfortran=/'
  if command -v lscpu >/dev/null 2>&1; then
    lscpu
  fi
} > "$OUT/metadata.txt"

compile_bench() {
  local opt="$1" extra="$2"
  local b="$BUILD/$opt"
  mkdir -p "$b"
  gfortran -std=f2008 -ffree-line-length-none $extra -J"$b" -I"$b" \
    -c src/solver/mod_soil_water_solver_contract.f90 -o "$b/contract.o"
  gfortran -std=f2008 -ffree-line-length-none $extra -J"$b" -I"$b" \
    -c src/solver/mod_reference_richards_workspace.f90 -o "$b/workspace.o"
  gfortran -std=f2008 -ffree-line-length-none $extra -J"$b" -I"$b" \
    -c tests/fpe/test_fpe18_richards_workspace_lifetime_timing.f90 -o "$b/bench.o"
  gfortran $extra "$b/contract.o" "$b/workspace.o" "$b/bench.o" -o "$b/bench.exe"
}

# Fail fast on bounds/runtime errors independently of the timing builds.
compile_bench strict "-O0 -g -fcheck=all -fbacktrace"
"$BUILD/strict/bench.exe" fresh 13 20 3 > "$OUT/strict-fresh.txt"
"$BUILD/strict/bench.exe" reuse 13 20 3 > "$OUT/strict-reuse.txt"

compile_bench O0 "-O0"
compile_bench O2 "-O2"

RAW="$OUT/raw.csv"
echo 'optimization,nodes,calls,warmup,round,position,arm,wall_s,cpu_s,payload_bytes,touch' > "$RAW"

run_one() {
  local opt="$1" arm="$2" nodes="$3" calls="$4" warmup="$5" round="$6" position="$7"
  local line wall cpu payload touch
  line=$("$BUILD/$opt/bench.exe" "$arm" "$nodes" "$calls" "$warmup")
  wall=$(sed -n 's/.*wall_s=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  cpu=$(sed -n 's/.*cpu_s=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  payload=$(sed -n 's/.*payload_bytes=\([^,]*\).*/\1/p' <<<"$line" | tr -d ' ')
  touch=$(sed -n 's/.*touch=\(.*\)$/\1/p' <<<"$line" | tr -d ' ')
  [[ -n "$wall" && -n "$cpu" && -n "$payload" && -n "$touch" ]] || {
    echo "FPE18_TIMING_PARSE_FAIL $line" >&2
    exit 18
  }
  echo "$opt,$nodes,$calls,$warmup,$round,$position,$arm,$wall,$cpu,$payload,$touch" >> "$RAW"
}

# Each profile targets roughly comparable reset work while changing allocation
# object sizes. Process order is balanced fresh/reuse | reuse/fresh.
for opt in O0 O2; do
  for spec in '20 40000' '100 8000' '500 1600'; do
    read -r nodes calls <<<"$spec"
    warmup=50
    for round in 1 2 3 4; do
      if (( round % 2 == 1 )); then
        run_one "$opt" fresh "$nodes" "$calls" "$warmup" "$round" 1
        run_one "$opt" reuse "$nodes" "$calls" "$warmup" "$round" 2
      else
        run_one "$opt" reuse "$nodes" "$calls" "$warmup" "$round" 1
        run_one "$opt" fresh "$nodes" "$calls" "$warmup" "$round" 2
      fi
    done
  done
done

cat "$RAW"
python3 - "$RAW" "$OUT/summary.json" <<'PY'
import csv, json, statistics, sys
raw_path, summary_path = sys.argv[1:]
rows = list(csv.DictReader(open(raw_path, newline='')))
if not rows:
    raise SystemExit('FPE18 no timing rows')
summary = {
    'method': 'paired_same_runner_balanced_order_fresh_vs_steady_state_reuse',
    'profiles': [],
}
all_payload_identity = True
all_touch_zero = True
for opt in ('O0', 'O2'):
    for nodes in sorted({int(r['nodes']) for r in rows if r['optimization'] == opt}):
        rs = [r for r in rows if r['optimization'] == opt and int(r['nodes']) == nodes]
        fresh_wall = [float(r['wall_s']) for r in rs if r['arm'] == 'fresh']
        reuse_wall = [float(r['wall_s']) for r in rs if r['arm'] == 'reuse']
        fresh_cpu = [float(r['cpu_s']) for r in rs if r['arm'] == 'fresh']
        reuse_cpu = [float(r['cpu_s']) for r in rs if r['arm'] == 'reuse']
        payloads = {int(r['payload_bytes']) for r in rs}
        touches = [float(r['touch']) for r in rs]
        payload_ok = len(payloads) == 1
        touch_ok = all(v == 0.0 for v in touches)
        all_payload_identity &= payload_ok
        all_touch_zero &= touch_ok
        fwm, rwm = statistics.median(fresh_wall), statistics.median(reuse_wall)
        fcm, rcm = statistics.median(fresh_cpu), statistics.median(reuse_cpu)
        paired_wall = []
        paired_cpu = []
        for rnd in range(1, 5):
            fw = next(float(r['wall_s']) for r in rs if r['arm']=='fresh' and int(r['round'])==rnd)
            rw = next(float(r['wall_s']) for r in rs if r['arm']=='reuse' and int(r['round'])==rnd)
            fc = next(float(r['cpu_s']) for r in rs if r['arm']=='fresh' and int(r['round'])==rnd)
            rc = next(float(r['cpu_s']) for r in rs if r['arm']=='reuse' and int(r['round'])==rnd)
            paired_wall.append(rw < fw)
            paired_cpu.append(rc < fc)
        item = {
            'optimization': opt,
            'nodes': nodes,
            'calls': int(rs[0]['calls']),
            'warmup': int(rs[0]['warmup']),
            'payload_bytes': next(iter(payloads)) if payload_ok else sorted(payloads),
            'payload_identity': payload_ok,
            'touch_zero': touch_ok,
            'fresh_wall_median_s': fwm,
            'reuse_wall_median_s': rwm,
            'fresh_over_reuse_wall': fwm / rwm,
            'reuse_wall_delta_percent': (1.0 - rwm / fwm) * 100.0,
            'reuse_faster_wall_rounds': sum(paired_wall),
            'fresh_cpu_median_s': fcm,
            'reuse_cpu_median_s': rcm,
            'fresh_over_reuse_cpu': fcm / rcm if rcm > 0.0 else None,
            'reuse_cpu_delta_percent': (1.0 - rcm / fcm) * 100.0 if fcm > 0.0 else None,
            'reuse_faster_cpu_rounds': sum(paired_cpu),
        }
        summary['profiles'].append(item)
        print(
            'FPE18_PROFILE_RESULT '
            f'opt={opt} nodes={nodes} payload_bytes={item["payload_bytes"]} '
            f'fresh_wall_median_s={fwm:.9f} reuse_wall_median_s={rwm:.9f} '
            f'fresh_over_reuse_wall={item["fresh_over_reuse_wall"]:.6f} '
            f'reuse_wall_delta_pct={item["reuse_wall_delta_percent"]:.3f} '
            f'reuse_faster_wall_rounds={sum(paired_wall)}/4 '
            f'fresh_cpu_median_s={fcm:.9f} reuse_cpu_median_s={rcm:.9f} '
            f'payload_identity={"PASS" if payload_ok else "FAIL"} '
            f'touch_zero={"PASS" if touch_ok else "FAIL"}'
        )
summary['payload_identity_all_profiles'] = all_payload_identity
summary['touch_zero_all_profiles'] = all_touch_zero
with open(summary_path, 'w') as f:
    json.dump(summary, f, indent=2, sort_keys=True)
print('FPE18_PAYLOAD_IDENTITY=' + ('PASS' if all_payload_identity else 'FAIL'))
print('FPE18_RESET_TOUCH_ZERO=' + ('PASS' if all_touch_zero else 'FAIL'))
print('FPE18_MEASUREMENT_COMPLETE=PASS')
print('FPE18_PRODUCTION_SPEEDUP_CLAIM=NOT_MADE')
if not all_payload_identity or not all_touch_zero:
    raise SystemExit(18)
PY

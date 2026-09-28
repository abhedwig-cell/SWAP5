#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=1759caebb7ca3bd62bbee65d9319f5d71d3e73f5
CORR_PARENT=d269ca78758f36ef2bcc3719761134a8ae919881
PREREG=docs/verification/evidence/F-PE-BOFEK00_ADAPTIVE_PREREGISTRATION.json
TARGET=tests/verification/test_bofek00_adaptive_wet_trajectory.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-adaptive-${GITHUB_RUN_ID:-local}-$$"
BASEWT="$WORK/base"
BUILD="$WORK/build"
mkdir -p "$WORK" "$BUILD"
trap 'git worktree remove --force "$BASEWT" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
fail(){ echo "F_PE_BOFEK00_ADAPTIVE_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after preregistration: $LIVE"
git merge-base --is-ancestor "$CORR_PARENT" HEAD || fail "adaptive branch lost frozen correctness parent"
grep -Fq '"policy_code_changes_allowed": false' "$PREREG" || fail "adaptive policy firewall missing"
grep -Fq '"numbit_crit": 4' "$PREREG" || fail "adaptive fixture prereg drift"

git worktree add --detach "$BASEWT" "$BASE" >/dev/null
mkdir -p "$BASEWT/tests/verification"
cp "$TARGET" "$BASEWT/$TARGET"

build_one(){
  local root="$1" label="$2" out="$BUILD/$2"
  local stubrel="tests/verification/.bofek00_adaptive_stub_${label}.f90"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$root/$stubrel" --nodes 16 --dz-cm 10
  python3 "$COMPILER" --root "$root" --stub "$stubrel" --target "$TARGET"     --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt 2
  OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/rom0_test" > "$BUILD/${label}.txt" 2>&1 || {
    cat "$BUILD/${label}.txt" >&2
    fail "${label} adaptive trajectory failed"
  }
  grep -Fq 'F_PE_BOFEK00_ADAPTIVE_TRAJECTORY=PASS' "$BUILD/${label}.txt" || fail "${label} PASS marker absent"
}

build_one "$BASEWT" baseline
build_one "$ROOT" corrected

echo "=== ADAPTIVE BASELINE ==="; cat "$BUILD/baseline.txt"
echo "=== ADAPTIVE CORRECTED ==="; cat "$BUILD/corrected.txt"

python3 - "$BUILD/baseline.txt" "$BUILD/corrected.txt" "$BUILD/baseline/rom0_test" "$BUILD/corrected/rom0_test" <<'PY'
import json,statistics,subprocess,sys,time

def parse(path):
    accepts=[]; rejects=[]; end=None
    for raw in open(path):
        line=raw.strip()
        if line.startswith("F_PE_BOFEK00_ADAPT_ACCEPT|"):
            d=dict(x.split("=",1) for x in line.split("|")[1:])
            accepts.append(d)
        elif line.startswith("F_PE_BOFEK00_ADAPT_REJECT|"):
            d=dict(x.split("=",1) for x in line.split("|")[1:])
            rejects.append(d)
        elif line.startswith("F_PE_BOFEK00_ADAPTIVE_END|"):
            end=dict(x.split("=",1) for x in line.split("|")[1:])
    if end is None:
        raise SystemExit("missing adaptive end record")
    return accepts,rejects,end

def timing(exe,n=9):
    vals=[]
    for _ in range(n):
        t0=time.perf_counter_ns()
        subprocess.run([exe],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,env={"OMP_NUM_THREADS":"1","OMP_DYNAMIC":"false"})
        vals.append((time.perf_counter_ns()-t0)/1e6)
    return {"median_ms":statistics.median(vals),"min_ms":min(vals),"max_ms":max(vals),"n":n}

ba,br,be=parse(sys.argv[1]); ca,cr,ce=parse(sys.argv[2])
assert abs(float(be["T"])-0.12) <= 1e-12
assert abs(float(ce["T"])-0.12) <= 1e-12
assert max(abs(float(x["LEDGER"])) for x in ba) <= 5e-8
assert max(abs(float(x["LEDGER"])) for x in ca) <= 5e-8
out={
 "policy":{"dt0":0.005,"dtmin":0.000625,"dtmax":0.02,"numbit_crit":4,"maxit":20,"fact_up":1.5,"fact_down":0.5,"fact_retry":2.0},
 "baseline":{
   "accepted_steps":int(be["ACCEPTED"]),"rejected_attempts":int(be["REJECTED"]),"reductions":int(be["REDUCTIONS"]),
   "growth_events":int(be["GROWTH"]),"nonlinear_iterations":int(be["NL"]),"backtracks":int(be["BACK"]),
   "cum_runoff":float(be["CUM_RUNOFF"]),"top_h":float(be["TOP_H"]),"pond":float(be["POND"]),
   "dt_sequence":[float(x["DT"]) for x in ba],
   "max_abs_ledger":max(abs(float(x["LEDGER"])) for x in ba)
 },
 "corrected":{
   "accepted_steps":int(ce["ACCEPTED"]),"rejected_attempts":int(ce["REJECTED"]),"reductions":int(ce["REDUCTIONS"]),
   "growth_events":int(ce["GROWTH"]),"nonlinear_iterations":int(ce["NL"]),"backtracks":int(ce["BACK"]),
   "cum_runoff":float(ce["CUM_RUNOFF"]),"top_h":float(ce["TOP_H"]),"pond":float(ce["POND"]),
   "dt_sequence":[float(x["DT"]) for x in ca],
   "max_abs_ledger":max(abs(float(x["LEDGER"])) for x in ca)
 },
 "delta":{"runoff":float(ce["CUM_RUNOFF"])-float(be["CUM_RUNOFF"]),"top_h":float(ce["TOP_H"])-float(be["TOP_H"]),"pond":float(ce["POND"])-float(be["POND"])},
 "runtime_observation":{"classification":"NON_BENCHMARK_CI_PROCESS_WALL_TIME","baseline":timing(sys.argv[3]),"corrected":timing(sys.argv[4])}
}
print("F_PE_BOFEK00_ADAPTIVE_COMPARISON="+json.dumps(out,sort_keys=True,separators=(",",":")))
PY

echo "F_PE_BOFEK00_ADAPTIVE_POLICY_CHANGED=FALSE"
echo "F_PE_BOFEK00_ADAPTIVE_INTERACTION_GATE=PASS"

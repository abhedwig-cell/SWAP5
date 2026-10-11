#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=1759caebb7ca3bd62bbee65d9319f5d71d3e73f5
TARGET=tests/verification/test_bofek00_adaptive_wet_trajectory.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-adaptive-${GITHUB_RUN_ID:-local}-$$"
BASEWT="$WORK/base"; BUILD="$WORK/build"
mkdir -p "$WORK" "$BUILD"
trap 'git worktree remove --force "$BASEWT" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
fail(){ echo "F_PE_BOFEK00_ADAPTIVE_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after adaptive preregistration: $LIVE"

# Source-bind the replay to current canonical TimeControl's active decision core.
grep -Fq "if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)" src/legacy/b1_10_fci11_port/timecontrol_part04.inc || fail "growth policy drift"
grep -Fq "if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)" src/legacy/b1_10_fci11_port/timecontrol_part04.inc || fail "accepted reduction policy drift"
grep -Fq "dt = dt / fact_dt_fldect" src/legacy/b1_10_fci11_port/timecontrol_part05.inc || fail "nonconvergence reduction policy drift"
echo "F_PE_BOFEK00_TIMECONTROL_SOURCE_GUARD=PASS"

git worktree add --detach "$BASEWT" "$BASE" >/dev/null
mkdir -p "$BASEWT/tests/verification"
cp "$TARGET" "$BASEWT/$TARGET"

build_one(){
  local root="$1" label="$2" out="$BUILD/$2"
  local stubrel="tests/verification/.bofek00_adaptive_stub_${label}.f90"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$root/$stubrel" --nodes 16 --dz-cm 10
  python3 "$COMPILER" --root "$root" --stub "$stubrel" --target "$TARGET" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt 2
  /usr/bin/time -f "%e" -o "$BUILD/${label}.time" env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/rom0_test" > "$BUILD/${label}.txt" 2>&1 || {
    cat "$BUILD/${label}.txt" >&2; fail "$label adaptive trajectory"
  }
  grep -Fq "F_PE_BOFEK00_ADAPTIVE_TRAJECTORY=PASS" "$BUILD/${label}.txt" || fail "$label PASS marker absent"
}

build_one "$BASEWT" baseline
build_one "$ROOT" corrected
echo "=== ADAPTIVE BASELINE ==="; cat "$BUILD/baseline.txt"
echo "=== ADAPTIVE CORRECTED ==="; cat "$BUILD/corrected.txt"

python3 - "$BUILD/baseline.txt" "$BUILD/corrected.txt" "$BUILD/baseline.time" "$BUILD/corrected.time" <<'PY'
import json,sys
def parse(path):
    attempts=[]; accepts=[]; end=None; begin=None
    for line in open(path):
        line=line.strip()
        if line.startswith("F_PE_BOFEK00_ADAPTIVE_BEGIN|"): begin=dict(x.split("=",1) for x in line.split("|")[1:])
        elif line.startswith("F_PE_BOFEK00_ADAPTIVE_ATTEMPT|"): attempts.append(dict(x.split("=",1) for x in line.split("|")[1:]))
        elif line.startswith("F_PE_BOFEK00_ADAPTIVE_ACCEPT|"): accepts.append(dict(x.split("=",1) for x in line.split("|")[1:]))
        elif line.startswith("F_PE_BOFEK00_ADAPTIVE_END|"): end=dict(x.split("=",1) for x in line.split("|")[1:])
    assert begin and end and accepts
    return begin,attempts,accepts,end
b0,ba,bc,be=parse(sys.argv[1]); c0,ca,cc,ce=parse(sys.argv[2])
policy_keys=["DTMIN","DTMAX","DT0","NUMBIT_CRIT","MAXIT","FACT_INC","FACT_DEC","FACT_FAIL"]
assert all(b0[k]==c0[k] for k in policy_keys)
assert abs(float(be["TIME"])-0.12)<=1e-13 and abs(float(ce["TIME"])-0.12)<=1e-13
out={
 "policy":{k:b0[k] for k in policy_keys},
 "baseline":{
  "attempts":int(be["ATTEMPTS"]),"accepted":int(be["ACCEPTED"]),"rejected":int(be["REJECTED"]),
  "growths":int(be["GROWTHS"]),"reductions":int(be["REDUCTIONS"]),"nonlinear_iterations":int(be["TOTAL_NL"]),
  "backtracks":int(be["TOTAL_BACK"]),"cum_runoff":float(be["CUM_RUNOFF"]),"top_h":float(be["TOP_H"]),
  "pond":float(be["POND"]),"max_abs_ledger":float(be["MAX_ABS_LEDGER"]),
  "accepted_dt":[float(x["DT"]) for x in bc],"wall_seconds":float(open(sys.argv[3]).read().strip())},
 "corrected":{
  "attempts":int(ce["ATTEMPTS"]),"accepted":int(ce["ACCEPTED"]),"rejected":int(ce["REJECTED"]),
  "growths":int(ce["GROWTHS"]),"reductions":int(ce["REDUCTIONS"]),"nonlinear_iterations":int(ce["TOTAL_NL"]),
  "backtracks":int(ce["TOTAL_BACK"]),"cum_runoff":float(ce["CUM_RUNOFF"]),"top_h":float(ce["TOP_H"]),
  "pond":float(ce["POND"]),"max_abs_ledger":float(ce["MAX_ABS_LEDGER"]),
  "accepted_dt":[float(x["DT"]) for x in cc],"wall_seconds":float(open(sys.argv[4]).read().strip())},
}
out["runoff_delta"]=out["corrected"]["cum_runoff"]-out["baseline"]["cum_runoff"]
out["terminal_head_delta"]=out["corrected"]["top_h"]-out["baseline"]["top_h"]
print("F_PE_BOFEK00_ADAPTIVE_COMPARISON="+json.dumps(out,sort_keys=True,separators=(",",":")))
PY
echo "F_PE_BOFEK00_ADAPTIVE_COMPARISON_GATE=PASS"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=0b67e2af993f16e9d1678b70cacfe9b164954140
TARGET=tests/verification/test_bofek00_adaptive_wet_application.f90
COMPILER="$ROOT/tests/rom/compile_f_rom0_fortran_closure.py"
MATERIALIZER="$ROOT/tests/rom/materialize_f_rom0_headcalc_stubs.py"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-adaptive-${GITHUB_RUN_ID:-local}-$$"
OLD="$BUILD/old"
mkdir -p "$BUILD"
trap 'git worktree remove --force "$OLD" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_ADAPTIVE_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin "$AUTH"
git merge-base --is-ancestor "$AUTH" HEAD || fail "candidate lost frozen reproduction ancestry"
git worktree add --detach "$OLD" "$AUTH" >/dev/null
mkdir -p "$OLD/tests/verification"
cp "$TARGET" "$OLD/$TARGET"

run_one(){
  local label="$1"
  local root="$2"
  local out="$BUILD/$label"
  mkdir -p "$out"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$out/stubs.f90" --nodes 16 --dz-cm 10
  cp "$out/stubs.f90" "$root/tests/verification/bofek00_generated_stubs.f90"
  python3 "$COMPILER" --root "$root"     --stub tests/verification/bofek00_generated_stubs.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --target "$TARGET" --build "$out/compile" --opt 2
  : > "$out/times.txt"
  for rep in 1 2 3 4 5; do
    /usr/bin/time -f '%e' -o "$out/time.txt" "$out/compile/rom0_test" > "$out/result.txt" 2>&1 || {
      cat "$out/result.txt" >&2
      fail "$label runtime"
    }
    grep -Fq 'F_PE_BOFEK00_ADAPTIVE_WET_APPLICATION=PASS' "$out/result.txt" || fail "$label missing pass marker"
    cat "$out/time.txt" >> "$out/times.txt"
  done
  rm -f "$root/tests/verification/bofek00_generated_stubs.f90"
}

run_one old "$OLD"
run_one corrected "$ROOT"

python3 - "$BUILD/old/result.txt" "$BUILD/corrected/result.txt" "$BUILD/old/times.txt" "$BUILD/corrected/times.txt" "$BUILD/summary.json" <<'PY'
import json,statistics,sys
from pathlib import Path

def parse_result(path):
    line=next(x for x in Path(path).read_text().splitlines() if x.startswith("BOFEK00_ADAPTIVE|"))
    row={}
    ints={"ACCEPTED_SUBSTEPS","SOLVER_ITERATIONS","NONLINEAR","INTERNAL_RETRIES","HEADCALC_CALLS",
          "JACOBIAN_BUILDS","LINEAR_SOLVES","BACKTRACK","ALT_SOLVER"}
    for item in line.split("|")[1:]:
        k,v=item.split("=",1)
        row[k]=int(float(v)) if k in ints else float(v)
    return row

def med(path):
    vals=[float(x) for x in Path(path).read_text().splitlines() if x.strip()]
    return statistics.median(vals)

old=parse_result(sys.argv[1]); new=parse_result(sys.argv[2])
out={
 "work_unit":"F-PE-BOFEK00F",
 "policy":{
   "temporal_mode":"TX_TEMPORAL_EXTERNAL_FULL_HALF",
   "temporal_tolerance":1e-6,
   "retry_scale":0.5,
   "max_retries":8,
   "max_committed_substeps":256,
   "identical_old_corrected":True
 },
 "old":old | {"runtime_median_seconds_5_runs":med(sys.argv[3])},
 "corrected":new | {"runtime_median_seconds_5_runs":med(sys.argv[4])}
}
out["delta"]={
 "accepted_substeps":new["ACCEPTED_SUBSTEPS"]-old["ACCEPTED_SUBSTEPS"],
 "nonlinear_iterations":new["NONLINEAR"]-old["NONLINEAR"],
 "internal_retries":new["INTERNAL_RETRIES"]-old["INTERNAL_RETRIES"],
 "headcalc_calls":new["HEADCALC_CALLS"]-old["HEADCALC_CALLS"],
 "backtracking_attempts":new["BACKTRACK"]-old["BACKTRACK"],
 "mass_residual":new["MASS_RESIDUAL"]-old["MASS_RESIDUAL"],
 "total_in":new["TOTAL_IN"]-old["TOTAL_IN"],
 "total_out":new["TOTAL_OUT"]-old["TOTAL_OUT"],
 "runtime_median_seconds":out["corrected"]["runtime_median_seconds_5_runs"]-out["old"]["runtime_median_seconds_5_runs"]
}
Path(sys.argv[5]).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
print(json.dumps(out,indent=2,sort_keys=True))
assert abs(old["MASS_RESIDUAL"]) <= 1e-8
assert abs(new["MASS_RESIDUAL"]) <= 1e-8
print("F_PE_BOFEK00_ADAPTIVE_COMPARISON=PASS")
PY

cat "$BUILD/summary.json"
echo "F_PE_BOFEK00_ADAPTIVE_GATE=PASS"

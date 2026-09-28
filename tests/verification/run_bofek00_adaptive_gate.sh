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
  : > "$out/status.txt"
  for rep in 1 2 3 4 5; do
    set +e
    /usr/bin/time -f '%e' -o "$out/time.txt" "$out/compile/rom0_test" > "$out/result.txt" 2>&1
    rc=$?
    set -e
    echo "$rc" >> "$out/status.txt"
    cat "$out/time.txt" >> "$out/times.txt"
  done
  rm -f "$root/tests/verification/bofek00_generated_stubs.f90"
}

run_one old "$OLD"
run_one corrected "$ROOT"

cp "$BUILD/old/status.txt" "$BUILD/old/times.txt.status"
cp "$BUILD/corrected/status.txt" "$BUILD/corrected/times.txt.status"
python3 - "$BUILD/old/result.txt" "$BUILD/corrected/result.txt" "$BUILD/old/times.txt" "$BUILD/corrected/times.txt" "$BUILD/summary.json" <<'PY'
import json,statistics,sys
from pathlib import Path

def parse_result(path, status_path):
    lines=Path(path).read_text().splitlines()
    rc=[int(x) for x in Path(status_path).read_text().splitlines() if x.strip()]
    row={"PROCESS_EXIT_CODES":rc, "PROCESS_SUCCESS":all(x==0 for x in rc)}
    final=next((x for x in lines if x.startswith("BOFEK00_ADAPTIVE|")), None)
    pre=next((x for x in lines if x.startswith("BOFEK00_ADAPTIVE_PRECHECK|")), None)
    status=next((x for x in lines if x.startswith("BOFEK00_ADAPTIVE_STATUS=")), None)
    if status is not None:
        row["APP_STATUS"]=int(status.split("=",1)[1])
    line=final if final is not None else pre
    if line is None:
        raise RuntimeError(f"no adaptive diagnostic line in {path}")
    ints={"ACCEPTED_SUBSTEPS","SOLVER_ITERATIONS","NONLINEAR","INTERNAL_RETRIES","HEADCALC_CALLS",
          "JACOBIAN_BUILDS","LINEAR_SOLVES","BACKTRACK","ALT_SOLVER"}
    for item in line.split("|")[1:]:
        k,v=item.split("=",1)
        if v in {"T","F"}:
            row[k]=(v=="T")
        else:
            row[k]=int(float(v)) if k in ints or k in {"KERNEL_STATUS"} else float(v)
    return row

def med(path):
    vals=[float(x) for x in Path(path).read_text().splitlines() if x.strip()]
    return statistics.median(vals)

old=parse_result(sys.argv[1], sys.argv[3]+".status"); new=parse_result(sys.argv[2], sys.argv[4]+".status")
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
 "accepted_substeps":new.get("ACCEPTED_SUBSTEPS",0)-old.get("ACCEPTED_SUBSTEPS",0),
 "nonlinear_iterations":new.get("NONLINEAR",0)-old.get("NONLINEAR",0),
 "internal_retries":new.get("INTERNAL_RETRIES",0)-old.get("INTERNAL_RETRIES",0),
 "headcalc_calls":new.get("HEADCALC_CALLS",0)-old.get("HEADCALC_CALLS",0),
 "backtracking_attempts":new.get("BACKTRACK",0)-old.get("BACKTRACK",0),
 "runtime_median_seconds":out["corrected"]["runtime_median_seconds_5_runs"]-out["old"]["runtime_median_seconds_5_runs"]
}
if "MASS_RESIDUAL" in old and "MASS_RESIDUAL" in new:
    out["delta"]["mass_residual"]=new["MASS_RESIDUAL"]-old["MASS_RESIDUAL"]
if "TOTAL_IN" in old and "TOTAL_IN" in new:
    out["delta"]["total_in"]=new["TOTAL_IN"]-old["TOTAL_IN"]
if "TOTAL_OUT" in old and "TOTAL_OUT" in new:
    out["delta"]["total_out"]=new["TOTAL_OUT"]-old["TOTAL_OUT"]
Path(sys.argv[5]).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
print(json.dumps(out,indent=2,sort_keys=True))
assert new.get("PROCESS_SUCCESS",False), "corrected adaptive candidate did not complete"
assert abs(new["MASS_RESIDUAL"]) <= 1e-8
if old.get("PROCESS_SUCCESS",False):
    assert abs(old["MASS_RESIDUAL"]) <= 1e-8
print("F_PE_BOFEK00_ADAPTIVE_COMPARISON=PASS")
PY

cat "$BUILD/summary.json"
echo "F_PE_BOFEK00_ADAPTIVE_GATE=PASS"

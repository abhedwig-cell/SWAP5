#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=0b67e2af993f16e9d1678b70cacfe9b164954140
TARGET=tests/verification/test_bofek00_adaptive_wet_application.f90
COMPILER="$ROOT/tests/rom/compile_f_rom0_fortran_closure.py"
MATERIALIZER="$ROOT/tests/rom/materialize_f_rom0_headcalc_stubs.py"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-adaptive-ladder-${GITHUB_RUN_ID:-local}-$$"
OLD="$BUILD/old"
mkdir -p "$BUILD"
trap 'git worktree remove --force "$OLD" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_ADAPTIVE_LADDER_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin "$AUTH"
git merge-base --is-ancestor "$AUTH" HEAD || fail "candidate lost preregistered authority"
git worktree add --detach "$OLD" "$AUTH" >/dev/null
mkdir -p "$OLD/tests/verification"
cp "$TARGET" "$OLD/$TARGET"

compile_one(){
  local label="$1"
  local root="$2"
  local out="$BUILD/$label"
  mkdir -p "$out"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$out/stubs.f90" --nodes 16 --dz-cm 10
  cp "$out/stubs.f90" "$root/tests/verification/bofek00_generated_stubs.f90"
  python3 "$COMPILER" --root "$root"     --stub tests/verification/bofek00_generated_stubs.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --target "$TARGET" --build "$out/compile" --opt 2
  rm -f "$root/tests/verification/bofek00_generated_stubs.f90"
}

compile_one old "$OLD"
compile_one corrected "$ROOT"

for seconds in 10 20 40 80 160 320; do
  for label in old corrected; do
    out="$BUILD/$label"
    /usr/bin/time -f '%e' -o "$out/time_${seconds}.txt"       "$out/compile/rom0_test" "$seconds" > "$out/result_${seconds}.txt" 2>&1 || {
        cat "$out/result_${seconds}.txt" >&2
        fail "$label runtime at ${seconds}s"
      }
    grep -Fq 'F_PE_BOFEK00_ADAPTIVE_WET_APPLICATION=OBSERVED' "$out/result_${seconds}.txt" ||       fail "$label missing observation at ${seconds}s"
  done
done

python3 - "$BUILD" "$BUILD/summary.json" <<'PY'
import json,sys
from pathlib import Path

root=Path(sys.argv[1])
durations=[10,20,40,80,160,320]
ints={"STATUS","KERNEL_STATUS","ACCEPTED_SUBSTEPS","SOLVER_ITERATIONS","NONLINEAR","INTERNAL_RETRIES",
      "HEADCALC_CALLS","JACOBIAN_BUILDS","LINEAR_SOLVES","BACKTRACK","ALT_SOLVER"}
bools={"COMPLETED","COMMITTED","MASS_COMPLETE"}

def parse(label,seconds):
    p=root/label/f"result_{seconds}.txt"
    line=next(x for x in p.read_text().splitlines() if x.startswith("BOFEK00_ADAPTIVE|"))
    row={"duration_seconds":seconds}
    for item in line.split("|")[1:]:
        k,v=item.split("=",1)
        if k in ints:
            row[k]=int(float(v))
        elif k in bools:
            row[k]=v.strip().upper().startswith("T")
        else:
            row[k]=float(v)
    row["runtime_seconds"]=float((root/label/f"time_{seconds}.txt").read_text().strip())
    return row

old=[parse("old",s) for s in durations]
new=[parse("corrected",s) for s in durations]
rows=[]
for o,n in zip(old,new):
    if n["COMPLETED"] and not o["COMPLETED"]:
        cls="CORRECTED_ACCEPTS_WHERE_OLD_FAILS"
    elif n["COMPLETED"] and o["COMPLETED"]:
        cls="BOTH_ACCEPT"
    elif (not n["COMPLETED"]) and (not o["COMPLETED"]):
        cls="BOTH_FAIL"
    else:
        cls="OLD_ACCEPTS_CORRECTED_FAILS"
    if o["MASS_COMPLETE"]:
        assert abs(o["MASS_RESIDUAL"]) <= 1e-8
    if n["MASS_COMPLETE"]:
        assert abs(n["MASS_RESIDUAL"]) <= 1e-8
    rows.append({
      "duration_seconds":o["duration_seconds"],
      "classification":cls,
      "old":o,
      "corrected":n,
      "delta":{
        "accepted_substeps":n["ACCEPTED_SUBSTEPS"]-o["ACCEPTED_SUBSTEPS"],
        "nonlinear_iterations":n["NONLINEAR"]-o["NONLINEAR"],
        "internal_retries":n["INTERNAL_RETRIES"]-o["INTERNAL_RETRIES"],
        "headcalc_calls":n["HEADCALC_CALLS"]-o["HEADCALC_CALLS"],
        "backtracks":n["BACKTRACK"]-o["BACKTRACK"],
        "runtime_seconds":n["runtime_seconds"]-o["runtime_seconds"],
        "runoff_cm":(n["TOTAL_OUT"]-o["TOTAL_OUT"]) if n["MASS_COMPLETE"] and o["MASS_COMPLETE"] else None
      }
    })

out={
 "work_unit":"F-PE-BOFEK00F",
 "qualification_ladder_seconds":durations,
 "policy":{
   "temporal_mode":"TX_TEMPORAL_EXTERNAL_FULL_HALF",
   "temporal_tolerance":1e-6,
   "mass_tolerance":1e-10,
   "retry_scale":0.5,
   "max_retries":8,
   "max_committed_substeps":256,
   "identical_old_corrected":True
 },
 "rows":rows,
 "exact_dt_distribution_available":False,
 "exact_dt_distribution_limitation":"Public application result exposes accepted substep count but not accepted dt sequence.",
 "policy_authority_finding":{
   "serialized_reference_temporal_error":"fmr_serialized_temporal_identity returns zero only for exact full/two-half physical-state identity and huge otherwise.",
   "implication":"For nontrivial Richards evolution, external full/half acceptance can fail independently of the wet-boundary correctness patch."
 }
}
Path(sys.argv[2]).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
print(json.dumps(out,indent=2,sort_keys=True))
print("F_PE_BOFEK00_ADAPTIVE_LADDER=PASS")
PY

cat "$BUILD/summary.json"
echo "F_PE_BOFEK00_ADAPTIVE_LADDER_GATE=PASS"
